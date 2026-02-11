# Cloud SQL Module

## Purpose

This module deploys a managed MySQL database with private IP addressing, automated backups, and secure credential management using Secret Manager.

## Components

### 1. Random Database Name Suffix
**Resource:** `random_id.db_name_suffix`

**What it does:**
- Generates a random 4-byte (8 character hex) suffix
- Appended to database instance name
- Example: `lab-dev-db-a1b2c3d4`

**Why it's necessary:**
- Cloud SQL instance names must be globally unique
- Names cannot be reused for 7 days after deletion
- Random suffix prevents name collisions
- Allows multiple deployments without conflicts

---

### 2. Random Database Password
**Resource:** `random_password.db_password`

**What it does:**
- Generates a secure random password (16 characters)
- Includes special characters
- Stored in Terraform state (encrypted if using remote backend)

**Why it's necessary:**
- Never use hardcoded or predictable passwords
- Meets MySQL password complexity requirements
- Automatically generated, no human intervention
- Different password for each deployment

**Security note:** Password is stored in Secret Manager and Terraform state. Use encrypted state backend in production.

---

### 3. Cloud SQL Instance
**Resource:** `google_sql_database_instance.main`

**What it does:**
- Creates a MySQL 8.0 managed database instance
- Configured with private IP only (no public IP)
- Smallest tier (db-f1-micro) for cost efficiency
- Zonal availability (REGIONAL for production HA)

**Why it's necessary:**
- Provides persistent relational data storage
- Fully managed (no server maintenance)
- Automated backups and updates
- Scalable performance tiers

**Key configurations:**

#### Database Version
```hcl
database_version = "MYSQL_8_0"
```
- Latest MySQL version with modern features
- Better performance than MySQL 5.7
- Long-term support

#### Instance Tier
```hcl
tier = "db-f1-micro"
```
- Shared-core instance (cost-effective)
- 0.6 GB RAM, limited CPU
- Good for development/testing
- ~$7-10/month

**Production alternatives:**
- `db-n1-standard-1`: 1 vCPU, 3.75 GB RAM (~$50/month)
- `db-n1-standard-2`: 2 vCPU, 7.5 GB RAM (~$100/month)

#### IP Configuration
```hcl
ip_configuration {
  ipv4_enabled    = false    # No public IP!
  private_network = var.network_id
}
```
- **Critical security feature:** Database is not accessible from internet
- Only accessible from VPC (via VPC peering)
- Backend Cloud Run connects through VPC connector

#### Deletion Protection
```hcl
deletion_protection = false
```
- Set to `false` for lab (easy cleanup)
- **Set to `true` in production** to prevent accidental deletion
- Terraform destroy will fail if true (must manually disable first)

---

### 4. Backup Configuration
**Configuration Block within Instance**

**What it does:**
```hcl
backup_configuration {
  enabled            = true
  start_time         = "03:00"      # 3 AM UTC
  binary_log_enabled = true
}
```

**Why it's necessary:**
- Automated daily backups prevent data loss
- Binary logging enables point-in-time recovery
- Can restore to any moment in the last 7 days
- Backups are encrypted and geo-redundant

**Backup process:**
1. Full backup at 3 AM UTC daily
2. Binary logs captured continuously
3. Retention: 7 days by default
4. Restore in ~5-10 minutes

**Cost:** ~$0.08/GB/month for backups

---

### 5. Maintenance Window
**Configuration Block within Instance**

**What it does:**
```hcl
maintenance_window {
  day          = 7       # Sunday
  hour         = 3       # 3 AM UTC
  update_track = "stable"
}
```

**Why it's necessary:**
- GCP needs to apply security patches and updates
- Scheduled maintenance reduces surprise downtime
- Choose low-traffic time (Sunday 3 AM)
- "stable" track gets thoroughly tested updates

---

### 6. Database Flags
**Configuration Block within Instance**

**What it does:**
```hcl
database_flags {
  name  = "max_connections"
  value = "100"
}
```

**Why it's necessary:**
- Default max_connections may be too low
- Prevents "Too many connections" errors
- Cloud Run can scale to many instances
- Each instance may open multiple connections

**Other useful flags:**
- `slow_query_log = ON` - Debug performance issues
- `long_query_time = 2` - Log queries taking > 2 seconds
- `max_allowed_packet = 67108864` - Allow larger queries

---

### 7. Application Database
**Resource:** `google_sql_database.database`

**What it does:**
- Creates a database named `{prefix}_{environment}_app`
- Example: `lab_dev_app`
- Schema is created by backend application on first run

**Why it's necessary:**
- Separates application data from system databases
- Can create multiple databases per instance
- Enables logical separation of environments

---

### 8. Database User
**Resource:** `google_sql_user.user`

**What it does:**
- Creates a MySQL user `{prefix}_user` (e.g., `lab_user`)
- Assigns the random password generated earlier
- Grants access to the instance

**Why it's necessary:**
- Root user should never be used by applications
- Principle of least privilege
- Can limit user to specific databases
- Easier to rotate credentials per application

**Permissions:**
- User has access to all databases (MySQL default)
- In production, limit with GRANT statements

---

### 9. Database Password Secret
**Resource:** `google_secret_manager_secret.db_password`

**What it does:**
- Creates a secret in Secret Manager named `{prefix}-{environment}-db-password`
- Configured with automatic replication (multi-region)

**Why it's necessary:**
- Passwords must never be in plain text env vars
- Secret Manager provides secure storage
- Enables access auditing
- Supports secret rotation

---

### 10. Database Password Secret Version
**Resource:** `google_secret_manager_secret_version.db_password`

**What it does:**
- Stores the actual password value in the secret
- Creates version 1 (secrets can have multiple versions)

**Why it's necessary:**
- Secrets need versions for rotation
- Can roll back to previous password if needed
- Backend reads "latest" version automatically

---

### 11. Database Connection Secret
**Resource:** `google_secret_manager_secret.db_connection`

**What it does:**
- Creates another secret for full connection info
- Named `{prefix}-{environment}-db-connection`

**Why it's necessary:**
- Stores all connection details in one place
- Backend only needs to read one secret
- Easier than managing multiple env vars

---

### 12. Connection Secret Version
**Resource:** `google_secret_manager_secret_version.db_connection`

**What it does:**
- Stores JSON with complete connection details:
```json
{
  "host": "10.x.x.x",
  "port": 3306,
  "database": "lab_dev_app",
  "username": "lab_user",
  "password": "randomly-generated-password"
}
```

**Why it's necessary:**
- Backend can parse this JSON and connect
- Single source of truth for all connection params
- Easier to update (just update secret, no code changes)

**How backend uses it:**
```javascript
const secret = JSON.parse(process.env.DB_SECRET);
const connection = mysql.createConnection({
  host: secret.host,
  user: secret.username,
  password: secret.password,
  database: secret.database
});
```

---

## Architecture

### VPC Peering for Private IP

```
Cloud SQL Instance (Google managed network)
            ↕ VPC Peering
    Your Custom VPC
            ↕ VPC Connector
    Cloud Run Backend
```

**Key points:**
- Cloud SQL runs in Google's network, not your VPC
- VPC peering connects the two networks
- Private IP is allocated from your VPC's reserved range
- Traffic never touches the internet

---

## Outputs

| Output | Description | Used By |
|--------|-------------|---------|
| `instance_name` | Cloud SQL instance name | Monitoring, logs |
| `private_ip_address` | Database private IP | Backend env var |
| `database_name` | Application database name | Backend env var |
| `db_secret_id` | Secret Manager secret ID | Backend env var |
| `connection_name` | Cloud SQL connection name | Cloud SQL Proxy (if used) |

---

## Security Features

### ✅ No Public IP
Database is completely inaccessible from internet.

### ✅ Private IP Only
Only VPC resources can connect.

### ✅ Automated Backups
Data loss protection with 7-day retention.

### ✅ Encrypted Storage
Data encrypted at rest (Google-managed keys).

### ✅ Encrypted Transit
SSL/TLS connections supported (optional but recommended).

### ✅ Secret Manager
Credentials never in plain text.

### ✅ IAM Integration
Backend service account needs `cloudsql.client` role.

---

## Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| db-f1-micro instance | ~$7-10 |
| SSD storage (10 GB) | ~$1.70 |
| Backups (10 GB) | ~$0.80 |
| Secret Manager | Free (first 6 secrets) |
| **Total** | **~$10/month** |

**Cost optimization:**
- db-f1-micro is cheapest option
- Consider stopping instance when not in use (costs ~50%)
- Delete after lab completion to avoid charges

---

## Performance Characteristics

### db-f1-micro Limits:
- **Connections:** Up to 100 (configured)
- **Storage:** 10 GB (can expand to 30 TB)
- **RAM:** 0.6 GB
- **CPU:** Shared core (burst capability)

**Good for:**
- Development and testing
- Low-traffic applications (< 100 req/min)
- Small datasets (< 5 GB)

**Not good for:**
- Production workloads
- High concurrency (> 50 concurrent connections)
- CPU-intensive queries

---

## Common Issues

### Error: Instance Name Already Exists

**Problem:** `Instance already exists` or `must wait 7 days`
**Cause:** Cloud SQL instance names are reserved for 7 days after deletion
**Solution:** Change `prefix` variable or wait 7 days

### Error: Cannot Create VPC Peering

**Problem:** `Overlapping IP ranges` or `peering already exists`
**Cause:** VPC networking module didn't complete successfully
**Solution:** 
```bash
terraform destroy -target=module.cloudsql
terraform destroy -target=module.networking
terraform apply
```

### Backend Cannot Connect

**Problem:** Connection timeout or refused
**Solutions:**
1. Check VPC connector exists: `gcloud compute networks vpc-access connectors list`
2. Verify private IP: `gcloud sql instances describe INSTANCE_NAME`
3. Check backend has `cloudsql.client` role
4. Test manually: `mysql -h PRIVATE_IP -u lab_user -p`

---

## Connecting to the Database

### From Cloud Run Backend (Automatic)

```javascript
// Backend automatically gets DB_SECRET env var
const secret = JSON.parse(process.env.DB_SECRET);
const pool = mysql.createPool({
  host: secret.host,
  user: secret.username,
  password: secret.password,
  database: secret.database
});
```

### From Cloud Shell (Testing)

```bash
# Get private IP
PRIVATE_IP=$(terraform output -raw database_private_ip)

# Get password from Secret Manager
PASSWORD=$(gcloud secrets versions access latest --secret="lab-dev-db-password")

# Connect
mysql -h $PRIVATE_IP -u lab_user -p$PASSWORD lab_dev_app
```

### Using Cloud SQL Proxy (Alternative)

```bash
# Download proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.0.0/cloud-sql-proxy.darwin.amd64

# Run proxy
./cloud-sql-proxy --private-ip INSTANCE_CONNECTION_NAME

# Connect through proxy
mysql -h 127.0.0.1 -u lab_user -p
```

---

## Best Practices

### ✅ Always Enable Backups
```hcl
backup_configuration {
  enabled = true
}
```

### ✅ Enable Binary Logs (Point-in-Time Recovery)
```hcl
binary_log_enabled = true
```

### ✅ Schedule Maintenance Windows
```hcl
maintenance_window {
  day  = 7  # Sunday (low traffic)
  hour = 3  # 3 AM
}
```

### ✅ Use Private IP
```hcl
ipv4_enabled = false
```

### ✅ Enable Deletion Protection in Production
```hcl
deletion_protection = true
```

### ✅ Use Secret Manager for Credentials
Never hardcode passwords.

### ✅ Monitor Slow Queries
```hcl
database_flags {
  name  = "slow_query_log"
  value = "ON"
}
```

---

## References

- [Cloud SQL for MySQL](https://cloud.google.com/sql/docs/mysql)
- [Private IP Configuration](https://cloud.google.com/sql/docs/mysql/configure-private-ip)
- [Backup and Recovery](https://cloud.google.com/sql/docs/mysql/backup-recovery/backups)
- [Secret Manager](https://cloud.google.com/secret-manager/docs)
