# Module Documentation Summary

This directory contains 6 Terraform modules, each with detailed README documentation.

## Module Overview

| Module | Purpose | Key Resources | Monthly Cost |
|--------|---------|---------------|--------------|
| **networking** | VPC, subnets, NAT, firewall | 11 resources | ~$25-30 |
| **security** | Service accounts, IAM | 5 resources | Free |
| **cloudsql** | MySQL database | 12 resources | ~$10-15 |
| **redis** | Cache (Memorystore) | 1 resource | ~$36 |
| **cloudrun-frontend** | Public web app | 2 resources | ~$5-10 |
| **cloudrun-backend** | Private API | 2 resources | ~$5-10 |
| **TOTAL** | Complete 3-tier architecture | **33 resources** | **~$80-100/month** |

---

## Module Dependency Graph

```
┌─────────────┐
│  networking │ (VPC, subnets, NAT, firewall, VPC connector)
└──────┬──────┘
       │
       ├─────────────────────────────┐
       │                             │
       ▼                             ▼
┌─────────────┐              ┌─────────────┐
│   security  │              │   cloudsql  │ (MySQL database)
│             │              │             │
│ (SA + IAM)  │              │ (needs VPC) │
└──────┬──────┘              └─────────────┘
       │
       │                             ┌─────────────┐
       │                             │    redis    │ (Cache)
       │                             │             │
       │                             │ (needs VPC) │
       │                             └─────────────┘
       │
       ├─────────────────┬───────────────────┐
       │                 │                   │
       ▼                 ▼                   ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ cloudrun-   │   │ cloudrun-   │   │  All other  │
│  frontend   │   │   backend   │   │  resources  │
│             │   │             │   │             │
│ (needs SA)  │   │ (needs all) │   │             │
└─────────────┘   └─────────────┘   └─────────────┘
```

**Deployment order:**
1. networking (foundation)
2. security (identities)
3. cloudsql (uses networking)
4. redis (uses networking)
5. cloudrun-frontend (uses security)
6. cloudrun-backend (uses everything)

---

## Quick Reference

### Networking Module

**📁 Location:** `modules/networking/`
**📄 README:** [modules/networking/README.md](networking/README.md)

**What it creates:**
- VPC network
- Public and private subnets
- Cloud NAT for internet access
- VPC Access Connector for Cloud Run
- Firewall rules (health checks, internal, SSH)
- VPC peering for Cloud SQL

**Key concept:** Private networking with controlled internet access

**Common issue:** VPC connector takes 5-10 minutes to create

---

### Security Module

**📁 Location:** `modules/security/`
**📄 README:** [modules/security/README.md](security/README.md)

**What it creates:**
- Frontend service account
- Backend service account
- IAM bindings (Cloud SQL, Secret Manager, run.invoker)

**Key concept:** Least-privilege access control

**Common issue:** Frontend can't call backend (check run.invoker permission)

---

### Cloud SQL Module

**📁 Location:** `modules/cloudsql/`
**📄 README:** [modules/cloudsql/README.md](cloudsql/README.md)

**What it creates:**
- MySQL 8.0 instance (db-f1-micro)
- Application database
- Database user with random password
- Secrets in Secret Manager
- Automated backups

**Key concept:** Private database with VPC peering

**Common issue:** "Instance name already exists" (use random suffix, wait 7 days)

---

### Redis Module

**📁 Location:** `modules/redis/`
**📄 README:** [modules/redis/README.md](redis/README.md)

**What it creates:**
- Memorystore Redis instance (1 GB, BASIC tier)
- VPC authorization
- Transit encryption
- LRU eviction policy

**Key concept:** In-memory caching for performance

**Common issue:** AUTH errors (ensure auth string is passed to backend)

---

### Cloud Run Frontend Module

**📁 Location:** `modules/cloudrun-frontend/`
**📄 README:** [modules/cloudrun-frontend/README.md](cloudrun-frontend/README.md)

**What it creates:**
- Public Cloud Run service
- IAM policy (allUsers)
- Auto-scaling (0-10 instances)

**Key concept:** Public-facing presentation tier

**Common issue:** Container image not found (use default or build custom)

---

### Cloud Run Backend Module

**📁 Location:** `modules/cloudrun-backend/`
**📄 README:** [modules/cloudrun-backend/README.md](cloudrun-backend/README.md)

**What it creates:**
- Private Cloud Run service
- VPC connector integration
- Secret Manager integration
- IAM policy (authenticated only)

**Key concept:** Private API with VPC access

**Common issue:** Can't connect to database (check VPC connector, SA permissions)

---

## Understanding the Architecture

### Data Flow: User Request

```
1. User Browser
   ↓ HTTPS
2. Cloud Run Frontend (Public)
   ↓ Authenticated HTTPS (service account)
3. Cloud Run Backend (Private)
   ↓ VPC Connector
4. VPC Network
   ↓
5. Cloud SQL (Private IP) + Redis (Private IP)
```

### Security Layers

| Layer | Security | Implementation |
|-------|----------|----------------|
| **Network** | Isolation | VPC, private subnets, no public IPs |
| **Transport** | Encryption | HTTPS, TLS, transit encryption |
| **Identity** | Authentication | Service accounts, IAM |
| **Application** | Authorization | run.invoker permissions |
| **Data** | Secrets | Secret Manager, encrypted storage |

---

## Common Deployment Issues

### Issue 1: VPC Connector Timeout

**Module:** networking
**Error:** Connector creation timeout
**Solution:** Wait 5-10 minutes, this is normal

### Issue 2: Cloud SQL Name Collision

**Module:** cloudsql
**Error:** Instance name already exists
**Solution:** Change prefix or wait 7 days

### Issue 3: Backend Can't Access Database

**Module:** cloudrun-backend
**Checklist:**
- [ ] VPC connector created?
- [ ] Backend SA has cloudsql.client role?
- [ ] Database has private IP?
- [ ] Secret Manager secret exists?
- [ ] Backend SA has secretAccessor role?

### Issue 4: Frontend Can't Call Backend

**Module:** cloudrun-frontend, cloudrun-backend
**Checklist:**
- [ ] Frontend SA has run.invoker role?
- [ ] Backend IAM policy correct?
- [ ] Backend URL in frontend env var?

### Issue 5: Redis Connection Fails

**Module:** cloudrun-backend, redis
**Checklist:**
- [ ] Redis instance created?
- [ ] VPC connector works?
- [ ] Redis host/port correct?
- [ ] AUTH string provided?

---

## Cost Optimization Tips

### Development

1. **Destroy when not in use:**
   ```bash
   terraform destroy
   ```
   Save ~$80/month

2. **Use smallest tiers:**
   - db-f1-micro (not db-n1-standard-1)
   - 1 GB Redis (not 5 GB)
   - Min instances = 0 (not warm pools)

3. **Disable flow logs:**
   - Remove log_config from subnets
   - Save ~$5/month

### Production

1. **Use committed use discounts:**
   - Save 37% on Cloud SQL
   - Save 25% on Memorystore

2. **Right-size instances:**
   - Monitor CPU/memory usage
   - Scale down if underutilized

3. **Use Cloud CDN:**
   - Reduce Cloud Run requests
   - Cache static assets at edge

---

## Module Modification Guide

### Add a Module

1. **Create directory:**
   ```bash
   mkdir -p modules/new-module
   ```

2. **Create files:**
   ```bash
   touch modules/new-module/{main.tf,variables.tf,outputs.tf,README.md}
   ```

3. **Reference in root:**
   ```hcl
   module "new_module" {
     source = "./modules/new-module"
     # variables
   }
   ```

### Modify Existing Module

1. **Edit module files:**
   ```bash
   vim modules/networking/main.tf
   ```

2. **Update variables if needed:**
   ```bash
   vim modules/networking/variables.tf
   ```

3. **Test changes:**
   ```bash
   terraform plan
   ```

4. **Apply:**
   ```bash
   terraform apply
   ```

### Delete a Module

1. **Remove from root main.tf:**
   ```hcl
   # Comment out or delete module block
   # module "redis" {
   #   source = "./modules/redis"
   # }
   ```

2. **Apply to destroy resources:**
   ```bash
   terraform apply
   ```

---

## Testing Modules Individually

### Test Networking Module

```bash
cd modules/networking
terraform init
terraform plan -var="project_id=PROJECT_ID" -var="region=us-central1"
```

### Test with main.tf

```bash
# From root directory
terraform plan -target=module.networking
terraform apply -target=module.networking
```

**Warning:** Targeted applies can cause dependency issues. Use with caution.

---

## Documentation Standards

Each module README follows this structure:

1. **Purpose** - What the module does
2. **Components** - Each resource explained
3. **Configuration Breakdown** - Key settings explained
4. **Outputs** - What the module exposes
5. **Security Features** - Security implementations
6. **Cost Breakdown** - Monthly costs
7. **Common Issues** - Troubleshooting
8. **Best Practices** - Recommendations
9. **References** - Official documentation

---

## Contributing to Modules

### Before Making Changes

1. Read the module's README
2. Understand dependencies
3. Check impact on other modules

### After Making Changes

1. Update README if behavior changed
2. Update variables.tf descriptions
3. Test deployment
4. Update root documentation if needed

---

## References

- [Terraform Module Documentation](https://www.terraform.io/language/modules)
- [GCP Terraform Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Infrastructure as Code Best Practices](https://cloud.google.com/docs/terraform/best-practices-for-terraform)

---

## Getting Help

### Module-Specific Issues

1. **Read the module's README first**
2. Check "Common Issues" section
3. Review GCP documentation links

### General Issues

1. Check [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
2. Review Terraform error messages
3. Check GCP Console for resource status
4. View logs in Cloud Logging

### Still Stuck?

1. Run with debug logging:
   ```bash
   TF_LOG=DEBUG terraform apply
   ```

2. Check GCP status:
   ```bash
   gcloud components update
   gcloud auth list
   gcloud config list
   ```

3. Validate configuration:
   ```bash
   terraform validate
   terraform fmt -check -recursive
   ```

---

**Happy building! 🚀**
