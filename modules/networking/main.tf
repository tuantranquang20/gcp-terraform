# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-${var.environment}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Public Subnet (for Cloud NAT)
resource "google_compute_subnetwork" "public" {
  name          = "${var.prefix}-${var.environment}-public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private Subnet (for backend services, databases)
resource "google_compute_subnetwork" "private" {
  name          = "${var.prefix}-${var.environment}-private-subnet"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.prefix}-${var.environment}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

# Cloud NAT for private subnet internet access
resource "google_compute_router_nat" "nat" {
  name                               = "${var.prefix}-${var.environment}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Serverless VPC Access Connector (for Cloud Run to access VPC)
resource "google_vpc_access_connector" "connector" {
  name          = "${var.prefix}-${var.environment}-connector"
  region        = var.region
  project       = var.project_id
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"

  min_instances = 2
  max_instances = 3
}

# Firewall: Allow health checks from Google Cloud load balancers
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.prefix}-${var.environment}-allow-health-checks"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["allow-health-checks"]
}

# Firewall: Allow internal communication between subnets
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.prefix}-${var.environment}-allow-internal"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.public_subnet_cidr,
    var.private_subnet_cidr
  ]
}

# Firewall: Allow SSH from IAP (for debugging if needed)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.prefix}-${var.environment}-allow-iap-ssh"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

# Private IP allocation for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.prefix}-${var.environment}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# Private VPC connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
