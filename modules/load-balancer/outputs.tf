output "load_balancer_ip" {
  description = "External IP address of the load balancer"
  value       = google_compute_global_address.default.address
}

output "load_balancer_ip_name" {
  description = "Name of the reserved IP address"
  value       = google_compute_global_address.default.name
}

output "frontend_neg_id" {
  description = "ID of the frontend NEG"
  value       = google_compute_region_network_endpoint_group.frontend_neg.id
}

output "backend_neg_id" {
  description = "ID of the backend NEG"
  value       = google_compute_region_network_endpoint_group.backend_neg.id
}

output "frontend_backend_service_id" {
  description = "ID of the frontend backend service"
  value       = google_compute_backend_service.frontend.id
}

output "backend_backend_service_id" {
  description = "ID of the backend backend service"
  value       = google_compute_backend_service.backend.id
}

output "url_map_id" {
  description = "ID of the URL map"
  value       = google_compute_url_map.default.id
}

output "ssl_certificate_id" {
  description = "ID of the SSL certificate (if enabled)"
  value       = var.enable_ssl ? google_compute_managed_ssl_certificate.default[0].id : null
}

output "https_proxy_id" {
  description = "ID of the HTTPS proxy (if SSL enabled)"
  value       = var.enable_ssl ? google_compute_target_https_proxy.default[0].id : null
}

output "http_proxy_id" {
  description = "ID of the HTTP proxy"
  value       = google_compute_target_http_proxy.default.id
}

output "security_policy_id" {
  description = "ID of the Cloud Armor security policy (if enabled)"
  value       = var.enable_cloud_armor ? google_compute_security_policy.policy[0].id : null
}

output "load_balancer_url" {
  description = "Full URL of the load balancer"
  value       = var.enable_ssl ? "https://${var.domain_name}" : "http://${var.domain_name}"
}
