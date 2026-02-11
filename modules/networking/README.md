# Networking Module

## Purpose

This module creates the foundational network infrastructure for the 3-tier architecture, providing isolated networking, internet connectivity for private resources, and secure communication between services.

## Components

### 1. VPC (Virtual Private Cloud)
**Resource:** `google_compute_network.vpc`

**What it does:**
- Creates an isolated private network in GCP
- Provides the foundation for all other networking resources
- Configured with manual subnet creation (not auto-created)

**Why it's necessary:**
- Isolates your infrastructure from other GCP projects
- Required for private IP addressing for Cloud SQL and Redis
- Enables custom network topology and firewall rules

---

### 2. Public Subnet
**Resource:** `google_compute_subnetwork.public`

**What it does:**
- Creates a subnet with CIDR range 10.0.1.0/24
- Hosts Cloud NAT gateway resources
- Enables flow logs for network monitoring

**Why it's necessary:**
- Required for Cloud NAT to provide internet access
- Provides a separate network segment for internet-facing components
- Enables network visibility through VPC flow logs

---

### 3. Private Subnet
**Resource:** `google_compute_subnetwork.private`

**What it does:**
- Creates a subnet with CIDR range 10.0.2.0/24
- Hosts backend services, database, and cache
- Enables flow logs for monitoring

**Why it's necessary:**
- Isolates backend services from direct internet access
- Provides private IP space for Cloud SQL and Redis
- Enhances security by limiting network exposure

---

### 4. Cloud Router
**Resource:** `google_compute_router.router`

**What it does:**
- Routes traffic between VPC and external networks
- Required for Cloud NAT functionality
- Manages dynamic routing

**Why it's necessary:**
- Cloud NAT requires a Cloud Router to function
- Enables advanced routing scenarios
- Manages BGP sessions for hybrid connectivity

---

### 5. Cloud NAT (Network Address Translation)
**Resource:** `google_compute_router_nat.nat`

**What it does:**
- Allows private resources to initiate outbound connections to the internet
- Automatically allocates public IPs for NAT
- Translates private IPs to public IPs for outbound traffic

**Why it's necessary:**
- Cloud Run needs to pull container images from GCR
- Backend services may need to call external APIs
- Private resources need to download packages and updates
- **Important:** NAT is one-way - allows outbound only, blocks inbound

**Configuration:**
- `source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"` - All subnets can use NAT
- `nat_ip_allocate_option = "AUTO_ONLY"` - GCP automatically allocates public IPs

---

### 6. VPC Access Connector
**Resource:** `google_vpc_access_connector.connector`

**What it does:**
- Creates a bridge between serverless services (Cloud Run) and VPC
- Allocates a dedicated /28 IP range (10.8.0.0/28)
- Scales from 2 to 3 instances based on traffic

**Why it's necessary:**
- Cloud Run is serverless and doesn't naturally exist in a VPC
- Backend Cloud Run needs to access Cloud SQL and Redis private IPs
- Without this, backend cannot connect to database/cache
- Provides secure, low-latency access to VPC resources

**How it works:**
```
Cloud Run Backend → VPC Connector → VPC → Cloud SQL/Redis
```

---

### 7. Firewall: Health Checks
**Resource:** `google_compute_firewall.allow_health_checks`

**What it does:**
- Allows incoming traffic from GCP load balancer health check ranges
- Source ranges: 35.191.0.0/16, 130.211.0.0/22
- Allows all TCP traffic from these ranges

**Why it's necessary:**
- Cloud Run requires health checks to monitor service availability
- Load balancers need to verify instances are healthy
- Without this, services may be marked as unhealthy and stop receiving traffic

---

### 8. Firewall: Internal Communication
**Resource:** `google_compute_firewall.allow_internal`

**What it does:**
- Allows all TCP, UDP, and ICMP traffic between subnets
- Source ranges: 10.0.1.0/24, 10.0.2.0/24
- Enables unrestricted communication within VPC

**Why it's necessary:**
- Backend needs to connect to Cloud SQL (port 3306)
- Backend needs to connect to Redis (port 6379)
- VPC connector needs to route traffic to services
- Enables troubleshooting with ping/traceroute

---

### 9. Firewall: IAP SSH Access
**Resource:** `google_compute_firewall.allow_iap_ssh`

**What it does:**
- Allows SSH access from Identity-Aware Proxy range
- Source range: 35.235.240.0/20
- Port 22 (SSH)

**Why it's necessary:**
- Enables secure SSH access without public IPs
- Useful for debugging VMs if added to the infrastructure
- Best practice for secure remote access

---

### 10. Private IP Address Range
**Resource:** `google_compute_global_address.private_ip_address`

**What it does:**
- Allocates a /16 IP range for private service connections
- Purpose: VPC_PEERING
- Reserved for services like Cloud SQL

**Why it's necessary:**
- Cloud SQL requires a reserved IP range for private IP allocation
- Enables VPC peering with Google managed services
- Must be allocated before creating the VPC peering connection

---

### 11. Service Networking Connection
**Resource:** `google_service_networking_connection.private_vpc_connection`

**What it does:**
- Creates VPC peering between your VPC and Google service producer network
- Connects to servicenetworking.googleapis.com
- Uses the reserved IP range from above

**Why it's necessary:**
- **Critical:** Cloud SQL can only use private IP through VPC peering
- Without this, Cloud SQL cannot have a private IP address
- Enables secure, low-latency connections to managed services
- No internet traversal for database traffic

**How it works:**
```
Your VPC ←→ VPC Peering ←→ Google Service Network (where Cloud SQL runs)
```

---

## Outputs

| Output | Description | Used By |
|--------|-------------|---------|
| `vpc_id` | VPC network ID | Cloud SQL, Redis modules |
| `vpc_name` | VPC network name | Display purposes |
| `public_subnet_id` | Public subnet ID | Future expansion |
| `private_subnet_id` | Private subnet ID | Future expansion |
| `vpc_connector_id` | VPC connector ID | Cloud Run backend |
| `nat_ip` | NAT gateway name | Monitoring |
| `private_vpc_connection` | VPC peering connection | Cloud SQL dependency |

---

## Network Flow Example

### Backend Connects to Database

1. Cloud Run backend initiates connection to Cloud SQL private IP (10.x.x.x)
2. Traffic goes through VPC Access Connector
3. VPC Access Connector forwards to VPC
4. Internal firewall rule allows traffic
5. VPC peering routes to Google service network
6. Connection reaches Cloud SQL instance
7. Response flows back through same path

### Backend Pulls Container Image

1. Cloud Run backend needs to pull image from GCR
2. GCP routes request to Cloud NAT
3. NAT translates private IP to public IP
4. Request goes to internet (GCR)
5. Response comes back through NAT
6. NAT forwards to backend

---

## Security Considerations

1. **No Public IPs**: Database and cache are completely isolated from internet
2. **Default Deny**: Only explicitly allowed traffic is permitted
3. **Network Segmentation**: Separate subnets for different functions
4. **VPC Flow Logs**: All traffic is logged for auditing
5. **Minimal NAT**: Only outbound connections allowed, no inbound

---

## Cost Considerations

| Component | Monthly Cost |
|-----------|--------------|
| VPC | Free |
| Subnets | Free |
| Firewall Rules | Free |
| Cloud Router | Free |
| Cloud NAT | ~$0.50/day (~$15/month) for idle time + data processing |
| VPC Connector | ~$11/month (2 instances minimum) |
| VPC Flow Logs | Minimal (depends on traffic) |

**Total:** ~$25-30/month

**Cost-saving tips:**
- VPC connector is the main cost - required for Cloud Run VPC access
- NAT idle time is unavoidable if you use NAT
- Flow logs can be disabled if not needed (but recommended for production)

---

## Common Issues

### VPC Connector Creation Timeout
**Problem:** VPC connector takes too long to create (5-10 minutes)
**Solution:** This is normal. Wait patiently or check GCP status page.

### Cloud SQL Can't Use Private IP
**Problem:** Cloud SQL fails to create with private IP
**Solution:** Ensure `private_vpc_connection` is created first (dependency exists in main.tf)

### Backend Can't Connect to Database
**Problem:** Connection timeout or refused
**Solution:** 
- Check VPC connector is created successfully
- Verify firewall rule allows internal traffic
- Ensure Cloud SQL has private IP allocated

---

## Dependencies

**This module must be created before:**
- Cloud SQL module (needs VPC peering)
- Redis module (needs VPC ID)
- Cloud Run backend module (needs VPC connector)

**This module requires:**
- Compute Engine API enabled
- Service Networking API enabled
- VPC Access API enabled

---

## Modification Guide

### Change Subnet CIDR Ranges

Edit variables in `variables.tf`:
```hcl
variable "public_subnet_cidr" {
  default = "10.1.1.0/24"  # Changed from 10.0.1.0/24
}
```

### Add Additional Subnet

Add to `main.tf`:
```hcl
resource "google_compute_subnetwork" "app_subnet" {
  name          = "${var.prefix}-${var.environment}-app-subnet"
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}
```

### Disable Flow Logs (Cost Saving)

Remove `log_config` blocks from subnet definitions.

---

## References

- [VPC Documentation](https://cloud.google.com/vpc/docs)
- [Cloud NAT Documentation](https://cloud.google.com/nat/docs)
- [VPC Access Connector](https://cloud.google.com/vpc/docs/configure-serverless-vpc-access)
- [Service Networking](https://cloud.google.com/service-infrastructure/docs/service-networking)
