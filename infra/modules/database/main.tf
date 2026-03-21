resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "main" {
  name             = "lease-manager-${var.environment}-db"
  database_version = "POSTGRES_17"
  region           = var.region
  project          = var.project_id

  deletion_protection = true

  settings {
    tier    = var.db_tier
    edition = "ENTERPRISE"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
      }
    }

    insights_config {
      query_insights_enabled = true
    }
  }
}

resource "google_sql_database" "app" {
  name     = "lease_manager_${var.environment}"
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "google_sql_user" "app" {
  name     = "lease_manager"
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
  project  = var.project_id
}
