# Frontend Service Account
resource "google_service_account" "frontend" {
  account_id   = "${var.prefix}-${var.environment}-frontend-sa"
  display_name = "Frontend Cloud Run Service Account"
  project      = var.project_id
}

# Backend Service Account
resource "google_service_account" "backend" {
  account_id   = "${var.prefix}-${var.environment}-backend-sa"
  display_name = "Backend Cloud Run Service Account"
  project      = var.project_id
}

# Grant backend service account access to Secret Manager
resource "google_project_iam_member" "backend_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# Grant backend service account Cloud SQL client role
resource "google_project_iam_member" "backend_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# Grant frontend service account ability to invoke backend
resource "google_project_iam_member" "frontend_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.frontend.email}"
}
