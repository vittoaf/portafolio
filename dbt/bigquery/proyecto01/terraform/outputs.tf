output "service_account_email" {
  description = "Correo de la Service Account creada"
  value       = google_service_account.dbt_sa.email
}

output "key_file_path" {
  description = "Ruta local donde se exporto la Service Account Key"
  value       = local_file.sa_key_json.filename
}
