# Quick Start — Deploy in 5 Minutes

## Prerequisites

- DigitalOcean account
- 2 new Ubuntu 22.04 LTS droplets
- SSH access to both droplets

## Step 1: Deploy WordPress ($12 VPS) — 2 minutes

```bash
# SSH into your $12 droplet
ssh root@WORDPRESS_IP

# Run one command
curl https://raw.githubusercontent.com/NedkoHristov/WordPress-Europe-2026/develop/scripts/deploy-12-vps.sh | bash

# Wait for completion (~90 seconds)
```

**Verify:**
```bash
curl http://localhost:8080
# Should show WordPress homepage
```

**Get your VPS IP:**
```bash
hostname -I
# Note this IP for the next step
```

## Step 2: Deploy Observability Droplet — 2 minutes

```bash
# SSH into your observability droplet
ssh root@OBSERVABILITY_IP

# Set VPS IP and run deployment
export VPS_IP=YOUR_WORDPRESS_IP
curl https://raw.githubusercontent.com/NedkoHristov/WordPress-Europe-2026/develop/scripts/deploy-obs.sh | bash

# Wait for completion (~60 seconds)
```

## Step 3: Access Everything — 1 minute

**WordPress:**
```
http://WORDPRESS_IP:8080
```

**Grafana Dashboards:**
```
http://OBSERVABILITY_IP:3000
Username: admin
Password: grafana
```

**Prometheus:**
```
http://OBSERVABILITY_IP:9090
```

## What You Get

✅ **Production WordPress instance**
- 14,000+ posts in database
- Nginx + PHP-FPM + MariaDB + Redis
- Fully optimized for 2GB RAM
- All 5 metric exporters exposed

✅ **Professional Monitoring**
- 6 Grafana dashboards
- 30-day metric retention
- Real-time alerts
- System + Database + Cache monitoring

✅ **Cost: $17.50/month**
- $12 for WordPress droplet
- $5.50 for Observability droplet

## Load Testing

Optional: Run load test on WordPress droplet

```bash
# SSH into WordPress droplet
ssh root@WORDPRESS_IP

# Start k6 load test
docker compose -f docker-compose.minimal.yml --profile load up -d k6

# Watch metrics in Grafana
# Go to: http://OBSERVABILITY_IP:3000 → k6 Live Dashboard
```

## Troubleshooting

**Can't access WordPress?**
```bash
docker compose -f docker-compose.minimal.yml ps
# All containers should show "Up"
```

**Grafana shows no data?**
```bash
# Check Prometheus can reach exporters
curl http://WORDPRESS_IP:9100/metrics
curl http://WORDPRESS_IP:9104/metrics
# etc...
```

**Slow response?**
- Check load: `docker compose -f docker-compose.minimal.yml stats`
- Check database: `curl http://WORDPRESS_IP:9104/metrics | grep mysql_`
- Monitor in Grafana → MySQL Deep Dive dashboard

## Next Steps

1. Configure domain name → Point to WordPress IP
2. Set up SSL/TLS (Let's Encrypt)
3. Configure backups (DigitalOcean snapshots)
4. Set up alerts in AlertManager
5. Monitor regularly

---

**Done!** You now have production WordPress running on $12/month with professional monitoring. 🚀
