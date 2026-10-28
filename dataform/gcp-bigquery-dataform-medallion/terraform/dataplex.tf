# ------------------------------------------------------------------------------
# 5. Gobierno de Datos con Google Cloud Dataplex (Lake, Zonas y Assets)
# ------------------------------------------------------------------------------
# Data Lake de Analitica Corporativa
resource "google_dataplex_lake" "enterprise_lake" {
  project      = var.project_id
  location     = var.region
  name         = "enterprise-data-lake"
  display_name = "Enterprise Analytics Data Lake"
  description  = "Gobernanza centralizada para las capas Bronze, Silver y Gold"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [google_project_service.enabled_apis]
}

# Zona 1: Raw (Capa Bronze)
resource "google_dataplex_zone" "raw_zone" {
  project       = var.project_id
  location      = var.region
  lake          = google_dataplex_lake.enterprise_lake.name
  name          = "raw-zone"
  display_name  = "Raw Ingestion Zone (Bronze)"
  type          = "RAW"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
    enabled = true
  }
}

# Zona 2: Curated (Capas Silver y Gold)
resource "google_dataplex_zone" "curated_zone" {
  project       = var.project_id
  location      = var.region
  lake          = google_dataplex_lake.enterprise_lake.name
  name          = "curated-zone"
  display_name  = "Curated & Refined Zone (Silver & Gold)"
  type          = "CURATED"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
    enabled = true
  }
}

# Asset 1: Mapeo de bronze_layer a la Zona Raw
resource "google_dataplex_asset" "bronze_asset" {
  project       = var.project_id
  location      = var.region
  lake          = google_dataplex_lake.enterprise_lake.name
  dataplex_zone = google_dataplex_zone.raw_zone.name
  name          = "asset-bronze-layer"
  display_name  = "BigQuery Bronze Layer Asset"

  resource_spec {
    name = "projects/${var.project_id}/datasets/${google_bigquery_dataset.medallion_datasets["bronze_layer"].dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled = true
  }
}

# Asset 2: Mapeo de silver_layer a la Zona Curated
resource "google_dataplex_asset" "silver_asset" {
  project       = var.project_id
  location      = var.region
  lake          = google_dataplex_lake.enterprise_lake.name
  dataplex_zone = google_dataplex_zone.curated_zone.name
  name          = "asset-silver-layer"
  display_name  = "BigQuery Silver Layer Asset"

  resource_spec {
    name = "projects/${var.project_id}/datasets/${google_bigquery_dataset.medallion_datasets["silver_layer"].dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled = true
  }
}

# Asset 3: Mapeo de gold_layer a la Zona Curated
resource "google_dataplex_asset" "gold_asset" {
  project       = var.project_id
  location      = var.region
  lake          = google_dataplex_lake.enterprise_lake.name
  dataplex_zone = google_dataplex_zone.curated_zone.name
  name          = "asset-gold-layer"
  display_name  = "BigQuery Gold Layer Asset"

  resource_spec {
    name = "projects/${var.project_id}/datasets/${google_bigquery_dataset.medallion_datasets["gold_layer"].dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled = true
  }
}
