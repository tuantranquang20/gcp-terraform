variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

# ============================================
# Cloud Run Service Names
# ============================================

variable "frontend_service_name" {
  description = "Name of the frontend Cloud Run service"
  type        = string
}

variable "backend_service_name" {
  description = "Name of the backend Cloud Run service"
  type        = string
}

# ============================================
# Domain and SSL Configuration
# ============================================

variable "domain_name" {
  description = "Domain name for the load balancer (e.g., example.com)"
  type        = string
  default     = "example.com"
}

variable "enable_ssl" {
  description = "Enable SSL/HTTPS with Google-managed certificate"
  type        = bool
  default     = true
}

# ============================================
# CDN Configuration
# ============================================

variable "enable_cdn" {
  description = "Enable Cloud CDN for frontend"
  type        = bool
  default     = true
}

# ============================================
# Cloud Armor Configuration
# ============================================

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor security policies"
  type        = bool
  default     = true
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection in Cloud Armor"
  type        = bool
  default     = true
}

variable "blocked_countries" {
  description = "List of country codes to block (e.g., ['CN', 'RU'])"
  type        = list(string)
  default     = []
}

# ============================================
# Logging Configuration
# ============================================

variable "log_sample_rate" {
  description = "Sample rate for load balancer logs (0.0 to 1.0)"
  type        = number
  default     = 1.0
  validation {
    condition     = var.log_sample_rate >= 0 && var.log_sample_rate <= 1
    error_message = "Log sample rate must be between 0.0 and 1.0"
  }
}

# ============================================
# IAP Configuration
# ============================================

variable "iap_client_id" {
  description = "OAuth2 client ID for Identity-Aware Proxy (leave empty to disable IAP)"
  type        = string
  default     = ""
}

variable "iap_client_secret" {
  description = "OAuth2 client secret for Identity-Aware Proxy"
  type        = string
  default     = ""
  sensitive   = true
}
