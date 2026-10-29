output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "pubsub_topic" {
  description = "Nombre completo del topico Pub/Sub"
  value       = google_pubsub_topic.orders_topic.id
}

output "pubsub_topic_dlq" {
  description = "Nombre completo del topico Pub/Sub para mensajes fallidos"
  value       = google_pubsub_topic.orders_dlq_topic.id
}

output "bigquery_table_id" {
  description = "ID de la tabla BigQuery de ingesta"
  value       = "${google_bigquery_dataset.ecommerce_raw.dataset_id}.${google_bigquery_table.raw_orders.table_id}"
}

output "bigquery_table_dlq_id" {
  description = "ID de la tabla BigQuery para mensajes fallidos"
  value       = "${google_bigquery_dataset.ecommerce_raw.dataset_id}.${google_bigquery_table.raw_orders_dlq.table_id}"
}

output "silver_view_id" {
  description = "Vista de BigQuery que asegura idempotencia y deduplicacion"
  value       = "${google_bigquery_dataset.ecommerce_raw.dataset_id}.${google_bigquery_table.silver_orders_dedup_view.table_id}"
}
