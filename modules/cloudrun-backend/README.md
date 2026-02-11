# Cloud Run Backend Module

## Purpose

This module deploys a private Cloud Run service that handles business logic, connects to the database and cache via VPC, and is accessible only from authenticated sources (the frontend).

## Components

### 1. Cloud Run Service (v2)
**Resource:** `google_cloud_run_v2_service.backend`

**What it does:**
- Deploys a containerized API server
- Connected to VPC via VPC Access Connector
- Private access only (requires authentication)
- Connects to Cloud SQL and Redis using private IPs

**Why it's necessary:**
- **Application Tier:** Handles business logic and data processing
- **VPC Integration:** Accesses private database and cache
- **Security:** Not directly exposed to internet
- **Scalability:** Auto-scales based on demand

---

## Configuration Breakdown

### Service Account
```hcl
service_account = var.service_account_email
```

**What it does:**
- Runs with dedicated backend service account
- Has permissions for Cloud SQL and Secret Manager

**Why it's necessary:**
- **Database Access:** Needs `cloudsql.client` role
- **Secrets Access:** Needs `secretmanager.secretAccessor` role
- **Security:** Separate from frontend identity

---

### Scaling
```hcl
scaling {
  min_instance_count = 0
  max_instance_count = 10
}
```

**Same as frontend, but considerations differ:**

**Why min = 0:**
- Cost-effective for dev/test
- Backend doesn't need to be always warm (frontend caches)

**Why max = 10:**
- Each instance can handle ~50-100 concurrent DB connections
- Prevents overwhelming database (db-f1-micro has 100 connection limit)

**Production recommendations:**
- **min = 2:** Always warm, database connections pooled
- **max = 20:** Calculate based on: `(DB max connections - 20 buffer) / connections per instance`
- Example: (100 - 20) / 5 = 16 max instances

---

### VPC Access
```hcl
vpc_access {
  connector = var.vpc_connector
  egress    = "PRIVATE_RANGES_ONLY"
}
```

**Critical configuration for private resource access.**

**connector:**
- ID of VPC Access Connector from networking module
- Bridges Cloud Run (serverless) to VPC
- Required for accessing Cloud SQL and Redis

**egress = "PRIVATE_RANGES_ONLY":**
- Traffic to private IPs (10.x.x.x) goes through VPC connector
- Traffic to public IPs (APIs, etc.) goes directly via internet
- Optimal performance and cost

**Alternative values:**
- `ALL_TRAFFIC`: Everything through connector (slower, more expensive)
- `PRIVATE_RANGES_ONLY`: Recommended for most use cases

**How it works:**
```
Cloud Run Backend
       ↓
VPC Access Connector (10.8.0.0/28)
       ↓
VPC Private Network
       ↓
Cloud SQL (10.x.x.x) + Redis (10.x.x.x)
```

---

### Container & Resources
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

**Why these limits:**
- **1 CPU:** Enough for API processing, DB queries
- **512 Mi RAM:** Node.js + connection pools + caching
- **Cost:** Same pricing as frontend

**When to increase:**
- CPU-intensive operations (image processing, etc.)
- Large result sets causing memory issues
- Many concurrent connections

---

### Environment Variables: Database
```hcl
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
```

**DB_HOST:**
- Cloud SQL private IP (e.g., 10.50.0.3)
- Accessed through VPC connector

**DB_NAME:**
- Database name (e.g., `lab_dev_app`)
- Plain text, not sensitive

**DB_SECRET:**
- **Secret reference, not plain text!**
- Cloud Run automatically fetches from Secret Manager
- Contains JSON with all connection details
- Backend service account must have `secretAccessor` role

**How backend uses secrets:**
```javascript
// Backend code automatically gets secret value
const secret = JSON.parse(process.env.DB_SECRET);
// secret = {host, port, username, password, database}

const pool = mysql.createPool({
  host: secret.host,
  user: secret.username,
  password: secret.password,
  database: secret.database
});
```

**Security benefits:**
- Password never in plain text env var
- Password never in code or logs
- Can rotate secret without redeploying
- Audit log shows who accessed secret when

---

### Environment Variables: Redis
```hcl
env {
  name  = "REDIS_HOST"
  value = var.redis_host
}

env {
  name  = "REDIS_PORT"
  value = tostring(var.redis_port)
}
```

**REDIS_HOST:**
- Redis private IP (e.g., 10.50.0.4)
- Accessed through VPC connector

**REDIS_PORT:**
- Typically 6379
- Converted to string for env var

**Redis AUTH:**
- Not shown here (should be added for production)
- AUTH string available from Redis module output
- Should also use Secret Manager

---

### Environment Variable: General
```hcl
env {
  name  = "ENVIRONMENT"
  value = var.environment
}
```

**What it does:**
- dev, staging, prod
- Backend can adjust behavior per environment
- Show in logs, health checks

---

### Traffic Configuration
```hcl
traffic {
  type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  percent = 100
}
```

Same as frontend - routes all traffic to latest revision.

---

### 2. IAM Policy (Private Access)
**Resource:** `google_cloud_run_v2_service_iam_policy.backend_policy`

**What it does:**
```hcl
data "google_iam_policy" "backend_noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${var.service_account_email}",
    ]
  }
}
```

**Critical security configuration:**
- **NOT** allUsers (unlike frontend)
- **ONLY** backend service account can invoke
- Actually, this binds backend SA to itself (should be frontend SA)

**⚠️ Bug in current code:**
This should grant frontend SA permission:
```hcl
members = [
  "serviceAccount:${var.frontend_service_account_email}",
]
```

**Why private access:**
- Backend should not be directly accessible from internet
- Only frontend can call backend
- Prevents unauthorized API access
- Defense in depth security

**How authentication works:**
1. Frontend makes request to backend URL
2. GCP adds frontend SA identity token to request
3. Backend validates token
4. Checks if frontend SA has `run.invoker` role
5. Processes request or returns 403

---

## Request Flow

### Frontend → Backend → Database

```
1. User clicks button in frontend

2. Frontend JavaScript makes fetch() to backend URL
   fetch(BACKEND_API_URL + '/api/stats')

3. GCP runtime attaches authentication header automatically
   Authorization: Bearer {FRONTEND_SA_IDENTITY_TOKEN}

4. Request routed to Cloud Run backend

5. Backend Cloud Run validates token

6. Backend checks if frontend SA has run.invoker permission

7. ✅ Permission granted → Process request

8. Backend connects to database via VPC connector:
   a. VPC connector proxies connection
   b. VPC routes to Cloud SQL private IP
   c. Cloud SQL validates backend SA has cloudsql.client
   d. Connection established

9. Backend queries database:
   SELECT COUNT(*) FROM visitors

10. Result returned to backend

11. Backend checks Redis cache (similar VPC flow)

12. Backend stores/retrieves from cache

13. Backend returns JSON response to frontend

14. Frontend displays data to user
```

---

## Outputs

| Output | Description | Used By |
|--------|-------------|---------|
| `service_url` | Private URL of backend | Frontend env var |
| `service_name` | Service name | Logs, monitoring |

---

## Security Features

### ✅ Private Access Only
Not publicly accessible from internet.

### ✅ Service-to-Service Authentication
Only frontend can invoke (via IAM).

### ✅ VPC Connectivity
Database and cache isolated from internet.

### ✅ Secret Manager Integration
No passwords in environment variables.

### ✅ Dedicated Service Account
Least-privilege permissions.

### ✅ Cloud SQL IAM
Backend SA validated on each connection.

---

## Cost Breakdown

**Similar to frontend:**
- Requests: $0.40 per million
- CPU: $0.00002400 per vCPU-second
- Memory: $0.00000250 per GiB-second

**Additional costs:**
- **VPC egress:** Free (private IPs within VPC)
- **VPC connector:** ~$11/month (shared resource)

**Example (1,000 requests/day, 50ms avg processing time):**
- Similar to frontend: ~$5-8/month

---

## Performance Characteristics

### Latency

**Cold start:** 1-3 seconds (if min = 0)
**Warm request breakdown:**
- Request routing: ~10 ms
- Business logic: ~10 ms
- Database query: ~20-50 ms
- Redis cache hit: ~0.5 ms
- Total: ~50-100 ms

**Optimization tips:**
- Cache frequently accessed data (Redis)
- Use database connection pooling
- Keep min_instances > 0 to avoid cold starts

### Database Connection Management

**Connection pool:**
```javascript
const pool = mysql.createPool({
  connectionLimit: 10,  // Per instance
  waitForConnections: true,
  queueLimit: 0
});
```

**Why pooling:**
- Reuses connections (faster than creating new)
- Limits concurrent connections per instance
- Prevents overwhelming database

**Calculation:**
- 10 instances × 10 connections = 100 total
- db-f1-micro limit: 100 connections
- Leave buffer for admin connections

---

## Common Issues

### Backend Cannot Connect to Database

**Problem:** Timeout or connection refused

**Diagnostic steps:**
```bash
# 1. Check VPC connector exists
gcloud compute networks vpc-access connectors describe \
  lab-dev-connector --region=us-central1

# 2. Get Cloud SQL private IP
gcloud sql instances describe INSTANCE_NAME \
  --format="value(ipAddresses[0].ipAddress)"

# 3. Check backend environment
gcloud run services describe lab-dev-backend \
  --region=us-central1 \
  --format="yaml(spec.template.spec.containers[0].env)"

# 4. Check backend SA permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:backend-sa@*"

# 5. View logs
gcloud run services logs read lab-dev-backend --limit=50
```

**Common causes:**
- VPC connector not created
- Incorrect database host
- Missing `cloudsql.client` role
- Secret not accessible

---

### Frontend Gets 403 When Calling Backend

**Problem:** Frontend cannot invoke backend

**Solution:**
Update IAM policy to grant frontend SA access:
```hcl
# In modules/cloudrun-backend/main.tf
data "google_iam_policy" "backend_noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${var.frontend_service_account_email}",  # Add this
    ]
  }
}
```

---

### Secrets Not Accessible

**Problem:** `Error accessing secret`

**Solutions:**
1. Check secret exists:
   ```bash
   gcloud secrets list
   ```

2. Check backend SA has permission:
   ```bash
   gcloud secrets get-iam-policy SECRET_NAME
   ```

3. Verify secret in env var:
   ```bash
   gcloud run services describe backend \
     --format="yaml(spec.template.spec.containers[0].env)"
   ```

---

## Monitoring

### Critical Metrics

**Request Metrics:**
- Request count
- Request latency (P50, P95, P99)
- Error rate (4xx, 5xx)

**Database Metrics:**
- Connection count
- Query latency
- Error rate

**Redis Metrics:**
- Cache hit rate
- Connection count
- Command latency

**System Metrics:**
- Instance count
- CPU utilization
- Memory utilization

### View Logs

```bash
# All logs
gcloud run services logs read lab-dev-backend --limit=100

# Errors only
gcloud run services logs read lab-dev-backend \
  --log-filter="severity>=ERROR" \
  --limit=50

# Follow logs in real-time
gcloud run services logs tail lab-dev-backend
```

---

## Best Practices

### ✅ Use Connection Pooling
```javascript
const pool = mysql.createPool({
  connectionLimit: 10,
  waitForConnections: true
});
```

### ✅ Implement Health Checks
```javascript
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});
```

### ✅ Handle Graceful Shutdown
```javascript
process.on('SIGTERM', async () => {
  await pool.end();
  process.exit(0);
});
```

### ✅ Use Redis for Caching
```javascript
const cached = await redis.get('key');
if (cached) return cached;

const result = await db.query(...);
await redis.setEx('key', 60, result);
return result;
```

### ✅ Set Appropriate Timeouts
```javascript
const pool = mysql.createPool({
  connectTimeout: 10000,  // 10 seconds
  acquireTimeout: 10000,
});
```

### ✅ Implement Retry Logic
```javascript
async function queryWithRetry(sql, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await pool.query(sql);
    } catch (err) {
      if (i === maxRetries - 1) throw err;
      await sleep(1000 * (i + 1));
    }
  }
}
```

---

## Production Enhancements

### Add Redis AUTH
```hcl
env {
  name = "REDIS_AUTH"
  value_source {
    secret_key_ref {
      secret  = "redis-auth-string"
      version = "latest"
    }
  }
}
```

### Increase Resources for Production
```hcl
resources {
  limits = {
    cpu    = "2"
    memory = "1Gi"
  }
}
```

### Configure Startup/Liveness Probes
```hcl
startup_probe {
  http_get {
    path = "/health"
  }
  initial_delay_seconds = 0
  timeout_seconds = 1
  period_seconds = 3
  failure_threshold = 10
}
```

---

## References

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [VPC Access](https://cloud.google.com/run/docs/configuring/connecting-vpc)
- [Secret Manager Integration](https://cloud.google.com/run/docs/configuring/secrets)
- [Service-to-Service Auth](https://cloud.google.com/run/docs/authenticating/service-to-service)
