variable "project_id" {
  description = "GCP Project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lab"
}

variable "frontend_image" {
  description = "Container image for frontend service (e.g., gcr.io/cloudrun/hello)"
  type        = string
  default     = "gcr.io/cloudrun/hello"
}

variable "backend_image" {
  description = "Container image for backend service (e.g., gcr.io/cloudrun/hello)"
  type        = string
  default     = "gcr.io/cloudrun/hello"
}
