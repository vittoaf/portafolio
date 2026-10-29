import sys
import json
from decimal import Decimal
from google.api_core.exceptions import DeadlineExceeded
from google.cloud import pubsub_v1
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, DecimalType
from pyspark.sql.types import TimestampType

def build_spark_session(app_name="FinFlow-Streaming"):
    return (
        SparkSession.builder
        .appName(app_name)
        .getOrCreate()
    )

def main():
    if len(sys.argv) < 5:
        print("Uso: spark_streaming_consumer.py <PROJECT_ID> <SUBSCRIPTION_ID> <BQ_TABLE> <CHECKPOINT_DIR>")
        sys.exit(1)

    project_id = sys.argv[1]
    subscription_id = sys.argv[2]
    bq_table = sys.argv[3]
    checkpoint_dir = sys.argv[4]

    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(project_id, subscription_id)

    print(f"[*] Escuchando suscripcion Pub/Sub: {subscription_path}")

    # Intentar obtener mensajes con captura de cola vacía (DeadlineExceeded)
    try:
        response = subscriber.pull(
            request={"subscription": subscription_path, "max_messages": 500},
            timeout=5.0
        )
        messages = response.received_messages
    except DeadlineExceeded:
        print("[INFO] No hay mensajes nuevos en Pub/Sub (Timeout alcanzado). Finalizando ejecucion limpiamente.")
        messages = []
    except Exception as e:
        print(f"[ERROR] Error inesperado consultando Pub/Sub: {e}")
        messages = []

    if not messages:
        print("[INFO] Cero mensajes pendientes por procesar. Apagando batch.")
        return

    # Inicializar Spark únicamente si hay datos por procesar
    spark = build_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    print(f"[INFO] Procesando {len(messages)} mensajes recibidos...")

    schema = StructType([
        StructField("transaction_id", StringType(), False),
        StructField("account_id", StringType(), False),
        StructField("customer_id", StringType(), False),
        StructField("amount", DecimalType(38, 9), False),
        StructField("currency", StringType(), False),
        StructField("transaction_type", StringType(), False),
        StructField("channel", StringType(), False),
        StructField("status", StringType(), False),
        StructField("merchant_name", StringType(), True),
        StructField("event_timestamp", StringType(), False),
        StructField("payload_hash", StringType(), False)
    ])

    records = []
    ack_ids = []

    for msg in messages:
        try:
            payload_str = msg.message.data.decode("utf-8")
            data = json.loads(payload_str)
            if "transaction_id" in data and "amount" in data:
                data["amount"] = Decimal(str(data["amount"]))
                records.append(data)
                ack_ids.append(msg.ack_id)
            else:
                print(f"[WARN] Mensaje con esquema invalido: {data}")
        except Exception as e:
            print(f"[DLQ] Error decodificando payload corrupto: {e}")

    if records:
        df = spark.createDataFrame(records, schema=schema)

        deduped_df = (
            df.dropDuplicates(["transaction_id"])
            .withColumn("event_timestamp", to_timestamp(col("event_timestamp")))
            .withColumn("ingestion_timestamp", current_timestamp())
        )

        final_schema = StructType([
                StructField("transaction_id", StringType(), False),
                StructField("account_id", StringType(), False),
                StructField("customer_id", StringType(), False),
                StructField("amount", DecimalType(38, 9), False),
                StructField("currency", StringType(), False),
                StructField("transaction_type", StringType(), False),
                StructField("channel", StringType(), False),
                StructField("status", StringType(), False),
                StructField("merchant_name", StringType(), True),  # NULLABLE en BQ
                StructField("event_timestamp", TimestampType(), False),  # REQUIRED en BQ
                StructField("payload_hash", StringType(), False),
                StructField("ingestion_timestamp", TimestampType(), False)  # REQUIRED en BQ
            ])

        final_df = spark.createDataFrame(deduped_df.rdd, schema=final_schema)
        temp_bucket = checkpoint_dir.replace("gs://", "").split("/")[0]

        (
            final_df.write
            .format("bigquery")
            .option("table", f"{project_id}:{bq_table}")
            .option("temporaryGcsBucket", temp_bucket)
            .mode("append")
            .save()
        )

        print(f"[SUCCESS] {final_df.count()} registros persistidos exitosamente en BigQuery.")

        subscriber.acknowledge(
            request={"subscription": subscription_path, "ack_ids": ack_ids}
        )
        print(f"[ACK] {len(ack_ids)} mensajes confirmados en Pub/Sub.")

    spark.stop()

if __name__ == "__main__":
    main()