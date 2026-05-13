# ─────────────────────────────────────────────────────────────────────────────
# WordPress Europe 2026 — Makefile
# Usage: make <target>
# ─────────────────────────────────────────────────────────────────────────────

COMPOSE := docker compose
WP_PORT_VALUE := $(or $(shell grep -E '^WP_PORT=' .env 2>/dev/null | cut -d= -f2),8080)
BLUE    := \033[1;34m
GREEN   := \033[1;32m
YELLOW  := \033[1;33m
RED     := \033[1;31m
RESET   := \033[0m

.DEFAULT_GOAL := help

# ─── HELP ────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "$(BLUE)WordPress Europe 2026 — Stress Testing & Scaling on a \$$12 VPS$(RESET)"
	@echo ""
	@echo "$(GREEN)Presentation levels:$(RESET)"
	@echo "  make level-0       Apache + mod_php (intentional crash baseline)"
	@echo "  make level-1       Nginx + PHP-FPM + OPcache + Redis object cache"
	@echo "  make level-2       Level-1 + FastCGI page cache + MariaDB tuning"
	@echo "  make level-4       Level-2 + hybrid-static (Simply Static export)"
	@echo ""
	@echo "$(GREEN)Observability:$(RESET)"
	@echo "  make obs-up        Start Prometheus + Grafana + all exporters"
	@echo "  make obs-down      Stop observability stack"
	@echo ""
	@echo "$(GREEN)Load testing:$(RESET)"
	@echo "  make load-smoke    Quick 10-VU smoke test (1 min)"
	@echo "  make load-crash    Black Friday ramp — crash the Level-0 stack"
	@echo "  make load-spike    Instant 500-VU spike"
	@echo "  make load-soak     1-hour soak (run overnight)"
	@echo "  make load-woo      WooCommerce browse-add-checkout flow"
	@echo ""
	@echo "$(GREEN)Utilities:$(RESET)"
	@echo "  make setup         Install WordPress + seed demo content"
	@echo "  make bloat         Seed 50k posts, 1k products, revisions, transients"
	@echo "  make baseline      Record before/after perf snapshot (JSON to results/)"
	@echo "  make static-build  Run Simply Static export → results/static-export/"
	@echo "  make reset         Nuclear reset — destroy volumes and rebuild"
	@echo "  make logs          Follow all container logs"
	@echo "  make status        Show running containers + resource usage"
	@echo ""

# ─── LEVEL 0 — Apache baseline ───────────────────────────────────────────────
.PHONY: level-0
level-0:
	@echo "$(YELLOW)▶ Level 0 — Apache + mod_php (crash baseline)$(RESET)"
	$(COMPOSE) --profile apache --profile obs up -d --build
	@echo "$(GREEN)✓ Level 0 running on http://localhost:8080$(RESET)"
	@echo "  Grafana: http://localhost:3000  (admin/grafana)"
	@echo "  Run 'make setup' if first time, then 'make load-crash'"

# ─── LEVEL 1 — Nginx + PHP-FPM + OPcache + Redis ────────────────────────────
.PHONY: level-1
level-1:
	@echo "$(YELLOW)▶ Level 1 — Nginx + PHP-FPM + OPcache + Redis$(RESET)"
	$(COMPOSE) --profile apache down 2>/dev/null || true
	NGINX_CONF=nginx.conf PHP_INI=php-tuned.ini FPM_CONF=www.conf MARIADB_CONFIG=00-baseline.cnf \
		$(COMPOSE) --profile nginx --profile obs up -d --build
	@echo "$(GREEN)✓ Level 1 running on http://localhost:8080$(RESET)"

# ─── LEVEL 2 — + FastCGI cache + MariaDB tuning ──────────────────────────────
.PHONY: level-2
level-2:
	@echo "$(YELLOW)▶ Level 2 — FastCGI page cache + MariaDB tuning$(RESET)"
	$(COMPOSE) --profile apache down 2>/dev/null || true
	NGINX_CONF=nginx-cache.conf PHP_INI=php-tuned.ini FPM_CONF=www.conf MARIADB_CONFIG=10-tuned.cnf \
		$(COMPOSE) --profile nginx --profile obs up -d --build
	@echo "$(GREEN)✓ Level 2 running on http://localhost:8080$(RESET)"
	@echo "  FastCGI cache active — hit MISS then HIT in response headers"

# ─── LEVEL 4 — Hybrid static ─────────────────────────────────────────────────
.PHONY: level-4
level-4: static-build
	@echo "$(YELLOW)▶ Level 4 — Hybrid static (WP origin + static frontend)$(RESET)"
	NGINX_CONF=nginx-cache.conf PHP_INI=php-tuned.ini FPM_CONF=www.conf MARIADB_CONFIG=10-tuned.cnf \
		$(COMPOSE) --profile nginx --profile obs --profile static up -d
	@echo "$(GREEN)✓ Level 4 running$(RESET)"
	@echo "  Static site: http://localhost:8090"
	@echo "  WP origin:   http://localhost:8080 (now idle at peak)"

# ─── OBSERVABILITY ───────────────────────────────────────────────────────────
.PHONY: obs-up
obs-up:
	$(COMPOSE) --profile obs up -d
	@echo "$(GREEN)✓ Grafana: http://localhost:3000  (admin/grafana)$(RESET)"

.PHONY: obs-down
obs-down:
	$(COMPOSE) --profile obs down

# ─── LOAD TESTS ──────────────────────────────────────────────────────────────
.PHONY: load-smoke
load-smoke:
	@echo "$(YELLOW)▶ Smoke test — 10 VU × 1 min$(RESET)"
	$(COMPOSE) --profile load run --rm \
		-e BASE_URL=http://host.docker.internal:$(WP_PORT_VALUE) \
		k6 run --vus 10 --duration 60s /scripts/browse.js | cat

.PHONY: load-crash
load-crash:
	@echo "$(RED)▶ Black Friday ramp — this WILL crash Level 0$(RESET)"
	$(COMPOSE) --profile load run --rm \
		-e BASE_URL=http://host.docker.internal:$(WP_PORT_VALUE) \
		k6 run /scripts/black-friday.js | cat

.PHONY: load-spike
load-spike:
	@echo "$(RED)▶ Instant 500-VU spike$(RESET)"
	$(COMPOSE) --profile load run --rm \
		-e BASE_URL=http://host.docker.internal:$(WP_PORT_VALUE) \
		k6 run /scripts/spike.js | cat

.PHONY: load-soak
load-soak:
	@echo "$(YELLOW)▶ 1-hour soak test$(RESET)"
	$(COMPOSE) --profile load run --rm \
		-e BASE_URL=http://host.docker.internal:$(WP_PORT_VALUE) \
		k6 run /scripts/soak.js | cat

.PHONY: load-woo
load-woo:
	@echo "$(YELLOW)▶ WooCommerce browse-add-checkout flow$(RESET)"
	$(COMPOSE) --profile load run --rm \
		-e BASE_URL=http://host.docker.internal:$(WP_PORT_VALUE) \
		k6 run /scripts/browse-product-cart.js | cat

.PHONY: load-compare
load-compare:
	@echo "$(YELLOW)▶ Level compare — 50 VU ramp (4 min)$(RESET)"
	$(COMPOSE) --profile load run --rm \
		-e BASE_URL=http://host.docker.internal:$(WP_PORT_VALUE) \
		k6 run /scripts/level-compare.js | cat

# ─── SETUP & CONTENT ─────────────────────────────────────────────────────────
.PHONY: setup
setup:
	@echo "$(YELLOW)▶ Installing WordPress and seeding demo content$(RESET)"
	$(COMPOSE) --profile nginx exec wordpress-fpm wp-setup.sh 2>/dev/null || \
		$(COMPOSE) --profile apache exec wordpress-apache wp-setup.sh
	@echo "$(GREEN)✓ WordPress ready — admin/admin123$(RESET)"

.PHONY: bloat
bloat:
	@echo "$(YELLOW)▶ Seeding bloat: 2.5k posts + 5k revisions, 500 products + 1.5k revisions, transients$(RESET)"
	$(COMPOSE) --profile nginx exec wordpress-fpm wp-bloat.sh 2>/dev/null || \
		$(COMPOSE) --profile apache exec wordpress-apache wp-bloat.sh

.PHONY: baseline
baseline:
	@echo "$(YELLOW)▶ Recording performance baseline$(RESET)"
	mkdir -p results
	$(COMPOSE) --profile nginx exec wordpress-fpm wp-perf-test.sh 2>/dev/null || \
		$(COMPOSE) --profile apache exec wordpress-apache wp-perf-test.sh

.PHONY: static-build
static-build:
	@echo "$(YELLOW)▶ Exporting static site$(RESET)"
	mkdir -p static/export
	bash static/build.sh

# ─── UTILITIES ───────────────────────────────────────────────────────────────
.PHONY: reset
reset:
	@echo "$(RED)▶ Nuclear reset — destroying all volumes$(RESET)"
	$(COMPOSE) --profile apache --profile nginx --profile obs --profile load --profile static down -v
	$(COMPOSE) --profile apache --profile nginx --profile obs --profile load --profile static build --no-cache
	@echo "$(GREEN)✓ Clean slate — run 'make level-0' or 'make level-1' then 'make setup'$(RESET)"

.PHONY: logs
logs:
	$(COMPOSE) --profile apache --profile nginx --profile obs logs -f | cat

.PHONY: status
status:
	$(COMPOSE) --profile apache --profile nginx --profile obs --profile load --profile static ps | cat
	@echo ""
	docker stats --no-stream | cat
