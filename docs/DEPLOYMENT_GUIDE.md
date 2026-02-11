# Deployment Guide

This step-by-step guide will walk you through deploying the 3-tier architecture.

## Prerequisites

✅ Complete [SETUP.md](../SETUP.md) first
✅ GCP project created and configured
✅ Required APIs enabled
✅ gcloud CLI authenticated
✅ Terraform installed and configured

## Deployment Steps

### Step 1: Initialize Terraform

Navigate to the project directory and initialize Terraform:

```bash
cd gcp-terraform

terraform init
```

**Expected Output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/google versions matching "~> 5.0"...
- Finding hashicorp/random versions matching "~> 3.5"...
- Installing hashicorp/google v5.x.x...
- Installing hashicorp/random v3.x.x...

Terraform has been successfully initialized!
```

**What happens:**
- Downloads required provider plugins
- Initializes module dependencies
- Creates `.terraform` directory
- Creates `.terraform.lock.hcl` for version locking

---

### Step 2: Review the Plan

See what Terraform will create:

```bash
terraform plan
```

**Expected Resources (approximately 30-35):**

```
Plan: 35 to add, 0 to change, 0 to destroy.

Resources to be created:
  # Networking (11 resources)
  + google_compute_network.vpc
  + google_compute_subnetwork.public
  + google_compute_subnetwork.private
  + google_compute_router.router
  + google_compute_router_nat.nat
  + google_vpc_access_connector.connector
  + google_compute_firewall.allow_health_checks
  + google_compute_firewall.allow_internal
  + google_compute_firewall.allow_iap_ssh
  + google_compute_global_address.private_ip_address
  + google_service_networking_connection.private_vpc_connection

  # Security (5 resources)
  + google_service_account.frontend
  + google_service_account.backend
  + google_project_iam_member.backend_secret_accessor
  + google_project_iam_member.backend_cloudsql_client
  + google_project_iam_member.frontend_invoker

  # Cloud SQL (7 resources)
  + random_id.db_name_suffix
  + random_password.db_password
  + google_sql_database_instance.main
  + google_sql_database.database
  + google_sql_user.user
  + google_secret_manager_secret.db_password
  + google_secret_manager_secret_version.db_password
  + google_secret_manager_secret.db_connection
  + google_secret_manager_secret_version.db_connection

  # Redis (1 resource)
  + google_redis_instance.cache

  # Cloud Run (5 resources)
  + google_cloud_run_v2_service.backend
  + google_cloud_run_v2_service_iam_policy.backend_policy
  + google_cloud_run_v2_service.frontend
  + google_cloud_run_v2_service_iam_member.public_access
```

**Review carefully:**
- Check resource names match your expectations
- Verify region settings
- Confirm no unexpected resources

---

### Step 3: Apply the Configuration

Deploy the infrastructure:

```bash
terraform apply
```

You'll see the plan again, then:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: 
```

**Type `yes` and press Enter**

**Deployment Timeline:**

| Phase | Duration | What's Happening |
|-------|----------|------------------|
| Networking | 2-3 min | VPC, subnets, NAT, firewall rules |
| VPC Connector | 3-5 min | Serverless VPC Access setup |
| Cloud SQL | 5-8 min | MySQL instance provisioning |
| Redis | 3-5 min | Memorystore instance creation |
| Cloud Run | 1-2 min | Container services deployment |
| **Total** | **15-20 min** | Complete deployment |

> **☕ Tip**: This is a good time for a coffee break!

**Progress Indicators:**
```
module.networking.google_compute_network.vpc: Creating...
module.networking.google_compute_network.vpc: Creation complete after 15s
module.networking.google_compute_subnetwork.public: Creating...
module.networking.google_compute_subnetwork.private: Creating...
...
module.cloudsql.google_sql_database_instance.main: Still creating... [5m0s elapsed]
module.cloudsql.google_sql_database_instance.main: Still creating... [6m0s elapsed]
...
```

---

### Step 4: Review the Outputs

Once complete, you'll see:

```
Apply complete! Resources: 35 added, 0 changed, 0 destroyed.

Outputs:

backend_url = "https://lab-dev-backend-xxxxx-uc.a.run.app"
database_private_ip = <sensitive>
frontend_url = "https://lab-dev-frontend-xxxxx-uc.a.run.app"
instructions = <<EOT

🎉 Deployment Complete! 

Frontend URL: https://lab-dev-frontend-xxxxx-uc.a.run.app
Backend URL:  https://lab-dev-backend-xxxxx-uc.a.run.app

Next steps:
1. Visit the frontend URL to see your application
2. Check Cloud Run logs: gcloud run services logs read lab-dev-frontend --project=your-project-id
3. Review the docs/ARCHITECTURE.md for detailed architecture explanation
4. When done, run 'terraform destroy' to clean up resources

EOT
redis_host = <sensitive>
vpc_name = "lab-dev-vpc"
```

**Save these URLs!** You'll need them for testing.

---

### Step 5: Verify the Deployment

#### 5.1 Test the Frontend

```bash
# Get the frontend URL (if you didn't save it)
FRONTEND_URL=$(terraform output -raw frontend_url)

# Visit in browser or curl
curl $FRONTEND_URL
```

**Expected**: You should see the default Cloud Run "hello world" page.

#### 5.2 Check Cloud Run Services

```bash
gcloud run services list --project=YOUR_PROJECT_ID
```

**Expected Output:**
```
SERVICE                REGION       URL                                        
lab-dev-frontend       us-central1  https://lab-dev-frontend-xxxxx-uc.a.run.app
lab-dev-backend        us-central1  https://lab-dev-backend-xxxxx-uc.a.run.app
```

#### 5.3 Verify Database

```bash
# List Cloud SQL instances
gcloud sql instances list --project=YOUR_PROJECT_ID
```

**Expected Output:**
```
NAME                DATABASE_VERSION  LOCATION      TIER        PRIMARY_ADDRESS
lab-dev-db-xxxxx    MYSQL_8_0         us-central1   db-f1-micro 10.x.x.x
```

Note: Only private IP, no public IP (secure!)

#### 5.4 Check Redis

```bash
# List Redis instances
gcloud redis instances list --region=us-central1 --project=YOUR_PROJECT_ID
```

**Expected Output:**
```
NAME             VERSION    REGION       TIER   SIZE_GB  HOST
lab-dev-redis    REDIS_7_0  us-central1  BASIC  1        10.x.x.x
```

#### 5.5 View in GCP Console

Open [GCP Console](https://console.cloud.google.com) and explore:

1. **Cloud Run**: See deployed services, logs, metrics
2. **VPC Network**: View VPC, subnets, firewall rules
3. **Cloud SQL**: Check database instance details
4. **Memorystore**: View Redis instance
5. **Secret Manager**: See stored secrets (but not values)

---

### Step 6: View Sensitive Outputs

To see sensitive values (database IP, Redis host):

```bash
# Database private IP
terraform output database_private_ip

# Redis host
terraform output redis_host
```

**Security Note**: These are marked sensitive to prevent accidental exposure in logs.

---

## Testing the Architecture

### Test 1: Frontend Accessibility

```bash
# Should return 200 OK
curl -I $(terraform output -raw frontend_url)
```

### Test 2: Backend is Private

Try accessing the backend directly:

```bash
# Should return 403 Forbidden (requires authentication)
curl -I $(terraform output -raw backend_url)
```

**Expected**: Access denied without proper authentication.

### Test 3: Check Logs

```bash
# Frontend logs
gcloud run services logs read lab-dev-frontend \
  --project=YOUR_PROJECT_ID \
  --limit=50

# Backend logs
gcloud run services logs read lab-dev-backend \
  --project=YOUR_PROJECT_ID \
  --limit=50
```

---

## Deploying Your Own Application

To replace the hello-world containers with your own:

### 1. Build Your Container

```bash
# Example: Build a Node.js app
cd your-app-directory
docker build -t gcr.io/YOUR_PROJECT_ID/frontend:v1 .
docker push gcr.io/YOUR_PROJECT_ID/frontend:v1
```

### 2. Update Variables

Edit `terraform.tfvars`:

```hcl
frontend_image = "gcr.io/YOUR_PROJECT_ID/frontend:v1"
backend_image  = "gcr.io/YOUR_PROJECT_ID/backend:v1"
```

### 3. Re-apply

```bash
terraform apply
```

Only the Cloud Run services will be updated (in-place revision).

---

## Common Deployment Issues

### Issue: API Not Enabled

**Error:**
```
Error: Error creating Network: googleapi: Error 403: 
Compute Engine API has not been used in project...
```

**Solution:**
```bash
gcloud services enable compute.googleapis.com --project=YOUR_PROJECT_ID
```

### Issue: Quota Exceeded

**Error:**
```
Error: Error creating VpcAccessConnector: 
Quota 'VPC_ACCESS_CONNECTORS' exceeded
```

**Solution:**
- Request quota increase in GCP Console
- Or choose a different region
- Or delete unused connectors

### Issue: VPC Connector Timeout

**Error:**
```
Error: Error waiting for Creating VpcAccessConnector: timeout while waiting for state
```

**Cause**: VPC connectors can take 5-10 minutes to create

**Solution:**
- Wait and try again
- Check [VPC Access status page](https://status.cloud.google.com/)

### Issue: Cloud SQL Already Exists

**Error:**
```
Error: Error, failed to create instance lab-dev-db-xxxxx: 
googleapi: Error 409: Already exists
```

**Cause**: Cloud SQL instance names must be unique for 7 days after deletion

**Solution:**
```bash
# Manually remove from state
terraform state rm module.cloudsql.google_sql_database_instance.main

# Or change the prefix variable
```

---

## Next Steps

1. ✅ **Understand what was deployed**: Review [ARCHITECTURE.md](ARCHITECTURE.md)
2. ✅ **Deploy your application**: Replace container images
3. ✅ **Monitor your infrastructure**: Set up Cloud Monitoring
4. ✅ **Experiment**: Try modifying the Terraform and redeploying
5. ✅ **Clean up**: When done, follow [CLEANUP.md](CLEANUP.md)

---

## Useful Commands

```bash
# Show all outputs
terraform output

# Show specific output
terraform output frontend_url

# Show sensitive output
terraform output database_private_ip

# Refresh outputs (if something changed manually)
terraform refresh

# Show current state
terraform show

# List all resources
terraform state list

# View specific resource
terraform state show module.networking.google_compute_network.vpc
```

---

**Deployment successful? Time to explore your architecture! 🎉**

**Next**: [Learn about troubleshooting →](TROUBLESHOOTING.md)
