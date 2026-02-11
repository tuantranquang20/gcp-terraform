# Memorystore for Redis Instance
resource "google_redis_instance" "cache" {
  name           = "${var.prefix}-${var.environment}-redis"
  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  region         = var.region
  project        = var.project_id

  redis_version      = var.redis_version
  display_name       = "${var.prefix}-${var.environment} Redis Cache"
  authorized_network = var.network_id

  # Security
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  auth_enabled            = true

  # Redis configuration
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  # Maintenance policy
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 3
        minutes = 0
      }
    }
  }
}
