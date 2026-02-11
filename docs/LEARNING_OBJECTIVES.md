# Learning Objectives

## Overview

This lab is designed to provide hands-on experience with Google Cloud Platform (GCP) infrastructure deployment using Terraform. By the end of this lab, you will have practical knowledge of cloud architecture, Infrastructure as Code (IaC), and GCP-specific services.

## Core Competencies

### 1. Infrastructure as Code (IaC)

**What you'll learn:**
- Writing declarative infrastructure configurations with Terraform
- Organizing Terraform projects with modular architecture
- Managing infrastructure state and dependencies
- Best practices for variable management and outputs
- Version control strategies for infrastructure code

**Key concepts:**
- Resource dependencies and implicit/explicit ordering
- Terraform module design patterns
- State management and remote backends
- Plan, apply, and destroy workflows

### 2. Cloud Networking Fundamentals

**What you'll learn:**
- Virtual Private Cloud (VPC) architecture and design
- Subnet planning and CIDR range allocation
- Public vs. private subnet patterns
- Network Address Translation (NAT) for private resources
- Firewall rules and network security

**Key concepts:**
- VPC isolation and network peering
- Serverless VPC Access for Cloud Run
- Private service connections
- Network security layers (firewall, IAM, private IPs)

### 3. 3-Tier Architecture Pattern

**What you'll learn:**
- Separation of concerns in distributed systems
- Presentation, application, and data tier responsibilities
- Inter-tier communication patterns
- Scalability and fault isolation benefits

**Architecture tiers:**
- **Presentation**: User-facing frontend (Cloud Run)
- **Application**: Business logic backend (Cloud Run with private access)
- **Data**: Persistent storage (Cloud SQL) and caching (Redis)

### 4. Serverless Computing

**What you'll learn:**
- Cloud Run deployment and configuration
- Container-based serverless architecture
- Auto-scaling and resource limits
- Public vs. private service exposure
- Service-to-service authentication

**Key concepts:**
- Stateless service design
- Container images and registries
- Request-based scaling
- Serverless cost optimization

### 5. Managed Databases on GCP

**What you'll learn:**
- Cloud SQL MySQL deployment and configuration
- Private IP configuration for databases
- Automated backups and maintenance windows
- Connection security (no public IPs)
- Performance tuning basics

**Key concepts:**
- Database tiers and sizing
- High availability vs. zonal deployments
- VPC peering for private access
- Backup and disaster recovery

### 6. Caching and Performance

**What you'll learn:**
- Memorystore for Redis deployment
- Cache strategy implementation
- Performance optimization with in-memory data stores
- Cache sizing and eviction policies

**Key concepts:**
- LRU (Least Recently Used) eviction
- Cache-aside pattern
- Session storage
- Performance vs. cost trade-offs

### 7. Security Best Practices

**What you'll learn:**
- Least-privilege IAM (Identity and Access Management)
- Service account design per workload
- Secret management with Secret Manager
- Network isolation strategies
- Transit encryption

**Security layers implemented:**
- **Network**: Private IPs, firewall rules, VPC isolation
- **Identity**: Service accounts with minimal permissions
- **Application**: Authenticated service-to-service calls
- **Data**: Encrypted connections, secret storage

### 8. GCP-Specific Services

**Services you'll master:**

| Service | Purpose | Key Learning |
|---------|---------|--------------|
| **Cloud Run** | Serverless containers | Auto-scaling, VPC connectivity |
| **Cloud SQL** | Managed MySQL | Private networking, backups |
| **Memorystore** | Managed Redis | In-memory caching |
| **VPC** | Virtual network | Custom topology, subnets |
| **Cloud NAT** | Outbound internet | Private resource internet access |
| **Secret Manager** | Credential storage | Secure secret access |
| **VPC Access Connector** | Serverless networking | Connect Cloud Run to VPC |

### 9. DevOps and Automation

**What you'll learn:**
- Automated infrastructure provisioning
- Reproducible deployments
- Configuration management
- Infrastructure testing (plan before apply)
- Cleanup automation to prevent cost waste

**Workflows:**
- Initial deployment: init → plan → apply
- Updates: modify code → plan → apply
- Cleanup: destroy to remove all resources

## Hands-On Skills Developed

By completing this lab, you will be able to:

1. ✅ **Design** cloud-native 3-tier architectures
2. ✅ **Deploy** production-ready infrastructure with Terraform
3. ✅ **Configure** private networking for security
4. ✅ **Implement** least-privilege access controls
5. ✅ **Manage** secrets and credentials securely
6. ✅ **Connect** serverless services to VPC resources
7. ✅ **Scale** applications with managed services
8. ✅ **Monitor** infrastructure through GCP Console
9. ✅ **Troubleshoot** common deployment issues
10. ✅ **Destroy** resources to manage costs

## Real-World Applications

This architecture pattern is used in:

- **Web applications** with frontend, API, and database
- **Mobile backends** with serverless API endpoints
- **Microservices** with service isolation
- **SaaS platforms** with multi-tenant architectures
- **E-commerce systems** with caching for performance
- **Enterprise applications** with strict security requirements

## Beyond This Lab

After mastering this lab, you can extend it with:

- **CI/CD pipelines** for automated deployments
- **Monitoring and alerting** with Cloud Monitoring
- **Load balancing** for high availability
- **Auto-scaling** based on metrics
- **Multi-region deployments** for global reach
- **Database replication** for disaster recovery
- **Custom domains and SSL** certificates
- **Application code deployment** (replace hello-world containers)

## Assessment Checklist

Test your understanding by answering:

- [ ] Why use separate service accounts for frontend and backend?
- [ ] What's the purpose of the VPC Access Connector?
- [ ] Why does the database have no public IP?
- [ ] How does Cloud NAT help private services?
- [ ] What happens if you run `terraform apply` twice?
- [ ] How would you add a staging environment?
- [ ] What cost optimization strategies apply here?
- [ ] How does the backend authenticate to the database?

---

**Ready to apply these concepts? Proceed to the deployment! 🎓**
