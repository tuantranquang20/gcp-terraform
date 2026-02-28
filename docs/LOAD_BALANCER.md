# Load Balancer with NEG - Quick Setup Guide

This document provides a quick reference for setting up and using the global HTTPS load balancer with Network Endpoint Groups (NEG) for Cloud Run services.

## 🎯 What is a Serverless NEG?

A **Serverless Network Endpoint Group (NEG)** is a configuration object that specifies a group of serverless backends (like Cloud Run services) for a load balancer. It allows you to use Cloud Run services as backends for Google Cloud Load Balancer, enabling:

- **Custom domain mapping** with your own domain name
- **Global load balancing** for worldwide traffic distribution
- **SSL/TLS termination** with Google-managed certificates
- **Cloud CDN** for caching static content
- **Cloud Armor** for DDoS protection and security policies
- **Advanced routing** based on URL paths and headers

## 🏗️ Architecture

```
                          Internet
                             │
                             ▼
                    ┌────────────────┐
                    │  Global Static │
                    │  IP Address    │
                    └────────┬───────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
    HTTP (80)           HTTPS (443)         Cloud Armor
         │                   │              Security Policy
         │                   │                   │
         ▼                   ▼                   │
   HTTP Proxy         HTTPS Proxy               │
   (Redirect)         (SSL Cert)                │
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             ▼
                        URL Map
                    (Routing Rules)
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
      Backend Service                Backend Service
      (Frontend)                     (Backend API)
      - Cloud CDN                    - No CDN
      - Compression                  - API endpoints
              │                             │
              ▼                             ▼
      Frontend NEG                   Backend NEG
      (Serverless)                   (Serverless)
              │                             │
              ▼                             ▼
      Cloud Run Service              Cloud Run Service
      (Frontend)                     (Backend)
```

## 📝 Configuration Variables

In `terraform.tfvars`:

```hcl
# Required: Your domain name
domain_name = "example.com"

# SSL/HTTPS Configuration
enable_ssl = true

# Performance: Enable Cloud CDN
enable_cdn = true

# Security: Cloud Armor
enable_cloud_armor     = true
enable_ddos_protection = true

# Optional: Geo-blocking
# blocked_countries = ["CN", "RU", "KP"]

# Logging
log_sample_rate = 1.0  # Log 100% of requests
```

## 🚀 Deployment Steps

### 1. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy everything
terraform apply
```

### 2. Get Load Balancer IP

```bash
# Get the IP address
terraform output load_balancer_ip

# Example output: 34.117.186.192
```

### 3. Configure DNS

Create an A record pointing your domain to the load balancer IP:

#### Using Google Cloud DNS:

```bash
# Set variables
DOMAIN="example.com"
LB_IP=$(terraform output -raw load_balancer_ip)
DNS_ZONE="your-dns-zone-name"

# Create A record
gcloud dns record-sets create ${DOMAIN}. \
  --rrdatas="${LB_IP}" \
  --type=A \
  --ttl=300 \
  --zone=${DNS_ZONE}
```

#### Using Other DNS Providers:

Add an A record:
- **Name**: `@` (or your subdomain)
- **Type**: `A`
- **Value**: `<load_balancer_ip>`
- **TTL**: `300` (5 minutes)

### 4. Wait for SSL Certificate Provisioning

Google-managed SSL certificates take **10-20 minutes** to provision:

```bash
# Check certificate status
gcloud compute ssl-certificates list

# Check detailed status
gcloud compute ssl-certificates describe <CERT_NAME> --global
```

Status will change from `PROVISIONING` → `ACTIVE`

### 5. Access Your Application

Once the certificate is active, visit:

```bash
# HTTPS URL
https://example.com

# Frontend traffic: https://example.com/
# Backend API: https://example.com/api/*
# Health check: https://example.com/health
```

## 🛣️ URL Routing Rules

The load balancer routes traffic based on URL paths:

| Request Path | Backend Service | Description |
|--------------|-----------------|-------------|
| `/api/*` | Backend | All API requests |
| `/api` | Backend | API root endpoint |
| `/health` | Backend | Health check endpoint |
| `/*` | Frontend | All other requests (default) |

## 🔒 Security Features

### Cloud Armor

Automatically configured with:

- **Rate Limiting**: 100 requests/minute per IP
  - Violators banned for 10 minutes
  - Returns HTTP 429 (Too Many Requests)

- **DDoS Protection**: Layer 7 adaptive protection
  - Automatic attack detection
  - Mitigation without manual intervention

- **Geo-blocking** (optional):
  ```hcl
  blocked_countries = ["CN", "RU", "KP"]
  ```

### SSL/TLS

- **Google-managed certificates**: Automatic renewal
- **HTTP to HTTPS redirect**: Automatic
- **TLS 1.2+**: Modern encryption protocols

## ⚡ Performance Features

### Cloud CDN

Enabled for frontend backend service:

- **Cache Mode**: CACHE_ALL_STATIC
- **Default TTL**: 1 hour
- **Max TTL**: 24 hours
- **Negative Caching**: Enabled
- **Compression**: Automatic (GZIP/Brotli)

### Benefits:

- Faster load times for global users
- Reduced latency (content served from edge locations)
- Lower backend load
- Cost savings (less egress from Cloud Run)

## 📊 Monitoring and Logging

### View Load Balancer Logs

```bash
# Recent load balancer logs
gcloud logging read "resource.type=http_load_balancer" --limit 50

# Filter by response code
gcloud logging read "resource.type=http_load_balancer AND httpRequest.status=500" --limit 50

# Filter by path
gcloud logging read "resource.type=http_load_balancer AND httpRequest.requestUrl=~'/api/.*'" --limit 50
```

### Check Cloud Armor Metrics

```bash
# View security policy events
gcloud logging read "resource.type=http_load_balancer AND jsonPayload.enforcedSecurityPolicy.name!=''" --limit 50
```

### Monitor SSL Certificate

```bash
# List all certificates
gcloud compute ssl-certificates list

# Check certificate expiration
gcloud compute ssl-certificates describe <CERT_NAME> --global \
  --format="value(expireTime)"
```

## 🔧 Troubleshooting

### SSL Certificate Stuck in PROVISIONING

**Possible causes:**
1. DNS not properly configured
2. Domain ownership not verified
3. Previous certificate exists

**Solutions:**
```bash
# Verify DNS resolution
nslookup example.com

# Check if DNS points to correct IP
dig example.com +short

# Wait longer (can take up to 20 minutes)
```

### 502 Bad Gateway

**Possible causes:**
1. Cloud Run service not healthy
2. Backend service misconfigured
3. IAM permissions missing

**Solutions:**
```bash
# Check Cloud Run service status
gcloud run services describe <SERVICE_NAME> --region=<REGION>

# Check Cloud Run logs
gcloud run services logs read <SERVICE_NAME> --region=<REGION> --limit=50

# Verify NEG backend health
gcloud compute backend-services get-health <BACKEND_SERVICE_NAME> --global
```

### 403 Forbidden

**Possible causes:**
1. Cloud Armor blocking the request
2. geo-blocking configuration
3. Rate limiting triggered

**Solutions:**
```bash
# Check Cloud Armor policy
gcloud compute security-policies describe <POLICY_NAME>

# Review blocked requests
gcloud logging read "resource.type=http_load_balancer AND jsonPayload.enforcedSecurityPolicy.outcome='DENY'" --limit 50

# Temporarily disable Cloud Armor
# In terraform.tfvars:
enable_cloud_armor = false
```

### 404 Not Found

**Possible causes:**
1. URL map routing misconfigured
2. Backend service not attached to NEG
3. Cloud Run service name changed

**Solutions:**
```bash
# Check URL map configuration
gcloud compute url-maps describe <URL_MAP_NAME> --global

# Verify backend services
gcloud compute backend-services list --global

# Check NEG configuration
gcloud compute network-endpoint-groups list --global
```

### High Latency

**Possible causes:**
1. Cold starts in Cloud Run
2. CDN not enabled
3. Backend processing slow

**Solutions:**
```bash
# Enable minimum instances for Cloud Run (reduce cold starts)
# In cloudrun module variables:
min_instances = 1

# Enable Cloud CDN
# In terraform.tfvars:
enable_cdn = true

# Check backend latency
gcloud logging read "resource.type=http_load_balancer" \
  --format="table(httpRequest.latency)" \
  --limit=50
```

## 💰 Cost Breakdown

### Load Balancer Costs

- **Forwarding Rules**: $0.025/hour (~$18/month)
  - 2 rules: HTTP (80) and HTTPS (443)
  
- **Data Processing**: First 5 rules free, then $0.010 per GB

- **SSL Certificate**: **FREE** (Google-managed)

### Cloud CDN Costs

- **Cache Fills**: $0.02 - $0.08 per GB (region dependent)
- **Cache Egress**: $0.02 - $0.15 per GB (region dependent)
- **Cache Lookups**: $0.0075 per 10,000 requests

### Cloud Armor Costs

- **Security Policy**: $5/month per policy
- **Rule Evaluation**: $0.75 per million requests (first 1M free)

**Total Estimated Monthly Cost**: ~$25-40 (excluding data transfer)

## 🎯 Best Practices

### 1. Use SSL/HTTPS Always
```hcl
enable_ssl = true
```

### 2. Enable Cloud CDN for Static Content
```hcl
enable_cdn = true
```

### 3. Protect with Cloud Armor
```hcl
enable_cloud_armor     = true
enable_ddos_protection = true
```

### 4. Configure Appropriate Rate Limits

Edit `modules/load-balancer/main.tf`:

```hcl
rate_limit_threshold {
  count        = 1000  # Adjust based on your needs
  interval_sec = 60
}
```

### 5. Monitor Logs Regularly

```bash
# Set up log-based alerts in Cloud Monitoring
gcloud alpha monitoring policies create \
  --notification-channels=<CHANNEL_ID> \
  --display-name="High 5xx Error Rate" \
  --condition-threshold-value=10 \
  --condition-threshold-duration=60s
```

### 6. Reserve Static IP

The Terraform configuration already reserves a static IP. This ensures:
- IP doesn't change during updates
- Consistent DNS configuration
- No downtime during redeployments

### 7. Use Health Checks

The load balancer automatically monitors backend health. Ensure your Cloud Run services respond to requests properly.

## 🔄 Updates and Changes

### Update Domain Name

```bash
# In terraform.tfvars
domain_name = "newdomain.com"

# Apply changes
terraform apply

# Update DNS to point to the same IP
```

### Add Geo-blocking

```bash
# In terraform.tfvars
blocked_countries = ["CN", "RU", "KP"]

# Apply changes
terraform apply
```

### Disable Cloud CDN

```bash
# In terraform.tfvars
enable_cdn = false

# Apply changes
terraform apply
```

## 📖 Related Documentation

- [Load Balancer Module README](modules/load-balancer/README.md) - Detailed module documentation
- [Serverless NEG Concepts](https://cloud.google.com/load-balancing/docs/negs/serverless-neg-concepts)
- [Cloud Armor Documentation](https://cloud.google.com/armor/docs)
- [Cloud CDN Documentation](https://cloud.google.com/cdn/docs)
- [SSL Certificate Management](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)

## 🆘 Support

If you encounter issues:

1. Check the [Troubleshooting](#-troubleshooting) section above
2. Review [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. Check Cloud Console for error messages
4. Review Terraform state: `terraform show`

---

**Happy Load Balancing! 🚀**
