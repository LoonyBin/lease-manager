output "rails_master_key_id" {
  value = google_secret_manager_secret.rails_master_key.id
}

output "google_oauth_client_id_id" {
  value = google_secret_manager_secret.google_oauth_client_id.id
}

output "google_oauth_client_secret_id" {
  value = google_secret_manager_secret.google_oauth_client_secret.id
}

output "database_url_id" {
  value = google_secret_manager_secret.database_url.id
}
