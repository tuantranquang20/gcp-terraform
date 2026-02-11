# Random suffix for unique database instance name
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

# Random password for database user
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Cloud SQL MySQL Instance
resource "google_sql_database_instance" "main" {
  name             = "${var.prefix}-${var.environment}-db-${random_id.db_name_suffix.hex}"
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  # Prevent accidental deletion
  deletion_protection = false # Set to true in production

  settings {
    tier              = var.tier
    availability_type = "ZONAL" # Use REGIONAL for production
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"

    # IP configuration - Private IP only
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    # Backup configuration
    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      binary_log_enabled = true
    }

    # Maintenance window
    maintenance_window {
      day          = 7 # Sunday
      hour         = 3
      update_track = "stable"
    }

    # Database flags for optimization
    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }
}

# Create application database
resource "google_sql_database" "database" {
  name     = "${var.prefix}_${var.environment}_app"
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

# Create database user
resource "google_sql_user" "user" {
  name     = "${var.prefix}_user"
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
  project  = var.project_id
}

# Store database credentials in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.prefix}-${var.environment}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# Store full connection string
resource "google_secret_manager_secret" "db_connection" {
  secret_id = "${var.prefix}-${var.environment}-db-connection"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_connection" {
  secret = google_secret_manager_secret.db_connection.id
  secret_data = jsonencode({
    host     = google_sql_database_instance.main.private_ip_address
    port     = 3306
    database = google_sql_database.database.name
    username = google_sql_user.user.name
    password = random_password.db_password.result
  })
}
