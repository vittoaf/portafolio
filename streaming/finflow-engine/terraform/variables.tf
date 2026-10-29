variable "project_id" {
  description = "ID del proyecto de Google Cloud"
  type        = string
}

variable "region" {
  description = "Región de despliegue de recursos"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "prefix" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
  default     = "finflow"
}

variable "pubsub_message_retention_duration" {
  description = "Duración de retención de mensajes en Pub/Sub"
  type        = string
  default     = "604800s"
}

variable "max_delivery_attempts" {
  description = "Número máximo de intentos antes de enviar al DLQ"
  type        = number
  default     = 5
}

variable "bigquery_delete_contents_on_destroy" {
  description = "Eliminar tablas al destruir el dataset"
  type        = bool
  default     = true
}
