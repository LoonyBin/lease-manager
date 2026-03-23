output "rails_master_key_id" {
  value = google_secret_manager_secret.rails_master_key.id
}

output "database_url_id" {
  value = google_secret_manager_secret.database_url.id
}
