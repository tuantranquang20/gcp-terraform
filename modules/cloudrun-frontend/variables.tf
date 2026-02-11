variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "container_image" {
  description = "Container image for the frontend service"
  type        = string
}

variable "backend_url" {
  description = "Backend API URL"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for the Cloud Run service"
  type        = string
}

variable "cpu" {
  description = "CPU limit for the service"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit for the service"
  type        = string
  default     = "512Mi"
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}
