terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.30"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.project_id
  region  = var.gcp_region
}

# ------------------------------------------------------------------------------
# 1. Habilitación de APIs Requeridas en GCP
# ------------------------------------------------------------------------------
locals {
  services = [
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "dataform.googleapis.com",
    "dataplex.googleapis.com",
    "datacatalog.googleapis.com",
    "datalineage.googleapis.com",
    "iam.googleapis.com"
  ]
}

resource "google_project_service" "enabled_apis" {
  for_each                   = toset(local.services)
  project                    = var.project_id
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# ------------------------------------------------------------------------------
# 2. Datasets de BigQuery (Monorregión us-central1 y borrado en cascada)
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "bronze" {
  dataset_id                 = "bronze_layer"
  friendly_name              = "Bronze Layer (Crudo)"
  location                   = var.gcp_region
  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.enabled_apis]
}

resource "google_bigquery_dataset" "silver" {
  dataset_id                 = "silver_layer"
  friendly_name              = "Silver Layer (Limpio)"
  location                   = var.gcp_region
  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.enabled_apis]
}

resource "google_bigquery_dataset" "gold" {
  dataset_id                 = "gold_layer"
  friendly_name              = "Gold Layer (Analítica)"
  location                   = var.gcp_region
  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.enabled_apis]
}

resource "google_bigquery_dataset" "assertions" {
  dataset_id                 = "dataform_assertions"
  friendly_name              = "Dataform Assertions (Calidad)"
  location                   = var.gcp_region
  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.enabled_apis]
}

# ------------------------------------------------------------------------------
# 3. Service Account de Pipeline / Ingesta, Llave y Roles en el Proyecto
# ------------------------------------------------------------------------------
resource "google_service_account" "ingestion_sa" {
  account_id   = "sa-medallion-ingestion"
  display_name = "Service Account para Pipeline e Ingesta Bronze"
  project      = var.project_id
  depends_on   = [google_project_service.enabled_apis]
}

locals {
  pipeline_sa_roles = [
    "roles/bigquery.admin",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/dataform.admin",
    "roles/dataplex.admin",
    "roles/datacatalog.tagTemplateUser",
    "roles/viewer"
  ]
}

resource "google_project_iam_member" "pipeline_sa_permissions" {
  for_each   = toset(local.pipeline_sa_roles)
  project    = var.project_id
  role       = each.key
  member     = "serviceAccount:${google_service_account.ingestion_sa.email}"
  depends_on = [google_project_service.enabled_apis]
}

resource "google_service_account_key" "ingestion_key" {
  service_account_id = google_service_account.ingestion_sa.name
}

resource "local_file" "ingestion_key_file" {
  content  = base64decode(google_service_account_key.ingestion_key.private_key)
  filename = "${path.module}/pipeline-service-account-key.json"
}

# ------------------------------------------------------------------------------
# 4. Dataform Service Agent: Permisos BigQuery e Impersonación de la SA
# ------------------------------------------------------------------------------
data "google_project" "current" {
  project_id = var.project_id
}

locals {
  dataform_service_agent = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dataform.iam.gserviceaccount.com"

  dataform_impersonation_roles = [
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser"
  ]
}

# Permisos nativos del agente interno de Dataform sobre BigQuery
resource "google_project_iam_member" "dataform_agent_editor" {
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = local.dataform_service_agent
  depends_on = [google_project_service.enabled_apis]
}

resource "google_project_iam_member" "dataform_agent_jobuser" {
  project    = var.project_id
  role       = "roles/bigquery.jobUser"
  member     = local.dataform_service_agent
  depends_on = [google_project_service.enabled_apis]
}

# Impersonación: El agente de Dataform puede impersonar a la Service Account del pipeline
resource "google_service_account_iam_member" "dataform_sa_impersonation" {
  for_each           = toset(local.dataform_impersonation_roles)
  service_account_id = google_service_account.ingestion_sa.name
  role               = each.key
  member             = local.dataform_service_agent
}

# ------------------------------------------------------------------------------
# 5. Permisos para el Usuario Operador (Linaje por Columna, Catálogo y Dataplex)
# ------------------------------------------------------------------------------
locals {
  admin_operator_roles = [
    "roles/datalineage.viewer",
    "roles/datacatalog.viewer",
    "roles/dataplex.viewer"
  ]
}

resource "google_project_iam_member" "admin_operator_perms" {
  for_each   = toset(local.admin_operator_roles)
  project    = var.project_id
  role       = each.key
  member     = "user:${var.admin_user_email}"
  depends_on = [google_project_service.enabled_apis]
}

# ------------------------------------------------------------------------------
# 6. Repositorio de Dataform
# ------------------------------------------------------------------------------
resource "google_dataform_repository" "medallion_repo" {
  provider     = google-beta
  name         = "medallion-dataform-repo"
  project      = var.project_id
  region       = var.gcp_region
  display_name = "Enterprise Medallion Dataform Repository"
  depends_on   = [google_project_service.enabled_apis]
}