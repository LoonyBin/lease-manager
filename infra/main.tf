# Enable required APIs
resource "google_project_service" "cloudresourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "vpcaccess" {
  service            = "vpcaccess.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudscheduler" {
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Modules

module "network" {
  source     = "./modules/network"
  project_id = var.project_id
  region     = var.region

  depends_on = [
    google_project_service.servicenetworking,
    google_project_service.vpcaccess,
  ]
}

module "registry" {
  source     = "./modules/registry"
  project_id = var.project_id
  region     = var.region

  depends_on = [google_project_service.artifactregistry]
}

module "database" {
  source      = "./modules/database"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  db_tier     = var.db_tier
  network_id  = module.network.vpc_id

  depends_on = [
    google_project_service.sqladmin,
    module.network,
  ]
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  region     = var.region

  depends_on = [
    google_project_service.iam,
    google_project_service.iamcredentials,
  ]
}

module "secrets" {
  source               = "./modules/secrets"
  project_id           = var.project_id
  database_url         = module.database.database_url
  cloud_run_sa_email   = module.iam.cloud_run_sa_email

  depends_on = [
    google_project_service.secretmanager,
    module.iam,
    module.database,
  ]
}

module "storage" {
  source             = "./modules/storage"
  project_id         = var.project_id
  region             = var.region
  environment        = var.environment
  cloud_run_sa_email = module.iam.cloud_run_sa_email

  depends_on = [
    google_project_service.storage,
    module.iam,
  ]
}

module "app" {
  source                  = "./modules/app"
  project_id              = var.project_id
  region                  = var.region
  image_tag               = var.image_tag
  registry_location       = module.registry.repository_location
  cloud_run_sa_email      = module.iam.cloud_run_sa_email
  vpc_connector_id        = module.network.vpc_connector_id
  db_connection_name      = module.database.connection_name
  secret_rails_master_key = module.secrets.rails_master_key_id
  secret_database_url     = module.secrets.database_url_id
  gcs_bucket              = module.storage.bucket_name

  depends_on = [
    google_project_service.run,
    module.iam,
    module.network,
    module.database,
    module.secrets,
    module.registry,
  ]
}

module "scheduler" {
  source               = "./modules/scheduler"
  project_id           = var.project_id
  region               = var.region
  image_tag            = var.image_tag
  registry_location    = module.registry.repository_location
  cloud_run_sa_email   = module.iam.cloud_run_sa_email
  scheduler_sa_email   = module.iam.scheduler_sa_email
  vpc_connector_id     = module.network.vpc_connector_id
  db_connection_name   = module.database.connection_name
  secret_rails_master_key     = module.secrets.rails_master_key_id
  secret_database_url         = module.secrets.database_url_id
  gcs_bucket                  = module.storage.bucket_name

  depends_on = [
    google_project_service.cloudscheduler,
    google_project_service.run,
    module.iam,
    module.network,
    module.database,
    module.secrets,
  ]
}
