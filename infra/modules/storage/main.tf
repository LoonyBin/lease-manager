resource "google_storage_bucket" "uploads" {
  name                        = "lease-manager-${var.environment}-uploads"
  location                    = var.region
  project                     = var.project_id
  force_destroy               = false
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "cloud_run_object_admin" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.cloud_run_sa_email}"
}
