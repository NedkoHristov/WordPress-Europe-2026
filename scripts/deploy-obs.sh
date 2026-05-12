#!/bin/bash
###############################################################################
# WordPress Europe 2026 — Observability Stack Deployment Script
# Nedko Hristov — github.com/NedkoHristov/WordPress-Europe-2026
#
# One-command setup for observability droplet
# Runs Prometheus + Grafana + Loki + AlertManager
# Configured to scrape metrics from remote $12 VPS
#
# USAGE:
#   VPS_IP=192.0.2.100 bash scripts/deploy-obs.sh
#
# PREREQUISITES:
#   - Ubuntu 22.04 LTS or later
#   - Docker + Docker Compose installed
#   - Network connectivity to $12 VPS on ports 9100, 9104, 9113, 8118, 9121
#
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  WordPress Europe 2026 — Observability Stack                  ║${NC}"
echo -e "${GREEN}║  Nedko Hristov — github.com/NedkoHristov/WordPress-Europe-2026 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check VPS_IP is set
if [ -z "$VPS_IP" ]; then
    echo -e "${RED}❌ VPS_IP environment variable not set${NC}"
    echo -e "${YELLOW}Usage: VPS_IP=192.0.2.100 bash scripts/deploy-obs.sh${NC}"
    exit 1
fi

echo -e "${GREEN}🎯 Target VPS: $VPS_IP${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Installing...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}⚠️  Please log out and back in to apply docker group changes${NC}"
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose v2 not found. Installing...${NC}"
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# Clone repository if not already in it
if [ ! -f "docker-compose.obs-remote.yml" ]; then
    echo -e "${YELLOW}📦 Cloning WordPress Europe 2026 repository...${NC}"
    cd /opt
    sudo git clone https://github.com/NedkoHristov/WordPress-Europe-2026.git
    cd WordPress-Europe-2026
else
    echo -e "${GREEN}✅ Repository already present${NC}"
fi

# Update to latest commit
echo -e "${YELLOW}📥 Pulling latest changes...${NC}"
git pull origin develop || true

# Create necessary directories
echo -e "${YELLOW}📁 Creating data directories...${NC}"
mkdir -p data/loki
chmod 777 data/loki

# Start observability stack
echo -e "${YELLOW}🚀 Starting observability stack...${NC}"
VPS_IP=$VPS_IP docker compose -f docker-compose.obs-remote.yml up -d

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for Prometheus to start (20 seconds)...${NC}"
sleep 20

# Verify Prometheus is running
echo -e "${YELLOW}🔍 Verifying Prometheus...${NC}"
if curl -sf http://localhost:9090/-/ready > /dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Prometheus is ready${NC}"
else
    echo -e "${RED}  ⚠️  Prometheus still starting...${NC}"
fi

# Check scrape targets
echo -e "${YELLOW}🔍 Checking scrape targets from $VPS_IP...${NC}"
sleep 10  # Give Prometheus time to scrape

TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -o '"health":"up"' | wc -l)
echo -e "${CYAN}  Found $TARGETS healthy targets${NC}"

# Expected targets: node, mysql, redis, nginx, php-fpm = 5
if [ "$TARGETS" -ge 3 ]; then
    echo -e "${GREEN}  ✅ Most targets are healthy${NC}"
else
    echo -e "${YELLOW}  ⚠️  Some targets may not be responding. Verify:${NC}"
    echo -e "${YELLOW}    1. VPS_IP is correct: $VPS_IP${NC}"
    echo -e "${YELLOW}    2. Network connectivity: VPS can reach observability server${NC}"
    echo -e "${YELLOW}    3. Firewall: Ports 9100, 9104, 9113, 8118, 9121 are open${NC}"
fi

# Verify Grafana is running
echo -e "${YELLOW}🔍 Verifying Grafana...${NC}"
if curl -sf http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Grafana is ready${NC}"
else
    echo -e "${RED}  ❌ Grafana NOT RESPONDING${NC}"
fi

# Display summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ OBSERVABILITY DEPLOYMENT COMPLETE                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📊 Status:${NC}"
docker compose -f docker-compose.obs-remote.yml ps --format 'table {{.Names}}\t{{.Status}}'
echo ""
echo -e "${GREEN}🌐 Access Points:${NC}"
OBS_IP=$(hostname -I | awk '{print $1}')
echo "  • Grafana:      http://$OBS_IP:3000 (admin/grafana)"
echo "  • Prometheus:   http://$OBS_IP:9090"
echo "  • AlertManager: http://$OBS_IP:9093"
echo ""
echo -e "${GREEN}📊 Dashboards:${NC}"
echo "  • 01-overview.json         — System overview"
echo "  • 02-php-fpm.json         — PHP-FPM deep dive"
echo "  • 03-mariadb.json         — MariaDB performance"
echo "  • 04-nginx-cache.json     — Nginx cache analysis"
echo "  • 05-redis-cache.json     — Redis cache utilization"
echo "  • 06-k6-live.json         — k6 load test metrics"
echo ""
echo -e "${GREEN}📈 Prometheus Targets:${NC}"
curl -s http://localhost:9090/api/v1/targets 2>/dev/null \
  | grep -o '"job":"[^"]*"' | sed 's/"job":"//;s/"//g' | sort | uniq \
  | sed 's/^/  • /' || echo "  (Unable to fetch targets)"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  1. Verify all targets are UP in Prometheus: http://$OBS_IP:9090/targets"
echo "  2. Check dashboards in Grafana: http://$OBS_IP:3000"
echo "  3. Run load test on VPS: docker compose --profile load up -d k6"
echo "  4. Watch metrics in real-time on Grafana"
echo ""
echo -e "${GREEN}💾 Data:${NC}"
echo "  • Prometheus: data/prometheus_data/"
echo "  • Grafana:    data/grafana_data/"
echo "  • Loki:       data/loki/"
echo ""
echo -e "${GREEN}🔗 Remote VPS Target:${NC}"
echo "  • IP: $VPS_IP"
echo "  • Change with: VPS_IP=NEW_IP docker compose -f docker-compose.obs-remote.yml restart prometheus${NC}"
echo ""
