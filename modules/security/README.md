# Security Module

## Purpose

This module implements the principle of **least privilege** by creating dedicated service accounts for each service and granting only the minimum permissions necessary for operation.

## Components

### 1. Frontend Service Account
**Resource:** `google_service_account.frontend`

**What it does:**
- Creates a dedicated identity for the frontend Cloud Run service
- Account ID: `{prefix}-{environment}-frontend-sa`
- Separate from backend for security isolation

**Why it's necessary:**
- Cloud Run services should not run as the default compute service account
- Enables fine-grained access control
- Limits blast radius if frontend is compromised
- Follows GCP security best practices

**Permissions granted:**
- None directly on this service account
- See "Frontend IAM Binding" below

---

### 2. Backend Service Account
**Resource:** `google_service_account.backend`

**What it does:**
- Creates a dedicated identity for the backend Cloud Run service
- Account ID: `{prefix}-{environment}-backend-sa`
- Has more permissions than frontend (needs database/secrets access)

**Why it's necessary:**
- Backend needs access to sensitive resources (database, secrets)
- Separating from frontend limits security exposure
- Enables audit logging per service
- Required for Secret Manager integration

**Permissions granted:**
- See IAM bindings below

---

### 3. Backend IAM: Secret Manager Access
**Resource:** `google_project_iam_member.backend_secret_accessor`

**What it does:**
- Grants `roles/secretmanager.secretAccessor` to backend service account
- Allows backend to read secrets from Secret Manager
- Project-level permission

**Why it's necessary:**
- Backend needs database credentials from Secret Manager
- Secrets should never be hardcoded or passed as plain-text env vars
- Enables credential rotation without code changes
- Secrets are accessed at runtime, not build time

**What this role allows:**
- Read secret values
- List secret versions
- Access secret metadata

**What this role does NOT allow:**
- Create secrets
- Delete secrets
- Modify secret values
- Manage IAM on secrets

---

### 4. Backend IAM: Cloud SQL Client
**Resource:** `google_project_iam_member.backend_cloudsql_client`

**What it does:**
- Grants `roles/cloudsql.client` to backend service account
- Allows backend to connect to Cloud SQL instances
- Project-level permission

**Why it's necessary:**
- Required for Cloud SQL connections, even with private IP
- Enables Cloud SQL connection tracking and auditing
- Allows use of Cloud SQL Proxy if needed
- Required for IAM database authentication (optional feature)

**What this role allows:**
- Connect to Cloud SQL instances
- View Cloud SQL instance metadata
- Use Cloud SQL Auth Proxy

**What this role does NOT allow:**
- Modify database instances
- Delete databases
- Change instance settings
- Manage backups

---

### 5. Frontend IAM: Invoke Backend
**Resource:** `google_project_iam_member.frontend_invoker`

**What it does:**
- Grants `roles/run.invoker` to frontend service account
- Allows frontend to call backend Cloud Run service
- Project-level permission (applies to all Cloud Run services)

**Why it's necessary:**
- Backend Cloud Run is private (requires authentication)
- Frontend needs permission to invoke backend API
- Enables service-to-service authentication
- Cloud Run validates service account on each request

**How it works:**
1. Frontend makes request to backend
2. GCP automatically attaches frontend service account identity token
3. Backend Cloud Run validates the token
4. If frontend SA has `run.invoker` role, request is allowed
5. Otherwise, request is rejected with 403 Forbidden

**Security note:** This grants permission to invoke ALL Cloud Run services. In production, you might want to use service-level IAM policies instead.

---

## Security Architecture

### Principle of Least Privilege

Each service account has **only** the permissions it needs:

| Service Account | Permissions | Rationale |
|----------------|-------------|-----------|
| Frontend SA | `run.invoker` on backend | Can call backend API only |
| Backend SA | `secretmanager.secretAccessor` | Can read database credentials |
| Backend SA | `cloudsql.client` | Can connect to database |

**What's NOT granted:**
- ❌ Frontend cannot access database
- ❌ Frontend cannot read secrets
- ❌ Backend cannot be invoked by public (only frontend)
- ❌ Neither can modify infrastructure
- ❌ Neither can access other GCP projects

---

## Service-to-Service Authentication Flow

### Frontend → Backend Request

```
1. Frontend code makes HTTP request to backend URL
2. GCP runtime automatically adds authentication header:
   - Header: Authorization: Bearer {IDENTITY_TOKEN}
   - Token contains frontend service account identity
3. Request reaches backend Cloud Run
4. Backend Cloud Run validates token with Google's auth service
5. Checks if frontend SA has run.invoker permission
6. If yes: Process request
   If no: Return 403 Forbidden
7. Response sent back to frontend
```

**Key points:**
- Authentication is automatic (no code changes needed)
- Token is short-lived and refreshed automatically
- Cannot be spoofed or replayed
- Works only between GCP services

---

## Outputs

| Output | Description | Used By |
|--------|-------------|---------|
| `frontend_service_account_email` | Frontend SA email | Cloud Run frontend module |
| `backend_service_account_email` | Backend SA email | Cloud Run backend module |

---

## Security Best Practices Implemented

### ✅ Separate Service Accounts
Each service has its own identity, limiting blast radius.

### ✅ Least Privilege
No service has more permissions than necessary.

### ✅ No Keys or Secrets
Service accounts are used via workload identity, not downloaded keys.

### ✅ Audit Logging
All service account actions are logged in Cloud Audit Logs.

### ✅ Service-to-Service Auth
Backend is not publicly accessible, requires authentication.

### ✅ Secret Manager Integration
Passwords never appear in code or environment variables in plain text.

---

## Common Issues

### Frontend Gets 403 When Calling Backend

**Problem:** Frontend cannot invoke backend
**Solutions:**
1. Verify IAM binding: `gcloud run services get-iam-policy BACKEND_NAME`
2. Check frontend is using correct service account
3. Ensure backend isn't set to `allUsers` (should be restricted)

### Backend Cannot Read Secrets

**Problem:** Error accessing Secret Manager
**Solutions:**
1. Verify SA has secretAccessor role: `gcloud projects get-iam-policy PROJECT_ID`
2. Check secret exists: `gcloud secrets list`
3. Verify backend is using correct service account

### Backend Cannot Connect to Database

**Problem:** Connection refused or timeout
**Solutions:**
1. Verify SA has cloudsql.client role
2. Check Cloud SQL private IP is accessible via VPC
3. Ensure credentials in secret are correct

---

## Cost Considerations

**Service accounts are FREE**
- No charge for creation
- No charge for usage
- No charge for IAM bindings

**Audit logging:**
- Admin activity logs: Free
- Data access logs: May incur storage costs (minimal)

---

## Extending This Module

### Add Permission to Existing Service Account

```hcl
resource "google_project_iam_member" "backend_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.backend.email}"
}
```

### Create Additional Service Account

```hcl
resource "google_service_account" "worker" {
  account_id   = "${var.prefix}-${var.environment}-worker-sa"
  display_name = "Worker Service Account"
  project      = var.project_id
}
```

### Use Service-Level IAM (More Restrictive)

Instead of project-level `run.invoker`, bind to specific service:

```hcl
# In cloudrun-backend module
resource "google_cloud_run_v2_service_iam_member" "frontend_can_invoke" {
  name     = google_cloud_run_v2_service.backend.name
  location = google_cloud_run_v2_service.backend.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.frontend_service_account_email}"
}
```

---

## Identity and Access Management (IAM) Concepts

### Service Account
A special Google account that represents an application, not a person.

### Role
A collection of permissions (e.g., `secretmanager.secretAccessor`)

### Permission
A specific action on a resource (e.g., `secretmanager.secrets.get`)

### Binding
Associates a role with an identity (service account, user, group)

### Principal
The "who" in IAM (service account, user, group)

---

## Compliance and Auditing

### Cloud Audit Logs

All actions by service accounts are logged:
- **Admin Activity:** Creating SAs, changing IAM (always on, free)
- **Data Access:** Reading secrets, connecting to database (must enable)

View logs:
```bash
gcloud logging read "protoPayload.authenticationInfo.principalEmail:BACKEND_SA_EMAIL" --limit 50
```

### IAM Policy Review

Regularly review who has access:
```bash
gcloud projects get-iam-policy PROJECT_ID
```

---

## References

- [Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
- [Understanding IAM Roles](https://cloud.google.com/iam/docs/understanding-roles)
- [Cloud Run Authentication](https://cloud.google.com/run/docs/authenticating/service-to-service)
- [Secret Manager IAM](https://cloud.google.com/secret-manager/docs/access-control)
- [Cloud SQL IAM](https://cloud.google.com/sql/docs/mysql/iam-roles)
