output "frontend_url" {
  description = "URL of the frontend Cloud Run service"
  value       = module.cloudrun_frontend.service_url
}

output "backend_url" {
  description = "URL of the backend Cloud Run service (internal)"
  value       = module.cloudrun_backend.service_url
}

output "database_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = module.cloudsql.private_ip_address
  sensitive   = true
}

output "redis_host" {
  description = "Redis instance host address"
  value       = module.redis.host
  sensitive   = true
}

output "vpc_name" {
  description = "Name of the created VPC"
  value       = module.networking.vpc_name
}

output "instructions" {
  description = "Next steps after deployment"
  value       = <<-EOT
  
  🎉 Deployment Complete! 
  
  Frontend URL: ${module.cloudrun_frontend.service_url}
  Backend URL:  ${module.cloudrun_backend.service_url}
  
  Next steps:
  1. Visit the frontend URL to see your application
  2. Check Cloud Run logs: gcloud run services logs read ${module.cloudrun_frontend.service_name} --project=${var.project_id}
  3. Review the docs/ARCHITECTURE.md for detailed architecture explanation
  4. When done, run 'terraform destroy' to clean up resources
  
  EOT
}
