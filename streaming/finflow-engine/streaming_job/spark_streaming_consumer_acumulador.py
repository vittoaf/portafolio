import sys
import json
import time
import logging
from datetime import datetime, timezone
from decimal import Decimal

from google.api_core.exceptions import DeadlineExceeded
from google.cloud import pubsub_v1
from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, DecimalType, TimestampType
)

# ---------------- Configuración ----------------
FLUSH_SIZE = 1000          # escribir a BQ cada N registros únicos
MAX_TOTAL_MESSAGES = 0     # tope de mensajes a consumir (0 = sin tope, vaciar todo)
MAX_TOTAL_SECONDS = 300    # tope de tiempo de ejecución
MAX_EMPTY_RETRIES = 2      # pulls vacíos seguidos antes de considerar cola vacía
PULL_BATCH_SIZE = 300
ACK_CHUNK_SIZE = 1000      # límite de ack_ids por request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    stream=sys.stdout,
)
logger = logging.getLogger("finflow-consumer")

REQUIRED_FIELDS = [
    "transaction_id", "account_id", "customer_id", "amount", "currency",
    "transaction_type", "channel", "status", "event_timestamp", "payload_hash",
]

# Esquema final igual al de BigQuery (REQUIRED = nullable False)
SCHEMA = StructType([
    StructField("transaction_id", StringType(), False),
    StructField("account_id", StringType(), False),
    StructField("customer_id", StringType(), False),
    StructField("amount", DecimalType(38, 9), False),
    StructField("currency", StringType(), False),
    StructField("transaction_type", StringType(), False),
    StructField("channel", StringType(), False),
    StructField("status", StringType(), False),
    StructField("merchant_name", StringType(), True),            # NULLABLE en BQ
    StructField("event_timestamp", TimestampType(), False),      # REQUIRED en BQ
    StructField("payload_hash", StringType(), False),
    StructField("ingestion_timestamp", TimestampType(), False),  # REQUIRED en BQ
])


def get_spark():
    logger.info("Inicializando sesión de Spark...")
    spark = SparkSession.builder.appName("FinFlow-Streaming").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")
    logger.info("Sesión de Spark lista.")
    return spark


def parse_message(raw: bytes) -> dict:
    """Decodifica, valida campos requeridos y convierte tipos.
    Lanza excepción si el mensaje es inválido."""
    data = json.loads(raw.decode("utf-8"))

    missing = [f for f in REQUIRED_FIELDS if data.get(f) is None]
    if missing:
        raise ValueError(f"campos requeridos faltantes o nulos: {missing}")

    data["amount"] = Decimal(str(data["amount"]))

    ts = datetime.fromisoformat(str(data["event_timestamp"]).replace("Z", "+00:00"))
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    data["event_timestamp"] = ts

    # Solo las columnas del esquema (ignora campos extra del JSON)
    return {
        "transaction_id": str(data["transaction_id"]),
        "account_id": str(data["account_id"]),
        "customer_id": str(data["customer_id"]),
        "amount": data["amount"],
        "currency": str(data["currency"]),
        "transaction_type": str(data["transaction_type"]),
        "channel": str(data["channel"]),
        "status": str(data["status"]),
        "merchant_name": data.get("merchant_name"),
        "event_timestamp": data["event_timestamp"],
        "payload_hash": str(data["payload_hash"]),
    }


def flush(spark, subscriber, sub_path, records, ack_ids,
          project_id, bq_table, temp_bucket, flush_num):
    """Escribe el lote en BigQuery y SOLO si funciona, hace ack."""
    logger.info("---- FLUSH #%d: %d registros únicos, %d mensajes por confirmar ----",
                flush_num, len(records), len(ack_ids))
    t0 = time.time()

    if records:
        ingestion_ts = datetime.now(timezone.utc)
        rows = [{**r, "ingestion_timestamp": ingestion_ts} for r in records.values()]
        df = spark.createDataFrame(rows, schema=SCHEMA)

        logger.info("Escribiendo en BigQuery: tabla=%s:%s bucket temporal=%s",
                    project_id, bq_table, temp_bucket)
        try:
            (
                df.write.format("bigquery")
                .option("table", f"{project_id}:{bq_table}")
                .option("temporaryGcsBucket", temp_bucket)
                .mode("append")
                .save()
            )
        except Exception as e:
            logger.warning("Falló la escritura en BigQuery. NO se confirman los mensajes "
                           "(volverán a la cola): %s", e)
            raise
        logger.info("%d registros escritos en BigQuery en %.1f s.",
                    len(records), time.time() - t0)
    else:
        logger.warning("Flush sin registros válidos; solo se confirmarán mensajes descartados.")

    ids = list(ack_ids)
    for i in range(0, len(ids), ACK_CHUNK_SIZE):
        chunk = ids[i:i + ACK_CHUNK_SIZE]
        subscriber.acknowledge(request={"subscription": sub_path, "ack_ids": chunk})
        logger.info("ACK enviado: %d mensajes (%d/%d)", len(chunk),
                    min(i + ACK_CHUNK_SIZE, len(ids)), len(ids))
    logger.info("---- FLUSH #%d completado ----", flush_num)


def main():
    if len(sys.argv) < 5:
        logger.warning("Uso: spark_streaming_consumer.py <PROJECT_ID> <SUBSCRIPTION_ID> <BQ_TABLE> <CHECKPOINT_DIR>")
        sys.exit(1)

    project_id, subscription_id, bq_table, checkpoint_dir = sys.argv[1:5]
    temp_bucket = checkpoint_dir.replace("gs://", "").split("/")[0]

    subscriber = pubsub_v1.SubscriberClient()
    sub_path = subscriber.subscription_path(project_id, subscription_id)

    logger.info("Iniciando consumidor. Suscripción: %s", sub_path)
    logger.info("Config: FLUSH_SIZE=%d, MAX_TOTAL_MESSAGES=%s, MAX_TOTAL_SECONDS=%d, MAX_EMPTY_RETRIES=%d",
                FLUSH_SIZE, MAX_TOTAL_MESSAGES or "sin tope", MAX_TOTAL_SECONDS, MAX_EMPTY_RETRIES)

    spark = None
    records = {}       # transaction_id -> dict (dedupe automático)
    ack_ids = set()    # incluye válidos, duplicados y corruptos
    empty_retries = 0
    start = time.time()

    total_received = 0
    total_written = 0
    total_invalid = 0
    total_duplicates = 0
    flush_count = 0
    stop_reason = "cola vacía"

    while True:
        elapsed = time.time() - start
        if elapsed >= MAX_TOTAL_SECONDS:
            stop_reason = f"tope de tiempo ({MAX_TOTAL_SECONDS}s)"
            logger.warning("Se alcanzó el tope de tiempo. Deteniendo lectura.")
            break
        if MAX_TOTAL_MESSAGES and total_received >= MAX_TOTAL_MESSAGES:
            stop_reason = f"tope de mensajes ({MAX_TOTAL_MESSAGES})"
            logger.warning("Se alcanzó el tope de mensajes. Deteniendo lectura.")
            break
        if empty_retries >= MAX_EMPTY_RETRIES:
            logger.info("Cola vacía tras %d intentos consecutivos.", empty_retries)
            break

        try:
            resp = subscriber.pull(
                request={"subscription": sub_path, "max_messages": PULL_BATCH_SIZE},
                timeout=10.0,
            )
        except DeadlineExceeded:
            empty_retries += 1
            logger.info("Timeout de lectura (%d/%d), sin mensajes por ahora...",
                        empty_retries, MAX_EMPTY_RETRIES)
            continue
        except Exception as e:
            logger.warning("Error en pull: %s", e)
            stop_reason = "error en pull"
            break

        if not resp.received_messages:
            empty_retries += 1
            logger.info("Pull vacío (%d/%d). Esperando...", empty_retries, MAX_EMPTY_RETRIES)
            time.sleep(2)
            continue

        empty_retries = 0
        batch_size = len(resp.received_messages)
        total_received += batch_size
        logger.info("Lote recibido: %d mensajes (total recibido: %d, pendientes de flush: %d)",
                    batch_size, total_received, len(records))

        for msg in resp.received_messages:
            ack_ids.add(msg.ack_id)  # se confirma igual (válido, duplicado o corrupto)
            try:
                data = parse_message(msg.message.data)
                tid = data["transaction_id"]
                if tid in records:
                    total_duplicates += 1
                    logger.warning("Duplicado ignorado: transaction_id=%s", tid)
                records[tid] = data
            except Exception as e:
                total_invalid += 1
                logger.warning("Mensaje inválido o corrupto (DLQ): %s", e)

        if len(records) >= FLUSH_SIZE:
            spark = spark or get_spark()
            flush_count += 1
            written = len(records)
            flush(spark, subscriber, sub_path, records, ack_ids,
                  project_id, bq_table, temp_bucket, flush_count)
            total_written += written
            records.clear()
            ack_ids.clear()

    # Flush final
    if records or ack_ids:
        logger.info("Realizando flush final (motivo de parada: %s)...", stop_reason)
        spark = spark or get_spark()
        flush_count += 1
        written = len(records)
        flush(spark, subscriber, sub_path, records, ack_ids,
              project_id, bq_table, temp_bucket, flush_count)
        total_written += written
    else:
        logger.info("No quedaron mensajes pendientes por escribir.")

    if spark:
        spark.stop()
        logger.info("Sesión de Spark cerrada.")

    logger.info("================ RESUMEN ================")
    logger.info("Motivo de parada     : %s", stop_reason)
    logger.info("Duración             : %.1f s", time.time() - start)
    logger.info("Mensajes recibidos   : %d", total_received)
    logger.info("Registros escritos   : %d", total_written)
    logger.info("Duplicados en lote   : %d", total_duplicates)
    logger.info("Inválidos/corruptos  : %d", total_invalid)
    logger.info("Flushes realizados   : %d", flush_count)
    logger.info("=========================================")


if __name__ == "__main__":
    main()