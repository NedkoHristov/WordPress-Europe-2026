# Context — WordPress Europe 2026 Repo

> **Last updated:** 2026-05-15
> **Status:** ✅ Ready for presentation — `bash scripts/full-run.sh` regenerates everything end-to-end
> **Purpose:** Session continuity — paste this into any AI tool to resume work.

## Talk

- **Event:** WordPress Europe 2026, Kraków
- **Title:** "Stress Testing and Scaling WordPress on a $12 VPS"
- **Description:** "From server crash to enterprise scale — a live-fire DevOps exercise. We'll stress-test a WP stack on a $12 VPS, visualizing bottlenecks in Grafana before implementing a hybrid-static leap. GitHub repo included!"
- **Speaker:** Nedko Hristov, Senior DevOps Engineer @ Nemetschek Bulgaria
- **Format:** Live demo, ~50 min talk + 10 min Q&A

## Repo

- **GitHub:** https://github.com/NedkoHristov/WordPress-Europe-2026
- **Local path (WSL2):** `/home/nedko/repo/personal/WordPress-Europe-2026`
- **Branch:** `develop`
- **Reference repo (security talk):** https://github.com/NedkoHristov/WordPress-Security-or-keep-yourself-positive-dev-bg-webinar

## Architecture — The Levels

| Level | Stack | Make target |
|---|---|---|
| 0 | Apache + mod_php (crash baseline) | `make level-0` |
| 1 | Nginx + PHP-FPM + OPcache + Redis | `make level-1` |
| 2 | Level 1 + FastCGI page cache + MariaDB tuning | `make level-2` |
| 3 | Level 2 + Cloudflare CDN (edge cache via tunnel) | `make level-3` *(pending token)* |
| 4 | Level 2 + hybrid-static (Simply Static export) | `make level-4` |

## Docker Compose Profiles

| Profile | Services |
|---|---|
| `apache` | wordpress-apache (Level 0) |
| `nginx` | wordpress-fpm + nginx (Level 1+) |
| `obs` | prometheus, grafana, node-exporter, cadvisor, mysqld-exporter, redis-exporter, nginx-exporter, php-fpm-exporter, loki, promtail |
| `load` | k6 load generator |
| `static` | static-site nginx (Level 4) |

## Repo File Structure

```
docker-compose.yml                          # all profiles
Makefile                                    # make level-0..4, load-*, obs-up
README.md                                   # quick start + level matrix
SCREENSHOT_GUIDE.md                         # step-by-step screenshot walkthrough
context.md                                  # this file
package.json                                # npm — playwright dependency (screenshot automation)

app/
  Dockerfile.wp-apache                      # Level 0
  Dockerfile.wp-fpm                         # Levels 1+

config/
  nginx/nginx.conf                          # Level 1 (no cache)
  nginx/nginx-cache.conf                    # Level 2 (FastCGI cache)
  php/php-baseline.ini                      # Level 0 (OPcache OFF)
  php/php-tuned.ini                         # Level 1+
  php/opcache.ini                           # OPcache config
  php/www.conf                              # FPM pool (pm.max_children=20)
  mariadb/00-baseline.cnf                   # Level 0/1 (default)
  mariadb/10-tuned.cnf                      # Level 2 (512MB buffer pool, slow log)

observability/
  prometheus/prometheus.yml                 # scrape config for all exporters
  prometheus/rules.yml                      # alerting rules
  grafana/provisioning/datasources/         # Prometheus + Loki auto-provisioned
  grafana/provisioning/dashboards/
  grafana/dashboards/01-overview.json       # All-in-one: RPS, latency, CPU, RAM
  grafana/dashboards/02-php-fpm.json        # FPM workers, queue, OPcache
  grafana/dashboards/03-mysql.json          # Threads, buffer pool, slow queries
  grafana/dashboards/04-nginx-cache.json    # HIT/MISS/BYPASS donut + rate
  grafana/dashboards/05-redis.json          # Hit ratio, memory, evictions
  grafana/dashboards/06-k6-live.json        # VUs, RPS, p99, errors (fixed PromQL)
  loki/loki.yml
  promtail/promtail.yml

load/k6/
  level-compare.js                          # 50-VU ramp (3m30s) — main comparison script
  black-friday.js                           # 0→500 VU ramp (crash scenario)
  spike.js                                  # instant 500 VU
  soak.js                                   # 1h flat 50 VU
  browse-product-cart.js                    # WooCommerce journey
  browse.js                                 # simple smoke test
  lib/helpers.js                            # shared BASE_URL, checks, thresholds

scripts/
  wp-setup.sh                               # idempotent WP + WooCommerce install
  wp-bloat.sh                               # 2.5k posts + 5k revisions, 500 products + 1.5k revisions
  wp-perf-test.sh                           # before/after JSON snapshot
screenshot.js                             # Playwright: capture 6 Grafana dashboards (auto-rotates old screenshots)
  screenshot-watcher.sh                     # Polls Prometheus for k6_vus, fires screenshot.js at peak
  full-run.sh                               # End-to-end: reset → setup → bloat → all screenshots → slides

static/
  build.sh                                  # wget crawler → static export
  nginx-static.conf                         # serves Level 4 static export

diagrams/
  level-0-apache-baseline.excalidraw
  level-1-nginx-fpm-redis.excalidraw
  level-2-fastcgi-cache.excalidraw
  level-4-hybrid-static.excalidraw
  cache-hierarchy.excalidraw
  fpm-pool-math.excalidraw

screenshots/
  l0-00-demo.png .. l0-06-k6-live.png      # Level 0 Apache baseline (7 dashboards)
  l0-crash-00-demo.png .. l0-crash-06-k6-live.png  # Level 0 crash (Black Friday ramp)
  l1-00-demo.png .. l1-06-k6-live.png      # Level 1 Nginx+FPM+Redis (7 dashboards)
  l2-00-demo.png .. l2-06-k6-live.png      # Level 2 FastCGI cache (7 dashboards)
  screenshots-DDMMYY-NNN/                  # Auto-rotated backups from previous runs
```

## What Still Needs Doing

- [x] ~~`PRESENTATION_OUTLINE.md`~~ → `Plan.md` — lecture structure with screenshot placement
- [x] ~~`results/screenshots/.gitkeep`~~ — created
- [x] ~~Fix `make level-0` port conflict~~ — stops nginx profile before starting apache
- [x] ~~`.env.example`~~ — created
- [x] ~~Dashboard metric fixes~~ — PHP-FPM (4 fixes), Redis (3 fixes), Nginx (1 fix), k6 (3 fixes)
- [x] ~~`make slides`~~ — generates HTML + PDF + PPTX + editable PPTX
- [x] ~~`bash scripts/full-run.sh`~~ — fully autonomous end-to-end: reset → setup → bloat → L0/L0-crash/L1/L2 screenshots → slide regeneration
- [ ] Add `blackbox_exporter` service to `docker-compose.yml` (nice-to-have)
- [ ] Add `simply-static` plugin auto-activation to `scripts/wp-setup.sh` (nice-to-have)

## Cloudflare CDN — Level 3 (blocked on token)

- **Domain:** `nedko.net`, subdomain `wp.nedko.net`
- **Approach:** `cloudflared` container in a `cdn` Docker Compose profile dials out to CF Zero Trust tunnel
- **Traffic path:** `k6 → https://wp.nedko.net → CF edge → cloudflared container → nginx:80`
- **Cloudflare setup steps (one-time manual):**
  1. Zero Trust → Networks → Tunnels → Create tunnel `wp-stress-demo` → copy token
  2. Public Hostname: subdomain=`wp`, domain=`nedko.net`, type=HTTP, URL=`localhost:8080`
  3. Cache Rule: cache everything on `wp.nedko.net/*`, bypass on WP/WooCommerce cookies
  4. SSL/TLS → Edge Certs → disable "Always Use HTTPS" (avoids redirect loops)
- **Code to add once token is ready:**
  - `docker-compose.yml`: new `cloudflared` service under `cdn` profile
  - `Makefile`: `make level-3`, `make load-cdn`
  - Add `CLOUDFLARE_TUNNEL_TOKEN=` to `.env` / `.env.example`
- **Status:** Blocked — no tunnel token yet.

## Key URLs When Running

| Service | URL | Credentials |
|---|---|---|
| WordPress frontend | http://localhost:8080 | — |
| WordPress admin | http://localhost:8080/wp-admin | admin / admin123 |
| Grafana | http://localhost:3000 | admin / grafana |
| Prometheus | http://localhost:9090 | — |
| Static site (Level 4) | http://localhost:8090 | — |

## Grafana Dashboard UIDs

| Dashboard | UID | Direct URL |
|---|---|---|
| Overview | wp-overview | http://localhost:3000/d/wp-overview |
| PHP-FPM | wp-php-fpm | http://localhost:3000/d/wp-php-fpm |
| MariaDB | wp-mysql | http://localhost:3000/d/wp-mysql |
| Nginx Cache | wp-nginx-cache | http://localhost:3000/d/wp-nginx-cache |
| Redis | wp-redis | http://localhost:3000/d/wp-redis |
| k6 Live | wp-k6-live | http://localhost:3000/d/wp-k6-live |

## Key Design Decisions

1. **No terminal confirmation prompts** — all commands use `| cat` or are non-interactive
2. **Excalidraw diagrams** as `.excalidraw` JSON files — open at excalidraw.com
3. **Makefile as the single interface** — audience can follow along with `make level-N`
4. **k6 → Prometheus remote-write** — real-time load metrics in Grafana during live demos
5. **All profiles independent** — `obs` profile works with both `apache` and `nginx`

## Demo Data Status

- ✅ WordPress 6.8 installed with WooCommerce, Yoast SEO, Redis Object Cache
- ✅ Database seeded: ~9K rows (2,500 posts + 5k revisions), 500 products + 1.5k revisions
- ✅ All 6 Grafana dashboards provisioned and auto-loaded
- ✅ Full observability stack healthy: Prometheus, Grafana, Loki, 8 exporters

## Load Test Results

### level-compare.js — 50 VU ramp (3m30s), 2.5k posts DB

| Level | RPS | P95 Latency | Error Rate | Notes |
|---|---|---|---|---|
| **L0** Apache+mod_php | 13.3 req/s | 2381 ms | 0% (threshold hit) | Slow but doesn't crash on localhost |
| **L1** Nginx+FPM+Redis | 3.1 req/s | 10,760 ms | 87.7% | PHP-FPM saturates, timeouts cascade |
| **L2** +FastCGI+MariaDB tuning | 23.0 req/s | 67 ms | 0% | 160× latency drop vs L1 |

**Talk narrative:** L1 is the "before" — looks modern but collapses under load. L2 is the cache fix — same stack, 160× faster. L0 shows Apache's raw baseline for context.

## All Screenshots

| Prefix | Level | Dashboards | Status |
|---|---|---|---|
| `l0-*.png` | Apache baseline | 7 (00-demo through 06-k6-live) | ✅ auto-generated by full-run.sh |
| `l0-crash-*.png` | Apache crash (0→500 VU) | 7 | ✅ auto-generated by full-run.sh |
| `l1-*.png` | Nginx+FPM+Redis | 7 | ✅ auto-generated by full-run.sh |
| `l2-*.png` | +FastCGI cache+MariaDB tuning | 7 | ✅ auto-generated by full-run.sh |
| `l3-*.png` | +Cloudflare CDN | — | ⏸ not live-demoed |
| `l4-*.png` | +Hybrid static | — | ⏸ not live-demoed |

## Screenshot Automation

**Script:** `scripts/screenshot.js` (Playwright)
**Usage:** `node scripts/screenshot.js <prefix> <from_epoch_ms> <to_epoch_ms>`
**Example:** `node scripts/screenshot.js l2 1778678880000 1778679240000`

- Logs into Grafana (admin/grafana), captures 6 dashboards in order
- Order: k6-live → overview → php-fpm → mysql → nginx-cache → redis
- Saved as: `screenshots/<prefix>-01-overview.png` … `<prefix>-06-k6-live.png`
- Requires `playwright` npm package (installed — `node_modules/` present at repo root)
- Chromium cached at `~/.cache/ms-playwright/chromium-1223/`
- Pattern: `waitUntil: 'domcontentloaded'` + 7s wait (not `'load'` — Grafana aborts queries on nav)
- Do NOT use `kiosk=1` — causes narrow panel stacking at 1920px

## Presentation Outputs

| File | Format | Size | Notes |
|---|---|---|---|
| `SLIDES-RICH.html` | HTML | ~240K | Open in browser, arrow keys to navigate, F for fullscreen |
| `SLIDES-RICH.pdf` | PDF | ~9 MB | Images embedded, print-ready |
| `SLIDES-RICH.pptx` | PPTX | ~9 MB | Pixel-perfect but slides are images |
| `SLIDES-RICH-editable.pptx` | PPTX | ~1.2 MB | Text editable, some styling lost (LibreOffice) |

**Generate all:** `make slides`
**Single command for everything:** `bash scripts/full-run.sh`


## Known Bugs & Workarounds

### make level-0 — port conflict (UNRESOLVED)

`make level-0` runs `docker compose --profile apache down` but does NOT stop the `nginx` profile.
If nginx is up, port 8080 is already allocated → Apache container starts but port binding silently
fails (`NetworkSettings.Ports` is empty even though `HostConfig.PortBindings` is set).

**Workaround:** `docker compose --profile nginx down && make level-0`

**Fix needed in Makefile:**
```makefile
level-0:
	$(COMPOSE) --profile nginx down 2>/dev/null || true   # ADD THIS LINE
	$(COMPOSE) --profile apache --profile obs up -d --build
```

### Prometheus "out of order sample" after stack restart

If `prometheus_data` volume has data from a previous run and you restart with a new test, k6
metrics get 400 errors ("out of order sample"). Fix: clear the volume before re-running.

```bash
docker compose --profile apache --profile obs down
docker volume rm wordpress-europe-2026_prometheus_data
docker compose --profile apache --profile obs up -d
```

### k6 Prometheus remote-write — native histograms disabled

`K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM` must be `"false"`. Prometheus v2.52.0 has
`--enable-feature=native-histograms` in its command but the remote-write receiver rejects them
with 400. k6 sends pre-calculated percentiles instead: `k6_http_req_duration_p99`,
`k6_http_req_failed_rate`, etc.

### k6 BASE_URL — canonical redirect loop

k6 must use `http://host.docker.internal:8080` (NOT `http://nginx:80`). WordPress siteurl is
`http://localhost:8080`. When `Host: nginx` arrives, WP issues a 301 to `http://nginx:8080/`
→ k6 follows → connection refused.

Requires `extra_hosts: ["host.docker.internal:host-gateway"]` in the k6 service
(WSL2/Linux does not define this automatically).

### WSL2 Docker port binding after nginx→apache switch

After stopping nginx and starting apache, the Apache container may start without port binding
(`docker port` returns empty). Force-recreate fixes it:

```bash
docker compose --profile apache --profile obs up -d --force-recreate wordpress-apache
```

## Modified Files (from original repo)

| File | Change |
|---|---|
| `load/k6/level-compare.js` | BASE_URL → `host.docker.internal:8080`; PAGES fixed (no short-links); no optional chaining (`?.`) |
| `docker-compose.yml` | k6: `extra_hosts` + `K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM: "false"`; Prometheus: ports, flags |
| `Makefile` | Added `load-compare` target |
| `observability/grafana/dashboards/06-k6-live.json` | All PromQL updated from `_bucket` histogram_quantile to pre-calculated percentiles |
| `scripts/screenshot.js` | NEW — Playwright screenshot automation |
| `package.json` | NEW — `npm init -y` + `playwright` dependency |
