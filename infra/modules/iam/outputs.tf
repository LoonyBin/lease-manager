output "cloud_run_sa_email" {
  value = google_service_account.cloud_run.email
}

output "cicd_sa_email" {
  value = google_service_account.cicd.email
}

output "scheduler_sa_email" {
  value = google_service_account.scheduler.email
}

output "wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}
