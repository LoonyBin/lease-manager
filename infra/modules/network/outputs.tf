output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "vpc_connector_id" {
  value = google_vpc_access_connector.connector.id
}
