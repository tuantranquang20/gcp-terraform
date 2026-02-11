# Backend Cloud Run Service (Private)
resource "google_cloud_run_v2_service" "backend" {
  name     = "${var.prefix}-${var.environment}-backend"
  location = var.region
  project  = var.project_id

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    vpc_access {
      connector = var.vpc_connector
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.container_image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      # Database configuration
      env {
        name  = "DB_HOST"
        value = var.database_host
      }

      env {
        name  = "DB_NAME"
        value = var.database_name
      }

      env {
        name = "DB_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.database_secret_id
            version = "latest"
          }
        }
      }

      # Redis configuration
      env {
        name  = "REDIS_HOST"
        value = var.redis_host
      }

      env {
        name  = "REDIS_PORT"
        value = tostring(var.redis_port)
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Only allow authenticated access (private backend)
# The frontend service account will be granted access via IAM in the security module
data "google_iam_policy" "backend_noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${var.service_account_email}",
    ]
  }
}

resource "google_cloud_run_v2_service_iam_policy" "backend_policy" {
  name        = google_cloud_run_v2_service.backend.name
  location    = google_cloud_run_v2_service.backend.location
  project     = var.project_id
  policy_data = data.google_iam_policy.backend_noauth.policy_data
}
