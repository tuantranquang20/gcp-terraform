# Cloud Run Frontend Module

## Purpose

This module deploys a public-facing Cloud Run service that serves the user interface. It's accessible from the internet and communicates with the private backend API.

## Components

### 1. Cloud Run Service (v2)
**Resource:** `google_cloud_run_v2_service.frontend`

**What it does:**
- Deploys a containerized web application
- Auto-scales from 0 to 10 instances based on traffic
- Serves HTTP/HTTPS requests
- Publicly accessible from the internet

**Why it's necessary:**
- **Presentation Tier:** Serves the user-facing interface
- **Serverless:** No server management, pay only for requests
- **Auto-scaling:** Handles traffic spikes automatically
- **HTTPS:** Automatic SSL/TLS certificates

---

## Configuration Breakdown

### Service Account
```hcl
service_account = var.service_account_email
```

**What it does:**
- Runs the service with a dedicated service account
- Identity for making authenticated requests to backend

**Why it's necessary:**
- Security: Separate identity per service
- IAM: Has `run.invoker` permission for backend
- Audit: Track frontend's actions separately

---

### Scaling
```hcl
scaling {
  min_instance_count = 0   # Scale to zero when idle
  max_instance_count = 10  # Cap at 10 instances
}
```

**What it does:**
- **min = 0:** Service scales down to zero when idle (no cost)
- **max = 10:** Prevents runaway costs, limits concurrent instances

**Why these values:**
- **min = 0:** Cost-effective for dev/test
- **max = 10:** Sufficient for demo (each instance handles ~100 concurrent requests = 1,000 total capacity)

**Production recommendations:**
- **min = 1-2:** Avoid cold starts
- **max = 100+:** Handle higher traffic

**Cold starts:**
- With min = 0, first request takes ~1-3 seconds (container startup)
- Subsequent requests: < 100 ms
- Set min = 1 to keep one instance warm

---

### Container
```hcl
containers {
  image = var.container_image
  
  resources {
    limits = {
      cpu    = "1"
      memory = "512Mi"
    }
  }
}
```

**Container Image:**
- Default: `gcr.io/cloudrun/hello` (demo app)
- Production: Your built React app with nginx
- Built with: `./build-and-push.sh`

**Resources:**
- **1 CPU:** Full vCPU for serving requests
- **512 Mi RAM:** Sufficient for React SPA with nginx
- **Cost:** ~$0.00002 per request + ~$0.024 per vCPU-hour

**Why these limits:**
- Frontend is mostly static files (low CPU)
- nginx is very efficient
- 512 Mi handles thousands of concurrent connections

---

### Environment Variables
```hcl
env {
  name  = "BACKEND_API_URL"
  value = var.backend_url
}

env {
  name  = "ENVIRONMENT"
  value = var.environment
}
```

**BACKEND_API_URL:**
- Passed to frontend during build
- React app uses this to make API calls
- Example: `https://lab-dev-backend-xxxxx.run.app`

**ENVIRONMENT:**
- dev, staging, prod
- Can show in UI
- Enables environment-specific behavior

---

### Traffic
```hcl
traffic {
  type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  percent = 100
}
```

**What it does:**
- Routes 100% of traffic to latest revision
- Every deployment creates a new revision

**Why this configuration:**
- Simple deployment model (no gradual rollout)
- Latest revision always serves traffic
- Can manually route to older revisions if needed

**Blue-green deployment (advanced):**
```hcl
traffic {
  type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
  revision = "frontend-00001"
  percent  = 50
}
traffic {
  type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  percent  = 50
}
```

---

### 2. Public Access IAM Policy
**Resource:** `google_cloud_run_v2_service_iam_member.public_access`

**What it does:**
```hcl
role   = "roles/run.invoker"
member = "allUsers"
```

- Grants `run.invoker` to **allUsers** (anyone on internet)
- Makes the service publicly accessible
- No authentication required

**Why it's necessary:**
- Frontend must be accessible to users
- Public-facing tier of 3-tier architecture
- Users can directly access the URL in browser

**Security note:**
- Frontend has NO sensitive data
- Backend is still private (requires authentication)
- Frontend can only invoke backend (limited permission)

---

## Request Flow

### User Visits Frontend

```
1. User types frontend URL in browser
   https://lab-dev-frontend-xxxxx.run.app

2. DNS resolves to Google's load balancer

3. Load balancer selects healthy instance
   (or starts new instance if all at zero)

4. Request routed to Cloud Run container

5. nginx serves index.html and static assets

6. Browser loads React app

7. React app makes API call to BACKEND_API_URL

8. Frontend uses its service account to authenticate

9. Backend validates frontend's identity token

10. Backend returns data

11. Frontend displays data to user
```

---

## Outputs

| Output | Description | Used By |
|--------|-------------|---------|
| `service_url` | Public URL of frontend | User access, testing |
| `service_name` | Service name | Logs, monitoring |

---

## Security Features

### ✅ Dedicated Service Account
Not running as default compute SA.

### ✅ HTTPS Only
Automatic TLS certificates.

### ✅ Least Privilege
Can only invoke backend, nothing else.

### ✅ Container Scanning
GCR automatically scans for vulnerabilities.

### ✅ Non-Root User
Container runs as non-root (if Dockerfile follows best practices).

---

## Cost Breakdown

**Pricing components:**
1. **Requests:** $0.40 per million requests
2. **CPU:** $0.00002400 per vCPU-second
3. **Memory:** $0.00000250 per GiB-second
4. **Networking:** $0.12 per GB egress (first 1 GB free)

**Example (1,000 requests/day):**
- Requests: 30,000/month × $0.40/million = $0.01
- CPU: ~10 seconds per request × 1 vCPU × $0.000024 = $7.20
- Memory: ~10 seconds × 0.5 GiB × $0.0000025 = $0.375
- **Total: ~$8/month**

**With scale-to-zero (min=0):**
- No idle costs!
- Pay only when serving requests

---

## Performance Characteristics

### Latency
- **Cold start:** 1-3 seconds (if min instances = 0)
- **Warm request:** 50-200 ms
- **Static assets:** Served from nginx (very fast)

### Throughput
- **Per instance:** ~100 concurrent requests
- **With 10 instances:** ~1,000 concurrent requests
- **Sufficient for:** Most small-to-medium applications

### Scaling Speed
- **Scale up:** New instance in ~3 seconds
- **Scale down:** Gradual (15 minutes of idle time)

---

## Common Issues

### Error: Container Image Not Found

**Problem:** `Image 'gcr.io/...' not found`

**Solutions:**
1. Use default image:
   ```hcl
   frontend_image = "gcr.io/cloudrun/hello"
   ```

2. Build and push your image:
   ```bash
   export PROJECT_ID=your-project-id
   ./build-and-push.sh
   ```

3. Check GCR permissions:
   ```bash
   gcloud container images list
   ```

### Service Returns 403 to Backend

**Problem:** Cannot call backend API

**Solutions:**
1. Check backend URL in env var
2. Verify frontend SA has `run.invoker` on backend
3. Check backend isn't set to allUsers

### Slow Cold Starts

**Problem:** First request takes 5+ seconds

**Solutions:**
1. Increase min instances:
   ```hcl
   min_instance_count = 1
   ```

2. Reduce container size (smaller = faster startup)

3. Use Cloud Run startup probes (advanced)

---

## Monitoring

### View Logs
```bash
gcloud run services logs read lab-dev-frontend \
  --project=YOUR_PROJECT_ID \
  --limit=50
```

### Check Metrics
- Cloud Console → Cloud Run → Select service
- View: Request count, latency, error rate, instance count

### Key Metrics
- **Request count:** Traffic volume
- **Request latency:** P50, P95, P99
- **Error rate:** 4xx, 5xx errors
- **Instance count:** Scaling behavior
- **CPU/Memory utilization:** Resource usage

---

## Best Practices

### ✅ Use Multi-Stage Docker Build
```dockerfile
FROM node:18-alpine AS build
# Build React app

FROM nginx:alpine
# Serve built files
```
Smaller final image = faster startup.

### ✅ Set Appropriate Resource Limits
```hcl
cpu    = "1"      # Don't over-allocate
memory = "512Mi"  # Match your needs
```

### ✅ Configure Health Checks
```nginx
location /health {
  return 200 "healthy\n";
}
```

### ✅ Enable Compression
```nginx
gzip on;
gzip_types text/plain text/css application/javascript;
```

### ✅ Set Cache Headers
```nginx
location ~* \.(js|css|png|jpg)$ {
  expires 1y;
  add_header Cache-Control "public, immutable";
}
```

### ✅ Use CDN for Global Users
- Cloud CDN in front of Cloud Run
- Static assets served from edge locations
- Reduced latency worldwide

---

## Updating the Frontend

### Deploy New Version

1. **Update code:**
   ```bash
   cd apps/frontend/src
   # Make changes to App.js, App.css, etc.
   ```

2. **Build and push:**
   ```bash
   export PROJECT_ID=your-project-id
   ./build-and-push.sh
   ```

3. **Apply Terraform:**
   ```bash
   terraform apply
   ```

4. **Verify:**
   ```bash
   curl $(terraform output -raw frontend_url)
   ```

### Rollback to Previous Version

```bash
# List revisions
gcloud run revisions list --service=lab-dev-frontend

# Route traffic to old revision
gcloud run services update-traffic lab-dev-frontend \
  --to-revisions=lab-dev-frontend-00001=100
```

---

## Production Enhancements

### Custom Domain
```hcl
# Add to Cloud Run service
resource "google_cloud_run_domain_mapping" "frontend" {
  name     = "app.example.com"
  location = var.region
  
  spec {
    route_name = google_cloud_run_v2_service.frontend.name
  }
}
```

### Cloud CDN
```hcl
# Create load balancer + CDN
resource "google_compute_global_forwarding_rule" "frontend" {
  # Configure CDN in front of Cloud Run
}
```

### Monitoring Alerts
```hcl
resource "google_monitoring_alert_policy" "frontend_errors" {
  display_name = "Frontend Error Rate High"
  conditions {
    # Alert on 5xx errors
  }
}
```

---

## References

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run Pricing](https://cloud.google.com/run/pricing)
- [Best Practices](https://cloud.google.com/run/docs/tips/general)
- [Custom Domains](https://cloud.google.com/run/docs/mapping-custom-domains)
