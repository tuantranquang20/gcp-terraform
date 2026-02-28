# Load Balancer Module

This module creates a **Global HTTP(S) Load Balancer** with **Serverless Network Endpoint Groups (NEGs)** for Cloud Run services.

## Features

### 🌐 Load Balancing
- **Global HTTP(S) Load Balancer** for worldwide traffic distribution
- **Serverless NEGs** for Cloud Run integration
- **URL-based routing** to frontend and backend services
- **Static IP address** reservation

### 🔒 Security
- **Google-managed SSL certificates** (automatic renewal)
- **HTTP to HTTPS redirect** (optional)
- **Cloud Armor** integration for DDoS protection
- **Rate limiting** (100 requests/minute per IP)
- **Geo-blocking** capability
- **Identity-Aware Proxy (IAP)** support

### ⚡ Performance
- **Cloud CDN** for frontend static content
- **Automatic compression** for better performance
- **Edge caching** with configurable TTL

### 📊 Observability
- **Request logging** with configurable sample rate
- **Custom request headers** for client geolocation
- **Health monitoring**

## Architecture

```
Internet
   │
   ▼
┌─────────────────────┐
│  Global Load        │
│  Balancer           │
│  (Static IP)        │
└──────┬──────────────┘
       │
       ├─── HTTPS (443) ──► HTTPS Proxy ──► URL Map
       │
       └─── HTTP (80) ───► HTTP Proxy ───► Redirect to HTTPS
                                             │
                    ┌────────────────────────┴────────────────────────┐
                    │                                                 │
                    ▼                                                 ▼
          ┌─────────────────┐                              ┌─────────────────┐
          │  Frontend NEG   │                              │  Backend NEG    │
          │  (Cloud Run)    │                              │  (Cloud Run)    │
          └─────────────────┘                              └─────────────────┘
                  │                                                  │
                  ▼                                                  ▼
          Frontend Service                                  Backend Service
          (/* path)                                         (/api/*, /health)
```

## URL Routing Rules

| Path Pattern | Target Service | Description |
|--------------|----------------|-------------|
| `/api/*`     | Backend        | API requests |
| `/api`       | Backend        | API root |
| `/health`    | Backend        | Health check endpoint |
| `/*`         | Frontend       | All other requests (default) |

## Resources Created

### Network Endpoint Groups (NEGs)
- `google_compute_region_network_endpoint_group.frontend_neg` - Frontend Cloud Run NEG
- `google_compute_region_network_endpoint_group.backend_neg` - Backend Cloud Run NEG

### Backend Services
- `google_compute_backend_service.frontend` - Frontend backend service with CDN
- `google_compute_backend_service.backend` - Backend API service

### Load Balancer Components
- `google_compute_global_address.default` - Reserved static IP
- `google_compute_url_map.default` - URL routing rules
- `google_compute_target_https_proxy.default` - HTTPS proxy
- `google_compute_target_http_proxy.default` - HTTP proxy
- `google_compute_global_forwarding_rule.https` - HTTPS forwarding rule (443)
- `google_compute_global_forwarding_rule.http` - HTTP forwarding rule (80)

### SSL/TLS
- `google_compute_managed_ssl_certificate.default` - Google-managed SSL certificate

### Security
- `google_compute_security_policy.policy` - Cloud Armor security policy
- Rate limiting rules
- Geo-blocking rules (optional)
- DDoS protection (adaptive)

## Usage

```hcl
module "load_balancer" {
  source = "./modules/load-balancer"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  prefix      = var.prefix

  # Cloud Run Service Names
  frontend_service_name = module.cloudrun_frontend.service_name
  backend_service_name  = module.cloudrun_backend.service_name

  # Domain Configuration
  domain_name = "example.com"
  enable_ssl  = true

  # Performance
  enable_cdn = true

  # Security
  enable_cloud_armor     = true
  enable_ddos_protection = true
  blocked_countries      = ["CN", "RU"] # Optional

  # Logging
  log_sample_rate = 1.0 # Log 100% of requests

  depends_on = [
    module.cloudrun_frontend,
    module.cloudrun_backend
  ]
}
```

## Configuration Options

### Required Variables
- `project_id` - GCP Project ID
- `region` - GCP region for regional resources
- `environment` - Environment name (dev, staging, prod)
- `prefix` - Resource name prefix
- `frontend_service_name` - Frontend Cloud Run service name
- `backend_service_name` - Backend Cloud Run service name

### Optional Variables
- `domain_name` - Domain for the load balancer (default: "example.com")
- `enable_ssl` - Enable HTTPS with managed certificate (default: true)
- `enable_cdn` - Enable Cloud CDN for frontend (default: true)
- `enable_cloud_armor` - Enable Cloud Armor security (default: true)
- `enable_ddos_protection` - Enable DDoS protection (default: true)
- `blocked_countries` - List of country codes to block (default: [])
- `log_sample_rate` - Logging sample rate 0.0-1.0 (default: 1.0)
- `iap_client_id` - OAuth2 client ID for IAP (default: "")
- `iap_client_secret` - OAuth2 client secret for IAP (default: "")

## Outputs

- `load_balancer_ip` - External IP address of the load balancer
- `load_balancer_url` - Full URL (http:// or https://)
- `frontend_neg_id` - Frontend NEG resource ID
- `backend_neg_id` - Backend NEG resource ID
- `ssl_certificate_id` - SSL certificate ID (if enabled)
- `security_policy_id` - Cloud Armor policy ID (if enabled)

## DNS Configuration

After deployment, create an A record pointing to the load balancer IP:

```bash
# Get the load balancer IP
terraform output load_balancer_ip

# Configure DNS A record
# example.com -> <load_balancer_ip>
```

For Google Cloud DNS:

```bash
gcloud dns record-sets create example.com. \
  --rrdatas="<LOAD_BALANCER_IP>" \
  --type=A \
  --ttl=300 \
  --zone=<YOUR_DNS_ZONE>
```

## SSL Certificate Provisioning

Google-managed SSL certificates can take **10-20 minutes** to provision. During this time:

1. The certificate status will be `PROVISIONING`
2. HTTPS traffic may not work immediately
3. The domain must be properly configured in DNS

Check certificate status:

```bash
gcloud compute ssl-certificates describe <CERT_NAME> --global
```

## Cloud Armor Features

### Rate Limiting
- Default: 100 requests per minute per IP
- Violators are banned for 10 minutes (600 seconds)
- Returns HTTP 429 (Too Many Requests)

### Geo-blocking
```hcl
blocked_countries = ["CN", "RU", "KP"]
```

### DDoS Protection
- Adaptive protection automatically detects and mitigates attacks
- Layer 7 DDoS defense enabled by default

## Cloud CDN Configuration

The frontend backend service uses Cloud CDN with:
- **Cache mode**: CACHE_ALL_STATIC
- **Default TTL**: 1 hour (3600s)
- **Max TTL**: 24 hours (86400s)
- **Client TTL**: 1 hour (3600s)
- **Negative caching**: Enabled
- **Serve while stale**: 24 hours

## Cost Considerations

- **Load Balancer**: Charged per forwarding rule and per GB of traffic
- **Cloud CDN**: Charged per GB of cache egress and cache lookups
- **Cloud Armor**: Charged per policy and per million requests
- **SSL Certificate**: Free (Google-managed)
- **Static IP**: Small hourly charge when not in use

## Health Checks

The load balancer automatically performs health checks on the Cloud Run services. No additional health check resources are needed for serverless NEGs.

## Monitoring

View load balancer metrics in Cloud Console:
- Request count
- Latency (50th, 95th, 99th percentile)
- Error rate
- Backend service health
- CDN hit ratio
- Security policy metrics

```bash
# View load balancer logs
gcloud logging read "resource.type=http_load_balancer" --limit 50
```

## Troubleshooting

### SSL Certificate Not Provisioning
1. Verify DNS is properly configured
2. Wait 10-20 minutes for provisioning
3. Check domain ownership verification

### 502 Bad Gateway
1. Verify Cloud Run services are healthy
2. Check service account permissions
3. Review backend service logs

### High Latency
1. Enable Cloud CDN for cacheable content
2. Check Cloud Run cold starts
3. Review backend service configuration

### Cloud Armor Blocking Legitimate Traffic
1. Review security policy rules
2. Adjust rate limiting thresholds
3. Check geo-blocking configuration

## Best Practices

1. **Use SSL/HTTPS** in production environments
2. **Enable Cloud CDN** for static content
3. **Configure rate limiting** to prevent abuse
4. **Monitor logs** regularly for security events
5. **Use IAP** for internal applications
6. **Reserve static IP** to prevent IP changes
7. **Configure health checks** appropriately
8. **Use Cloud Armor** for DDoS protection

## References

- [Cloud Load Balancing Documentation](https://cloud.google.com/load-balancing/docs)
- [Serverless NEGs](https://cloud.google.com/load-balancing/docs/negs/serverless-neg-concepts)
- [Cloud Armor](https://cloud.google.com/armor/docs)
- [Cloud CDN](https://cloud.google.com/cdn/docs)
