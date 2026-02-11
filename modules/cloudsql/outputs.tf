output "instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.main.name
}

output "private_ip_address" {
  description = "Private IP address of the database"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "Name of the application database"
  value       = google_sql_database.database.name
}

output "db_secret_id" {
  description = "Secret Manager secret ID for database connection"
  value       = google_secret_manager_secret.db_connection.secret_id
}

output "connection_name" {
  description = "Connection name for Cloud SQL proxy"
  value       = google_sql_database_instance.main.connection_name
}
