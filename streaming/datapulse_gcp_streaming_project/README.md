# DataPulse GCP: Ingesta Streaming Zero-Compute (Pub/Sub direct to BigQuery)

Proyecto cloud nativo de arquitectura **Zero-Compute** en Google Cloud Platform (GCP). Diseñado para ingesta de datos en tiempo real de bajo costo ($0 a $3 USD/mes en tiers gratuitos) sin desplegar servidores ni pipelines de Dataflow/Cloud Functions.

---

## 1. Arquitectura de la Solución

```
   [Productor Python (Simulador)]
                 │
                 ▼ (JSON Event Payload)
     [Cloud Pub/Sub: Topic]
                 │
                 ▼ (BigQuery Direct Subscription - Zero-Compute)
  [BigQuery Raw Partitioned Table (Bronze)]
                 │
                 ▼ (SQL Window Function / ELT Transformation)
 [BigQuery Deduplicated Clean View (Silver)]
```

### Componentes Clave:
1. **Google Cloud Pub/Sub:** Recibe y desacopla eventos en streaming.
2. **BigQuery Subscription:** Escribe directamente desde Pub/Sub a BigQuery con cero intermediarios de cómputo.
3. **BigQuery Partitioned Table (Bronze):** Particionada diariamente por `published_at` y clustered por `status` y `customer_id` para optimizar costos de scan.
4. **Vista de Deduplicación (Silver):** Implementa deduplicación determinista (`ROW_NUMBER() OVER PARTITION BY order_id`) garantizando **idempotencia** ante reintentos de red o entregas *at-least-once*.

---

## 2. Estructura del Proyecto

```text
datapulse-gcp/
├── README.md                           # Documentacion completa de ejecucion
├── sql/
│   └── deduplicate_orders.sql.tpl      # SQL de deduplicacion para la capa Silver
├── terraform/
│   ├── main.tf                         # Recursos GCP, APIs, IAM y suscripcion directa
│   ├── variables.tf                    # Definicion estricta de variables parametrizadas
│   ├── terraform.tfvars                # Valores de variables especificos del entorno
│   └── outputs.tf                      # Identificadores de recursos resultantes
└── producer/
    ├── requirements.txt                # Dependencias Python (google-cloud-pubsub)
    └── producer.py                     # Generador y publicador de eventos streaming
```

---

## 3. Prerrequisitos

1. **Google Cloud SDK (`gcloud` CLI):** Instalado y autenticado.
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```
2. **Terraform:** `>= 1.5.0`
3. **Python:** `>= 3.9` con `pip` y `venv`

---

## 4. Despliegue de Infraestructura con Terraform

### Paso 1: Configurar Variables
Edita el archivo `terraform/terraform.tfvars` y reemplaza el ID de tu proyecto:
```hcl
project_id               = "tu-proyecto-gcp-id"
region                   = "us-central1"
bq_location              = "US"
bq_dataset_id            = "ds_ecommerce_raw"
bq_table_id              = "raw_orders_stream"
pubsub_topic_name        = "top_ecommerce_orders"
pubsub_subscription_name = "sub_ecommerce_orders_to_bq"
```

### Paso 2: Inicializar y Aplicar
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

*Terraform habilitará automáticamente las APIs (`pubsub`, `bigquery`), creará el tópico, el dataset, la tabla con particiones, asignará el rol `roles/bigquery.dataEditor` al Service Agent de Pub/Sub y montará la vista Silver.*

---

## 5. Simulación de Streaming con Python

### Paso 1: Configurar el Entorno Virtual
Desde la raíz del proyecto:
```bash
cd producer
python -m venv venv

# En Linux/macOS:
source venv/bin/activate

# En Windows (CMD/PowerShell):
.\venv\Scripts\activate

pip install -r requirements.txt
```

### Paso 2: Ejecutar el Productor
Ejecuta la simulación pasando el ID de tu proyecto:

```bash
# Enviar 20 eventos con inyeccion intencional de duplicados para probar la capa Silver
python producer.py --project_id "tu-proyecto-gcp-id" --count 20 --interval 0.8 --simulate_duplicates --simulate_corrupt

# O ejecucion continua en segundo plano (Ctrl+C para salir):
python producer.py --project_id "tu-proyecto-gcp-id" --count 0 --interval 1.5
```

---

## 6. Validación de Datos e Idempotencia en BigQuery

Entra a la consola de **BigQuery** en GCP y ejecuta las siguientes consultas:

### A. Inspeccionar la ingesta cruda (Bronze):
```sql
SELECT 
  order_id, 
  status, 
  total_amount, 
  published_at 
FROM `tu-proyecto-gcp-id.ds_ecommerce_raw.raw_orders_stream`
ORDER BY published_at DESC 
LIMIT 20;
```

### B. Validar la Deduplicación Idempotente (Silver):
Si el simulador envió duplicados del mismo `order_id`, la tabla cruda tendrá múltiples filas, pero la vista mantendrá exactamente un registro consistente por cada transacción:
```sql
SELECT 
  order_id, 
  COUNT(*) as repeticiones
FROM `tu-proyecto-gcp-id.ds_ecommerce_raw.vw_silver_orders_clean`
GROUP BY order_id
HAVING repeticiones > 1;
-- Retornara 0 filas, confirmando idempotencia.
```

---

## 7. Desinstalación y Limpieza (Tear Down)

Para eliminar absolutamente todos los recursos de GCP y evitar cualquier cargo:

```bash
cd terraform
terraform destroy -auto-approve
```
