provider "google" {
  project = var.project_id
  region  = var.region
}

# Networking Module - VPC, Subnets, NAT, Firewall
module "networking" {
  source = "./modules/networking"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  prefix      = var.prefix
}

# Security Module - Service Accounts, Secrets
module "security" {
  source = "./modules/security"

  project_id  = var.project_id
  environment = var.environment
  prefix      = var.prefix
}

# Cloud SQL Module - MySQL Database
module "cloudsql" {
  source = "./modules/cloudsql"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  prefix      = var.prefix

  network_id = module.networking.vpc_id

  depends_on = [module.networking]
}

# Redis Module - Memorystore
module "redis" {
  source = "./modules/redis"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  prefix      = var.prefix

  network_id = module.networking.vpc_id

  depends_on = [module.networking]
}

# Backend Cloud Run Service
module "cloudrun_backend" {
  source = "./modules/cloudrun-backend"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  prefix      = var.prefix

  container_image = var.backend_image
  vpc_connector   = module.networking.vpc_connector_id

  database_host         = module.cloudsql.private_ip_address
  database_name         = module.cloudsql.database_name
  database_secret_id    = module.cloudsql.db_secret_id
  redis_host            = module.redis.host
  redis_port            = module.redis.port
  service_account_email = module.security.backend_service_account_email

  depends_on = [
    module.networking,
    module.cloudsql,
    module.redis,
    module.security
  ]
}

# Frontend Cloud Run Service
module "cloudrun_frontend" {
  source = "./modules/cloudrun-frontend"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  prefix      = var.prefix

  container_image       = var.frontend_image
  backend_url           = module.cloudrun_backend.service_url
  service_account_email = module.security.frontend_service_account_email

  depends_on = [
    module.cloudrun_backend,
    module.security
  ]
}

# Load Balancer Module - Global HTTPS Load Balancer with NEG
module "load_balancer" {
  source = "./modules/load-balancer"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  prefix      = var.prefix

  # Cloud Run Service Names for NEG
  frontend_service_name = module.cloudrun_frontend.service_name
  backend_service_name  = module.cloudrun_backend.service_name

  # Domain Configuration
  domain_name = var.domain_name
  enable_ssl  = var.enable_ssl

  # Performance Features
  enable_cdn = var.enable_cdn

  # Security Features
  enable_cloud_armor     = var.enable_cloud_armor
  enable_ddos_protection = var.enable_ddos_protection
  blocked_countries      = var.blocked_countries

  # Logging
  log_sample_rate = var.log_sample_rate

  depends_on = [
    module.cloudrun_frontend,
    module.cloudrun_backend
  ]
}

