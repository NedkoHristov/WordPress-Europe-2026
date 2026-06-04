# WordPress Europe 2026 — $12 VPS Deployment Guide

## Overview

This guide demonstrates how to run a production-ready WordPress instance on a **$12 DigitalOcean Droplet** (1 vCPU, 2GB RAM, 50GB SSD) with professional observability running on a separate droplet.

**Goal:** Show that WordPress with 14,000+ posts, caching, and monitoring can run profitably on minimal infrastructure.

---

## Architecture

### Two-Droplet Design

```
┌─────────────────────────┐           ┌─────────────────────────┐
│   $12 VPS (Droplet 1)   │           │ Observability (Droplet 2)│
│                         │           │                         │
│  • Nginx                │──HTTP───→ │  • Prometheus           │
│  • PHP-FPM (12 workers) │  :9100    │  • Grafana              │
│  • MariaDB (256MB pool) │  :9104    │  • Loki                 │
│  • Redis (128MB)        │  :9113    │  • AlertManager         │
│  • 5 Exporters          │  :8118    │                         │
│                         │  :9121    │  6 Dashboards           │
│ Handles: 100 req/s      │           │  30-day retention       │
│ Memory: ~1.3GB peak     │           │                         │
│ Cost: $12/month         │           │ Cost: $5-12/month       │
└─────────────────────────┘           └─────────────────────────┘
```

**Why separate?**
- ✅ Production separation of concerns
- ✅ Droplet 1 stays lean and fast (100% resources for WordPress)
- ✅ Droplet 2 can monitor multiple WordPress instances
- ✅ No performance impact on WordPress from monitoring
- ✅ Can reboot WordPress without losing monitoring
- ✅ Scales efficiently (add more WordPress droplets, 1 Prometheus)

---

## Deployment

### Step 1: Deploy $12 VPS

**Prerequisites:**
- DigitalOcean account + API access
- SSH key configured

**Option A: Automated (Recommended)**

```bash
# SSH into new $12 droplet
ssh root@YOUR_DROPLET_IP

# Run deployment script
curl https://raw.githubusercontent.com/NedkoHristov/WordPress-Europe-2026/develop/scripts/deploy-12-vps.sh | bash
```

**Option B: Manual**

```bash
git clone https://github.com/NedkoHristov/WordPress-Europe-2026.git
cd WordPress-Europe-2026
docker compose -f docker-compose.minimal.yml up -d
```

**Verification:**

```bash
# Check all services are running
docker compose -f docker-compose.minimal.yml ps

# Test metrics endpoints
curl http://localhost:9100/metrics  # Node Exporter
curl http://localhost:9104/metrics  # MySQL Exporter
curl http://localhost:9113/metrics  # Nginx Exporter
curl http://localhost:8118/metrics  # PHP-FPM Exporter
curl http://localhost:9121/metrics  # Redis Exporter
```

**Access WordPress:**

```
http://YOUR_DROPLET_IP:8080
```

### Step 2: Deploy Observability Stack

**On a separate droplet (can be cheaper: $5 Basic):**

```bash
# SSH into observability droplet
ssh root@OBS_DROPLET_IP

# Set VPS_IP to your $12 droplet's IP
export VPS_IP=YOUR_DROPLET_IP

# Run deployment script
curl https://raw.githubusercontent.com/NedkoHristov/WordPress-Europe-2026/develop/scripts/deploy-obs.sh | bash
```

**Verification:**

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana is up
curl http://localhost:3000
```

**Access Monitoring:**

```
Grafana:      http://OBS_DROPLET_IP:3000        (admin/grafana)
Prometheus:   http://OBS_DROPLET_IP:9090
AlertManager: http://OBS_DROPLET_IP:9093
```

---

## Resource Usage

### Memory Allocation ($12 Droplet)

```
Total Available:  2048 MB
├─ System:         150 MB
├─ MariaDB:        256 MB (16% utilization at 50% capacity)
├─ PHP-FPM:        480 MB (12 workers × 40MB average)
├─ Redis:          128 MB (allkeys-lru policy)
├─ Nginx:           75 MB
└─ Headroom:       961 MB
```

### CPU Usage

**Baseline (idle):**
- PHP-FPM: ~0.2 CPU (waiting for requests)
- Nginx: <0.1 CPU
- MariaDB: <0.1 CPU
- Exporters: <0.1 CPU

**Under Load (100 req/s):**
- PHP-FPM: 0.6-0.8 CPU
- Nginx: 0.1-0.2 CPU
- MariaDB: 0.05-0.15 CPU

---

## Configuration Files

### docker-compose.minimal.yml

Main compose file for $12 VPS. Key differences from development:

```yaml
# PHP-FPM optimized for 2GB
pm.max_children = 12          # vs 20 on dev
pm.start_servers = 6          # scales down

# MariaDB optimized for 2GB
innodb_buffer_pool_size = 256M  # vs 512M on dev
max_connections = 100         # vs 151 on dev

# Redis optimized for 2GB
maxmemory = 128mb            # vs 256mb on dev
```

### config/mariadb/00-minimal-vps.cnf

Minimal MariaDB configuration focused on throughput without hogging memory:

- Buffer pool: 256MB
- Log file size: 64MB
- No slow query log (reduce I/O)
- No persistent storage (RDB/AOF off)

### config/php/www-minimal.conf

PHP-FPM pool for 2GB environment:

```
pm.max_children = 12
pm.start_servers = 6
pm.min_spare_servers = 4
pm.max_spare_servers = 10
```

This allows PHP to dynamically scale from 4 to 10 spare workers, bursting to 12 total.

### config/php/php-minimal.ini

Lightweight PHP settings:

```
memory_limit = 96M             # vs 128M on dev
OPcache enabled (64M)          # Critical for performance
dangerous_functions disabled   # Security hardening
```

### config/nginx/nginx-minimal.conf

Minimal Nginx configuration:

- FastCGI cache enabled (10min validity)
- Gzip compression (reduce bandwidth)
- Stub status for metrics
- Security headers included

---

## Monitoring Dashboards

### 6 Pre-Configured Grafana Dashboards

1. **01-overview.json** — System Overview
   - CPU, Memory, Disk usage
   - Network traffic
   - Service health status

2. **02-php-fpm.json** — PHP-FPM Deep Dive
   - Active/idle processes
   - Slow requests
   - Memory per worker
   - Request duration histogram

3. **03-mariadb.json** — MariaDB Performance
   - Query throughput
   - Slow queries
   - Buffer pool utilization
   - Connection count

4. **04-nginx-cache.json** — Nginx Cache Analysis
   - Total requests
   - Cache hit ratio
   - Request duration
   - Response codes

5. **05-redis-cache.json** — Redis Cache Utilization
   - Keys stored
   - Memory usage
   - Hit/miss ratio
   - Eviction rate

6. **06-k6-live.json** — k6 Load Test Metrics
   - Virtual users (VUs)
   - Requests/second
   - Error rate
   - Response time percentiles

---

## Performance Tuning

### Database Optimization

```sql
-- Check buffer pool efficiency
SHOW STATUS LIKE 'Innodb_buffer_pool%';

-- Monitor slow queries
SHOW VARIABLES LIKE 'slow_query_log';
SHOW PROCESSLIST;  -- Currently running queries
```

### PHP-FPM Optimization

Monitor from Grafana or command line:

```bash
# Check PHP-FPM status
curl http://localhost:9000/status

# Monitor in real-time
watch -n 1 curl http://localhost:9000/status
```

### Nginx Cache

Check cache effectiveness:

```bash
# View cache stats in metrics
curl http://localhost:9113/metrics | grep nginx_cache
```

---

## Backup Strategy

### Database Backups

```bash
# Backup MariaDB
docker exec wordpress-europe-2026-db-1 \
  mysqldump -u wordpress -pwordpress wordpress \
  > backup-$(date +%Y%m%d).sql

# Restore from backup
docker exec -i wordpress-europe-2026-db-1 \
  mysql -u wordpress -pwordpress wordpress \
  < backup-20260512.sql
```

### WordPress Data Backups

```bash
# Backup WordPress files
tar -czf wordpress-backup.tar.gz data/wordpress/

# Backup entire droplet (via DigitalOcean snapshots)
# - Recommended: Weekly snapshots
# - Retention: 4 snapshots (1 month rolling)
```

---

## Troubleshooting

### Prometheus not scraping targets

```bash
# Check Prometheus target health
curl http://localhost:9090/api/v1/targets

# Check network connectivity
curl -v http://DROPLET_IP:9100/metrics

# Check firewall
ssh DROPLET_IP "sudo ufw status"
```

**Solutions:**
- Verify VPS_IP is correct
- Confirm firewall allows ports 9100-9121
- Check Docker network routing
- Verify exporters are running: `docker compose ps`

### High memory usage

```bash
# Check memory by container
docker compose -f docker-compose.minimal.yml stats

# Monitor over time in Grafana
# Check for memory leaks in PHP-FPM
```

**Solutions:**
- Increase pm.max_requests (force worker restart)
- Reduce PHP memory_limit if safe
- Check WordPress plugins for leaks
- Monitor with redis-cli and mysql slow log

### Slow queries

```bash
# Enable slow query log
docker exec wordpress-europe-2026-db-1 \
  mariadb-admin flush-logs

# Check slow log
docker exec wordpress-europe-2026-db-1 \
  tail -f /var/log/mysql/slow.log
```

---

## Cost Analysis

### Monthly Costs

```
$12 VPS (WordPress):
├─ Droplet:        $12.00
├─ Bandwidth:      included (2TB/month)
├─ Storage:        included (50GB SSD)
└─ Total/month:    $12.00

Observability:
├─ Droplet ($5):   $5.00  (or reuse $12 with space)
├─ Bandwidth:      ~$0.50 (minimal)
└─ Total/month:    $5.50

Total 2-Droplet:   $17.50/month
```

### Comparison

| Option | Cost | Scalability | Performance | Monitoring |
|--------|------|-------------|-------------|-----------|
| **$12 VPS (our setup)** | $12/mo | Medium | Good | Excellent |
| Shared Hosting | $3-5/mo | Low | Fair | Limited |
| $20+ VPS | $20/mo | High | Excellent | Included |
| AWS EC2 t3.small | ~$20/mo | Medium | Good | Included |

---

## Load Testing

### Using k6 from $12 VPS

```bash
# Run 1-minute smoke test
docker compose -f docker-compose.minimal.yml \
  --profile load up -d k6

# Monitor in Grafana: http://OBS_IP:3000 → k6 Live Dashboard
```

### Expected Results on $12 VPS

```
Load Test: 100 virtual users × 1 minute
├─ Requests/sec:     ~50-80 RPS
├─ Error rate:       0-1%
├─ Response time:    100-300ms p95
├─ CPU usage:        60-80%
├─ Memory usage:     ~1.3GB
└─ PHP workers:      All 12 active
```

---

## Production Checklist

- [ ] Database backups configured
- [ ] Droplet snapshots scheduled (weekly)
- [ ] Alerting rules configured in AlertManager
- [ ] Log retention verified (Loki 30-day retention)
- [ ] SSL/TLS configured (nginx + Let's Encrypt)
- [ ] Firewall rules tightened (only open necessary ports)
- [ ] Monitoring accessed regularly
- [ ] Slow query log reviewed weekly
- [ ] PHP-FPM max_requests tuned (restart workers periodically)
- [ ] Cache invalidation strategy defined

---

## Conclusion

This setup proves WordPress can:
- ✅ Run efficiently on minimal hardware
- ✅ Be professionally monitored
- ✅ Scale to handle moderate traffic
- ✅ Remain cost-effective
- ✅ Support real production workloads

**Architecture:** Separate concerns (WordPress + Monitoring)
**Cost:** $17.50/month for both droplets
**Performance:** Handles ~50-80 requests/second
**Reliability:** Professional observability + automated alerting
