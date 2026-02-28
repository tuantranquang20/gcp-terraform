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

output "load_balancer_ip" {
  description = "External IP address of the load balancer"
  value       = module.load_balancer.load_balancer_ip
}

output "load_balancer_url" {
  description = "Full URL of the load balancer"
  value       = module.load_balancer.load_balancer_url
}

output "instructions" {
  description = "Next steps after deployment"
  value       = <<-EOT
  
  🎉 Deployment Complete! 
  
  Frontend URL: ${module.cloudrun_frontend.service_url}
  Backend URL:  ${module.cloudrun_backend.service_url}
  
  🌐 Load Balancer Configuration:
  IP Address:   ${module.load_balancer.load_balancer_ip}
  Domain:       ${var.domain_name}
  
  📝 Next steps:
  1. Configure DNS A record:
     ${var.domain_name} -> ${module.load_balancer.load_balancer_ip}
     
  2. Wait 10-20 minutes for SSL certificate provisioning
  
  3. Access your application:
     ${module.load_balancer.load_balancer_url}
  
  4. View load balancer logs:
     gcloud logging read "resource.type=http_load_balancer" --limit 50
  
  5. Monitor your services:
     - Frontend: gcloud run services logs read ${module.cloudrun_frontend.service_name} --project=${var.project_id}
     - Backend:  gcloud run services logs read ${module.cloudrun_backend.service_name} --project=${var.project_id}
  
  6. When done, run 'terraform destroy' to clean up resources
  
  EOT
}

