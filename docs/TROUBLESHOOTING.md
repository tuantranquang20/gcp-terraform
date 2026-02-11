# Troubleshooting Guide

Common issues and their solutions when deploying this lab.

## General Troubleshooting Steps

Before diving into specific issues:

1. **Check Terraform version**: `terraform version` (should be >= 1.5.0)
2. **Verify gcloud authentication**: `gcloud auth list`
3. **Confirm project is set**: `gcloud config get-value project`
4. **Review Terraform state**: `terraform state list`
5. **Check GCP quotas**: [Quotas page](https://console.cloud.google.com/iam-admin/quotas)

---

## API and Permission Issues

### Error: API Not Enabled

**Symptoms:**
```
Error: Error creating Network: googleapi: Error 403: 
Compute Engine API has not been used in project X before or it is disabled.
```

**Cause**: Required GCP APIs are not enabled

**Solution:**
```bash
# Enable all required APIs
gcloud services enable \
  compute.googleapis.com \
  servicenetworking.googleapis.com \
  run.googleapis.com \
  vpcaccess.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  secretmanager.googleapis.com \
  --project=YOUR_PROJECT_ID

# Wait 1-2 minutes for APIs to propagate
```

---

### Error: Permission Denied

**Symptoms:**
```
Error: Error creating Service Account: googleapi: Error 403: 
Permission iam.serviceAccounts.create denied
```

**Cause**: Your account lacks necessary permissions

**Solution:**

Check your permissions:
```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"
```

Required roles:
- `roles/editor` (recommended for lab)
- Or specific roles: `roles/compute.admin`, `roles/run.admin`, `roles/cloudsql.admin`, etc.

Grant editor role:
```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/editor"
```

---

## Quota Issues

### Error: Quota Exceeded

**Symptoms:**
```
Error: Error creating VpcAccessConnector: 
Quota 'VPC_ACCESS_CONNECTORS' exceeded. Limit: 2.0 globally.
```

**Cause**: Project quotas are insufficient

**Solutions:**

1. **Request quota increase**:
   - Go to [Quotas page](https://console.cloud.google.com/iam-admin/quotas)
   - Filter by service and metric (e.g., "VPC Access Connectors")
   - Select quota and click "Edit Quotas"
   - Request increase (usually approved within hours for reasonable requests)

2. **Delete unused resources**:
   ```bash
   # List VPC connectors
   gcloud compute networks vpc-access connectors list --region=us-central1
   
   # Delete unused connector
   gcloud compute networks vpc-access connectors delete CONNECTOR_NAME --region=us-central1
   ```

3. **Use different region**:
   - Quotas are regional
   - Try `us-east1`, `europe-west1`, etc.

---

## Networking Issues

### Error: VPC Connector Creation Timeout

**Symptoms:**
```
Error: Error waiting for Creating VpcAccessConnector: 
timeout while waiting for state to become 'READY'
```

**Cause**: VPC connectors can take 5-10 minutes to create; occasional GCP delays

**Solutions:**

1. **Wait longer**:
   ```bash
   # Check connector status
   gcloud compute networks vpc-access connectors describe \
     lab-dev-connector \
     --region=us-central1
   ```

2. **Retry**:
   ```bash
   terraform apply
   ```
   Terraform will continue from where it left off.

3. **Manual cleanup if stuck**:
   ```bash
   # Delete the connector
   gcloud compute networks vpc-access connectors delete \
     lab-dev-connector \
     --region=us-central1
   
   # Remove from Terraform state
   terraform state rm module.networking.google_vpc_access_connector.connector
   
   # Re-apply
   terraform apply
   ```

---

### Error: IP Address Range Conflict

**Symptoms:**
```
Error: Error creating Subnetwork: googleapi: Error 400: 
IP address range 10.0.1.0/24 conflicts with existing subnet
```

**Cause**: CIDR range already in use (maybe from previous deployment)

**Solution:**

1. **Change CIDR ranges** in `modules/networking/variables.tf`:
   ```hcl
   variable "public_subnet_cidr" {
     default = "10.1.1.0/24"  # Changed from 10.0.1.0/24
   }
   
   variable "private_subnet_cidr" {
     default = "10.1.2.0/24"  # Changed from 10.0.2.0/24
   }
   ```

2. **Or delete old VPC**:
   ```bash
   gcloud compute networks list
   gcloud compute networks delete OLD_VPC_NAME
   ```

---

## Cloud SQL Issues

### Error: Cloud SQL Instance Already Exists

**Symptoms:**
```
Error: Error creating Cloud SQL instance: googleapi: Error 409: 
The Cloud SQL instance already exists. When deleted, instance names 
cannot be reused for up to 7 days.
```

**Cause**: Cloud SQL instance names are globally unique and retained for 7 days after deletion

**Solutions:**

1. **Change prefix variable** to generate new name:
   ```hcl
   # In terraform.tfvars
   prefix = "lab2"  # Changed from "lab"
   ```

2. **Wait 7 days** (if you recently destroyed this)

3. **Remove from state and use existing** (if instance still exists):
   ```bash
   terraform import module.cloudsql.google_sql_database_instance.main INSTANCE_NAME
   ```

---

### Error: Private Service Connection Failed

**Symptoms:**
```
Error: Error creating Service Networking Connection: 
Cannot create a VPC peering to a network that has overlapping IP ranges
```

**Cause**: IP range conflicts with existing VPC peering

**Solution:**

1. **Check existing peerings**:
   ```bash
   gcloud compute networks peerings list
   ```

2. **Delete old peering** if safe:
   ```bash
   gcloud services vpc-peerings delete \
     --service=servicenetworking.googleapis.com \
     --network=OLD_VPC_NAME
   ```

3. **Use fresh VPC** (destroy and re-create with different name)

---

## Cloud Run Issues

### Error: Container Image Not Found

**Symptoms:**
```
Error: Error creating Cloud Run Service: 
Revision 'lab-dev-frontend-00001-abc' is not ready and cannot serve traffic.
Image 'gcr.io/my-project/app:latest' not found.
```

**Cause**: Specified container image doesn't exist or is private

**Solutions:**

1. **Use default hello-world image**:
   ```hcl
   # In terraform.tfvars
   frontend_image = "gcr.io/cloudrun/hello"
   backend_image  = "gcr.io/cloudrun/hello"
   ```

2. **Build and push your image**:
   ```bash
   docker build -t gcr.io/YOUR_PROJECT_ID/app:latest .
   docker push gcr.io/YOUR_PROJECT_ID/app:latest
   ```

3. **Grant Cloud Run access to private GCR**:
   ```bash
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:SERVICE_ACCOUNT@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/storage.objectViewer"
   ```

---

### Error: Service Account Not Found

**Symptoms:**
```
Error: Error creating Cloud Run Service: 
Service account backend-sa@project.iam.gserviceaccount.com does not exist
```

**Cause**: Dependency ordering issue; service account not created yet

**Solution:**

Service accounts should be created first due to `depends_on`. If this occurs:

```bash
# Check if service account exists
gcloud iam service-accounts list

# If not, there may be an IAM API issue
# Re-run apply:
terraform apply
```

---

## Redis Issues

### Error: Redis Zone Unavailable

**Symptoms:**
```
Error: Error creating Redis Instance: 
Redis instance cannot be created in zone us-central1-a due to resource constraints
```

**Cause**: GCP resource availability varies by zone

**Solutions:**

1. **Change region**:
   ```hcl
   # In terraform.tfvars
   region = "us-east1"
   ```

2. **Retry later**: Capacity issues are usually temporary

3. **Use alternative tier**: Try STANDARD_HA (more costly but better availability)

---

## State and Dependency Issues

### Error: Resource Dependencies

**Symptoms:**
```
Error: Cycle: module.cloudrun_backend.google_cloud_run_v2_service.backend, 
module.cloudsql.google_sql_database_instance.main
```

**Cause**: Circular dependency in Terraform configuration

**Solution:**

This shouldn't happen with the lab code. If it does:

```bash
# View dependency graph
terraform graph | dot -Tpng > graph.png

# Review and fix dependencies in code
# Ensure depends_on is used correctly
```

---

### Error: State Lock

**Symptoms:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        xxxxxx-yyyy-zzzz
  Operation: OperationTypeApply
  Who:       user@machine
  Created:   2024-02-11 10:30:00
```

**Cause**: Another Terraform operation is running, or previous operation was interrupted

**Solution:**

1. **Wait** if another operation is genuinely running

2. **Force unlock** if operation was interrupted:
   ```bash
   terraform force-unlock LOCK_ID
   ```
   Use the ID shown in the error message.

---

## Validation Issues

### Error: Invalid Terraform Configuration

**Symptoms:**
```
Error: Unsupported argument
An argument named "invalid_arg" is not expected here.
```

**Cause**: Syntax error or wrong provider version

**Solutions:**

1. **Validate configuration**:
   ```bash
   terraform validate
   ```

2. **Format code**:
   ```bash
   terraform fmt -recursive
   ```

3. **Check provider version**:
   ```bash
   terraform version
   terraform providers
   ```

---

## Cost Issues

### Unexpected Charges

**Symptoms**: GCP billing shows unexpected costs

**Common culprits:**
- Redis (most expensive: ~$36/month for 1GB BASIC)
- Cloud SQL (~$7-10/month for db-f1-micro)
- VPC Access Connector (~$11/month)

**Solutions:**

1. **Destroy when not in use**:
   ```bash
   terraform destroy
   ```

2. **Check billing**:
   ```bash
   gcloud billing accounts list
   gcloud billing projects describe YOUR_PROJECT_ID
   ```

3. **Set budget alerts**: See [SETUP.md](../SETUP.md)

4. **Use GCP's Pricing Calculator**: [Pricing Calculator](https://cloud.google.com/products/calculator)

---

## Destruction Issues

### Error: Cannot Destroy VPC

**Symptoms:**
```
Error: Error deleting Network: The network resource 'lab-dev-vpc' 
is already being used by 'projects/X/global/firewalls/lab-dev-allow-internal'
```

**Cause**: Resources still reference the VPC

**Solution:**

Terraform should handle this with dependencies, but if not:

```bash
# Destroy in stages
terraform destroy -target=module.cloudrun_frontend
terraform destroy -target=module.cloudrun_backend
terraform destroy -target=module.cloudsql
terraform destroy -target=module.redis
terraform destroy
```

---

### Error: Cloud SQL Cannot Be Deleted

**Symptoms:**
```
Error: Error deleting Cloud SQL instance: 
The instance or operation is not in an appropriate state to handle the request.
```

**Cause**: Cloud SQL deletion protection is enabled

**Solution:**

1. **Check deletion protection**:
   ```bash
   gcloud sql instances describe INSTANCE_NAME
   ```

2. **Disable it** (in `modules/cloudsql/main.tf`):
   ```hcl
   deletion_protection = false
   ```

3. **Re-apply and destroy**:
   ```bash
   terraform apply  # Update deletion_protection
   terraform destroy
   ```

---

## Getting Help

If you encounter issues not covered here:

1. **Check Terraform docs**: [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
2. **GCP Status**: [status.cloud.google.com](https://status.cloud.google.com)
3. **Terraform verbose logs**:
   ```bash
   export TF_LOG=DEBUG
   terraform apply
   ```
4. **GCP Support**: [cloud.google.com/support](https://cloud.google.com/support)

---

## Debug Commands Reference

```bash
# Terraform debugging
terraform validate              # Check syntax
terraform fmt -check -recursive # Check formatting
terraform plan -out=plan.out    # Save plan
terraform show plan.out         # View saved plan
export TF_LOG=DEBUG             # Enable debug logging
terraform refresh               # Sync state with reality

# GCP debugging
gcloud services list --enabled                    # Check enabled APIs
gcloud projects get-iam-policy YOUR_PROJECT_ID    # Check permissions
gcloud compute networks list                      # List VPCs
gcloud run services list                          # List Cloud Run services
gcloud sql instances list                         # List databases
gcloud redis instances list --region=us-central1  # List Redis instances

# State management
terraform state list                              # List all resources
terraform state show RESOURCE_ADDRESS             # Show resource details
terraform state rm RESOURCE_ADDRESS               # Remove from state (careful!)
terraform import RESOURCE_ADDRESS ID              # Import existing resource
```

---

**Still stuck? Create an issue in the repository or consult GCP documentation! 💪**
