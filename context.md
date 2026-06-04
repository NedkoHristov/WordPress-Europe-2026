# Context — WordPress Europe 2026 Repo

> **Last updated:** 2026-06-03
> **Status:** ✅ All slides corrected, fonts reduced, new screenshot cycle complete, HTML regenerated
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

diagrams/                         # 19 .excalidraw + 19 .png (all normalized + exported)
  level-0-apache-baseline.excalidraw   # L0: Apache prefork crash architecture
  level-1-nginx-fpm-redis.excalidraw   # L1: Nginx + FPM + OPcache + Redis
  level-2-fastcgi-cache.excalidraw     # L2: FastCGI page cache + MariaDB tuning
  level-4-hybrid-static.excalidraw     # L4: hybrid static concept (WP + Simply Static)
  cache-hierarchy.excalidraw           # Original cache pyramid (6 layers)
  cache-hierarchy-full.excalidraw      # Full stack cache hierarchy used on slide
  fpm-pool-math.excalidraw             # pm.max_children formula visualization
  apache-math.excalidraw               # Apache worker/thread math
  apache-prefork.excalidraw            # Apache prefork process model
  redis-intercept.excalidraw           # Redis: 246 HITs 0.1ms vs 54 MySQL misses
  redis-flow.excalidraw                # Redis flow diagram
  fastcgi-intercept.excalidraw         # FastCGI: 70 HIT 8ms vs 30 BYPASS 100ms
  fpm-offload.excalidraw               # Time-series: Nginx total vs PHP-FPM gap (70% cached)
  static-concept.excalidraw            # Build-time vs runtime for Simply Static
  cloudflare-cdn.excalidraw            # 3 browsers → CF edge (80-85% HIT) → $12 VPS
  cloudflare-flow.excalidraw           # Cloudflare traffic flow diagram
  observability-stack.excalidraw       # Prometheus + Grafana + Loki stack
  simply-static-routing.excalidraw     # Simply Static routing concept
  full-picture.excalidraw              # 5-column card layout L0→L4 grand finale (171 KB PNG)

  # NOTE (Windows users): drag-and-drop to excalidraw.com only works from Windows Explorer
  # Use UNC path: \\wsl.localhost\Ubuntu\home\nedko\repo\personal\WordPress-Europe-2026\diagrams

screenshots/
  l0-00-demo.png .. l0-06-k6-live.png      # Level 0 Apache baseline (7 dashboards)
  l0-crash-00-demo.png .. l0-crash-06-k6-live.png  # Level 0 crash (Black Friday ramp)
  l1-00-demo.png .. l1-06-k6-live.png      # Level 1 Nginx+FPM+Redis (7 dashboards)
  l2-00-demo.png .. l2-06-k6-live.png      # Level 2 FastCGI cache (7 dashboards)
  screenshots-DDMMYY-NNN/                  # Auto-rotated backups from previous runs
```

## Slide State (as of 2026-06-03)

- All hardcoded run-specific numbers replaced with approximate ranges (~)
- HTML font reduced further: base CSS 26px → 20px, dense h2 1.6em → 1.15em, sed 20.8px → 16px override
- **"The two load test scripts"** slide added — explains `snapshot.js` (50 VU, 90s) vs `black-friday.js` (0→500 VU, 14 min) and why 500 VU is not used for comparison
- **Apache terminology** fixed throughout Level 0 slides: PHP-FPM references removed, replaced with Apache prefork / mod_php language
- HTML font reduced 20% (sed post-processing: 26px → 20.8px)
- `<!-- _class: dense -->` + 4-col table on: "Level 1 — reading the dashboard", "Level 2 — reading the dashboard", "Cloudflare Free Plan — what you get"
- All `see screenshot` values replaced with real approximates everywhere
- `scripts/export-diagrams.js` — natural bounding box (no hardcoded 1200×700 clip)
- `scripts/normalize-diagrams.js` — adds all excalidraw.com-required fields before export
- `scripts/screenshot.js` — rotation scoped to current PREFIX
- `make diagrams` runs normalize → export automatically
- **Diagram PNGs live in slides:** cloudflare-cdn, cache-hierarchy-full, full-picture
- **"What is a Virtual User?"** slide rewritten — removed ❌ list, 3-loop code block + real-world equivalence table
- **"Lessons learned"** split into 3 slides (1/3: measure+cache layers, 2/3: FPM math+DB, 3/3: numbers table)
- **"Lessons learned 3/3"** has the speed improvement table (37×/200×/750×)
- **"What you'll leave with"** slide added before lessons learned (5 cards: crash → 37× → DB−75% → 200× → 750×)
- **"The full picture"** slide uses full-picture.png (5-column fancy card layout, 171 KB)
- **"The full cache hierarchy"** slide uses cache-hierarchy-full.png
- **"Level 3 — Cloudflare CDN"** slide uses cloudflare-cdn.png

## What Still Needs Doing

- [x] ~~`PRESENTATION_OUTLINE.md`~~ → `Plan.md` — lecture structure with screenshot placement
- [x] ~~`results/screenshots/.gitkeep`~~ — created
- [x] ~~Fix `make level-0` port conflict~~ — stops nginx profile before starting apache
- [x] ~~`.env.example`~~ — created
- [x] ~~Dashboard metric fixes~~ — PHP-FPM (4 fixes), Redis (3 fixes), Nginx (1 fix), k6 (3 fixes)
- [x] ~~`make slides`~~ — generates HTML + PDF + PPTX + editable PPTX
- [x] ~~`bash scripts/full-run.sh`~~ — fully autonomous end-to-end
- [x] ~~Zone.Identifier files~~ — deleted (9 files), `*:Zone.Identifier` added to `.gitignore`
- [x] ~~All diagram PNGs~~ — 19 excalidraw → 19 PNG, all normalized and exported
- [x] ~~Slides: "Level 1 — what Redis is actually doing"~~ → `![w:900](diagrams/redis-intercept.png)` added
- [x] ~~Slides: "Level 2 — the FPM offload panel explained"~~ → `![w:900](diagrams/fpm-offload.png)` added
- [x] ~~Slides: "Level 4 — the concept"~~ → `![w:900](diagrams/static-concept.png)` added
- [x] ~~Screenshot Grafana time window~~ — fixed: `--window 90` added to `run_snapshot` in `full-run.sh` and all 3 Makefile snapshot targets
- [x] ~~Screenshot re-run~~ — all 28 PNGs regenerated 2026-06-03 with clean 90s windows
- [x] ~~Font sizes~~ — base CSS 26→20px, sed 20.8→16px; dense section padding/h2 reduced
- [x] ~~"The two load test scripts" slide~~ — added with 50 VU vs 500 VU explanation
- [x] ~~Apache terminology in Level 0 slides~~ — PHP-FPM references removed
- [ ] Add `blackbox_exporter` to `docker-compose.yml` (nice-to-have)
- [ ] Add `simply-static` plugin auto-activation to `scripts/wp-setup.sh` (nice-to-have)
- [ ] Level 3 Cloudflare live demo — blocked on `CLOUDFLARE_TUNNEL_TOKEN`

## Slide Fixes Done (2026-06-02)

- All 8 screenshot-grounded number fixes applied (Changes 1–8 from June 2 analysis)
- All 3 diagram insertions applied (redis-intercept, fpm-offload, static-concept)
- Discovered "~140 req/s" and "24.5 req/s at 500 VU" were not grounded in screenshots
  - Watcher fires at 107 VU; crash peak happens off-screen past ~200 VU
  - Fixed in: "Level 0 — reading the crash", "The journey", "L0→L1 jump", "L0→L1→L2 progression" tables
- Added "Screenshot Re-Analysis — L0 Crash Numbers" section at bottom of context.md

## Cleanup Done (2026-05-18)

- Deleted 9 `*:Zone.Identifier` files from `diagrams/` (Windows NTFS ADS, ZoneId=3 from excalidraw.com)
- Added `*:Zone.Identifier` to `.gitignore`
- README.md: added UNC path note for Windows drag-and-drop to excalidraw.com
- README.md: updated diagrams table to reflect all 19 current diagrams

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

---

## Screenshot vs Slides Cross-Analysis — June 2, 2026 Run

> **Updated:** 2026-06-02
> **Run:** `bash scripts/full-run.sh` — clean slate, all phases completed
> **Screenshots directory:** `screenshots/` — 28 PNGs (l0×7, l0-crash×7, l1×7, l2×7)

---

### Screenshot Inventory — Actual Numbers Extracted

#### l0-00-demo.png — Level 0 Baseline (50 VU snapshot, captured at ramp peak)
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Virtual Users | **50** | ✓ matches slide |
| Requests/sec | **28.0 req/s** | Captured mid-ramp before VUs fully stabilise |
| p95 Latency | **812 ms** | Mid-ramp value; latency chart shows 3 s at 50 VU |
| CPU % | **61.5%** | |
| PHP-FPM Active Workers | **No data** | ✓ correct — this is Apache, no FPM |
| MariaDB Threads | spike to **~30+** visible in chart | Slide says "20 (max)" → wrong |

#### l0-crash-00-demo.png — Level 0 Black Friday ramp (watcher fires at 100 VU)
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Virtual Users | **107** | Watcher target=100, fires when ramp crosses it |
| Requests/sec | **38.4 req/s** | Still serving; collapse accelerates past this |
| p95 Latency | **1.03 s** | Stat box; latency chart shows **3–4 s** bands throughout |
| CPU % | **94.5%** | |
| PHP-FPM | **No data** | ✓ Apache |
| MariaDB Threads | spike to **~30+** visible in chart | Slide says "20 (max)" |
| Redis Hit Rate | **visible ~80%** | Redis is warmed from setup; chart shows climb |

#### l1-00-demo.png — ⚠️ TIME WINDOW PROBLEM (see below)
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Virtual Users | **500** | **WRONG** — this is L0 crash data still in 5-min window |
| Requests/sec | **50.8 req/s** | Partially reflects L1 start at tail of window |
| p95 Latency | **6.50 s** | **WRONG** — inherited from crash window |
| CPU % | **27.8%** | Correct (already at L1) |
| PHP-FPM Active Workers | **3** | Real L1 data at tail of window |
| MariaDB Threads | ~125 peak → drop to 0 | Chart shows crash era then L1 cleanup |

#### l1-02-php-fpm.png — Level 1 PHP-FPM (same window issue, but mostly useful)
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Active Workers | **3** | Correct for L1 early stage |
| Idle Workers | **8** | |
| Queue Depth | **0** | ✓ crash eliminated |
| Requests/sec | **50.4 req/s** | Tail of L1 start |
| Peak active (chart) | **~8 workers** | Visible in Workers chart; well under max_children=20 |

#### l1-05-redis.png — Level 1 Redis (same window issue, but stats are real)
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Cache Hit Ratio | **97.0%** | Slide claims "~80%"; actual is higher because crash run pre-warmed cache |
| Used Memory | **23.1 MB** | Slide claims "14.5 MB" |
| Total Keys | **43.4 K** | Slide claims "~46K" — close |
| Commands/sec | **2.57 K ops/s** | Slide claims "~6,000" — much lower at capture |
| Evictions | **0** | ✓ |

#### l2-00-demo.png — ⚠️ TIME WINDOW PROBLEM (see below)
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Virtual Users | **275** | **WRONG** — crash era data still in window |
| Requests/sec | **52.2 req/s** | Partially reflects L2 start |
| p95 Latency | **6.50 s** | **WRONG** — inherited from crash window |
| CPU % | **19.5%** | Correct for L2 |
| PHP-FPM Active Workers | **1** | Correct — very low at L2 (cache serving) |
| MariaDB Threads (chart) | drop to **~0–3** at 19:08+ | Actual L2 DB thread behaviour ✓ |
| Requests chart (chart) | **gap visible at 19:08+** | FPM vs Nginx gap appears — cache in action ✓ |

#### l2-02-php-fpm.png — Level 2 PHP-FPM
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Active Workers | **1** | End-of-run state |
| Peak active (chart) | **~10–12** | During L2 snapshot run at 19:08–19:09 |
| Queue Depth | **0** | ✓ |
| Peak FPM req/s (chart) | **~65–70 req/s** | Visible in Request Rate chart |
| Max Queue Reached | **0** | ✓ clean |

#### l2-04-nginx-cache.png — Level 2 Nginx + FastCGI Cache ✅ BEST SCREENSHOT
| Metric | Screenshot stat box | Notes |
|---|---|---|
| Active Connections | **51** | |
| Requests/sec | **52.3 req/s** | At capture time |
| Total Requests (5 min) | **6.59 K** | |
| FPM Offload chart | Total Nginx peak **~65 req/s**, FPM peak **~15–20 req/s** | Offload = ~70–75% ✓ matches slide claim |
| FPM Offload % | **~70–75%** | Calculated from chart: (65−15)/65 |

---

### Root Cause: Screenshot Time Window Contamination

The `screenshot-watcher.sh` fires `screenshot.js` when `k6_vus >= 45` (target VU). However, Grafana's time window in the screenshot is **5 minutes back from now**. This creates a systematic problem:

1. L0 Black Friday crash runs for ~14 minutes, ending at ~18:57
2. L1 snapshot starts. The watcher fires when VUs reach 45 (early in the L1 run, ~19:03)
3. Grafana window at that moment: 18:58–19:03 → still shows crash data!
4. Stat boxes show CURRENT values (transitional) but CHARTS show crash-era data
5. Same issue propagates to L2 (window 19:05–19:10 still includes crash tail)

**Effect on screenshots:**
- `l1-00-demo.png`: headline stats show 500 VU / 6.50s p95 (crash data) — misleading
- `l2-00-demo.png`: same problem — 275 VU / 6.50s p95 — misleading

**Fix applied (2026-06-03):** Option 2 implemented — `--window 90` passed to `screenshot-watcher.sh` from both `full-run.sh` (`run_snapshot` function) and all 3 Makefile snapshot targets (`snapshot`, `snapshot-l1`, `snapshot-l2`). Screenshots regenerated clean.

---

### Specific Text Changes Required in SLIDES-RICH.md

#### CHANGE 1 — "Level 0 — reading the crash" table
**Slide location:** search for `## Level 0 — reading the crash`

| Row to change | Current text | Replace with | Reason |
|---|---|---|---|
| MariaDB Threads Running | `**20** (max)` | `**30+**` | Chart clearly shows 30+ spike |

No other changes needed in this table — the chart-level descriptions (p95 ~3–6s, req/s collapse) are still correct as visual narrative.

---

#### CHANGE 2 — "The journey" comparison table
**Slide location:** search for `## The journey`

| Column | Current value | New value | Source |
|---|---|---|---|
| L1 p95 | `**~100–150 ms**` | `**~100–130 ms**` | Approximation, unverifiable from polluted screenshot; keep conservative |
| L1 req/s | `**~60–70**` | `**~50–60**` | l1-02-php-fpm shows 50.4 req/s at start; actual peak probably ~55–60 |
| L2 req/s | `**~65–75**` | `**~65–70**` | l2-04-nginx-cache shows peak ~65 req/s |

---

#### CHANGE 3 — "Level 1 — reading the dashboard" table
**Slide location:** search for `## Level 1 — reading the dashboard`

| Panel row | Current text | Replace with | Source |
|---|---|---|---|
| Requests/s Peak | `**~65 req/s**` | `**~50–55 req/s**` | l1-02-php-fpm: 50.4 req/s |
| FPM Workers Peak active | `~12 / 20` | `~8 / 20` | l1-02-php-fpm chart: peak ~8 workers |
| MariaDB Peak threads | `**~12 threads**` | `**~15–20 threads**` | l1-00-demo chart tail shows ~15 before drop |
| Redis Hit rate | `**0% → ~80%**` | `**~80% → ~97%**` | l1-05-redis: 97.0% at capture; warmed from prior crash run |
| Redis Keys / memory | `~46K keys · 14.5 MB` | `~43K keys · 23 MB` | l1-05-redis: 43.4K / 23.1MB |
| Redis ops/s | `~6,000` | `~2,500` | l1-05-redis: 2.57K ops/s |

---

#### CHANGE 4 — "L0 → L1: the jump" table
**Slide location:** search for `## L0 → L1: the jump`

| Row | Current | Replace with | Source |
|---|---|---|---|
| Peak requests/s | L1 = `**~65 req/s**` | `**~50–55 req/s**` | l1-02-php-fpm |
| DB Threads peak | L1 = `**~12**` | `**~15–20**` | l1-00-demo chart |
| Redis hit ratio | L1 = `**~80%**` | `**~80–97%**` | l1-05-redis |

---

#### CHANGE 5 — "Level 1 — Redis: 82% Hit Rate" slide headline
**Slide location:** search for `## 📸 Level 1 — Redis: 82% Hit Rate`

Current: `## 📸 Level 1 — Redis: 82% Hit Rate, 6K ops/s`
Replace with: `## 📸 Level 1 — Redis: 97% Hit Rate, ~2.5K ops/s`

Also the body paragraph just before/after the screenshot:
Current: `**46,000 cached keys · 14.5 MB · 6,000 ops/s at peak**`
Replace with: `**~43,000 cached keys · 23 MB · ~2,500 ops/s at peak**`

---

#### CHANGE 6 — "Level 2 — reading the dashboard" table
**Slide location:** search for `## Level 2 — reading the dashboard`

| Panel row | Current text | Replace with | Source |
|---|---|---|---|
| Requests/s | `**~70–75 req/s**` | `**~65 req/s**` | l2-04-nginx-cache chart peak |
| FPM Workers Peak | `**~11 / 20**` | `**~10–12 / 20**` | l2-02-php-fpm chart |
| MariaDB Peak threads | `**~3**` | `**~0–3**` | l2-00-demo chart shows drop to ~0 |
| FastCGI Cache Offload | `**~70%**` | `**~70–75%**` | l2-04-nginx-cache FPM offload chart |

---

#### CHANGE 7 — "L0 → L1 → L2: the progression" table
**Slide location:** search for `## L0 → L1 → L2: the progression`

| Row | L1 current | L1 new | L2 current | L2 new | Source |
|---|---|---|---|---|---|
| Peak requests/s | `~65 req/s` | `~50–55 req/s` | `**~70–75 req/s**` | `**~65 req/s**` | Screenshots |
| DB Threads peak | `~10–15` | `~15–20` | `**~3**` | `**~0–3**` | Charts |
| Redis hit ratio | `~80%+` | `~80–97%` | `**~80%+**` | `**~80–97%**` | l1-05-redis, l2 redis |

---

#### CHANGE 8 — "Level 1 vs Level 2 — the real numbers" table
**Slide location:** search for `## Level 1 vs Level 2 — the real numbers`

| Row | L1 current | L1 new | L2 current | L2 new | Source |
|---|---|---|---|---|---|
| Peak requests/s @ 50 VU | `~65 req/s` | `~50–55 req/s` | `**~70–75 req/s**` | `**~65 req/s**` | Screenshots |
| FPM workers peak | `~12 / 20` | `~8 / 20` | `**~11 / 20**` | `**~10–12 / 20**` | FPM screenshots |
| MariaDB threads peak | `~12–15` | `~15–20` | `**~3**` | `**~0–3**` | Charts |
| Requests in 5 min | L1=`~19,500` | L1=`~15,000` | L2=`**~21,500**` | L2=`**~19,500**` | ~50 req/s × 300s = 15K; ~65 × 300s = 19.5K |

---

### Screenshot Quality Assessment

| Screenshot | Usable for slides? | Issue | Recommendation |
|---|---|---|---|
| `l0-00-demo.png` | ✅ Yes | Stat box shows mid-ramp (28 req/s, 812ms), not peak. Charts show the spike. | Accept — charts tell the story |
| `l0-crash-00-demo.png` | ✅ Yes | Captured at 107 VU not 500 VU. Chart window shows full crash arc. | Accept — "the collapse is visible" |
| `l1-00-demo.png` | ✅ Fixed | Regenerated 2026-06-03 with 90s window — stat boxes now show L1 data only | Time window contamination resolved |
| `l1-02-php-fpm.png` | ✅ Yes | Shows 8 active workers, queue=0. Clean L1 FPM story. | Accept |
| `l1-05-redis.png` | ✅ Yes | 97% hit rate — actually better story than claimed 80%. | Update slide headline (Change 5) |
| `l2-00-demo.png` | ✅ Fixed | Regenerated 2026-06-03 with 90s window — stat boxes now show L2 data only | Time window contamination resolved |
| `l2-02-php-fpm.png` | ✅ Yes | Clear FPM offload in chart. Stat box low (end of run). | Accept — chart shows peak |
| `l2-04-nginx-cache.png` | ✅ Best screenshot | FPM offload graph perfectly shows the cache gap. | Accept as-is — this is the "money slide" |

---

### Summary: Priority Order for Slide Text Fixes

1. **HIGH** — Change 5: Update Redis slide headline "82% → 97%, 6K → 2.5K ops/s"
2. **HIGH** — Change 3: Level 1 reading table — req/s (65→50-55), workers (12→8), Redis numbers
3. **HIGH** — Change 6: Level 2 reading table — req/s (70-75→65), threads (3→0-3)
4. **MEDIUM** — Changes 4, 7, 8: Consistency tables (journey, L0→L1→L2, L1vsL2)
5. **LOW** — Change 1: DB threads "20 max" → "30+"
6. **LOW** — Change 2: The journey table — minor req/s range adjustments

> All ~ approximations in the slides are intentional for resilience across runs.
> The screenshots primarily serve as VISUAL confirmation — the text narrative is the authoritative claim.
> Fix text first; re-run screenshots only if l1-00-demo / l2-00-demo window issue is resolved.


## Session Changes (2026-06-03)

- **Screenshot time window contamination fixed** — `--window 90` added to `run_snapshot` in `full-run.sh` and all 3 Makefile snapshot targets
- **All 28 screenshots regenerated** — `l0-` (23:56), `l0-crash-` (00:03), `l1-` (00:13), `l2-` (00:15) — all clean 90s windows
- **HTML regenerated** — `SLIDES-RICH.html` at 00:16, 16px font override present
- **Font sizes reduced** — CSS base 26→20px; dense section h2 1.6em→1.15em, padding 28px 48px→20px 40px; sed 20.8→16px
- **"The two load test scripts" slide added** — between "Key metric definitions" and "Observability stack"; explains 50 VU vs 500 VU choice with code blocks and blockquote
- **Apache terminology fixed in Level 0 slides** — removed all PHP-FPM references; "FPM queue depth" rows renamed to "Request backlog / Request queue"; stat box warning note updated
- **SLIDES-RICH.md modified lines:** ~1060+ lines; CSS block, 5 table rows, 2 blockquotes, 1 new slide inserted
- **Known bug resolved:** `make level-0` port conflict fix confirmed in Makefile

## Screenshot Re-Analysis — L0 Crash Numbers (2026-06-02)

> **Key finding:** The "~140 req/s → collapse" and "24.5 req/s at 500 VU" figures in the slides
> are NOT visible in the screenshots. Here's why:

### Root Cause
- `screenshot-watcher.sh` was configured with `--target-vu 100`, so it fires at **107 VUs**
- That is ~5 minutes into a 14-minute ramp to 500 VUs
- At 107 VUs Apache is **still serving** — peak-then-collapse happens later (~200+ VUs)
- The "140" was from a prior manual observation, not grounded in current screenshots

### What the screenshots actually show

| Screenshot | req/s | VUs | Notes |
|---|---|---|---|
| `l0-00-demo.png` | ~28 req/s | 50 | Y-axis top = 30; steady baseline |
| `l0-crash-00-demo.png` | 38.4 req/s | 107 | Y-axis top = 40; still climbing, not yet collapsed |
| `l0-crash-06-k6-live.png` | ~40–43 req/s | ~107 | Peak in this window; collapse happens after screenshot |

### Two slide claims that are unverifiable from screenshots
1. `~140 → collapse` — peak never visible (screenshot captured before peak)
2. `req/s at 500 VU | 24.5` — screenshot only reaches 107 VU

### Fix applied (2026-06-02)
- "Level 0 — reading the crash" table: replaced unverifiable rows with what IS visible
- "The journey" table: L0 req/s changed from `~140 → collapse` to `~40+ → collapse`
- "L0 → L1: the jump" table: same fix
- "L0 → L1 → L2: the progression" table: same fix
- Narrative updated to explain the watcher fires early — collapse happens off-screen
