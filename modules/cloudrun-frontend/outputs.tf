output "service_url" {
  description = "URL of the frontend Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "service_name" {
  description = "Name of the frontend Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.name
}
