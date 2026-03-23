output "connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  value = google_sql_database_instance.main.private_ip_address
}

output "database_url" {
  value     = "postgres://${google_sql_user.app.name}:${random_password.db_password.result}@${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.app.name}"
  sensitive = true
}
