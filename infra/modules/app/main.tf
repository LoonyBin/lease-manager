locals {
  app_image = "${var.registry_location}/lease-manager:${var.image_tag}"

  common_env_vars = [
    {
      name  = "APP_HOST"
      value = "lease-manager.loonyb.in"
    },
    {
      name  = "GCP_PROJECT_ID"
      value = var.project_id
    },
    {
      name  = "GCS_BUCKET"
      value = var.gcs_bucket
    },
    {
      name  = "RAILS_LOG_LEVEL"
      value = "info"
    },
    {
      name  = "HTTP_PORT"
      value = "8080"
    },
  ]

  common_secret_vars = [
    {
      name       = "RAILS_MASTER_KEY"
      secret_id  = var.secret_rails_master_key
    },
    {
      name       = "GOOGLE_CLIENT_ID"
      secret_id  = var.secret_google_client_id
    },
    {
      name       = "GOOGLE_CLIENT_SECRET"
      secret_id  = var.secret_google_client_secret
    },
    {
      name       = "DATABASE_URL"
      secret_id  = var.secret_database_url
    },
  ]
}

# Cloud Run service
resource "google_cloud_run_v2_service" "app" {
  name                = "lease-manager"
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.cloud_run_sa_email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      name  = "lease-manager"
      image = local.app_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = local.common_env_vars
        content {
          name  = env.value.name
          value = env.value.value
        }
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
        name = "GOOGLE_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = var.secret_google_client_id
            version = "latest"
          }
        }
      }

      env {
        name = "GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.secret_google_client_secret
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

      ports {
        container_port = 8080
      }

      startup_probe {
        http_get {
          path = "/up"
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 12
        timeout_seconds       = 5
      }

      liveness_probe {
        http_get {
          path = "/up"
        }
        period_seconds    = 30
        failure_threshold = 3
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

# Allow public unauthenticated access
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Run Job for database migrations
resource "google_cloud_run_v2_job" "migrate" {
  name                = "lease-manager-migrate"
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
        name    = "migrate"
        image   = local.app_image
        command = ["./bin/rails", "db:migrate"]

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        dynamic "env" {
          for_each = local.common_env_vars
          content {
            name  = env.value.name
            value = env.value.value
          }
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

# Custom domain mapping is not supported in asia-south1.
# Use a Global External Application Load Balancer or
# CNAME lease-manager.loonyb.in → Cloud Run service URL instead.
