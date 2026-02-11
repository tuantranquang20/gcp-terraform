# Redis Module (Memorystore)

## Purpose

This module deploys a managed Redis cache instance for high-performance in-memory data storage, session management, and application caching.

## Components

### 1. Memorystore Redis Instance
**Resource:** `google_redis_instance.cache`

**What it does:**
- Creates a managed Redis 7.0 instance
- 1 GB memory with BASIC tier (single node)
- VPC-authorized access only
- Transit encryption enabled

**Why it's necessary:**
- **Performance:** In-memory storage = microsecond latency
- **Caching:** Reduce database load by 80-90%
- **Sessions:** Store user sessions for fast access
- **Rate Limiting:** Track API usage limits
- **Real-time Features:** Pub/sub messaging, leaderboards

---

## Configuration Breakdown

### Tier Selection
```hcl
tier = "BASIC"
```

**BASIC Tier:**
- Single Redis node
- No automatic failover
- ~$36/month for 1GB
- Good for dev/test, caching

**STANDARD_HA Tier:**
- Two Redis nodes (primary + replica)
- Automatic failover (99.9% SLA)
- ~$72/month for 1GB
- Required for production

**Why BASIC for this lab:**
- Cost-effective ($36 vs $72)
- Caching is non-critical (can rebuild from DB)
- Educational purposes
- Easy to upgrade later

---

### Memory Size
```hcl
memory_size_gb = 1
```

**Why 1 GB:**
- Smallest available size
- Cost-effective ($36/month)
- Sufficient for caching demo (thousands of keys)
- Can scale up to 300 GB

**Example capacity (1 GB):**
- ~1 million small keys (1 KB each)
- ~10,000 medium objects (100 KB each)
- ~1,000 large objects (1 MB each)

---

### Redis Version
```hcl
redis_version = "REDIS_7_0"
```

**Why Redis 7.0:**
- Latest stable version
- Better performance than 6.x
- New commands (COPY, GETEX, etc.)
- Improved ACL support

---

### Network Authorization
```hcl
authorized_network = var.network_id
```

**What it does:**
- Restricts access to specified VPC only
- No public internet access
- Redis instance gets private IP in VPC

**Why it's necessary:**
- Security: No internet exposure
- Performance: Low latency within VPC
- Backend connects through VPC connector
- Prevents unauthorized access

**Connection path:**
```
Cloud Run Backend → VPC Connector → VPC → Redis Private IP
```

---

### Transit Encryption
```hcl
transit_encryption_mode = "SERVER_AUTHENTICATION"
auth_enabled            = true
```

**What it does:**
- Encrypts data in transit using TLS
- Requires TLS certificates for connections
- Generates AUTH string (password)

**Why it's necessary:**
- Protects data from network sniffing
- Compliance with security standards
- Best practice for sensitive data
- AUTH prevents unauthorized connections

**How it works:**
1. Client initiates TLS handshake
2. Server presents certificate
3. Client validates certificate
4. Encrypted tunnel established
5. Client sends AUTH password
6. Redis validates and allows commands

**Performance impact:** Minimal (< 5% overhead)

---

### AUTH String (Password)
```hcl
auth_enabled = true
```

**What it does:**
- Generates a random password for Redis
- Required for all connections
- Provided as output (sensitive)

**Why it's necessary:**
- Without AUTH, anyone in VPC could access Redis
- Prevents accidental misconfiguration
- Defense in depth (VPC + AUTH)

**How backend uses it:**
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST,
    port: 6379,
    tls: true  // Required for transit encryption
  },
  password: process.env.REDIS_AUTH_STRING
});
```

---

### Eviction Policy
```hcl
redis_configs = {
  maxmemory-policy = "allkeys-lru"
}
```

**What it does:**
- When memory is full, removes **L**east **R**ecently **U**sed keys
- Applies to **all** keys (not just those with TTL)

**Why this policy:**
- Cache should evict old data automatically
- Prevents out-of-memory errors
- Most recently used data likely to be accessed again

**Other policies available:**
- `noeviction` - Return errors when full (not good for caching)
- `allkeys-lfu` - Evict **L**east **F**requently **U**sed
- `volatile-lru` - Only evict keys with expiration set
- `volatile-ttl` - Evict keys with shortest TTL first

**Example with allkeys-lru:**
1. Memory fills to 1 GB
2. New key arrives
3. Redis finds least recently accessed key
4. Evicts that key
5. Stores new key
6. Happens automatically, no errors

---

### Maintenance Window
```hcl
maintenance_policy {
  weekly_maintenance_window {
    day = "SUNDAY"
    start_time {
      hours   = 3
      minutes = 0
    }
  }
}
```

**What it does:**
- Schedules automatic updates for Sunday 3 AM
- GCP applies security patches and updates
- Brief downtime (usually < 1 minute for BASIC tier)

**Why it's necessary:**
- Redis needs security updates
- Scheduled window = predictable downtime
- Choose low-traffic time

**BASIC vs STANDARD_HA:**
- BASIC: Brief downtime during maintenance
- STANDARD_HA: Failover to replica, no downtime

---

## Outputs

| Output | Description | Used By |
|--------|-------------|---------|
| `host` | Redis private IP | Backend env var |
| `port` | Redis port (6379) | Backend env var |
| `current_location_id` | Zone where Redis runs | Monitoring |
| `auth_string` | Password (sensitive) | Backend connection |

---

## Use Cases in This Lab

### 1. Statistics Caching
```javascript
// Backend checks cache first
const cached = await redis.get('stats');
if (cached) {
  return JSON.parse(cached);  // Fast! (< 1 ms)
}

// Cache miss - query database
const stats = await db.query('SELECT COUNT(*) ...');  // Slow (~50 ms)

// Store in cache for 30 seconds
await redis.setEx('stats', 30, JSON.stringify(stats));
return stats;
```

**Result:** 99% of requests served from cache, database load reduced by 99%

### 2. Session Storage (Future Enhancement)
```javascript
// Store user session
await redis.setEx(`session:${userId}`, 3600, JSON.stringify(sessionData));

// Retrieve session
const session = await redis.get(`session:${userId}`);
```

### 3. Rate Limiting (Future Enhancement)
```javascript
// Track API calls
const key = `ratelimit:${ip}:${minute}`;
const count = await redis.incr(key);
await redis.expire(key, 60);

if (count > 100) {
  throw new Error('Rate limit exceeded');
}
```

---

## Performance Characteristics

### Latency (within VPC)
- **GET:** < 1 ms (typical: 0.3-0.5 ms)
- **SET:** < 1 ms
- **Complex commands:** 1-5 ms

### Throughput (BASIC tier, 1 GB)
- **Operations/sec:** ~25,000
- **Network:** Up to 1 Gbps
- **Sufficient for:** Most applications

**Comparison to database:**
```
Redis GET:    0.5 ms  (2,000 ops/sec per connection)
MySQL Query: 50 ms   (20 ops/sec per connection)

100x faster! 🚀
```

---

## Cost Breakdown

| Tier | Memory | Monthly Cost |
|------|--------|--------------|
| BASIC | 1 GB | ~$36 |
| BASIC | 5 GB | ~$180 |
| STANDARD_HA | 1 GB | ~$72 |
| STANDARD_HA | 5 GB | ~$360 |

**Cost optimization:**
- Use BASIC for dev/test
- Delete when not in use (full cost even when idle)
- Smallest size for testing: 1 GB

---

## Security Features

### ✅ No Public IP
Redis is completely isolated from internet.

### ✅ VPC Authorization
Only authorized VPC can access.

### ✅ Transit Encryption (TLS)
All data encrypted in flight.

### ✅ AUTH Password
Must authenticate before issuing commands.

### ✅ Encrypted at Rest
Google-managed encryption keys.

### ✅ IAM Integration
Can use IAM for access control (advanced feature).

---

## Common Issues

### Backend Cannot Connect

**Problem:** Connection timeout or refused

**Solutions:**
1. Check Redis is running:
   ```bash
   gcloud redis instances describe lab-dev-redis --region=us-central1
   ```

2. Verify host/port in backend env vars:
   ```bash
   terraform output redis_host
   ```

3. Check VPC connector allows traffic

4. Test from Cloud Shell (if in same VPC):
   ```bash
   # Install redis-cli
   sudo apt-get install redis-tools
   
   # Connect
   redis-cli -h REDIS_HOST -p 6379 --tls
   AUTH your-auth-string
   PING
   ```

### AUTH Errors

**Problem:** `NOAUTH Authentication required`

**Cause:** Missing or incorrect AUTH string

**Solution:**
```bash
# Get AUTH string
terraform output -raw redis_host

# Ensure backend has REDIS_AUTH_STRING env var
```

### Memory Full

**Problem:** OOM errors

**Solutions:**
1. Check memory usage:
   ```bash
   gcloud redis instances describe lab-dev-redis --region=us-central1
   ```

2. With `allkeys-lru`, this should auto-resolve

3. If persistent, increase memory size:
   ```hcl
   memory_size_gb = 5
   ```

---

## Connecting to Redis

### From Backend (Automatic)
```javascript
const redis = require('redis');
const client = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST,
    port: 6379,
    tls: true
  },
  password: process.env.REDIS_AUTH_STRING
});

await client.connect();
await client.set('key', 'value');
const value = await client.get('key');
```

### From Cloud Shell (Testing)
```bash
# Get connection info
REDIS_HOST=$(terraform output -raw redis_host)
REDIS_AUTH=$(terraform output -raw auth_string)

# Install redis-cli
sudo apt-get install redis-tools

# Connect
redis-cli -h $REDIS_HOST -p 6379 --tls

# Authenticate
AUTH $REDIS_AUTH

# Test commands
PING
SET test "Hello Redis"
GET test
KEYS *
INFO memory
```

---

## Monitoring

### Key Metrics to Watch

```bash
# View metrics in Cloud Console
# Or use gcloud:
gcloud redis instances describe lab-dev-redis \
  --region=us-central1 \
  --format="table(
    persistenceIamIdentity,
    currentLocationId,
    memorySizeGb,
    redisVersion,
    tier
  )"
```

**Important metrics:**
- **Memory usage:** Should stay below 80%
- **Connected clients:** Monitor for connection leaks
- **Commands/sec:** Understand load patterns
- **Cache hit rate:** Higher = better (check in app logs)

---

## Best Practices

### ✅ Always Enable Transit Encryption
```hcl
transit_encryption_mode = "SERVER_AUTHENTICATION"
```

### ✅ Use AUTH
```hcl
auth_enabled = true
```

### ✅ Set Appropriate Eviction Policy
```hcl
maxmemory-policy = "allkeys-lru"
```

### ✅ Schedule Maintenance Windows
```hcl
maintenance_policy {
  weekly_maintenance_window {
    day = "SUNDAY"
  }
}
```

### ✅ Use STANDARD_HA for Production
```hcl
tier = "STANDARD_HA"
```

### ✅ Monitor Memory Usage
Set up alerts at 80% capacity.

### ✅ Set TTLs on Cached Data
```javascript
await redis.setEx('key', 300, 'value');  // Expires in 5 minutes
```

---

## Upgrading to Production

Changes for production use:

```hcl
resource "google_redis_instance" "cache" {
  tier           = "STANDARD_HA"      # High availability
  memory_size_gb = 5                  # More capacity
  
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
    notify-keyspace-events = "Ex"     # Enable expiration notifications
  }
  
  # Read replicas for scaling reads
  read_replicas_mode = "READ_REPLICAS_ENABLED"
  replica_count      = 2
}
```

---

## References

- [Memorystore for Redis](https://cloud.google.com/memorystore/docs/redis)
- [Redis Best Practices](https://cloud.google.com/memorystore/docs/redis/memory-management-best-practices)
- [Transit Encryption](https://cloud.google.com/memorystore/docs/redis/in-transit-encryption)
- [Redis Commands](https://redis.io/commands)
- [Eviction Policies](https://redis.io/docs/manual/eviction/)
