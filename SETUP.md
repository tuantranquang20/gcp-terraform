# GCP Project Setup Guide

This guide will walk you through setting up your Google Cloud Platform environment and preparing for the Terraform deployment.

## Prerequisites

Before starting this lab, ensure you have:

### 1. Google Cloud Account
- Active GCP account with billing enabled
- If new to GCP, you may be eligible for $300 free credits
- [Sign up for GCP](https://cloud.google.com/free)

### 2. Local Tools

Install the following tools on your local machine:

#### Terraform
```bash
# macOS (using Homebrew)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform version  # Should be >= 1.5.0
```

#### Google Cloud SDK (gcloud CLI)
```bash
# macOS (using Homebrew)
brew install --cask google-cloud-sdk

# Or download from: https://cloud.google.com/sdk/docs/install

# Verify installation
gcloud version
```

## GCP Project Setup

### Step 1: Create a New GCP Project

It's recommended to create a dedicated project for this lab:

```bash
# Set variables
export PROJECT_ID="gcp-terraform-lab-$(date +%s)"
export PROJECT_NAME="GCP Terraform Lab"

# Create project
gcloud projects create $PROJECT_ID --name="$PROJECT_NAME"

# Set as default project
gcloud config set project $PROJECT_ID

# Verify
gcloud config get-value project
```

### Step 2: Enable Billing

Link a billing account to your project:

```bash
# List available billing accounts
gcloud billing accounts list

# Link billing account (replace BILLING_ACCOUNT_ID)
gcloud billing projects link $PROJECT_ID \
  --billing-account=BILLING_ACCOUNT_ID
```

Or enable billing through the [GCP Console](https://console.cloud.google.com/billing).

### Step 3: Enable Required APIs

Enable all GCP APIs needed for this lab:

```bash
gcloud services enable \
  compute.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  run.googleapis.com \
  vpcaccess.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com

# This may take a few minutes
```

### Step 4: Set Up Authentication

#### Option A: User Account (Recommended for Learning)

```bash
# Authenticate with your Google account
gcloud auth application-default login

# This will open a browser for authentication
```

#### Option B: Service Account (Production Use)

```bash
# Create service account
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

# Create and download key
gcloud iam service-accounts keys create ~/terraform-key.json \
  --iam-account=terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/terraform-key.json
```

> **⚠️ Security Note**: If using a service account, never commit the key file to version control!

## Terraform Configuration

### Step 1: Configure Variables

```bash
cd gcp-terraform

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update `terraform.tfvars`:
```hcl
project_id  = "your-actual-project-id"
region      = "us-central1"
environment = "dev"
prefix      = "lab"
```

### Step 2: Add to .gitignore

Create or update `.gitignore`:

```bash
cat >> .gitignore << 'EOF'
# Terraform files
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Sensitive files
terraform.tfvars
*.json  # Service account keys
EOF
```

## Verification

Verify your setup is ready:

```bash
# 1. Check Terraform
terraform version

# 2. Check gcloud authentication
gcloud auth list

# 3. Check project is set
gcloud config get-value project

# 4. Check APIs are enabled
gcloud services list --enabled | grep -E 'compute|run|sql|redis'

# 5. Validate Terraform configuration
terraform init
terraform validate
```

## Cost Management

### Set Up Budget Alerts

Create a budget to avoid unexpected costs:

```bash
# Set budget amount (e.g., $100)
BUDGET_AMOUNT=100

gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="Lab Budget Alert" \
  --budget-amount=${BUDGET_AMOUNT}USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100
```

Or set budget alerts in the [GCP Console](https://console.cloud.google.com/billing/budgets).

### Enable Resource Cleanup

Set a reminder to destroy resources when not in use:

```bash
# Add to your shell profile
echo 'alias lab-cleanup="cd ~/path/to/gcp-terraform && terraform destroy"' >> ~/.zshrc
```

## Troubleshooting

### API Not Enabled Error
If you see errors about APIs not being enabled:
```bash
gcloud services enable SERVICE_NAME
```

### Permission Denied
Ensure your account has necessary permissions:
```bash
gcloud projects get-iam-policy $PROJECT_ID
```

### Quota Exceeded
Check and request quota increases:
```bash
gcloud compute project-info describe --project=$PROJECT_ID
```

## Next Steps

Once setup is complete, proceed to:
1. Review [LEARNING_OBJECTIVES.md](docs/LEARNING_OBJECTIVES.md)
2. Study [ARCHITECTURE.md](docs/ARCHITECTURE.md)
3. Follow [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)

---

**Ready to deploy? Let's build your 3-tier architecture! 🚀**
