variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "database_url" {
  description = "Database connection URL"
  type        = string
  sensitive   = true
}

variable "cloud_run_sa_email" {
  description = "Cloud Run service account email"
  type        = string
}
