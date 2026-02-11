# Cleanup Guide

This guide explains how to safely destroy all resources created by this lab to avoid ongoing costs.

## Why Cleanup Matters

**Cost Implications:**
- Cloud SQL: ~$7-10/month (continuous charging)
- Redis: ~$36/month (continuous charging)
- VPC Connector: ~$11/month (continuous charging)
- Cloud Run: Minimal when idle (pay-per-use)

**Total monthly cost if left running**: ~$50-60

Even when not in use, most resources incur costs. Cleanup is essential!

---

## Quick Cleanup (Recommended)

### One Command Destruction

```bash
cd gcp-terraform
terraform destroy
```

**You'll be prompted for confirmation:**
```
Plan: 0 to add, 0 to change, 35 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: 
```

**Type `yes` and press Enter**

---

## Destruction Timeline

| Resource Type | Destruction Time |
|---------------|------------------|
| Cloud Run services | ~30 seconds |
| VPC Connector | ~3-5 minutes |
| Redis | ~3-5 minutes |
| Cloud SQL | ~5-10 minutes |
| Networking (VPC, subnets, firewall) | ~1-2 minutes |
| **Total** | **15-20 minutes** |

**Progress indicators:**
```
module.cloudrun_frontend.google_cloud_run_v2_service.frontend: Destroying... [id=...]
module.cloudrun_frontend.google_cloud_run_v2_service.frontend: Destruction complete after 25s
module.cloudsql.google_sql_database_instance.main: Destroying... [id=...]
module.cloudsql.google_sql_database_instance.main: Still destroying... [5m0s elapsed]
module.cloudsql.google_sql_database_instance.main: Still destroying... [6m0s elapsed]
...
Destroy complete! Resources: 35 destroyed.
```

---

## Selective Cleanup

If you want to keep some resources and only destroy others:

### Destroy Specific Modules

```bash
# Destroy only Cloud Run services (keep database for later)
terraform destroy -target=module.cloudrun_frontend -target=module.cloudrun_backend

# Destroy only expensive resources (Redis)
terraform destroy -target=module.redis

# Destroy database only
terraform destroy -target=module.cloudsql
```

### Destroy by Resource Type

```bash
# List all resources
terraform state list

# Destroy specific resource
terraform destroy -target=module.redis.google_redis_instance.cache
```

---

## Verification

### Confirm Resources Are Deleted

After destruction, verify in GCP Console or via gcloud:

```bash
# Check Cloud Run services
gcloud run services list --project=YOUR_PROJECT_ID
# Expected: No services or "Listed 0 items."

# Check Cloud SQL instances
gcloud sql instances list --project=YOUR_PROJECT_ID
# Expected: No instances or "Listed 0 items."

# Check Redis instances
gcloud redis instances list --region=us-central1 --project=YOUR_PROJECT_ID
# Expected: No instances

# Check VPCs
gcloud compute networks list --project=YOUR_PROJECT_ID
# Expected: Only 'default' VPC (if you have one)

# Check VPC connectors
gcloud compute networks vpc-access connectors list --region=us-central1 --project=YOUR_PROJECT_ID
# Expected: No connectors
```

### Check Billing

1. Go to [GCP Billing](https://console.cloud.google.com/billing)
2. View current project costs
3. Verify costs drop to near $0 within 24 hours

---

## Common Cleanup Issues

### Issue: Cannot Destroy Cloud SQL

**Error:**
```
Error: Error deleting Cloud SQL instance: 
deletion_protection is enabled for this instance.
```

**Solution:**

1. Edit `modules/cloudsql/main.tf`:
   ```hcl
   deletion_protection = false
   ```

2. Apply change:
   ```bash
   terraform apply
   ```

3. Destroy:
   ```bash
   terraform destroy
   ```

---

### Issue: VPC Still Has Resources

**Error:**
```
Error: Error when reading or editing Network: 
The network resource is already being used by other resources.
```

**Cause**: Some resources reference the VPC

**Solution:**

Destroy in stages:
```bash
terraform destroy -target=module.cloudrun_frontend
terraform destroy -target=module.cloudrun_backend
terraform destroy -target=module.redis
terraform destroy -target=module.cloudsql
terraform destroy -target=module.networking
terraform destroy
```

---

### Issue: Stale State

**Problem**: Terraform thinks resources exist, but they're already deleted

**Solution:**

```bash
# Remove specific resource from state
terraform state rm module.cloudsql.google_sql_database_instance.main

# Or refresh state
terraform refresh

# Then destroy
terraform destroy
```

---

## Manual Cleanup (If Terraform Fails)

If `terraform destroy` fails completely, manually delete via gcloud:

### Delete Cloud Run Services
```bash
gcloud run services delete lab-dev-frontend --region=us-central1 --project=YOUR_PROJECT_ID
gcloud run services delete lab-dev-backend --region=us-central1 --project=YOUR_PROJECT_ID
```

### Delete Cloud SQL
```bash
# List instances
gcloud sql instances list --project=YOUR_PROJECT_ID

# Delete instance
gcloud sql instances delete INSTANCE_NAME --project=YOUR_PROJECT_ID
```

### Delete Redis
```bash
gcloud redis instances delete lab-dev-redis --region=us-central1 --project=YOUR_PROJECT_ID
```

### Delete VPC Connector
```bash
gcloud compute networks vpc-access connectors delete lab-dev-connector --region=us-central1 --project=YOUR_PROJECT_ID
```

### Delete Networking
```bash
# Delete firewall rules
gcloud compute firewall-rules delete lab-dev-allow-health-checks --project=YOUR_PROJECT_ID
gcloud compute firewall-rules delete lab-dev-allow-internal --project=YOUR_PROJECT_ID
gcloud compute firewall-rules delete lab-dev-allow-iap-ssh --project=YOUR_PROJECT_ID

# Delete Cloud Router NAT
gcloud compute routers nats delete lab-dev-nat --router=lab-dev-router --region=us-central1 --project=YOUR_PROJECT_ID

# Delete Cloud Router
gcloud compute routers delete lab-dev-router --region=us-central1 --project=YOUR_PROJECT_ID

# Delete subnets
gcloud compute networks subnets delete lab-dev-public-subnet --region=us-central1 --project=YOUR_PROJECT_ID
gcloud compute networks subnets delete lab-dev-private-subnet --region=us-central1 --project=YOUR_PROJECT_ID

# Delete VPC
gcloud compute networks delete lab-dev-vpc --project=YOUR_PROJECT_ID
```

### Delete Service Accounts
```bash
gcloud iam service-accounts delete lab-dev-frontend-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com --project=YOUR_PROJECT_ID
gcloud iam service-accounts delete lab-dev-backend-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com --project=YOUR_PROJECT_ID
```

### Delete Secrets
```bash
gcloud secrets delete lab-dev-db-password --project=YOUR_PROJECT_ID
gcloud secrets delete lab-dev-db-connection --project=YOUR_PROJECT_ID
```

---

## Complete Project Deletion

If you want to delete the entire GCP project (nuclear option):

```bash
# List your projects
gcloud projects list

# Delete the project (IRREVERSIBLE!)
gcloud projects delete YOUR_PROJECT_ID
```

**⚠️ WARNING**: This deletes EVERYTHING in the project, including:
- All resources
- All data
- All configurations
- Billing history
- Cannot be undone!

Only do this if the project was created specifically for this lab.

---

## Cost-Saving Alternatives to Full Destruction

If you plan to use the lab again soon:

### Option 1: Keep Networking, Destroy Services

```bash
# Destroy expensive resources only
terraform destroy \
  -target=module.redis \
  -target=module.cloudsql \
  -target=module.cloudrun_backend \
  -target=module.cloudrun_frontend
```

**Cost**: ~$11/month (VPC Connector only)
**Rebuild time**: ~10 minutes

---

### Option 2: Stop Cloud SQL

Cloud SQL can be stopped (but still costs ~50% of running cost):

```bash
gcloud sql instances patch INSTANCE_NAME --activation-policy=NEVER --project=YOUR_PROJECT_ID
```

To restart:
```bash
gcloud sql instances patch INSTANCE_NAME --activation-policy=ALWAYS --project=YOUR_PROJECT_ID
```

**Note**: This doesn't save much; better to destroy and recreate.

---

## Cleanup Checklist

After running `terraform destroy`, verify:

- [ ] Cloud Run services deleted
- [ ] Cloud SQL instance deleted
- [ ] Redis instance deleted
- [ ] VPC Connector deleted
- [ ] VPC and subnets deleted
- [ ] Firewall rules deleted
- [ ] Cloud Router and NAT deleted
- [ ] Service accounts deleted (optional)
- [ ] Secrets deleted (optional)
- [ ] Terraform state is empty: `terraform state list` returns nothing
- [ ] GCP billing shows reduced costs within 24 hours

---

## Re-Deployment

To deploy again after cleanup:

```bash
# Same commands as initial deployment
terraform init
terraform plan
terraform apply
```

Everything will be recreated fresh in ~15-20 minutes.

**Tip**: Keep your `terraform.tfvars` file so you don't have to reconfigure.

---

## Automated Cleanup Script

Create an alias for quick cleanup:

```bash
# Add to ~/.zshrc or ~/.bashrc
alias lab-cleanup='cd ~/path/to/gcp-terraform && terraform destroy -auto-approve'

# Usage:
# lab-cleanup
```

**⚠️ WARNING**: `-auto-approve` skips confirmation. Use carefully!

---

## Final Cost Verification

1-2 days after cleanup, check your GCP billing:

```bash
# View billing report
gcloud billing accounts list
```

Or visit: [GCP Billing Reports](https://console.cloud.google.com/billing/reports)

**Expected**: Only small residual costs (API calls, storage if any)

---

**Cleanup complete! Your lab environment is removed and costs are stopped. 🎉**

**Ready to rebuild?** Start from [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
