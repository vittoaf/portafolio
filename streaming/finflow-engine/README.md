# FinFlow-Engine: Low-Cost Idempotent Financial Streaming on GCP

Proyecto completo de streaming para procesamiento de transacciones financieras con Pub/Sub, Dead-Letter Queue (DLQ), PySpark y BigQuery.

## Arquitectura
1. **Producer**: Publica eventos de transacciones financieras en JSON con deduplication keys (`transaction_id`, `payload_hash`).
2. **Pub/Sub Topic & DLQ**: Desacopla la ingesta y redirige eventos corruptos o no procesables tras 5 intentos fallidos a un Dead-Letter Topic.
3. **PySpark Structured Streaming**: Ingesta continua o micro-batching con control de checkpoints en GCS.
4. **BigQuery Storage & Deduplication**: Almacena en crudo particionado (`transactions_raw`) y provee una vista (`transactions_gold_dedup`) con deduplicación idempotente vía `QUALIFY ROW_NUMBER()`.

## Estructura
```text
finflow-engine/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── producer/
│   ├── requirements.txt
│   └── stream_producer.py
├── streaming_job/
│   ├── requirements.txt
│   └── spark_streaming_consumer.py
│   .gitignore
└── README.md
```

## Despliegue y Flujo de Ejecución

### 1. Desplegar Infraestructura (Terraform)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Modificar project_id en terraform.tfvars
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

### 2. Subir el Script de Spark a Cloud Storage
```bash
export PROJECT_ID="tu-gcp-project-id"
export REGION="us-central1"

gcloud storage cp ../streaming_job/spark_streaming_consumer.py gs://finflow-spark-artifacts-${PROJECT_ID}/
```

### 3. Ejecutar el Consumidor Spark (`spark_streaming_consumer.py`)
Inicia el consumidor en Dataproc Serverless (o clúster efímero) para que quede escuchando la suscripción de Pub/Sub:
```bash
gcloud dataproc batches submit pyspark gs://finflow-spark-artifacts-${PROJECT_ID}/spark_streaming_consumer.py \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --service-account="finflow-spark-executor@${PROJECT_ID}.iam.gserviceaccount.com" \
    --version="2.2" \
    --ttl="10m" \
    -- \
    "${PROJECT_ID}" \
    "finflow-transactions-spark-sub" \
    "finflow_analytics_dev.transactions_raw" \
    "gs://finflow-spark-checkpoints-${PROJECT_ID}"
```

### 4. Ejecutar el Productor (Simulación)
En otra terminal local, levanta el productor para emitir transacciones en streaming:
```bash
cd ../producer
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

export PROJECT_ID="tu-gcp-project-id"
export TOPIC_ID="finflow-transactions-main"
python stream_producer.py
```

### 5. Verificar Idempotencia y DLQ

**Validar mensajes corruptos en DLQ:**
```bash
gcloud pubsub subscriptions pull finflow-transactions-dlq-sub --auto-ack --limit=5
```

**Validar deduplicación en BigQuery:**
```sql
-- Validar deduplicación en la vista Gold
SELECT transaction_id, count(*) as count
FROM `tu-gcp-project-id.finflow_analytics_dev.transactions_gold_dedup`
GROUP BY transaction_id
HAVING count > 1; -- Debe devolver 0 registros
```

---

## Destrucción y Limpieza (Desinstalación)
```bash
cd ../terraform
terraform destroy -auto-approve
```

En Cloud Storage quedarán dos buckets que Dataproc los crea de manera automática y no son gestionados por Terraform.
Asegúrate de elminarlos, tendrán nombres similar a gs://dataproc-staging-us-central1 y gs://dataproc-temp-us-central1.

```bash
# Eliminarlos junto con su contenido
gcloud storage rm --recursive gs://dataproc-staging-us-central1-*
gcloud storage rm --recursive gs://dataproc-temp-us-central1-*
```