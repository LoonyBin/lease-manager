variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "image_tag" {
  description = "Docker image tag (git SHA) to deploy"
  type        = string
}

variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}
