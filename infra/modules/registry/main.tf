resource "google_artifact_registry_repository" "images" {
  repository_id = "lease-manager-images"
  format        = "DOCKER"
  location      = var.region
  project       = var.project_id
  description   = "Docker images for lease-manager"
}
