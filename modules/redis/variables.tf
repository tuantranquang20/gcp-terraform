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

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "REDIS_7_0"
}

variable "memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
}

variable "tier" {
  description = "Redis tier (BASIC or STANDARD_HA)"
  type        = string
  default     = "BASIC"
}
