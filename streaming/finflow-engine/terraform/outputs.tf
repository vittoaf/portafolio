output "pubsub_main_topic" {
  value = google_pubsub_topic.transactions_main.name
}

output "pubsub_subscription_id" {
  value = google_pubsub_subscription.transactions_spark_sub.name
}

output "pubsub_dlq_topic" {
  value = google_pubsub_topic.transactions_dlq.name
}

output "bigquery_table_id" {
  value = "${google_bigquery_dataset.finflow_ds.dataset_id}.${google_bigquery_table.transactions_raw.table_id}"
}

output "checkpoint_bucket" {
  value = google_storage_bucket.spark_checkpoints.name
}

output "artifacts_bucket" {
  value = google_storage_bucket.spark_artifacts.name
}
