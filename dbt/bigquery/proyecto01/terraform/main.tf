terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. Crear Service Account dedicada
resource "google_service_account" "dbt_sa" {
  account_id   = var.service_account_id
  display_name = "Service Account para dbt, Python y BigQuery"
  description  = "Cuenta con permisos minimos necesarios para operar el pipeline Medallion"
}

# 2. Asignar Roles de BigQuery requeridos
resource "google_project_iam_member" "bq_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}

resource "google_project_iam_member" "bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}

# 3. Generar y exportar la Service Account Key localmente
resource "google_service_account_key" "dbt_key" {
  service_account_id = google_service_account.dbt_sa.name
}

resource "local_file" "sa_key_json" {
  content         = base64decode(google_service_account_key.dbt_key.private_key)
  filename        = "${path.module}/dbt-service-account-key.json"
  file_permission = "0600"
}
