output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = module.app.cloud_run_url
}

output "db_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.database.connection_name
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository URL"
  value       = module.registry.repository_url
}

output "wif_provider" {
  description = "Workload Identity Federation provider resource name"
  value       = module.iam.wif_provider
}

output "cicd_service_account" {
  description = "CI/CD service account email"
  value       = module.iam.cicd_sa_email
}
