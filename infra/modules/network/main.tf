resource "google_compute_network" "vpc" {
  name                    = "lease-manager-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "subnet" {
  name          = "lease-manager-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# Private IP range for Cloud SQL VPC peering
resource "google_compute_global_address" "private_ip_range" {
  name          = "lease-manager-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

resource "google_service_networking_connection" "vpc_peering" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Serverless VPC Access connector for Cloud Run → Cloud SQL private IP
resource "google_vpc_access_connector" "connector" {
  name          = "lease-manager-connector"
  region        = var.region
  project       = var.project_id
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name

  min_throughput = 200
  max_throughput = 300

  depends_on = [google_service_networking_connection.vpc_peering]
}
