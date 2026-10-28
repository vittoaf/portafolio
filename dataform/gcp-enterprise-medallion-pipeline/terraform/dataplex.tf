resource "google_dataplex_lake" "enterprise_lake" {
  name         = "enterprise-data-lake"
  project      = var.project_id
  location     = var.gcp_region
  display_name = "Enterprise Medallion Data Lake"
  depends_on   = [google_project_service.enabled_apis]
}

resource "google_dataplex_zone" "raw_zone" {
  name         = "raw-zone"
  lake         = google_dataplex_lake.enterprise_lake.name
  project      = var.project_id
  location     = var.gcp_region
  type         = "RAW"
  display_name = "Zona Cruda (Bronze)"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
      enabled = true
    }
}

resource "google_dataplex_zone" "curated_zone" {
  name         = "curated-zone"
  lake         = google_dataplex_lake.enterprise_lake.name
  project      = var.project_id
  location     = var.gcp_region
  type         = "CURATED"
  display_name = "Zona Curada (Silver y Gold)"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
      enabled = true
    }
}

resource "google_dataplex_asset" "bronze_asset" {
  name          = "asset-bronze-layer"
  lake          = google_dataplex_lake.enterprise_lake.name
  dataplex_zone = google_dataplex_zone.raw_zone.name
  project       = var.project_id
  location      = var.gcp_region

  resource_spec {
    name = "projects/${var.project_id}/datasets/${google_bigquery_dataset.bronze.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled = true
  }
}

resource "google_dataplex_asset" "silver_asset" {
  name          = "asset-silver-layer"
  lake          = google_dataplex_lake.enterprise_lake.name
  dataplex_zone = google_dataplex_zone.curated_zone.name
  project       = var.project_id
  location      = var.gcp_region

  resource_spec {
    name = "projects/${var.project_id}/datasets/${google_bigquery_dataset.silver.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled = true
  }
}

resource "google_dataplex_asset" "gold_asset" {
  name          = "asset-gold-layer"
  lake          = google_dataplex_lake.enterprise_lake.name
  dataplex_zone = google_dataplex_zone.curated_zone.name
  project       = var.project_id
  location      = var.gcp_region

  resource_spec {
    name = "projects/${var.project_id}/datasets/${google_bigquery_dataset.gold.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled = true
  }
}
