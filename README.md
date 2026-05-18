# Stress Testing & Scaling WordPress on a $12 VPS

> **WordPress Europe 2026 — Kraków**  
> Speaker: Nedko Hristov, Senior DevOps Engineer @ Nemetschek Bulgaria  
> Talk: "From server crash to enterprise scale — a live-fire DevOps exercise"

Clone → `docker compose` → reproduce every number from the talk.

## Quick Start

```bash
# Start Level 0 (Apache crash baseline) + full observability stack
make level-0
make setup          # install WP + WooCommerce (first time only)
make bloat          # seed 2.5k posts + 5k revisions, 500 products + 1.5k revisions

# Open Grafana
open http://localhost:3000   # admin / grafana

# Run the Black Friday crash scenario
make load-crash

# Upgrade to Level 1 (Nginx + PHP-FPM + OPcache + Redis) — no restart needed
make level-1

# Run the same load — compare Grafana side-by-side
make load-crash
```

## Level Matrix

| Level | Stack | Target RPS on $12 VPS |
|---|---|---|
| 0 | Apache + mod_php (default) | ~30–50 RPS before 503 |
| 1 | Nginx + PHP-FPM + OPcache + Redis | ~200–400 RPS |
| 2 | Level 1 + FastCGI page cache + MariaDB tuning | ~2,000–5,000 RPS |
| 4 | Level 2 + hybrid static (Simply Static export) | ~50,000+ RPS (static limit) |

## Grafana Dashboards

| Dashboard | When to screenshot |
|---|---|
| 01 — Overview | During every level transition |
| 02 — PHP-FPM | Level 0 vs Level 1 worker saturation |
| 03 — MariaDB | Level 0 crash (threads_running spike) + Level 2 after tuning |
| 04 — Nginx Cache | Level 2: cache HIT/MISS donut |
| 05 — Redis | Level 1: object cache hit ratio climbing |
| 06 — k6 Live | During every `make load-*` run |

Open at: **http://localhost:3000** (admin/grafana)

## Architecture Diagrams

All diagrams in `diagrams/` are Excalidraw files. Open at https://excalidraw.com (File → Open).

> **Windows users:** drag-and-drop from Windows Explorer using the UNC path:
> `\\wsl.localhost\Ubuntu\home\nedko\repo\personal\WordPress-Europe-2026\diagrams`
>
> Drag-and-drop from VS Code's file explorer into the browser **does not work** — use Windows Explorer instead.

| File | Shows |
|---|---|
| `level-0-apache-baseline.excalidraw` | Level 0: Apache + mod_php crash mode |
| `level-1-nginx-fpm-redis.excalidraw` | Level 1: Nginx + FPM + OPcache + Redis |
| `level-2-fastcgi-cache.excalidraw` | Level 2: FastCGI page cache + DB tuning |
| `level-4-hybrid-static.excalidraw` | Level 4: Hybrid static architecture |
| `cache-hierarchy.excalidraw` | Full 6-layer cache pyramid |
| `cache-hierarchy-full.excalidraw` | Full stack — browser → CF → FastCGI → PHP → DB |
| `fpm-pool-math.excalidraw` | pm.max_children formula visualization |
| `apache-math.excalidraw` | Apache worker/thread math |
| `apache-prefork.excalidraw` | Apache prefork process model |
| `redis-intercept.excalidraw` | Redis: 246 HITs (0.1ms) vs 54 MySQL misses |
| `redis-flow.excalidraw` | Redis object cache flow |
| `fastcgi-intercept.excalidraw` | FastCGI: 70 HIT (8ms) vs 30 BYPASS (100ms) |
| `fpm-offload.excalidraw` | Time-series: Nginx total vs PHP-FPM gap |
| `static-concept.excalidraw` | Build-time + runtime model for Simply Static |
| `cloudflare-cdn.excalidraw` | 3 browsers → CF edge (80–85% HIT) → $12 VPS |
| `cloudflare-flow.excalidraw` | Cloudflare traffic flow |
| `observability-stack.excalidraw` | Prometheus + Grafana + Loki architecture |
| `simply-static-routing.excalidraw` | Simply Static routing concept |
| `full-picture.excalidraw` | L0→L4 journey — 5-column grand finale card layout |

## Load Test Scenarios

```bash
make load-smoke     # 10 VU × 1 min (sanity check)
make load-crash     # Black Friday ramp 0→500 VU (crash Level 0)
make load-spike     # Instant 500 VU spike
make load-soak      # 1h flat 50 VU (memory leak detection)
make load-woo       # WooCommerce browse-add-to-cart flow
```

## Screenshot Walkthrough

See **`SCREENSHOT_GUIDE.md`** for the step-by-step guide: when to run each command, which Grafana panel to look at, and what to capture for each presentation slide.

## Repository Structure

```
├── Makefile                    # make level-0 … level-4, make load-*, make obs-up
├── docker-compose.yml          # all profiles: apache, nginx, obs, load, static
├── app/
│   ├── Dockerfile.wp-apache    # Level 0
│   └── Dockerfile.wp-fpm       # Levels 1+
├── config/
│   ├── nginx/                  # nginx.conf (L1) + nginx-cache.conf (L2)
│   ├── php/                    # php-baseline.ini, php-tuned.ini, opcache.ini, www.conf
│   └── mariadb/                # 00-baseline.cnf, 10-tuned.cnf
├── observability/
│   ├── prometheus/             # prometheus.yml + alerting rules
│   ├── grafana/                # 6 pre-provisioned dashboards (JSON)
│   ├── loki/                   # log aggregation
│   └── promtail/               # log shipping
├── load/k6/                    # black-friday.js, spike.js, soak.js, browse-product-cart.js
├── scripts/
│   ├── wp-setup.sh             # idempotent WP + WooCommerce install
│   ├── wp-bloat.sh             # database bloat seeder
│   └── wp-perf-test.sh         # before/after snapshot writer
├── static/
│   ├── build.sh                # wget crawler → static export
│   └── nginx-static.conf       # serves the export (Level 4)
├── diagrams/                   # Excalidraw architecture diagrams
└── results/                    # committed sample runs + screenshots
```

## Reset

```bash
make reset   # destroys all volumes and rebuilds — fresh start
```
