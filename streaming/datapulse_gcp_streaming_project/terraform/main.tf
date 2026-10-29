terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------
# Enable Required Google Cloud APIs
# ---------------------------------------------------------
resource "google_project_service" "enabled_apis" {
  for_each = toset([
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# ---------------------------------------------------------
# BigQuery Dataset & Tables (Bronze / Raw Ingestion)
# ---------------------------------------------------------
resource "google_bigquery_dataset" "ecommerce_raw" {
  dataset_id                 = var.bq_dataset_id
  friendly_name              = "E-Commerce Raw Ingestion Dataset"
  description                = "Almacena los eventos crudos provenientes directamente de Pub/Sub (Zero-Compute)."
  location                   = var.bq_location
  delete_contents_on_destroy = true

  depends_on = [google_project_service.enabled_apis]
}

# Tabla Principal Raw particionada por día y con clustering
resource "google_bigquery_table" "raw_orders" {
  dataset_id          = google_bigquery_dataset.ecommerce_raw.dataset_id
  table_id            = var.bq_table_id
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "published_at"
  }

  clustering = ["status", "customer_id"]

  schema = jsonencode([
    {
      name        = "order_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Identificador unico de la transaccion"
    },
    {
      name        = "customer_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Identificador unico del cliente"
    },
    {
      name        = "event_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Timestamp de generacion del evento en el productor"
    },
    {
      name        = "published_at"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Timestamp de llegada/publicacion a Pub/Sub utilizado para particionamiento"
    },
    {
      name        = "status"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Estado de la orden (COMPLETED, PENDING, CANCELLED)"
    },
    {
      name        = "total_amount"
      type        = "NUMERIC"
      mode        = "REQUIRED"
      description = "Monto monetario de la orden"
    },
    {
      name        = "currency"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Moneda de la transaccion (e.g. USD, PEN)"
    },
    {
      name        = "items"
      type        = "RECORD"
      mode        = "REPEATED"
      description = "Listado anidado de productos en la orden"
      fields = [
        {
          name = "product_id"
          type = "STRING"
          mode = "REQUIRED"
        },
        {
          name = "quantity"
          type = "INTEGER"
          mode = "REQUIRED"
        },
        {
          name = "unit_price"
          type = "NUMERIC"
          mode = "REQUIRED"
        }
      ]
    },
    {
      name        = "raw_metadata"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Payload JSON o atributos adicionales de auditoria"
    }
  ])

  depends_on = [google_bigquery_dataset.ecommerce_raw]
}

# Tabla Dead-Letter Queue (DLQ) para capturar mensajes con schema mismatch
resource "google_bigquery_table" "raw_orders_dlq" {
  dataset_id          = google_bigquery_dataset.ecommerce_raw.dataset_id
  table_id            = "${var.bq_table_id}_dlq"
  deletion_protection = false

  time_partitioning {
    type = "DAY"
  }

  schema = jsonencode([
    {
      name = "subscription_name"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "message_id"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "publish_time"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    },
    {
      name = "data"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "attributes"
      type = "STRING"
      mode = "NULLABLE"
    }
  ])

  depends_on = [google_bigquery_dataset.ecommerce_raw]
}

# ---------------------------------------------------------
# Pub/Sub Topic & Service Agent IAM
# ---------------------------------------------------------
resource "google_pubsub_topic" "orders_topic" {
  name                       = var.pubsub_topic_name
  message_retention_duration = "86400s" # 24 horas

  depends_on = [google_project_service.enabled_apis]
}

# Permisos para la Service Account gestionada de Pub/Sub en BigQuery
data "google_project" "project" {
  project_id = var.project_id
}

# La cuenta de servicio interna de Pub/Sub: service-{PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com
resource "google_project_iam_member" "pubsub_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "pubsub_bigquery_metadata_viewer" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ---------------------------------------------------------
# BigQuery Subscription (Zero-Compute Direct Streaming)
# ---------------------------------------------------------
# 1. Tópico secundario para almacenar los mensajes fallidos (Dead-Letter Topic)
resource "google_pubsub_topic" "orders_dlq_topic" {
  name                       = "${var.pubsub_topic_name}-dlq"
  message_retention_duration = "604800s" # 7 días de retención para análisis
}

# 2. Permisos IAM para que Pub/Sub pueda reenviar mensajes al tópico DLQ
resource "google_pubsub_topic_iam_member" "pubsub_publisher_dlq" {
  topic  = google_pubsub_topic.orders_dlq_topic.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# 3. Suscripción directa del tópico DLQ hacia la tabla raw_orders_dlq
resource "google_pubsub_subscription" "bq_dlq_subscription" {
  name  = "${var.pubsub_subscription_name}-dlq-to-bq"
  topic = google_pubsub_topic.orders_dlq_topic.id

  bigquery_config {
    table          = "${var.project_id}:${google_bigquery_dataset.ecommerce_raw.dataset_id}.${google_bigquery_table.raw_orders_dlq.table_id}"
    write_metadata = true # Guarda message_id, publish_time y attributes automáticamente
  }

  depends_on = [
    google_bigquery_table.raw_orders_dlq,
    google_project_iam_member.pubsub_bigquery_data_editor
  ]
}

# Permiso INDISPENSABLE para que Pub/Sub pueda confirmar (ACK) mensajes 
# tras enviarlos a la DLQ y evitar el bucle infinito:
resource "google_project_iam_member" "pubsub_subscriber_role" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# 4. Tu suscripción principal modificada (con dead_letter_policy conectada)
resource "google_pubsub_subscription" "bq_subscription" {
  name  = var.pubsub_subscription_name
  topic = google_pubsub_topic.orders_topic.id

  bigquery_config {
    table               = "${var.project_id}:${google_bigquery_dataset.ecommerce_raw.dataset_id}.${google_bigquery_table.raw_orders.table_id}"
    use_topic_schema    = false
    write_metadata      = false
    drop_unknown_fields = true
    use_table_schema    = true
  }

  # ESTE ES EL ENLACE QUE FALTABA:
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.orders_dlq_topic.id
    max_delivery_attempts = 5 # Tras 5 intentos fallidos de inserción, lo manda a la DLQ
  }

  depends_on = [
    google_bigquery_table.raw_orders,
    google_project_iam_member.pubsub_bigquery_data_editor,
    google_project_iam_member.pubsub_bigquery_metadata_viewer,
    google_pubsub_topic_iam_member.pubsub_publisher_dlq,
    google_project_iam_member.pubsub_subscriber_role
  ]
}

# ---------------------------------------------------------
# Silver Layer View: Deduplicacion e Idempotencia
# ---------------------------------------------------------
resource "google_bigquery_table" "silver_orders_dedup_view" {
  dataset_id          = google_bigquery_dataset.ecommerce_raw.dataset_id
  table_id            = "vw_silver_orders_clean"
  deletion_protection = false

  view {
    query          = templatefile("${path.module}/../sql/deduplicate_orders.sql.tpl", {
      project_id = var.project_id
      dataset_id = var.bq_dataset_id
      table_id   = var.bq_table_id
    })
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.raw_orders]
}
