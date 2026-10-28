terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
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

# ------------------------------------------------------------------------------
# 1. Habilitación de APIs de Google Cloud
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
# 2. Datasets de BigQuery con Idempotencia (Bronze, Silver, Gold)
# ------------------------------------------------------------------------------
# delete_contents_on_destroy = false protege la data ante destrucciones accidentales.
# Se configuran con ubicación idéntica para permitir joins cruzados sin costo de red.
locals {
  datasets = {
    bronze_layer = {
      description = "Capa Bronze: Tablas crudas ingeridas directamente desde fuentes con auditoria temporal."
    },
    silver_layer = {
      description = "Capa Silver: Tablas estandarizadas, deduplicadas, tipadas y saneadas mediante Dataform."
    },
    gold_layer = {
      description = "Capa Gold: Tablas de hechos y dimensiones con metricas agregadas para consumo analitico y agentes de IA."
    }
  }
}

resource "google_bigquery_dataset" "medallion_datasets" {
  for_each                    = local.datasets
  project                     = var.project_id
  dataset_id                  = each.key
  friendly_name               = each.key
  description                 = each.value.description
  location                    = var.region
  delete_contents_on_destroy  = true

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    layer       = split("_", each.key)[0]
  }

  depends_on = [google_project_service.enabled_apis]
}

# ------------------------------------------------------------------------------
# 3. Service Account, Permisos IAM e Impersonación de Dataform
# ------------------------------------------------------------------------------

# Obtener los metadatos del proyecto (necesario para extraer el número de proyecto)
data "google_project" "current" {
  project_id = var.project_id
}

# Service Account para el pipeline
resource "google_service_account" "pipeline_sa" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Service Account para Dataform, Ingesta Python y Dataplex"
  description  = "Identidad de servicio que ejecuta las canalizaciones Medallion"
  depends_on   = [google_project_service.enabled_apis]
}

# Roles asignados a la Service Account en el proyecto
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

resource "google_project_iam_member" "pipeline_sa_roles" {
  for_each = toset(local.pipeline_sa_roles)
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

# AUTORIZACIÓN: Permitir que el agente de servicio interno de Dataform
# suplante (impersonate) a sa-dataform-pipeline para ejecutar las canalizaciones
locals {
  dataform_impersonation_roles = [
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser"
  ]
}

resource "google_service_account_iam_member" "dataform_service_agent_binding" {
  for_each           = toset(local.dataform_impersonation_roles)
  service_account_id = google_service_account.pipeline_sa.name
  role               = each.key
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [
    google_service_account.pipeline_sa,
    google_project_service.enabled_apis
  ]
}

# Clave local de la Service Account
resource "google_service_account_key" "sa_key" {
  service_account_id = google_service_account.pipeline_sa.name
}

resource "local_file" "sa_key_json" {
  content         = base64decode(google_service_account_key.sa_key.private_key)
  filename        = "${path.module}/pipeline-service-account-key.json"
  file_permission = "0600"
}

# ------------------------------------------------------------------------------
# 4. Repositorio Nativo de Dataform en Google Cloud
# ------------------------------------------------------------------------------
resource "google_dataform_repository" "medallion_repo" {
  provider     = google-beta
  project      = var.project_id
  region       = var.region
  name         = var.dataform_repo_name
  display_name = "Repositorio Dataform Medallion Architecture"

  depends_on = [google_project_service.enabled_apis]
}

# ------------------------------------------------------------------------------
# Permisos de Dataplex y Data Lineage para el usuario operador
# ------------------------------------------------------------------------------
locals {
  admin_operator_roles = [
    "roles/datalineage.viewer",    # Permite ver el grafo y dependencias por columna
    "roles/datacatalog.viewer",    # Permite leer esquemas y metadatos del catálogo
    "roles/dataplex.viewer"        # Permite explorar lagos, zonas y assets
  ]
}

resource "google_project_iam_member" "admin_operator_permissions" {
  for_each = toset(local.admin_operator_roles)
  project  = var.project_id
  role     = each.key
  member   = "user:${var.admin_user_email}"

  depends_on = [google_project_service.enabled_apis]
}

import {
  to = google_bigquery_dataset.medallion_datasets["bronze_layer"]
  id = "projects/${var.project_id}/datasets/bronze_layer"
}

import {
  to = google_bigquery_dataset.medallion_datasets["silver_layer"]
  id = "projects/${var.project_id}/datasets/silver_layer"
}

import {
  to = google_bigquery_dataset.medallion_datasets["gold_layer"]
  id = "projects/${var.project_id}/datasets/gold_layer"
}