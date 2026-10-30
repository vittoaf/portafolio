import sys
import json
from decimal import Decimal
import time
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
    messages = []
    print("[*] Vaciando cola de Pub/Sub...")
    
    empty_retries = 0
    max_empty_retries = 2

    while empty_retries < max_empty_retries:
        try:
            response = subscriber.pull(
                request={"subscription": subscription_path, "max_messages": 300},
                timeout=10.0  # Tiempo suficiente para la negociación gRPC de GCP
            )
            batch = response.received_messages
            if batch:
                messages.extend(batch)
                print(f"[+] Lote extraído: {len(batch)} mensajes (Total acumulado: {len(messages)})")
                empty_retries = 0  # Reiniciar contador si hubo mensajes
                time.sleep(0.5)    # Breve respiro para sincronizar buffers del broker
            else:
                empty_retries += 1
                time.sleep(2.0)
        except DeadlineExceeded:
            empty_retries += 1
            print(f"[INFO] Intento {empty_retries}/{max_empty_retries}: Timeout de lectura (esperando mensajes en tránsito)...")
            time.sleep(2.0)
        except Exception as e:
            print(f"[WARN] Error en lectura: {e}")
            break

    print(f"[INFO] Total de mensajes capturados para este batch: {len(messages)}")

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