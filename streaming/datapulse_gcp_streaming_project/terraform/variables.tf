variable "project_id" {
  type        = string
  description = "El ID del proyecto de Google Cloud (GCP)."
}

variable "region" {
  type        = string
  description = "Region principal de despliegue para los recursos GCP."
  default     = "us-central1"
}

variable "bq_location" {
  type        = string
  description = "Ubicacion multirregion o regional para el Dataset de BigQuery."
  default     = "US"
}

variable "bq_dataset_id" {
  type        = string
  description = "ID del dataset en BigQuery para datos crudos."
  default     = "ds_ecommerce_raw"
}

variable "bq_table_id" {
  type        = string
  description = "ID de la tabla de BigQuery receptora de streaming."
  default     = "raw_orders_stream"
}

variable "pubsub_topic_name" {
  type        = string
  description = "Nombre del topico de Pub/Sub."
  default     = "top_ecommerce_orders"
}

variable "pubsub_subscription_name" {
  type        = string
  description = "Nombre de la suscripcion BigQuery en Pub/Sub."
  default     = "sub_ecommerce_orders_to_bq"
}
