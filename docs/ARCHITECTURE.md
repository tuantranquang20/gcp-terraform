# Architecture Deep Dive

This document provides a detailed explanation of the 3-tier architecture deployed by this lab.

## Architecture Overview

![Architecture Diagram](../diagrams/architecture.png)

## The 3-Tier Pattern

### Why 3-Tier Architecture?

The 3-tier architecture separates applications into three logical layers:

1. **Presentation Tier**: User interface and user interaction
2. **Application Tier**: Business logic and data processing
3. **Data Tier**: Data storage and retrieval

**Benefits:**
- **Separation of Concerns**: Each tier has a distinct responsibility
- **Scalability**: Scale each tier independently based on demand
- **Security**: Isolate sensitive data from public access
- **Maintainability**: Update one tier without affecting others
- **Flexibility**: Swap implementations (e.g., different frontend frameworks)

## Detailed Component Analysis

### Tier 1: Presentation Layer

#### Cloud Run Frontend Service

**Purpose**: Serve the user-facing application

**Configuration:**
- **Access**: Public internet (allUsers can invoke)
- **Networking**: No VPC connector (internet-facing)
- **Scaling**: 0-10 instances based on traffic
- **Resources**: 1 CPU, 512Mi memory

**Key Features:**
```hcl
# Public access via IAM
google_cloud_run_v2_service_iam_member.public_access {
  member = "allUsers"
  role   = "roles/run.invoker"
}
```

**Request Flow:**
1. User sends HTTPS request to Cloud Run URL
2. GCP load balancer routes to available instance
3. Container processes request
4. Calls backend API if needed (authenticated)
5. Returns response to user

**Security:**
- HTTPS enforced automatically
- No sensitive credentials in frontend
- Backend URL passed as environment variable
- Service account with minimal permissions

---

### Tier 2: Application Layer

#### Cloud Run Backend Service

**Purpose**: Handle business logic, process data, coordinate database and cache

**Configuration:**
- **Access**: Private (requires authentication)
- **Networking**: Connected to VPC via Serverless VPC Access Connector
- **Scaling**: 0-10 instances
- **Resources**: 1 CPU, 512Mi memory

**Key Features:**
```hcl
# VPC connectivity
vpc_access {
  connector = var.vpc_connector
  egress    = "PRIVATE_RANGES_ONLY"
}

# Private access control
google_cloud_run_v2_service_iam_policy.backend_policy {
  # Only frontend SA can invoke
}
```

**VPC Connectivity:**

The VPC Access Connector bridges Cloud Run (serverless) with VPC resources:

```
Cloud Run Backend
       ↓
VPC Access Connector (10.8.0.0/28)
       ↓
Private Subnet (10.0.2.0/24)
       ↓
Cloud SQL & Redis
```

**Why VPC Connector?**
- Cloud Run is serverless (no fixed network)
- Database and Redis are in VPC (private IPs)
- Connector provides secure bridge
- Alternative: Cloud SQL Proxy (more complex)

**Egress Control:**
- `PRIVATE_RANGES_ONLY`: Traffic to VPC goes through connector
- Internet traffic goes directly (for APIs, etc.)
- Optimal performance and security

**Request Flow:**
1. Frontend sends authenticated request
2. GCP verifies service account token
3. Backend container processes business logic
4. Queries database via VPC (private IP)
5. Checks/updates cache via VPC
6. Returns response to frontend

**Security:**
- No public access (IAM enforced)
- Service account with minimal permissions
- Database credentials from Secret Manager
- VPC firewall protection

---

### Tier 3: Data Layer

#### Cloud SQL (MySQL)

**Purpose**: Primary persistent data storage

**Configuration:**
- **Version**: MySQL 8.0
- **Tier**: db-f1-micro (smallest, cost-effective)
- **Networking**: Private IP only (no public IP)
- **Availability**: Zonal (REGIONAL for production HA)
- **Disk**: 10GB SSD

**Private IP Architecture:**

```
Cloud SQL Instance
       ↓
Private IP (allocated from VPC)
       ↓
VPC Peering (servicenetworking.googleapis.com)
       ↓
Custom VPC
```

**Why Private IP?**
- Database never exposed to internet
- Only VPC resources can connect
- No SSL/TLS overhead for encryption (trusted network)
- Reduced attack surface

**VPC Peering:**
```hcl
google_service_networking_connection.private_vpc_connection {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
```

This creates a private connection between your VPC and Google's service producer network where Cloud SQL runs.

**Backup Configuration:**
- Automated daily backups at 3:00 AM
- Binary logging enabled (point-in-time recovery)
- 7-day retention (default)

**Security:**
- Private IP only
- Firewall rules block external access
- Credentials stored in Secret Manager
- Backend SA granted `cloudsql.client` role

#### Memorystore for Redis

**Purpose**: High-performance in-memory caching

**Configuration:**
- **Version**: Redis 7.0
- **Tier**: BASIC (single node, cost-effective)
- **Memory**: 1GB
- **Networking**: Authorized network (VPC)
- **Security**: Transit encryption + AUTH enabled

**Use Cases:**
- Session storage
- Frequently accessed data caching
- Rate limiting
- Real-time analytics
- Pub/sub messaging

**AUTH Enabled:**
```hcl
auth_enabled = true
transit_encryption_mode = "SERVER_AUTHENTICATION"
```

- Requires password for connections
- TLS encryption in transit
- AUTH string stored in Terraform output (sensitive)

**Why Redis BASIC vs STANDARD_HA?**
- BASIC: Single node, ~$36/month, good for dev/testing
- STANDARD_HA: Two nodes with failover, ~$72/month, production-ready

**Eviction Policy:**
```hcl
redis_configs = {
  maxmemory-policy = "allkeys-lru"
}
```

- LRU (Least Recently Used) eviction when memory is full
- Automatically removes oldest unused keys
- Prevents out-of-memory errors

---

## Networking Architecture

### Custom VPC

**Why Custom VPC?**
- Default VPC uses auto-created subnets (limited control)
- Custom VPC allows precise CIDR planning
- Better security isolation
- Required for VPC peering (Cloud SQL)

**VPC Configuration:**
```hcl
google_compute_network.vpc {
  auto_create_subnetworks = false  # Manual control
}
```

### Subnets

#### Public Subnet (10.0.1.0/24)

**Purpose**: Cloud NAT, Cloud Router

**Why Public?**
- Technically, GCP subnets aren't "public" like AWS
- "Public" means it contains NAT gateway for internet access
- No VMs in this lab, but would host bastion hosts

**CIDR**: 10.0.1.0/24 = 256 IP addresses

#### Private Subnet (10.0.2.0/24)

**Purpose**: Backend services, database, cache (conceptually)

**Why Private?**
- Resources use private IPs only
- No direct internet access (except through NAT)
- Isolated from public internet

**CIDR**: 10.0.2.0/24 = 256 IP addresses

**Note**: Cloud Run doesn't actually use subnet IPs (serverless), but VPC connector and Cloud SQL do.

### Cloud NAT

**Purpose**: Allow private resources to initiate outbound internet connections

**Why Needed?**
```
Cloud Run Backend (serverless) → needs to:
  - Pull container images from GCR
  - Call external APIs
  - Download dependencies
```

**How It Works:**
1. Private resource initiates outbound connection
2. Traffic routes through Cloud Router
3. Cloud NAT translates private IP to public IP
4. Internet sees request from NAT public IP
5. Response routes back through NAT
6. NAT forwards to private resource

**Configuration:**
```hcl
source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
```

This allows all subnets to use NAT for internet access.

**Important**: NAT is one-way. Inbound connections from internet are still blocked.

### Firewall Rules

#### Allow Health Checks
```hcl
source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
```
- Google Cloud Load Balancer health check ranges
- Required for Cloud Run (GCP checks service health)

#### Allow Internal Communication
```hcl
source_ranges = ["10.0.1.0/24", "10.0.2.0/24"]
```
- Subnets can communicate with each other
- Required for VPC connector → Cloud SQL/Redis

#### Allow IAP SSH
```hcl
source_ranges = ["35.235.240.0/20"]
```
- Identity-Aware Proxy SSH range
- Allows secure SSH without public IPs (for debugging VMs if added)

---

## Security Architecture

### Defense in Depth

This architecture implements multiple security layers:

| Layer | Control | Implementation |
|-------|---------|----------------|
| **Network** | Private IPs | No public database access |
| **Network** | Firewall | Explicit allow rules only |
| **Network** | VPC Isolation | Custom VPC boundary |
| **Identity** | Service Accounts | Separate per service |
| **Identity** | IAM Policies | Least privilege |
| **Application** | Authentication | Service-to-service auth |
| **Data** | Encryption | TLS for Redis, SSL for SQL |
| **Data** | Secret Management | Secret Manager for credentials |

### Service Account Design

#### Frontend Service Account
```hcl
permissions:
  - roles/run.invoker (on backend)
```
Minimal permissions: Can only invoke backend, nothing else.

#### Backend Service Account
```hcl
permissions:
  - roles/cloudsql.client (database access)
  - roles/secretmanager.secretAccessor (read credentials)
```
Can access database and secrets, but not modify infrastructure.

### Secret Manager Integration

**Credentials Stored:**
1. Database password (auto-generated, 16 chars)
2. Database connection string (JSON format)

**Access Pattern:**
```
Backend Cloud Run
       ↓ (IAM check)
Secret Manager
       ↓ (return secret)
Backend decodes and uses
```

**Environment Variable:**
```hcl
env {
  name = "DB_SECRET"
  value_source {
    secret_key_ref {
      secret  = var.database_secret_id
      version = "latest"  # Auto-rotation support
    }
  }
}
```

Container automatically gets secret value, no code changes needed.

---

## Data Flow Examples

### Example 1: User Loads Frontend

```
1. User → HTTPS → Frontend Cloud Run
2. Frontend Cloud Run → Render HTML
3. Frontend → User (HTML/CSS/JS)
```

### Example 2: Frontend Fetches Data

```
1. User → HTTPS → Frontend Cloud Run
2. Frontend → Authenticated HTTPS → Backend Cloud Run
   (Using frontend SA credentials)
3. Backend → Check Redis cache (VPC private connection)
4a. Cache hit → Return cached data
4b. Cache miss → Query Cloud SQL (VPC private connection)
5. Backend → Store in Redis
6. Backend → Frontend (JSON response)
7. Frontend → User (formatted data)
```

### Example 3: Backend Queries Database

```
1. Backend Cloud Run receives request
2. Backend → Secret Manager (get DB credentials via IAM)
3. Backend → Cloud SQL via VPC connector
   Connection: mysql://private-ip:3306
4. Cloud SQL processes query
5. Cloud SQL → Backend (result set)
6. Backend caches result in Redis
7. Backend returns response
```

---

## Scalability Considerations

### Auto-Scaling

**Cloud Run:**
- Scales from 0 to max instances based on:
  - Request concurrency
  - CPU utilization
  - Memory usage
- Cold starts: ~1-3 seconds for new instances
- Min instances = 0: Cost-effective (pay only when used)

**Cloud SQL:**
- Fixed instance (db-f1-micro)
- To scale: Change tier (db-n1-standard-1, etc.)
- Read replicas for read-heavy workloads

**Redis:**
- Fixed memory (1GB)
- To scale: Increase memory or migrate to STANDARD_HA

### Performance Optimization

**Redis Caching Strategy:**
```
1. Check cache first (microseconds)
2. If miss, query database (milliseconds)
3. Store in cache for future requests
4. Set appropriate TTL (time-to-live)
```

**Result**: 10-100x faster response times for cached data.

---

## Cost Optimization

### Current Monthly Estimates

- Cloud Run: $0-5 (mostly free tier)
- Cloud SQL db-f1-micro: $7-10
- Redis BASIC 1GB: $36
- VPC Access Connector: $11
- Networking: $1-2
- **Total: ~$50-60/month**

### Cost-Saving Strategies

1. **Destroy when not in use**: `terraform destroy`
2. **Cloud SQL**: Use shared-core (f1-micro) for testing
3. **Redis**: Use BASIC tier, minimum memory
4. **Cloud Run**: Min instances = 0 (scale to zero)
5. **Budget alerts**: Get notified at thresholds

---

**Next**: [Deploy the architecture →](DEPLOYMENT_GUIDE.md)
