#!/bin/bash
###############################################################################
# WordPress Europe 2026 — $12 VPS Deployment Script
# Nedko Hristov — github.com/NedkoHristov/WordPress-Europe-2026
#
# One-command setup for DigitalOcean $12 Droplet (1 vCPU, 2GB RAM, 50GB SSD)
#
# USAGE:
#   curl https://raw.githubusercontent.com/NedkoHristov/WordPress-Europe-2026/develop/scripts/deploy-12-vps.sh | bash
#
# OR locally:
#   bash scripts/deploy-12-vps.sh
#
# PREREQUISITES:
#   - Ubuntu 22.04 LTS or later
#   - Docker + Docker Compose installed
#   - ~1GB free disk space after OS
#
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  WordPress Europe 2026 — \$12 VPS Deployment                   ║${NC}"
echo -e "${GREEN}║  Nedko Hristov — github.com/NedkoHristov/WordPress-Europe-2026 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
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
if [ ! -f "docker-compose.minimal.yml" ]; then
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
mkdir -p data/mysql data/redis
chmod 777 data/mysql data/redis

# Start WordPress stack
echo -e "${YELLOW}🚀 Starting WordPress stack with minimal profile...${NC}"
docker compose -f docker-compose.minimal.yml up -d

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for services to start (30 seconds)...${NC}"
sleep 30

# Verify all exporters are running
echo -e "${YELLOW}🔍 Verifying exporters...${NC}"

verify_exporter() {
    local name=$1
    local port=$2
    if curl -sf http://localhost:$port/metrics > /dev/null 2>&1; then
        echo -e "${GREEN}  ✅ $name (:$port)${NC}"
        return 0
    else
        echo -e "${RED}  ❌ $name (:$port) — NOT RESPONDING${NC}"
        return 1
    fi
}

verify_exporter "Node Exporter" 9100
verify_exporter "MySQL Exporter" 9104
verify_exporter "Redis Exporter" 9121
verify_exporter "Nginx Exporter" 9113
verify_exporter "PHP-FPM Exporter" 8118

# Check WordPress is up
echo -e "${YELLOW}🔍 Checking WordPress...${NC}"
if curl -sf http://localhost:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✅ WordPress (http://localhost:8080)${NC}"
else
    echo -e "${RED}  ❌ WordPress NOT RESPONDING${NC}"
fi

# Display summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ DEPLOYMENT COMPLETE                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📊 Resource Usage:${NC}"
docker compose -f docker-compose.minimal.yml ps --format 'table {{.Names}}\t{{.Status}}\t{{.CPUPerc}}\t{{.MemUsage}}'
echo ""
echo -e "${GREEN}📋 Metrics Endpoints:${NC}"
echo "  • Node Exporter:   http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "  • MySQL Exporter:  http://$(hostname -I | awk '{print $1}'):9104/metrics"
echo "  • Redis Exporter:  http://$(hostname -I | awk '{print $1}'):9121/metrics"
echo "  • Nginx Exporter:  http://$(hostname -I | awk '{print $1}'):9113/metrics"
echo "  • PHP-FPM Exporter: http://$(hostname -I | awk '{print $1}'):8118/metrics"
echo ""
echo -e "${GREEN}🌐 WordPress:${NC}"
echo "  • http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  1. Set up observability droplet with deploy-obs.sh"
echo "  2. Configure VPS_IP in deploy-obs.sh with this IP: $(hostname -I | awk '{print $1}')"
echo "  3. Run load test: docker compose --profile load up -d k6"
echo ""
echo -e "${GREEN}💾 Data Management:${NC}"
echo "  • Database:   data/mysql/"
echo "  • WordPress:  data/wordpress/"
echo "  • Redis:      data/redis/"
echo ""
