output "vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = google_compute_subnetwork.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = google_compute_subnetwork.private.id
}

output "vpc_connector_id" {
  description = "ID of the VPC Access Connector"
  value       = google_vpc_access_connector.connector.id
}

output "nat_ip" {
  description = "NAT gateway IP"
  value       = google_compute_router_nat.nat.name
}

output "private_vpc_connection" {
  description = "Private VPC connection for services"
  value       = google_service_networking_connection.private_vpc_connection.network
}
