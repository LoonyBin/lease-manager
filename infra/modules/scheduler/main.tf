locals {
  app_image = "${var.registry_location}/lease-manager:${var.image_tag}"
}

# ────────────────────────────────────────────────────────────────────────────────
# clear_solid_queue_finished_jobs
# Sourced from config/recurring.yml: every hour at minute 12
# ────────────────────────────────────────────────────────────────────────────────

resource "google_cloud_run_v2_job" "clear_solid_queue_finished_jobs" {
  name                = "lease-manager-job-clear-solid-queue-jobs"
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  template {
    template {
      service_account = var.cloud_run_sa_email

      vpc_access {
        connector = var.vpc_connector_id
        egress    = "PRIVATE_RANGES_ONLY"
      }

      containers {
        name  = "task"
        image = local.app_image
        command = [
          "./bin/rails",
          "runner",
          "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)",
        ]

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        env {
          name  = "APP_HOST"
          value = "lease-manager.loonyb.in"
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "GCS_BUCKET"
          value = var.gcs_bucket
        }

        env {
          name  = "RAILS_LOG_LEVEL"
          value = "info"
        }

        env {
          name = "RAILS_MASTER_KEY"
          value_source {
            secret_key_ref {
              secret  = var.secret_rails_master_key
              version = "latest"
            }
          }
        }

        env {
          name = "DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = var.secret_database_url
              version = "latest"
            }
          }
        }
      }

      # Cloud SQL Auth Proxy sidecar
      containers {
        name  = "cloud-sql-proxy"
        image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2"

        args = [
          "--structured-logs",
          "--port=5432",
          var.db_connection_name,
        ]

        resources {
          limits = {
            cpu    = "0.5"
            memory = "256Mi"
          }
        }
      }
    }
  }
}

resource "google_cloud_scheduler_job" "clear_solid_queue_finished_jobs" {
  name      = "lease-manager-trigger-clear-solid-queue-jobs"
  region    = var.region
  project   = var.project_id
  schedule  = "12 * * * *"
  time_zone = "UTC"

  http_target {
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.clear_solid_queue_finished_jobs.name}:run"
    http_method = "POST"

    oauth_token {
      service_account_email = var.scheduler_sa_email
    }
  }
}
