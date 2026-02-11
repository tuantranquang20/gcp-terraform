# Frontend Cloud Run Service (Public)
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.prefix}-${var.environment}-frontend"
  location = var.region
  project  = var.project_id

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.container_image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      env {
        name  = "BACKEND_API_URL"
        value = var.backend_url
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

# Allow unauthenticated access (public frontend)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.frontend.name
  location = google_cloud_run_v2_service.frontend.location
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}
