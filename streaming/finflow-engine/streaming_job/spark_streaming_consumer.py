import sys
import json
from google.cloud import pubsub_v1
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, DoubleType

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

    spark = build_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    schema = StructType([
        StructField("transaction_id", StringType(), False),
        StructField("account_id", StringType(), False),
        StructField("customer_id", StringType(), False),
        StructField("amount", DoubleType(), False),
        StructField("currency", StringType(), False),
        StructField("transaction_type", StringType(), False),
        StructField("channel", StringType(), False),
        StructField("status", StringType(), False),
        StructField("merchant_name", StringType(), True),
        StructField("event_timestamp", StringType(), False),
        StructField("payload_hash", StringType(), False)
    ])

    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(project_id, subscription_id)

    print(f"[*] Escuchando suscripcion Pub/Sub: {subscription_path}")

    # Pull sincrónico por lotes (micro-batch)
    response = subscriber.pull(
        request={"subscription": subscription_path, "max_messages": 500},
        timeout=10.0
    )

    messages = response.received_messages
    if not messages:
        print("[INFO] No se encontraron mensajes pendientes en Pub/Sub.")
        spark.stop()
        return

    print(f"[INFO] Procesando {len(messages)} mensajes recibidos...")

    records = []
    ack_ids = []

    for msg in messages:
        try:
            payload_str = msg.message.data.decode("utf-8")
            data = json.loads(payload_str)
            # Validación básica de estructura
            if "transaction_id" in data and "amount" in data:
                records.append(data)
                ack_ids.append(msg.ack_id)
            else:
                # Esquema inválido: no hacer ack para permitir que Pub/Sub lo envíe al DLQ tras max_delivery_attempts
                print(f"[WARN] Mensaje con esquema inválido: {data}")
        except Exception as e:
            # Mensajes no parseables (corruptos): se omiten para enrutamiento a DLQ
            print(f"[DLQ] Error decodificando payload: {e}")

    if records:
        df = spark.createDataFrame(records, schema=schema)

        # Idempotencia intra-batch
        deduped_df = (
            df.dropDuplicates(["transaction_id"])
            .withColumn("event_timestamp", to_timestamp(col("event_timestamp")))
            .withColumn("ingestion_timestamp", current_timestamp())
        )

        temp_bucket = checkpoint_dir.replace("gs://", "").split("/")[0]

        # Escritura nativa en BigQuery sin necesidad de JARs externos
        (
            deduped_df.write
            .format("bigquery")
            .option("table", f"{project_id}:{bq_table}")
            .option("temporaryGcsBucket", temp_bucket)
            .mode("append")
            .save()
        )

        print(f"[SUCCESS] {deduped_df.count()} registros persistidos exitosamente en BigQuery.")

        # Confirmar recepción (ACK) solo tras persistencia exitosa en BigQuery
        subscriber.acknowledge(
            request={"subscription": subscription_path, "ack_ids": ack_ids}
        )
        print(f"[ACK] {len(ack_ids)} mensajes confirmados en Pub/Sub.")

    spark.stop()

if __name__ == "__main__":
    main()