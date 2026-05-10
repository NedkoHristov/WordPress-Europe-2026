# Screenshot & Demo Execution Guide
## WordPress Europe 2026 — Stress Testing & Scaling on a $12 VPS

> **This is your presentation run-book.**
> Follow it top to bottom. Every screenshot slot has: command to run, Grafana URL, panel to capture, what to look for, and the slide it feeds.

---

## Pre-Flight (15 min before talk)

```bash
cd ~/repo/WordPress-Europe-2026

# 1. Start everything (Level 0 baseline + obs)
make level-0

# 2. Install WordPress (first time — skip if done before)
make setup

# 3. Seed the bloat (skip if done before — takes 5 min)
make bloat

# 4. Verify
docker compose --profile apache --profile obs ps | cat
```

**Pre-open browser tabs (in this order):**
1. http://localhost:8080 — WP frontend
2. http://localhost:8080/wp-admin — WP admin (admin/admin123)
3. http://localhost:3000/d/wp-overview — Grafana Overview
4. http://localhost:3000/d/wp-k6-live — k6 Live
5. http://localhost:3000/d/wp-mysql — MariaDB
6. http://localhost:3000/d/wp-php-fpm — PHP-FPM
7. http://localhost:3000/d/wp-nginx-cache — Nginx Cache
8. http://localhost:3000/d/wp-redis — Redis

---

## ACT I — The Crash (Level 0)

### DEMO 1.1 — Baseline smoke test

**Run:**
```bash
make load-smoke
```

**Watch:** Grafana tab 3 (Overview) → note current p95 latency and RPS  
**Screenshot:** `results/screenshots/act1-level0-smoke-overview.png`  
- Stat row: RPS, p95 latency, CPU, RAM, Load Average  
- Time series: Request Rate — flat, healthy  
**Slide:** "This is what normal looks like"

---

### DEMO 1.2 — The Black Friday Crash

**Run (leave running, switch to Grafana):**
```bash
make load-crash
```

**Watch sequence (switch tabs as each event happens):**

| Time | Event | Grafana Tab | What to capture |
|---|---|---|---|
| ~1 min (10 VU) | All green | Overview | Baseline screenshot — green stats |
| ~3 min (50 VU) | First yellows | Overview | CPU climbing, load average > 2 |
| ~4 min (80–100 VU) | PHP-FPM saturated | PHP-FPM (tab 6) | Active Workers = 20, Queue Depth > 0 — **SCREENSHOT** |
| ~4:30 min | MySQL overwhelmed | MariaDB (tab 5) | Threads Running spike — **SCREENSHOT** |
| ~5 min (100–150 VU) | Stack crashes | Overview | Load > 10, RAM near zero, 503 errors — **SCREENSHOT** |
| ~5:30 min | k6 error rate > 50% | k6 Live (tab 4) | Error Rate stat red, p99 latency vertical — **SCREENSHOT** |

**Critical screenshots for slides:**
1. **`act1-crash-overview.png`** — Overview dashboard: CPU 100%, Load > 10, RAM near 0 — the "money shot"
2. **`act1-crash-fpm-queue.png`** — PHP-FPM: Active=20, Queue > 5 — "pm.max_children hit"
3. **`act1-crash-mysql-threads.png`** — MariaDB: Threads Running spike → "DB is the bottleneck"
4. **`act1-crash-k6-rps.png`** — k6 Live: VUs climbing but RPS plateauing → "saturation point"

**Talking point:** "Apache prefork × mod_php = N full PHP processes in RAM. With 2GB, you get ~50 slots. Beyond that: queue, timeout, crash."

---

## ACT II — Stop the Bleeding (Level 1)

### Transition

```bash
# While load is still running (or restart it after)
make level-1

# Wait ~10s for nginx + FPM to be ready, then rerun
make load-crash
```

**What changes in Grafana instantly:**
- CPU drops (event-driven Nginx vs Apache prefork)
- PHP-FPM dashboard appears (it's new — was not available on Apache)
- Redis dashboard shows activity

### Screenshots

| Grafana Tab | What to capture | Filename |
|---|---|---|
| PHP-FPM (tab 6) | Workers graph: Active stays < 15 even at 200 VU | `act2-level1-fpm-workers.png` |
| Redis (tab 8) | Hit ratio climbing to 70%+ | `act2-level1-redis-hits.png` |
| Overview | Same load, lower CPU/RAM | `act2-level1-overview-comparison.png` |
| k6 Live | p95 < 500ms vs crash before | `act2-level1-k6-p95.png` |
| PHP-FPM | OPcache Hit Rate > 98% | `act2-level1-opcache.png` |

**Key annotation for `act2-level1-fpm-workers.png`:**  
Draw an arrow in Excalidraw pointing to "Queue Depth = 0" → "This is why it doesn't crash"

**Talking point:**  
"OPcache means PHP reads bytecode from shared memory — zero disk, zero compilation.  
Redis means ~70% of DB queries return from RAM.  
The worker is finally doing useful work instead of waiting."

---

## ACT III — Cache Everything (Level 2)

### Transition

```bash
make level-2
# Reload nginx config — no container restart
docker compose --profile nginx exec nginx nginx -s reload | cat

# Run same crash scenario
make load-crash
```

### Watching the cache warm up

Open Grafana tab 7 (Nginx Cache — `wp-nginx-cache`).

| Timeline | Event | Screenshot |
|---|---|---|
| First 30s | Cache is cold — mostly MISS | `act3-cache-cold.png` — Pie chart: 100% MISS |
| 1 min | Cache warming — MISS drops | watch the pie chart shift |
| 2–3 min | Cache hot — 90%+ HIT | `act3-cache-hot.png` — Pie chart: 90% HIT ← **KEY SLIDE** |

**Critical screenshots:**
1. **`act3-cache-hit-pie.png`** — Nginx Cache dashboard, donut chart: 90%+ HIT green slice  
2. **`act3-fpm-offload.png`** — "PHP-FPM Offload" panel: Total RPS line (high) vs PHP-FPM line (near zero)  
3. **`act3-mysql-tuned.png`** — MariaDB: InnoDB Buffer Pool Hit % > 99%, Threads Running < 5

**Talking point:**  
"95% of requests never touch PHP. The remaining 5% are admin, cart, logged-in users.  
TTFB went from 800ms to 8ms. The $12 VPS is practically bored."

---

## ACT IV — The Hybrid Static Leap (Level 4)

### Build the static export

```bash
# Make sure WP is running (nginx profile)
make static-build

# This takes 1-2 min — wget crawls every page
# Then start the static nginx server
make level-4
```

### Side-by-side demo

Open two tabs:
- http://localhost:8080 — WP origin (heavy)
- http://localhost:8090 — Static export (instant)

```bash
# Hammer ONLY the static site
docker compose --profile load run --rm k6 run \
  --env BASE_URL=http://static-site:80 \
  --vus 500 --duration 2m \
  /scripts/browse.js | cat
```

### Screenshots

| What | Screenshot | Slide |
|---|---|---|
| Overview: origin RPS ≈ 0 while static serves 500 VU | `act4-origin-idle.png` | "WordPress as a CMS, not a runtime" |
| Static site loading in < 100ms (DevTools Network panel) | `act4-static-ttfb.png` | "5 MB, 8ms TTFB, infinite scale" |
| Cart still works (dynamic island) | `act4-cart-working.png` | "It's not broken, it's separated" |
| k6 Live: 500 VU, 0% errors, p95 < 50ms | `act4-k6-static.png` | The "mic drop" slide |

---

## LESSONS LEARNED Slide — Screenshots to embed

Collect these in `results/screenshots/lessons/`:

```
lessons-pm-max-children.png  → act2-level1-fpm-workers.png annotated with the formula
lessons-opcache.png          → act2-level1-opcache.png
lessons-cache-hit.png        → act3-cache-hot.png  
lessons-db-threads.png       → act1-crash-mysql-threads.png
lessons-static-rps.png       → act4-k6-static.png
```

---

## Grafana Screenshot Tips

- Set time range to **"Last 5 minutes"** — tight window shows the story more dramatically  
- Use **"Zoom to data"** on time series panels for before/after comparisons  
- Share → **"Export as PNG"** from the panel menu (three dots → More → Export as PNG)  
- For full dashboards: take a browser screenshot with DevTools hidden, full-screen, zoom 80%  
- Recommended resolution: 2560×1440 (retina)  

---

## Emergency Reset

```bash
# Something went wrong mid-demo:
make reset
# Wait ~90s for volumes to rebuild, then:
make level-0 && make setup
```

If only the load test is stuck:
```bash
docker compose --profile load down
# Then re-run any make load-* command
```

---

## Results Folder Structure (commit before talk)

```
results/
├── screenshots/
│   ├── act1-level0-smoke-overview.png
│   ├── act1-crash-overview.png
│   ├── act1-crash-fpm-queue.png
│   ├── act1-crash-mysql-threads.png
│   ├── act1-crash-k6-rps.png
│   ├── act2-level1-fpm-workers.png
│   ├── act2-level1-redis-hits.png
│   ├── act2-level1-opcache.png
│   ├── act2-level1-overview-comparison.png
│   ├── act2-level1-k6-p95.png
│   ├── act3-cache-cold.png
│   ├── act3-cache-hot.png
│   ├── act3-fpm-offload.png
│   ├── act3-mysql-tuned.png
│   ├── act4-origin-idle.png
│   ├── act4-static-ttfb.png
│   ├── act4-cart-working.png
│   └── act4-k6-static.png
└── .gitkeep
```

Create the folder now:
```bash
mkdir -p results/screenshots/lessons
touch results/.gitkeep
```
