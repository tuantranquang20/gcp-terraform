output "host" {
  description = "Redis instance host address"
  value       = google_redis_instance.cache.host
}

output "port" {
  description = "Redis instance port"
  value       = google_redis_instance.cache.port
}

output "current_location_id" {
  description = "The current zone where the Redis instance is located"
  value       = google_redis_instance.cache.current_location_id
}

output "auth_string" {
  description = "AUTH string for Redis instance"
  value       = google_redis_instance.cache.auth_string
  sensitive   = true
}
