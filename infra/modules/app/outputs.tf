output "cloud_run_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "migrate_job_name" {
  value = google_cloud_run_v2_job.migrate.name
}
