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

variable "database_version" {
  description = "MySQL database version"
  type        = string
  default     = "MYSQL_8_0"
}

variable "tier" {
  description = "Database instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size" {
  description = "Database disk size in GB"
  type        = number
  default     = 10
}
