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
  description = "Container image for the backend service"
  type        = string
}

variable "vpc_connector" {
  description = "VPC Access Connector ID"
  type        = string
}

variable "database_host" {
  description = "Database host address"
  type        = string
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_secret_id" {
  description = "Secret Manager secret ID for database connection"
  type        = string
}

variable "redis_host" {
  description = "Redis host address"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
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
