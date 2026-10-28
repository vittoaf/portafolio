output "project_id" {
  description = "ID del proyecto desplegado"
  value       = var.project_id
}

output "dataform_repository" {
  description = "Nombre del repositorio Dataform creado"
  value       = google_dataform_repository.medallion_repo.name
}

output "dataplex_lake_name" {
  description = "Nombre del Lago Dataplex"
  value       = google_dataplex_lake.enterprise_lake.name
}

output "service_account_email" {
  description = "Email de la cuenta de servicio de ingesta"
  value       = google_service_account.ingestion_sa.email
}
