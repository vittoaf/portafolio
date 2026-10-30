terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "apis" {
  for_each = toset([
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "dataproc.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

# 1. Crear la Service Account del ejecutor Spark
resource "google_service_account" "spark_sa" {
  account_id   = "${var.prefix}-spark-executor"
  display_name = "Service Account para ejecutor PySpark Streaming"
}

# 2. Rol obligatorio de Dataproc para inicializar workers y contenedores
resource "google_project_iam_member" "spark_sa_dataproc_worker" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.spark_sa.email}"
}

# 3. Rol para leer mensajes de la suscripción de Pub/Sub
resource "google_project_iam_member" "spark_sa_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.spark_sa.email}"
}

# 4. Rol para insertar registros en BigQuery
resource "google_project_iam_member" "spark_sa_bq" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.spark_sa.email}"
}

# 5. Rol para escribir checkpoints y leer artefactos en Cloud Storage
resource "google_project_iam_member" "spark_sa_gcs" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.spark_sa.email}"
}

# 6. Permiso para que TU usuario pueda impersonar/usar la Service Account al enviar el job
# (Evita el error 'IAMIdentityCanActAs.CanActAsServiceAccount')
data "google_client_openid_userinfo" "me" {}

resource "google_service_account_iam_member" "act_as_spark_sa" {
  service_account_id = google_service_account.spark_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}

resource "google_project_iam_member" "spark_sa_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.spark_sa.email}"
}

resource "google_storage_bucket" "spark_artifacts" {
  name                        = "${var.prefix}-spark-artifacts-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [google_project_service.apis]
}

resource "google_storage_bucket" "spark_checkpoints" {
  name                        = "${var.prefix}-spark-checkpoints-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [google_project_service.apis]
}

resource "google_pubsub_topic" "transactions_dlq" {
  name       = "${var.prefix}-transactions-dlq"
  depends_on = [google_project_service.apis]
}

resource "google_pubsub_subscription" "transactions_dlq_sub" {
  name                       = "${var.prefix}-transactions-dlq-sub"
  topic                      = google_pubsub_topic.transactions_dlq.name
  message_retention_duration = var.pubsub_message_retention_duration
}

resource "google_pubsub_topic" "transactions_main" {
  name       = "${var.prefix}-transactions-main"
  depends_on = [google_project_service.apis]
}

# Forzar la creación y obtención del Service Agent de Pub/Sub
resource "google_project_service_identity" "pubsub_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "pubsub.googleapis.com"

  depends_on = [google_project_service.apis]
}

# Asignar el rol publisher usando el email dinámico y verificado
resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  topic  = google_pubsub_topic.transactions_dlq.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_project_service_identity.pubsub_agent.email}"
}

resource "google_pubsub_subscription_iam_member" "dlq_subscriber" {
  subscription = google_pubsub_subscription.transactions_spark_sub.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_project_service_identity.pubsub_agent.email}"
}

resource "google_pubsub_subscription" "transactions_spark_sub" {
  name                       = "${var.prefix}-transactions-spark-sub"
  topic                      = google_pubsub_topic.transactions_main.name
  ack_deadline_seconds       = 60
  message_retention_duration = var.pubsub_message_retention_duration

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.transactions_dlq.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  depends_on = [google_pubsub_topic_iam_member.dlq_publisher]
}

resource "google_bigquery_dataset" "finflow_ds" {
  dataset_id                  = "${var.prefix}_analytics_${var.environment}"
  friendly_name               = "FinFlow Streaming Dataset"
  location                    = var.region
  delete_contents_on_destroy  = var.bigquery_delete_contents_on_destroy
  depends_on                  = [google_project_service.apis]
}

resource "google_bigquery_table" "transactions_raw" {
  dataset_id = google_bigquery_dataset.finflow_ds.dataset_id
  table_id   = "transactions_raw"

  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "event_timestamp"
  }

  clustering = ["transaction_type", "status"]

  schema = <<EOF
[
  {"name": "transaction_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "account_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "customer_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "amount", "type": "NUMERIC", "mode": "REQUIRED"},
  {"name": "currency", "type": "STRING", "mode": "REQUIRED"},
  {"name": "transaction_type", "type": "STRING", "mode": "REQUIRED"},
  {"name": "channel", "type": "STRING", "mode": "REQUIRED"},
  {"name": "status", "type": "STRING", "mode": "REQUIRED"},
  {"name": "merchant_name", "type": "STRING", "mode": "NULLABLE"},
  {"name": "event_timestamp", "type": "TIMESTAMP", "mode": "REQUIRED"},
  {"name": "payload_hash", "type": "STRING", "mode": "REQUIRED"},
  {"name": "ingestion_timestamp", "type": "TIMESTAMP", "mode": "REQUIRED"}
]
EOF
}

resource "google_bigquery_table" "transactions_dedup_view" {
  dataset_id = google_bigquery_dataset.finflow_ds.dataset_id
  table_id   = "transactions_gold_dedup"

  deletion_protection = false

  view {
    query          = <<EOF
SELECT * EXCEPT(row_num)
FROM (
  SELECT 
    *,
    ROW_NUMBER() OVER (
      PARTITION BY transaction_id 
      ORDER BY ingestion_timestamp DESC, event_timestamp DESC
    ) as row_num
  FROM `${var.project_id}.${google_bigquery_dataset.finflow_ds.dataset_id}.transactions_raw`
)
WHERE row_num = 1
EOF
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.transactions_raw]
}
