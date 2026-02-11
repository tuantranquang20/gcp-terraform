output "service_url" {
  description = "URL of the backend Cloud Run service"
  value       = google_cloud_run_v2_service.backend.uri
}

output "service_name" {
  description = "Name of the backend Cloud Run service"
  value       = google_cloud_run_v2_service.backend.name
}
