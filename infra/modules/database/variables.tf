variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
}

variable "network_id" {
  description = "VPC network ID for private IP"
  type        = string
}
