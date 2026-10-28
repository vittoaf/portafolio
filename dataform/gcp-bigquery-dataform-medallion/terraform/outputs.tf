output "project_id" {
  description = "ID del proyecto en GCP"
  value       = var.project_id
}

output "region" {
  description = "Region de computo y almacenamiento"
  value       = var.region
}

output "service_account_email" {
  description = "Correo de la Service Account creada"
  value       = google_service_account.pipeline_sa.email
}

output "key_file_path" {
  description = "Ubicacion local de la Service Account Key JSON"
  value       = local_file.sa_key_json.filename
}

output "dataform_repository_id" {
  description = "Identificador unico del repositorio de Dataform"
  value       = google_dataform_repository.medallion_repo.id
}

output "dataplex_lake_name" {
  description = "Nombre del Data Lake en Dataplex"
  value       = google_dataplex_lake.enterprise_lake.name
}
