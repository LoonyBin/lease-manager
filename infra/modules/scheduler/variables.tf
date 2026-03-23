variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag (git SHA)"
  type        = string
}

variable "registry_location" {
  description = "Artifact Registry repository URL"
  type        = string
}

variable "cloud_run_sa_email" {
  description = "Cloud Run service account email"
  type        = string
}

variable "scheduler_sa_email" {
  description = "Cloud Scheduler service account email"
  type        = string
}

variable "vpc_connector_id" {
  description = "Serverless VPC Access connector ID"
  type        = string
}

variable "db_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
}

variable "secret_rails_master_key" {
  description = "Secret Manager resource ID for rails-master-key"
  type        = string
}

variable "secret_google_client_id" {
  description = "Secret Manager resource ID for google-oauth-client-id"
  type        = string
}

variable "secret_google_client_secret" {
  description = "Secret Manager resource ID for google-oauth-client-secret"
  type        = string
}

variable "secret_database_url" {
  description = "Secret Manager resource ID for database-url"
  type        = string
}

variable "gcs_bucket" {
  description = "GCS bucket name for ActiveStorage"
  type        = string
}
