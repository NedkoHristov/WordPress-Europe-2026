#!/usr/bin/env bash
# =============================================================================
# full-run.sh — End-to-end screenshot automation
# WordPress Europe 2026 — "Stress Testing and Scaling WordPress on a $12 VPS"
#
# What it does:
#   Phase 0  Preflight checks
#   Phase 1  Clean slate (docker down -v + rebuild)
#   Phase 2  Start obs stack + Level 0 (Apache), wait for healthy
#   Phase 3  WordPress install + plugins
#   Phase 4  Seed bloat data (2.5k posts, 500 products, revisions)
#   Phase 5  L0 snapshot  → screenshots/l0-*.png
#   Phase 6  Switch to L1 (Nginx+FPM+Redis), snapshot → screenshots/l1-*.png
#   Phase 7  Switch to L2 (FastCGI cache), snapshot → screenshots/l2-*.png
#   Phase 8  Summary
#
# Skip flags (export before running or prefix on command line):
#   SKIP_RESET=1   Skip Phase 1 — reuse existing volumes / running containers
#   SKIP_SETUP=1   Skip Phase 3 — WordPress already installed
#   SKIP_BLOAT=1   Skip Phase 4 — DB already seeded
#
# Example — full clean run:
#   bash scripts/full-run.sh
#
# Example — rerun screenshots only (DB + containers already up):
#   SKIP_RESET=1 SKIP_SETUP=1 SKIP_BLOAT=1 bash scripts/full-run.sh
# =============================================================================
set -euo pipefail

# ── Resolve repo root regardless of where the script is called from
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

COMPOSE="docker compose"
WP_PORT="${WP_PORT:-8080}"
GRAFANA="http://localhost:3000"
SCREENSHOTS_DIR="$REPO_DIR/screenshots"

# ── Colour helpers
RED='\033[1;31m'; YELLOW='\033[1;33m'; GREEN='\033[1;32m'
CYAN='\033[1;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}══ $* ${RESET}"; }
ok()    { echo -e "${GREEN}✓ $*${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()   { echo -e "${RED}✗ $*${RESET}"; exit 1; }

# ── Skip flags
SKIP_RESET="${SKIP_RESET:-0}"
SKIP_SETUP="${SKIP_SETUP:-0}"
SKIP_BLOAT="${SKIP_BLOAT:-0}"

# =============================================================================
# PHASE 0 — Preflight checks
# =============================================================================
step "Phase 0 — Preflight checks"

command -v docker  >/dev/null 2>&1 || die "docker not found"
docker info        >/dev/null 2>&1 || die "Docker daemon not running"
command -v node    >/dev/null 2>&1 || die "node not found — run: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs"

# Check Playwright is installed
if ! node -e "require('playwright')" 2>/dev/null; then
  warn "Playwright not installed — running npm install..."
  npm install --prefix "$REPO_DIR"
fi
if ! node -e "require('playwright/lib/server/registry').Registry" 2>/dev/null; then
  warn "Playwright browser not installed — running npx playwright install chromium..."
  npx playwright install chromium --with-deps 2>&1 | tail -5
fi

ok "All preflight checks passed"

# =============================================================================
# PHASE 1 — Clean slate
# =============================================================================
step "Phase 1 — Clean slate"

if [[ "$SKIP_RESET" == "1" ]]; then
  warn "SKIP_RESET=1 — skipping teardown, reusing existing containers/volumes"
else
  echo "Stopping and removing all containers + volumes..."
  $COMPOSE --profile apache --profile nginx --profile obs --profile load --profile static \
    down -v --remove-orphans 2>/dev/null || true
  ok "Clean slate ready"
fi

mkdir -p "$SCREENSHOTS_DIR"

# =============================================================================
# PHASE 2 — Start obs stack + Level 0, wait for healthy
# =============================================================================
step "Phase 2 — Start obs stack + Level 0 (Apache baseline)"

$COMPOSE --profile apache --profile obs up -d --build
echo "Waiting for MariaDB to be healthy..."
until $COMPOSE exec db mariadb-admin ping -h localhost -u root -prootpassword --silent 2>/dev/null; do
  printf '.'; sleep 3
done
echo ""
ok "MariaDB healthy"

echo "Waiting for WordPress (Apache) to respond..."
until curl -sf "http://localhost:${WP_PORT}/" -o /dev/null 2>/dev/null; do
  printf '.'; sleep 3
done
echo ""
ok "WordPress reachable at http://localhost:${WP_PORT}/"

echo "Waiting for Grafana to be ready..."
until curl -sf "${GRAFANA}/api/health" -o /dev/null 2>/dev/null; do
  printf '.'; sleep 3
done
echo ""
ok "Grafana ready at ${GRAFANA}"

echo "Waiting for Prometheus to be ready..."
until curl -sf "http://localhost:9090/-/ready" -o /dev/null 2>/dev/null; do
  printf '.'; sleep 3
done
echo ""
ok "Prometheus ready"

# =============================================================================
# PHASE 3 — WordPress install + plugins
# =============================================================================
step "Phase 3 — WordPress setup"

if [[ "$SKIP_SETUP" == "1" ]]; then
  warn "SKIP_SETUP=1 — skipping WordPress install"
else
  echo "Running wp-setup.sh inside container..."
  $COMPOSE --profile apache exec -T wordpress-apache wp-setup.sh
  ok "WordPress installed — admin / admin123"
fi

# =============================================================================
# PHASE 4 — Seed bloat data
# =============================================================================
step "Phase 4 — Seed bloat data (2.5k posts, 500 products, revisions, transients)"

if [[ "$SKIP_BLOAT" == "1" ]]; then
  warn "SKIP_BLOAT=1 — skipping bloat seeding"
else
  echo "Running wp-bloat.sh inside container (takes ~3 min)..."
  $COMPOSE --profile apache exec -T wordpress-apache wp-bloat.sh
  ok "Bloat data seeded"
fi

# =============================================================================
# Helper: run a warmup + snapshot + screenshot for a given level
#
# The screenshot-watcher runs in the background alongside k6. It polls
# Prometheus for k6_vus and fires screenshot.js the moment VUs are stable
# at TARGET_VU, rather than waiting until after k6 finishes.
#
# Arguments:
#   $1  level label for screenshot prefix (l0 / l1 / l2)
#   $2  warmup count  (how many 3-page curl rounds, 10 = ~30 requests)
#   $3  optional: extra sleep before snapshot (for cache to warm)
# =============================================================================
run_snapshot() {
  local LABEL="$1"
  local WARMUP_ROUNDS="${2:-10}"
  local EXTRA_SLEEP="${3:-0}"

  step "Snapshot for ${LABEL}"

  # Warmup — pre-heat OPcache and Redis / FastCGI cache
  echo "Warming up (${WARMUP_ROUNDS} rounds × 3 URLs = $((WARMUP_ROUNDS * 3)) requests)..."
  for _ in $(seq 1 "$WARMUP_ROUNDS"); do
    curl -sf -o /dev/null "http://localhost:${WP_PORT}/" || true
    curl -sf -o /dev/null "http://localhost:${WP_PORT}/post-2498/" || true
    curl -sf -o /dev/null "http://localhost:${WP_PORT}/category/uncategorized/" || true
  done
  ok "Warmup done"

  if [[ "$EXTRA_SLEEP" -gt 0 ]]; then
    echo "Waiting ${EXTRA_SLEEP}s for cache to settle..."
    sleep "$EXTRA_SLEEP"
  fi

  # Start the screenshot watcher in the background — it will fire as soon as
  # k6_vus >= 45 has been stable for 3 × 3s = 9s, then settle 5s and shoot.
  echo "Starting screenshot watcher (prefix=${LABEL}, target 45 VU)..."
  bash "$REPO_DIR/scripts/screenshot-watcher.sh" \
    --prefix "$LABEL" \
    --target-vu 45 \
    --timeout 300 &
  WATCHER_PID=$!

  echo "Running 90s snapshot k6 test..."
  $COMPOSE --profile load run --rm \
    -e BASE_URL="http://host.docker.internal:${WP_PORT}" \
    k6 run /scripts/snapshot.js | cat || true   # k6 exits non-zero when thresholds fail — that's fine

  # k6 is done — kill the watcher if it hasn't already exited (e.g. if VUs
  # never reached target due to Apache crash), then reap the process.
  kill "$WATCHER_PID" 2>/dev/null || true
  wait "$WATCHER_PID" 2>/dev/null || true

  ok "Screenshots saved → screenshots/${LABEL}-*.png"
}

# =============================================================================
# PHASE 5 — Level 0 snapshots (Apache)
#   5a: snapshot.js (50 Virtual Users) → l0-*.png — shows idle/stable baseline
#   5b: black-friday.js (0→500 Virtual Users) → l0-crash-*.png — shows the crash
#       Watcher fires at TARGET_VU=100: Apache is already buckling but VUs are
#       still climbing — the most dramatic moment of the collapse.
# =============================================================================
step "Phase 5a — Level 0 baseline snapshot (50 Virtual Users)"

# At Level 0 FPM panels will show No data — that's correct and expected
run_snapshot "l0" 10

step "Phase 5b — Level 0 crash capture (Black Friday ramp: 0→500 Virtual Users)"

echo "Warming up before crash run (10 rounds)..."
for _ in $(seq 1 10); do
  curl -sf -o /dev/null "http://localhost:${WP_PORT}/" || true
  curl -sf -o /dev/null "http://localhost:${WP_PORT}/post-2498/" || true
  curl -sf -o /dev/null "http://localhost:${WP_PORT}/category/uncategorized/" || true
done
ok "Warmup done"

# Fire watcher at 100 Virtual Users — Apache is collapsing but VUs are still climbing.
# That's the most dramatic screenshot: high VU count, low requests/s, queue depth huge.
echo "Starting screenshot watcher (prefix=l0-crash, target 100 Virtual Users)..."
bash "$REPO_DIR/scripts/screenshot-watcher.sh" \
  --prefix "l0-crash" \
  --target-vu 100 \
  --hold 2 \
  --settle 8 \
  --timeout 900 &
CRASH_WATCHER_PID=$!

echo "Running black-friday.js crash ramp (0→500 Virtual Users, ~14 min)..."
$COMPOSE --profile load run --rm \
  -e BASE_URL="http://host.docker.internal:${WP_PORT}" \
  k6 run /scripts/black-friday.js | cat || true

kill "$CRASH_WATCHER_PID" 2>/dev/null || true
wait "$CRASH_WATCHER_PID" 2>/dev/null || true
ok "Crash screenshots saved → screenshots/l0-crash-*.png"

# =============================================================================
# PHASE 6 — Switch to Level 1 (Nginx + FPM + Redis)
# =============================================================================
step "Phase 6 — Switch to Level 1 (Nginx + PHP-FPM + OPcache + Redis)"

echo "Stopping Apache..."
$COMPOSE --profile apache stop wordpress-apache 2>/dev/null || true

echo "Starting Nginx + FPM (obs stack keeps running)..."
NGINX_CONF=nginx.conf PHP_INI=php-tuned.ini FPM_CONF=www.conf MARIADB_CONFIG=00-baseline.cnf \
  $COMPOSE --profile nginx up -d --build wordpress-fpm nginx

echo "Waiting for Nginx to respond..."
until curl -sf "http://localhost:${WP_PORT}/" -o /dev/null 2>/dev/null; do
  printf '.'; sleep 2
done
echo ""
ok "Level 1 running"

echo "Waiting 10s for php-fpm-exporter to register metrics..."
sleep 10

run_snapshot "l1" 10

# =============================================================================
# PHASE 7 — Switch to Level 2 (FastCGI cache + MariaDB tuning)
# =============================================================================
step "Phase 7 — Switch to Level 2 (FastCGI page cache + MariaDB tuning)"

echo "Restarting with FastCGI cache config (obs stack keeps running)..."
NGINX_CONF=nginx-cache.conf PHP_INI=php-tuned.ini FPM_CONF=www.conf MARIADB_CONFIG=10-tuned.cnf \
  $COMPOSE --profile nginx up -d --build wordpress-fpm nginx

echo "Waiting for Nginx to respond..."
until curl -sf "http://localhost:${WP_PORT}/" -o /dev/null 2>/dev/null; do
  printf '.'; sleep 2
done
echo ""
ok "Level 2 running"

echo "Waiting 10s for FastCGI cache to initialise..."
sleep 10

# Extra warmup rounds (20 instead of 10) — FastCGI cache needs MISS passes
# before it starts serving HITs. 20 rounds × 3 URLs = 60 requests,
# enough to populate the cache for the 3 key URLs.
run_snapshot "l2" 20 5

# =============================================================================
# PHASE 8 — Regenerate slides
# ================================================================
CHROME_PATH="${CHROME_PATH:-/home/nedko/.cache/ms-playwright/chromium-1223/chrome-linux64/chrome}"
step "Phase 8 — Regenerate presentation slides"
echo "Generating HTML + PDF + PPTX from SLIDES-RICH.md..."
CHROME_PATH="$CHROME_PATH" make -C "$REPO_DIR" slides
ok "Slides regenerated → SLIDES-RICH.html / .pdf / .pptx / -editable.pptx"

# PHASE 9 — Summary
# =============================================================================
step "Phase 9 — Done! 🎉"

echo ""
echo -e "${BOLD}Screenshots saved:${RESET}"
ls -1 "$SCREENSHOTS_DIR"/l0-*.png "$SCREENSHOTS_DIR"/l1-*.png "$SCREENSHOTS_DIR"/l2-*.png 2>/dev/null \
  | sed "s|$REPO_DIR/||" | while read -r f; do echo "  $f"; done

echo ""
echo -e "${BOLD}Services still running:${RESET}"
echo "  WordPress (Level 2):  http://localhost:${WP_PORT}"
echo "  WordPress admin:      http://localhost:${WP_PORT}/wp-admin  (admin / admin123)"
echo "  Grafana:              ${GRAFANA}  (admin / grafana)"
echo "  Demo dashboard:       ${GRAFANA}/d/wp-demo"
echo ""
echo -e "${BOLD}To view all three levels on one timeline:${RESET}"
echo "  Open ${GRAFANA}/d/wp-demo and zoom to the last 30 minutes."
echo "  L0 crash → L1 saturation → L2 cache: all visible in one graph."
echo ""
ok "full-run.sh complete"
