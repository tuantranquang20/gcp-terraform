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

variable "public_subnet_cidr" {
  description = "CIDR range for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR range for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}
