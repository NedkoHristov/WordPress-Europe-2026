# plan-rich.md — Lecture Script + Slide Content

> **One file. Open this alongside SLIDES-RICH.html.**
> For each slide: timing, what to say, the actual slide content.

---

## OPENING (~3 min, slides 1–6)

### SLIDE 1 — Title
> ⏱ `OPENING · slide 1/6 · ~0:00`

**🗣 What to say:**
"Stress Testing and Scaling WordPress on a $12 VPS." Introduce yourself, the talk, the repo (github.com/NedkoHristov/WordPress-Europe-2026). Say: "Every number in this talk is reproducible — git clone, docker compose up."

<details>
<summary>Slide content</summary>

<!-- _class: title -->

# Stress Testing and Scaling WordPress
## on a $12 VPS

<br>

**Nedko Hristov** · Senior DevOps Engineer @ Nemetschek Bulgaria
WordPress Europe 2026 · Kraków 🇵🇱

<br>

`github.com/NedkoHristov/WordPress-Europe-2026`
> `docker compose up` — every number in this talk is reproducible on your laptop

</details>

---

### SLIDE 2 — The setup
> ⏱ `OPENING · slide 2/6 · ~0:30`

**🗣 What to say:**
Walk through what we're testing: WordPress + WooCommerce, 2,500 posts, 500 products. A real site, not a toy. 2 GB RAM, 2 vCPU — this is a €12/month VPS on Hetzner.

<details>
<summary>Slide content</summary>

## The setup

<div class="cols">
<div>

**The hardware**
<div class="card">

💻 2 vCPU · 2 GB RAM · 20 GB SSD
💰 ~$12/month (Hetzner CX22)
🐳 Docker Compose (same constraints, same demo)

</div>

<br>

**The WordPress site**
<div class="card">

📝 2,500 posts · 500 WooCommerce products
🗄️ ~6,000 revisions in DB
🧹 Realistic bloat: transients, orphaned meta
🛍️ WooCommerce + Yoast SEO active

</div>

</div>
<div>

**The load generator**
<div class="card">

⚡ k6 — open source, Grafana Labs
📈 Ramp: 10 → 50 Virtual Users
⏱️ 90-second burst scenario
📊 Metrics → Prometheus remote-write → Grafana (live)

</div>

<br>

**The observability**
<div class="card">

7 Grafana dashboards auto-provisioned:
Demo Story · Overview · PHP-FPM · MariaDB
Nginx Cache · Redis · k6 Live

</div>

</div>
</div>

</details>

---

### SLIDE 3 — The journey
> ⏱ `OPENING · slide 3/6 · ~1:00`

**🗣 What to say:**
Preview the 5-level table. Key message: same VPS, same site, same k6 script. Every improvement is configuration — not hardware. p95 goes from crash to 3ms.

<details>
<summary>Slide content</summary>

## The journey

<div style="font-size:0.78em">

| Level | Stack | p95 Latency | requests/s | CPU | DB Threads | New layer |
|---|---|---|---|---|---|---|
| <span class="pill pill-red">0</span> | Apache + mod_php | 💥 crash @ ~50 VU | ~40 → collapse | 100% | 20+ | — |
| <span class="pill pill-blue">1</span> | + Nginx · FPM · OPcache · Redis | **133 ms** | **65** | 25% | 12.5 | OPcache · Redis |
| <span class="pill pill-blue">2</span> | + FastCGI cache · MariaDB tuning | **79 ms** | **70** | 18% | 3 | FastCGI page cache |
| <span class="pill pill-gold">3</span> | + Cloudflare CDN | **~15 ms** (edge) | origin sees ~15% | <5% | <1 | Edge cache (300+ PoPs) |
| <span class="pill pill-green">4</span> | + Simply Static export | **~4 ms** | 500–1,500+ | <3% | ~0 | Static file serving |

</div>

<br>

> **Same $12 VPS. Same WordPress site. Same k6 load script.**
> Every improvement is configuration — not more hardware.

<br>

> 💡 **50 Virtual Users ≠ 50 visitors.** 50 VUs = 50 concurrent loops each making ~1 request/second = ~50 req/s sustained. *(See next slide.)*

</details>

---

### SLIDE 4 — Key concept: Virtual Users
> ⏱ `OPENING · slide 4/6 · ~1:30`

**🗣 What to say:**
Explain VUs. 50 VUs ≠ 50 visitors. Each VU is a continuous loop — ~1 req/s each = 50 req/s sustained. Real traffic has 10-30× longer think time. This is deliberately aggressive — it makes the crash happen faster and improvements more visible.

<details>
<summary>Slide content</summary>

## Key concept: what is a Virtual User?

<div class="cols">
<div>

**NOT this:**
<div class="card">

❌ 50 VUs = 50 people who visited today
❌ 50 VUs = 50 page loads total
❌ 1 VU = 1 unique session

</div>

<br>

**THIS:**
<div class="card">

✅ 1 VU = 1 browser-like loop running **continuously**

```
VU #1: GET /  → sleep 1-2s
       → GET /?p=1  → sleep 1-2s
       → GET /  → repeat forever
```

50 VUs = **50 concurrent loops**
       = **~50 simultaneous open connections**
       = **~50 requests/second sustained**

</div>

</div>
<div>

**The real-world translation:**
<div class="card">

Real users have **10–30× longer think time** between clicks.

```
50 VUs (k6, 1s think time)
  ≈ 500–1,500 real simultaneous visitors
```

k6's 50 VUs is deliberately **aggressive** — it simulates a spike, not casual browsing.
The crash happens faster and the improvements are more visible.

</div>

</div>
</div>

</details>

---

### SLIDE 5 — Key metric definitions
> ⏱ `OPENING · slide 5/6 · ~2:15`

**🗣 What to say:**
Quick glossary. Highlight p95: "95% of requests finished faster than this number. 5% were slower." Point to FPM queue depth: "Zero is healthy. Anything above zero means PHP is falling behind."

<details>
<summary>Slide content</summary>

## Key metric definitions

| Term | What it actually means |
|---|---|
| **Virtual Users** | Concurrent browser-like loops running continuously — not unique visitors |
| **requests/s** | Total HTTP responses served per second across all VUs |
| **p95 latency** | 95% of requests were *faster* than this — 5% were slower |
| **p99 latency** | The near-worst case — 1% of requests were slower than this |
| **FPM workers** | PHP processes *currently executing code* right now |
| **FPM queue depth** | Requests waiting for a free PHP worker — 0 = healthy, >0 = trouble |
| **DB threads running** | MySQL queries *actively executing* — not just connected |
| **Redis hit rate** | % of WordPress DB calls answered from RAM instead of MySQL |
| **Cache offload** | % of HTTP requests served by nginx without PHP running at all |

</details>

---

### SLIDE 6 — Observability stack
> ⏱ `OPENING · slide 6/6 · ~2:45`

**🗣 What to say:**
Show the stack diagram. "Prometheus + 6 exporters + Grafana + Loki. Every number on screen is a real metric from a real process. No synthetic benchmarks. No cherry-picked results."

<details>
<summary>Slide content</summary>

## Observability stack

```
k6 ──remote-write──▶ Prometheus ◀── node-exporter  (CPU, RAM, disk)
                          │       ◀── cadvisor       (container metrics)
                          │       ◀── mysqld-exporter (threads, buffer pool)
                          │       ◀── php-fpm-exporter (workers, queue)
                          │       ◀── nginx-exporter  (connections, requests/s)
                          │       ◀── redis-exporter  (hit rate, memory)
                          ▼
                       Grafana  ←── Loki (container logs)
                    7 dashboards
                    (live during demo)
```

<br>

> Every number you see on screen is a **real metric from a real process.**
> No synthetic benchmarks. No cherry-picked results.

</details>

---

---

## ACT I — THE CRASH (~10 min, slides 7–12)

### SLIDE 7 — ACT I — The Crash
> ⏱ `ACT I · title card · ~3:00`

**🗣 What to say:**
Build tension. "Let's see what happens when real traffic hits a default WordPress install." Pause. Let it sit.

<details>
<summary>Slide content</summary>

<!-- _class: act -->

<div class="act-icon">💥</div>

# ACT I
## The Crash
### Level 0 — Apache + mod_php

</details>

---

### SLIDE 8 — How Apache prefork works
> ⏱ `ACT I · slide 2/5 · ~3:15`

**🗣 What to say:**
Explain the process model: 1 OS process per connection. Each WP request = 300+ DB queries, 30-50MB RAM. The process stays alive after the response, holding RAM. "This model was designed for static files in 1996."

<details>
<summary>Slide content</summary>

## Level 0 — How Apache prefork works

**Each connection = one OS process**

```
Browser connects
  → Apache forks a worker process
    → worker loads PHP + WordPress into RAM
      → PHP runs, queries MySQL
        → response sent
          → worker stays alive, waiting
            (idle, ~32 MB RAM held)
```

**The problem:**
- 60 idle workers = 1.9 GB RAM consumed
- Browser #61 gets: queue
- Browser #200 gets: **503**

> The process model was designed for static files in 1996.
> WordPress averages **300+ database queries per page.**

</details>

---

### SLIDE 9 — The Apache math
> ⏱ `ACT I · slide 3/5 · ~5:00`

**🗣 What to say:**
Walk through the formula on screen. (2048MB - 512MB) / 32MB = 47 workers max. Show the table: at 48 workers the queue forms, at 100+ it's 503s. "This is not a bug. It is arithmetic. The crash happens at a completely predictable, calculable user count."

<details>
<summary>Slide content</summary>

## The Apache math

$$\text{Max safe workers} = \frac{\text{RAM} - \text{OS + DB + Redis overhead}}{\text{RAM per PHP-WordPress process}}$$

$$= \frac{2048 \text{ MB} - 512 \text{ MB}}{32 \text{ MB/worker}} = \textbf{47 workers max}$$

<br>

| Workers busy | What happens |
|---|---|
| 1 – 40 | ✅ Fast responses |
| 41 – 47 | ⚠️ Slow — swapping begins |
| 48 | Queue forms — new requests wait |
| 100+ | **503 Service Unavailable** |

<br>

> This is not a bug. It is arithmetic.
> The "crash" happens at a completely predictable, calculable virtual user count.

</details>

---

### SLIDE 10 — 📸 Level 0 — Baseline (50 VU before the storm)
> ⏱ `ACT I · slide 4/5 · ~7:00`

**🗣 What to say:**
"Here's Apache at 50 Virtual Users — stable, working fine. This is the calm before the storm. Note the numbers: req/s, p95, zero errors. Hold this picture in mind."

**📸 Screenshot:** `screenshots/l0-00-demo.png`
> Apache working OK at 50 VU — stable baseline before the crash

**💡 Speaker note:** Point at the green req/s line — smooth and stable. Point at the p95 — acceptable. This is the 'before' picture.

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 0 — Baseline (50 Virtual Users — before the storm)

![w:1060](screenshots/l0-00-demo.png)

</details>

---

### SLIDE 11 — 📸 Level 0 — The Crash (0→500 VU)
> ⏱ `ACT I · slide 5/5 · ~7:45`

**🗣 What to say:**
"Now we ramp to 500 Virtual Users. Black Friday scenario." Walk through: green req/s goes UP — then DOWN — while blue VUs keep climbing. "The server stopped responding. Not an error — arithmetic."

**📸 Screenshot:** `screenshots/l0-crash-00-demo.png`
> Apache crashing — req/s collapses while VUs keep rising

**💡 Speaker note:** PAUSE HERE. Let the audience absorb the chart. Point to the exact moment req/s starts falling. Ask: 'Who has seen this in production?'

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 0 — The Crash (Black Friday ramp: 0 → 500 Virtual Users)

![w:1060](screenshots/l0-crash-00-demo.png)

</details>

---

### SLIDE 12 — Level 0 — reading the crash
> ⏱ `ACT I · ~9:00`

**🗣 What to say:**
Walk the table row by row. Key callouts: p95 2.9s → 15× worse than L1. Queue depth ~250 → catastrophic backlog. req/s at 500 VU = 24.5 → 83% of requests failing. "Every metric tells the same story: saturation."

<details>
<summary>Slide content</summary>

## Level 0 — reading the crash

| Panel | Metric | Value | What it means |
|---|---|---|---|
| VU & req/s | Peak requests/s | ~40 → **collapse** | Server buckled — req/s fell while VUs kept climbing |
| VU & req/s | req/s at 500 VU | **24.5** | 83% of requests failing or queued |
| Latency | p95 | **2.9 s** | 15× worse than Level 1 |
| Latency | p99 | **6 s flat** | Hard ceiling — connections timing out |
| Latency | p50 | ~1 s | Even the median is unusable |
| PHP-FPM | Queue depth | **~250** | Catastrophic backlog — workers exhausted |
| PHP-FPM | Active workers | maxed → dropping | Workers timing out under load |
| MariaDB | Threads running | **20** (max) | Every PHP request holding a DB connection |

<br>

> **The crash is visible in one chart:**
> Green requests/s goes up, then down, while Blue Virtual Users keep climbing.
> The server is no longer responding to more load — only less.

</details>

---

---

## ACT II — STOP THE BLEEDING (~12 min, slides 13–21)

### SLIDE 13 — ACT II — Stop the Bleeding
> ⏱ `ACT II · title card · ~10:30`

**🗣 What to say:**
"Three changes. Zero cost. No code." Let that land.

<details>
<summary>Slide content</summary>

<!-- _class: act -->

<div class="act-icon">🩹</div>

# ACT II
## Stop the Bleeding
### Level 1 — Nginx + PHP-FPM + OPcache + Redis

</details>

---

### SLIDE 14 — Level 1 — Three changes, zero cost
> ⏱ `ACT II · slide 2/9 · ~10:45`

**🗣 What to say:**
List the three: (1) Replace Apache with Nginx — event-driven, zero RAM per idle connection. (2) PHP-FPM — decoupled pool, hard worker limit, never OOM. (3) OPcache + Redis — compiled PHP + DB results in RAM. "All apt install + config file changes. make level-1 switches in 10 seconds."

<details>
<summary>Slide content</summary>

## Level 1 — Three changes, zero cost

**1. Nginx (event-driven)**
One thread, 10,000+ concurrent connections.
Zero RAM per idle connection.

**2. PHP-FPM (decoupled pool)**
Workers handle PHP execution only.
Nginx queues connections externally.
`pm.max_children = 20` — hard limit, **never OOM**.

**3. OPcache + Redis object cache**
- OPcache: compiled PHP bytecode in shared memory — zero disk reads
- Redis: DB query results in RAM — 82% of DB calls served from memory

<br>

```bash
make level-1   # 10 seconds to switch
```

</details>

---

### SLIDE 15 — OPcache — the biggest free win
> ⏱ `ACT II · slide 3/9 · ~12:00`

**🗣 What to say:**
Show the two-panel comparison. Without: every single request does a full disk read, parse, compile cycle for 300+ PHP files. With: compile once, store in shared RAM, read opcodes forever. "~98% hit rate after 30 seconds of traffic. opcache.validate_timestamps = 0 — never re-check disk in production."

<details>
<summary>Slide content</summary>

## OPcache — the biggest free win

<div class="cols">
<div class="card">

### ❌ Without OPcache (Level 0)

```
Every single request:
  disk read  → parse → lex
  → AST → compile → opcodes
  → execute → response

Repeat for 300+ PHP files.
wp-settings.php alone
includes 100+ files.
```

</div>
<div class="card">

### ✅ With OPcache (Level 1+)

```
First request only:
  compile → store in shared RAM

Every request after:
  read opcodes from RAM
  → execute → response

Zero disk. Zero compilation.
~98% hit rate after 30s of traffic.
```

</div>
</div>

<br>

```ini
opcache.enable = 1
opcache.validate_timestamps = 0   ; never re-check disk (production)
opcache.memory_consumption = 256  ; MB
```

</details>

---

### SLIDE 16 — 📸 Level 1 — Demo Dashboard
> ⏱ `ACT II · slide 4/9 · ~13:30`

**🗣 What to say:**
"RPS stable at 65, p95 133ms, zero errors. The crash is gone." Compare to the previous screenshot in your head — same VPS, same site. "But notice: every request still hits PHP and MySQL. We have room to go further."

**📸 Screenshot:** `screenshots/l1-00-demo.png`
> Level 1 stable at 50 VU — RPS 65, p95 133ms, 0% errors

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 1 — Demo Dashboard (50 Virtual Users)

![w:1060](screenshots/l1-00-demo.png)

</details>

---

### SLIDE 17 — Level 1 — reading the dashboard
> ⏱ `ACT II · slide 5/9 · ~14:30`

**🗣 What to say:**
Point at each panel. FPM: 14 active workers / 20 max, queue 0. MariaDB: 12.5 threads running — every request still hitting MySQL. Requests vs FPM gap: almost no gap — PHP handling everything. Redis: climbed to 82.3% hit rate as cache warmed.

<details>
<summary>Slide content</summary>

## Level 1 — reading the dashboard

<div class="cols3">
<div class="metric metric-blue"><div class="num">50</div><div class="lbl">Peak Virtual Users</div></div>
<div class="metric metric-green"><div class="num">65</div><div class="lbl">Peak requests/s</div></div>
<div class="metric metric-gold"><div class="num">133 ms</div><div class="lbl">p95 Latency</div></div>
</div>

<br>

<div class="cols">
<div>

**FPM Workers chart — top right:**
- Active Workers peaked at **14 / 20**
- Queue Depth: **0 throughout** ← the stack did not crash
- Idle workers always available → Nginx never queued

**MariaDB Threads — bottom right:**
- Spiked to **12.5 threads running**
- Every request still hitting MySQL

</div>
<div>

**Requests vs FPM — bottom left:**
- Both lines nearly overlap
- Tiny gap = almost no caching yet
- **Every Nginx request forwarded to PHP**

**Redis Hit Rate — bottom right:**
- Climbed from 0% → **82.3%** as cache warmed
- 46,000 keys, 14.5 MB used
- 6,000+ Redis ops/s vs ~300 MySQL queries/s

</div>
</div>

</details>

---

### SLIDE 18 — L0 → L1: the jump
> ⏱ `ACT II · slide 6/9 · ~16:00`

**🗣 What to say:**
Walk the comparison table. p95: 3s → 133ms. CPU: 100% → 25%. Errors: crash → zero. "Same VPS. Same site. Three config changes." Pause.

**💡 Speaker note:** This is a powerful moment. Same hardware, same code — p95 went from 3 seconds to 133ms. Let that sink in before moving on.

<details>
<summary>Slide content</summary>

## L0 → L1: the jump

| Metric | Level 0 | Level 1 | Δ |
|---|---|---|---|
| Crash at 50 Virtual Users | ❌ server buckles | ✅ stable | **crash eliminated** |
| Peak requests/s | ~40 → **collapse** | **65** | stable throughput |
| p95 Latency | ~3 s | **133 ms** | **−95%** |
| p99 Latency | 6 s flat ceiling | **~350 ms** | **−94%** |
| CPU @ 50 Virtual Users | ~100% | **25%** | −75% |
| FPM queue depth | ~250 backlog | **0** | ✅ |
| DB Threads peak | 20+ | **12.5** | −37% |
| Redis hit ratio | — | **82.3%** | new layer added |

<br>

> The crash is gone. The server is stable at 50 Virtual Users.
> But every request still hits PHP and MySQL — there is room to go further.

</details>

---

### SLIDE 19 — 📸 Level 1 — PHP-FPM Workers
> ⏱ `ACT II · slide 7/9 · ~17:30`

**🗣 What to say:**
"14 active workers at peak out of 20. Queue depth zero. We have headroom — FPM never saturated. But we can do better."

**📸 Screenshot:** `screenshots/l1-02-php-fpm.png`
> FPM workers: 14 active / 20 max, queue depth 0

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 1 — PHP-FPM Workers & Request Rate

![w:1060](screenshots/l1-02-php-fpm.png)

</details>

---

### SLIDE 20 — 📸 Level 1 — Redis
> ⏱ `ACT II · slide 8/9 · ~18:15`

**🗣 What to say:**
"82% hit rate. 6,000 ops/s at peak. 82% of WordPress database calls never reached MySQL — answered from RAM in 0.1ms instead of 4-8ms from MySQL."

**📸 Screenshot:** `screenshots/l1-05-redis.png`
> Redis: 82% hit rate, 6K ops/s

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 1 — Redis: 82% Hit Rate, 6K ops/s

![w:1060](screenshots/l1-05-redis.png)

</details>

---

### SLIDE 21 — Level 1 — what Redis is actually doing
> ⏱ `ACT II · slide 9/9 · ~19:00`

**🗣 What to say:**
Walk through the code example: WP_Query → Redis HIT → 0.1ms. After warmup MySQL sees 54 queries/request instead of 300+. "Redis delayed the crash significantly. But it doesn't eliminate it. That requires removing PHP from the hot path entirely."

<details>
<summary>Slide content</summary>

## Level 1 — what Redis is actually doing

**46,000 cached keys · 14.5 MB · 6,000 ops/s at peak**

```
WordPress makes 300+ DB calls per page request.
Redis intercepts most of them:

wp_get_option('siteurl')        → Redis HIT → 0.1 ms
wp_get_option('blogname')       → Redis HIT → 0.1 ms
WP_Query (recent posts)         → Redis HIT → 0.1 ms
get_post_meta(post_id, '_price')→ Redis HIT → 0.1 ms
WC product lookup               → Redis MISS → MySQL → 4 ms → cached

After warmup: ~82% of DB calls answered from memory.
MySQL sees ~54 queries/request instead of 300+.
```

> Redis did not prevent the crash at Level 0 because we never got there.
> It **would** delay the crash significantly — but doesn't eliminate it.
> That requires removing PHP from the hot path entirely.

</details>

---

---

## ACT III — CACHE EVERYTHING (~12 min, slides 22–32)

### SLIDE 22 — ACT III — Cache Everything
> ⏱ `ACT III · title card · ~20:30`

**🗣 What to say:**
"Most WordPress pages return identical HTML for every anonymous visitor." Pause. Let that sit.

<details>
<summary>Slide content</summary>

<!-- _class: act -->

<div class="act-icon">🚀</div>

# ACT III
## Cache Everything
### Level 2 — FastCGI page cache + MariaDB tuning

</details>

---

### SLIDE 23 — The key insight
> ⏱ `ACT III · slide 2/11 · ~20:45`

**🗣 What to say:**
Read the blockquote slowly. "Home page. Category. Blog post. Shop. PHP runs. MySQL queries. The output is the same HTML every time. Why keep generating it?" The FastCGI cache is the logical conclusion.

<details>
<summary>Slide content</summary>

## The key insight

> **Most WordPress page requests return identical HTML for every anonymous visitor.**
> Home page. Category. Blog post. Shop.
> PHP runs. MySQL queries. OPcache helps. Redis helps.
> **The output is still the same HTML every time.**

**FastCGI page cache — the logical conclusion:**
```
First anonymous visitor  → PHP runs → nginx stores response on disk
Every visitor after      → nginx reads cached file → 8ms TTFB
                           PHP never runs
                           MySQL never runs
                           Redis never asked
```

<div class="cols">
<div class="card">

**Cached (anonymous visitors)** ✅
Homepage · Category pages · Posts · Shop

</div>
<div class="card">

**Bypassed (dynamic)** 🔄
Logged-in · Cart · Checkout · Admin

</div>
</div>

</details>

---

### SLIDE 24 — Level 2 — nginx config
> ⏱ `ACT III · slide 3/11 · ~21:45`

**🗣 What to say:**
Walk through the config. cache_path — where pages are stored. fastcgi_cache_key — what makes a unique page. skip_cache rule — logged-in users and WooCommerce cart always bypass. add_header X-Cache-Status — you can see HIT/MISS in browser devtools. "make level-2 — 10 seconds."

<details>
<summary>Slide content</summary>

## Level 2 — nginx config

```nginx
fastcgi_cache_path /var/cache/nginx
  levels=1:2
  keys_zone=WORDPRESS:100m
  inactive=60m
  max_size=1g;

# Bypass rule — logged-in users and WooCommerce sessions
set $skip_cache 0;
if ($http_cookie ~* "wordpress_logged_in|woocommerce_cart|woocommerce_session") {
    set $skip_cache 1;
}

location ~ \.php$ {
    fastcgi_cache WORDPRESS;
    fastcgi_cache_key "$scheme$request_method$host$request_uri";
    fastcgi_cache_valid 200 60m;
    fastcgi_cache_bypass $skip_cache;
    fastcgi_no_cache $skip_cache;
    add_header X-Cache-Status $upstream_cache_status;  # HIT / MISS / BYPASS
}
```

```bash
make level-2   # 10 seconds to switch. Same hardware.
```

</details>

---

### SLIDE 25 — 📸 Level 2 — Demo Dashboard
> ⏱ `ACT III · slide 4/11 · ~23:15`

**🗣 What to say:**
"70 requests/s. p95 79ms. CPU 18%. Zero errors. Same 50 VUs. Same VPS." Compare to L1 mentally. Let them absorb the numbers.

**📸 Screenshot:** `screenshots/l2-00-demo.png`
> Level 2 at 50 VU — RPS 70, p95 79ms, 0% errors, CPU 18%

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 2 — Demo Dashboard (50 Virtual Users)

![w:1060](screenshots/l2-00-demo.png)

</details>

---

### SLIDE 26 — Level 2 — reading the dashboard
> ⏱ `ACT III · slide 5/11 · ~24:15`

**🗣 What to say:**
Key callout: FPM only handling 20 req/s while Nginx is serving 70 req/s. Gap of 50 req/s served from cache. DB threads: from 12.5 to 3. "70% of requests never left nginx."

<details>
<summary>Slide content</summary>

## Level 2 — reading the dashboard

<div class="cols3">
<div class="metric metric-green"><div class="num">70</div><div class="lbl">Peak requests/s (+8%)</div></div>
<div class="metric metric-green"><div class="num">79 ms</div><div class="lbl">p95 Latency (was 133ms)</div></div>
<div class="metric metric-green"><div class="num">18%</div><div class="lbl">CPU (was 25%)</div></div>
</div>

<br>

<div class="cols">
<div>

**FPM Workers — top right:**
- Active Workers peaked at **11 / 20** (was 14)
- Queue Depth: **0** — same as L1 but with less work
- FPM Request Rate: only **~20 requests/s** (vs 70 requests/s from Nginx)
- **50 requests/s served from cache — PHP never ran**

</div>
<div>

**MariaDB Threads — bottom right:**
- Max **3 threads running** (was 12.5!)
- **76% fewer DB queries** — cache bypass requests only
- Buffer pool pressure gone

**Requests vs FPM gap:**
- Nginx: **~70 requests/s**
- PHP-FPM: **~20 requests/s**
- Gap = **~50 requests/s served from disk cache**

</div>
</div>

</details>

---

### SLIDE 27 — L0 → L1 → L2: progression
> ⏱ `ACT III · slide 6/11 · ~25:30`

**🗣 What to say:**
Walk the three-column table. The story in one slide: crash → stable → fast. DB threads: 20+ → 12.5 → 3. Cache offload: 0% → 0% → 70%. "Same hardware. Configuration only."

<details>
<summary>Slide content</summary>

## L0 → L1 → L2: the progression

| Metric | Level 0 | Level 1 | Level 2 |
|---|---|---|---|
| Peak requests/s | ~40 → 💥 | 65 | **70** |
| p95 Latency | ~3 s 💥 | 133 ms | **79 ms** |
| CPU @ 50 Virtual Users | ~100% | 25% | **18%** |
| FPM workers (peak) | — | 14 / 20 | **11 / 20** |
| FPM queue depth | ~250 | 0 | **0** |
| DB Threads peak | 20+ | 12.5 | **3** |
| FastCGI cache offload | 0% | 0% | **~70%** |
| Redis hit ratio | — | 82.3% | **~80%+** |

<br>

> Level 2 does **more work with less resource** — 70% of requests never leave nginx.
> DB threads: 12.5 → **3**. The bottleneck is gone.

</details>

---

### SLIDE 28 — 📸 Level 2 — Nginx Cache
> ⏱ `ACT III · slide 7/11 · ~26:30`

**🗣 What to say:**
"This is the money slide." Point at the two lines. Top line = total nginx requests. Bottom line = requests that hit PHP. The gap between them is the cache.

**📸 Screenshot:** `screenshots/l2-04-nginx-cache.png`
> Nginx cache dashboard — gap between total req and FPM passthrough

**💡 Speaker note:** Point at the gap between the two lines. Say: 'This gap is PHP execution that never happened. Every request in this gap was served from nginx's memory. Zero PHP. Zero MySQL.' Pause.

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 2 — Nginx Cache: 9.94K requests, FPM Offload

![w:1060](screenshots/l2-04-nginx-cache.png)

</details>

---

### SLIDE 29 — FPM offload panel explained
> ⏱ `ACT III · slide 8/11 · ~27:30`

**🗣 What to say:**
Walk the ASCII diagram: 9,940 total requests in 5 min. ~7,000 from cache (<10ms, disk read). ~2,940 required PHP. "Scale that to a Black Friday spike — 10× traffic hits nginx, not your server. Your VPS stays idle."

<details>
<summary>Slide content</summary>

## Level 2 — the FPM offload panel explained

**Bottom-right panel: PHP-FPM Offload — Requests NOT hitting PHP**

```
Total requests/s (Nginx)    ████████████████████████  ~70  ← everything
Requests/s hitting PHP-FPM  ████████                  ~20  ← only cache misses

Gap                  ████████████████          ~50  ← served from cache
                                                            PHP never ran
                                                            MySQL never queried
```

<br>

**In 5 minutes of the test:** `9,940 total requests`
- ~7,000 served from nginx cache (disk read, <10ms)
- ~2,940 required PHP execution (cold cache, logged in, dynamic pages)

<br>

> **This is the money slide.**
> The gap between the two lines is PHP execution that never happened.
> Scale that to a Black Friday spike — 10× traffic hits nginx, not your server.

</details>

---

### SLIDE 30 — 📸 Level 2 — PHP-FPM
> ⏱ `ACT III · slide 9/11 · ~28:30`

**🗣 What to say:**
"Steady at 10-11 workers. Queue depth zero. CPU idle. The bottleneck is gone." Compare to L1's 14 workers — less work per worker because 70% is cached.

**📸 Screenshot:** `screenshots/l2-02-php-fpm.png`
> FPM workers steady at 10-11, queue 0, CPU idle

<details>
<summary>Slide content</summary>

<!-- _class: screenshot -->

## 📸 Level 2 — PHP-FPM: Steady at 10-11 Workers

![w:1060](screenshots/l2-02-php-fpm.png)

</details>

---

### SLIDE 31 — MariaDB tuning — Level 2
> ⏱ `ACT III · slide 10/11 · ~29:15`

**🗣 What to say:**
Show the two configs side by side. Key change: buffer pool 128MB → 512MB. "WordPress DB is ~500MB. With 128MB pool every query reads from disk. With 512MB the whole DB fits in RAM — sub-millisecond reads. Two config lines." Also: slow query log at 0.5s — visible in Loki.

<details>
<summary>Slide content</summary>

## MariaDB tuning — Level 2

<div class="cols">
<div>

**Level 0 baseline config:**
```ini
# 00-baseline.cnf
innodb_buffer_pool_size = 128M
# (default — fits almost nothing)
max_connections = 151
```
With 128M buffer pool:
- WordPress DB ≈ 500MB
- **Every query reads from disk**
- Buffer pool full → constant disk I/O
- Slow queries undetected

</div>
<div>

**Level 2 tuned config:**
```ini
# 10-tuned.cnf
innodb_buffer_pool_size = 512M
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 128M
slow_query_log = 1
long_query_time = 0.5
```
After tuning:
- DB fits in RAM → sub-millisecond reads
- Commits batched (1×/sec vs every write)
- Slow queries logged → visible in Loki
- **MariaDB Threads Running: 12.5 → 3**

</div>
</div>

</details>

---

### SLIDE 32 — Level 1 vs Level 2 — real numbers
> ⏱ `ACT III · slide 11/11 · ~30:30`

**🗣 What to say:**
Walk the table. Key callout: L2 does 24% more requests with 29% less CPU. DB threads: 12.5 → 3 (−76%). "L2 does more work with less resource because 70% of requests never leave nginx. The remaining 30% are served faster too — because MariaDB has headroom now."

<details>
<summary>Slide content</summary>

## Level 1 vs Level 2 — the real numbers

| Metric | Level 1 | Level 2 | Change |
|---|---|---|---|
| Peak requests/s @ 50 Virtual Users | 65 | **70** | +8% |
| p95 Latency | 133 ms | **79 ms** | **−41%** |
| CPU usage | 25.4% | **18.1%** | **−29%** |
| FPM workers (peak) | 14 / 20 | **11 / 20** | −21% |
| FPM queue depth | 0 | **0** | — |
| MariaDB threads (peak) | 12.5 | **3** | **−76%** |
| Cache offload | 0% | **~70%** | ✅ 50 requests/s saved |
| Requests in 5 min | ~8K | **9.94K** | +24% |
| Redis hit ratio | 82.3% | ~80%+ | similar |

<br>

> L2 does **more** work with **less** resource because 70% of requests
> never leave nginx. The remaining 30% are served faster too —
> because MariaDB has headroom now.

</details>

---

---

## ACT IV — WHAT'S NEXT (~8 min, slides 33–39)

### SLIDE 33 — What's Next? — The Static Leap
> ⏱ `ACT IV · title card · ~32:00`

**🗣 What to say:**
"What if we remove PHP from the picture entirely?"

<details>
<summary>Slide content</summary>

<!-- _class: act -->

<div class="act-icon">⚡</div>

# What's Next?
## The Static Leap
### Level 4 — Simply Static: WordPress as a CMS, not a runtime

</details>

---

### SLIDE 34 — Level 4 — the concept
> ⏱ `ACT IV · slide 2/7 · ~32:15`

**🗣 What to say:**
Explain Simply Static: crawls every published URL → flat HTML. Runtime: Nginx reads a .html file from disk. Zero PHP for anonymous traffic. WordPress only activates for cart/checkout/admin. "WordPress becomes a CMS, not a runtime."

<details>
<summary>Slide content</summary>

## Level 4 — the concept

**Build time** (once per publish cycle, after content is seeded):
```bash
# Setup — install the Simply Static plugin:
wp plugin install simply-static --activate

# Export — trigger once after content is ready:
wp simply-static run
# Crawls every published URL → flat HTML + assets
# Output: static/export/  →  served by Nginx, zero PHP
```

> **Simply Static** is a WordPress plugin — no external tooling needed.
> Run once after seeding 2,500 posts + 500 products. Re-run after any publish.
> Takes ~2–5 min. Output directory is the same `static/export/` Nginx already serves.

**Runtime** (every anonymous request):
```
Browser → Nginx
  ├── /           → static/export/index.html   (0ms PHP)
  ├── /post-2498/ → static/export/post-2498/index.html   (0ms PHP)
  └── /checkout   → proxy → WordPress (live)
     /wp-admin    → proxy → WordPress (live)
     /wp-json/*   → proxy → WordPress (live)
```

**WordPress only activates for cart / checkout / admin.**
Everything else is a static file served by Nginx from disk.

</details>

---

### SLIDE 35 — Level 4 — expected numbers
> ⏱ `ACT IV · slide 3/7 · ~33:30`

**🗣 What to say:**
Walk the comparison table. 500-1,500+ req/s vs 70. p95 3-5ms vs 79ms. PHP workers needed: zero. "The trade-off: content is stale until next export. Perfect for blogs, marketing sites, WooCommerce catalogues. Use L2 for live inventory, personalised pages, real-time data."

<details>
<summary>Slide content</summary>

## Level 4 — Simply Static: expected numbers

| Metric | Level 2 | Level 4 (estimated) |
|---|---|---|
| requests/s @ 50 Virtual Users | 70 | **500–1,500+** |
| p95 Latency | 79 ms | **~3–5 ms** |
| CPU @ 50 Virtual Users | 18% | **<3%** |
| DB Threads | 3 | **~0** |
| PHP workers needed | 11 | **0** |

<br>

**The math:**
```
Level 2 bottleneck: PHP executing 300+ DB queries per page
  → Redis saves 82%, FastCGI saves another 70%
  → PHP still runs for cache misses

Level 4: nginx reads a .html file from disk
  → ~0.1ms SSD seek (or OS page cache → ~0.01ms)
  → 2 vCPU can sustain ~10,000 file serves/second
  → FPM pool never touched for anonymous traffic
```

> **The trade-off:** content is stale until next `wp simply-static run`.
> Perfect for: blogs, marketing sites, WooCommerce catalogues.
> Use Level 2 for: live inventory, personalised pages, real-time data.

</details>

---

### SLIDE 36 — Level 3 — Cloudflare CDN
> ⏱ `ACT IV · slide 4/7 · ~35:00`

**🗣 What to say:**
Explain the edge model. Your VPS only sees cache misses — 10-20% of total traffic. "Level 3 turns your $12 VPS into a globally distributed site. The VPS becomes the origin. No code changes. DNS cutover is the entire deployment."

<details>
<summary>Slide content</summary>

## Level 3 — Cloudflare CDN

**The concept:**
```
Browser (anywhere in the world)
  ↓
Cloudflare Edge (300+ PoPs — nearest data center, <30ms away)
  ├── CACHE HIT  → response from edge   (0ms origin, ~10–20ms to browser)
  └── CACHE MISS → fetch from your VPS  (once per TTL, then cached at edge)
```

Your $12 VPS **only sees cache misses** — ~10–20% of total traffic during a spike.

| Metric | Level 2 (direct) | Level 3 (+ Cloudflare) | Δ |
|---|---|---|---|
| TTFB for cached pages | 79 ms | **10–20 ms** | −75% |
| Origin requests at peak | 100% | **~15–20%** | **−80%** |
| Bandwidth from VPS | 100% | **~20–30%** | −75% |
| DDoS protection | ❌ none | **✅ unlimited** | — |
| Cost | $0 | **$0** | — |

> Level 3 turns your $12 VPS into a globally distributed site.
> The VPS becomes the **origin** — it only handles 10–20% of peak load.
> No code changes. DNS cutover is the entire "deployment".

</details>

---

### SLIDE 37 — Cloudflare Free Plan
> ⏱ `ACT IV · slide 5/7 · ~36:30`

**🗣 What to say:**
Walk through what you get for free: global CDN, DDoS protection, free SSL, HTTP/3. Show the one Cache Rule. "Same bypass logic as FastCGI cache — logged-in and cart users always hit origin. Everything else: served from the nearest Cloudflare PoP. VPS stays idle."

<details>
<summary>Slide content</summary>

## Cloudflare Free Plan — what you get

<div class="cols">
<div>

**Performance (free)**
<div class="card">

- 🌍 **Global CDN** — 300+ PoPs worldwide
- ⚡ **Full page caching** via Cache Rules
- 🖼️ **Polish** — automatic image compression
- 🚀 **Rocket Loader** — async JS loading
- 🔒 **Free SSL/TLS** — automatic HTTPS
- 📡 **HTTP/2 + HTTP/3 (QUIC)** — automatic

</div>
</div>
<div>

**Security (free)**
<div class="card">

- 🛡️ **DDoS mitigation** — unlimited, unmetered
- 🤖 **Bot Fight Mode** — basic bot blocking
- 🔥 **WAF** — 5 custom rules
- 🚫 **IP reputation** — automatic bad actor blocking
- 📊 **Analytics** — requests, bandwidth, threats

</div>
</div>
</div>

<br>

**One Cache Rule in the Cloudflare dashboard:**
```
URL:            *.yourdomain.com/*
Cache Level:    Cache Everything
Edge TTL:       1 hour
Bypass cookie:  wordpress_logged_in.*|woocommerce_cart.*
```

> Same bypass logic as FastCGI cache — logged-in + cart users always hit origin.
> Everything else: served from the nearest Cloudflare PoP. VPS stays idle.

</details>

---

### SLIDE 38 — The full picture
> ⏱ `ACT IV · slide 6/7 · ~38:00`

**🗣 What to say:**
Five levels in one table. "Every improvement except Cloudflare costs exactly zero dollars. It was configuration, architecture, and understanding the bottleneck."

<details>
<summary>Slide content</summary>

## The full picture

| Level | Stack | p95 Latency | CPU @ 50 Virtual Users | DB Threads |
|---|---|---|---|---|
| **0** | Apache + mod_php | 💥 crash ~50 Virtual Users | 100% | 20–30 |
| **1** | Nginx + FPM + OPcache + Redis | **133 ms** | 25% | 12.5 |
| **2** | Level 1 + FastCGI cache + MariaDB | **79 ms** | 18% | 3 |
| **3** | Level 2 + Cloudflare CDN | ~20 ms (edge) | <5% | <1 |
| **4** | Level 2 + Simply Static | ~4 ms | <5% | <1 |

<br>

> ⬜ Levels 3 and 4 are architectural next steps — not live-demoed in this talk.
> **Every improvement except Cloudflare costs exactly $0.**
> It was configuration, architecture, and understanding the bottleneck.

</details>

---

### SLIDE 39 — The full cache hierarchy
> ⏱ `ACT IV · slide 7/7 · ~39:00`

**🗣 What to say:**
Walk the ASCII diagram top to bottom. Each layer absorbs 70-95% of what reaches it. "MariaDB only sees the requests Redis couldn't answer. And FastCGI means Redis only sees misses."

<details>
<summary>Slide content</summary>

## The full cache hierarchy

```
Request from browser
  │
  ▼
[Cloudflare CDN]  ← Level 3 (edge cache, global PoP)
  │ miss
  ▼
[Nginx FastCGI Cache]  ← Level 2 (disk cache, 60-min TTL)
  │ miss
  ▼
[PHP-FPM]  ← always running, pool of 20 workers
  ├── [OPcache]  ← Level 1 (compiled bytecode in RAM)
  └── [Redis Object Cache]  ← Level 1 (DB query results in RAM)
       │ miss (first time only)
       ▼
    [MariaDB]  ← tuned at Level 2: 512MB buffer pool
```

> Each layer absorbed ~70–95% of what reached it.
> MariaDB only sees the requests Redis couldn't answer.

</details>

---

---

## CLOSING (~5 min + Q&A, slides 40–42)

### SLIDE 40 — Lessons learned
> ⏱ `CLOSING · slide 1/3 · ~40:30`

**🗣 What to say:**
Four takeaways. Emphasise #1: "Set up Prometheus and Grafana before you need them. You cannot fix what you cannot see." Emphasise #3: pm.max_children is math — show the formula again. Emphasise #4: DB threads in Grafana tells you everything.

<details>
<summary>Slide content</summary>

## Lessons learned

<div class="cols">
<div>

**1. Measure before you fix**
<div class="card">

Set up Prometheus + Grafana
**before** you need it.
You cannot fix what you cannot see.

`make obs-up` — 30 seconds.

</div>

<br>

**2. The three WP cache layers**
<div class="card">

```
OPcache  → PHP bytecode  → always on
Redis    → DB queries    → wp redis enable
FastCGI  → Full pages    → nginx.conf
```

Most sites use 0 of these 3.
All three: completely different machine.

</div>

</div>
<div>

**3. pm.max_children is math, not guessing**
<div class="card">

$$\frac{\text{RAM available for PHP}}{\text{MB per WordPress worker}}$$

Over-provision → OOM killer.
Under-provision → queue → 503.

Measure with Grafana, then calculate.

</div>

<br>

**4. The DB is almost always the real bottleneck**
<div class="card">

- `innodb_buffer_pool_size` = 70% of RAM
- Enable `slow_query_log`, watch Loki
- Watch **Threads Running** in Grafana
- Level 2: threads went 12.5 → **3**

</div>

</div>
</div>

</details>

---

### SLIDE 41 — The tools
> ⏱ `CLOSING · slide 2/3 · ~43:00`

**🗣 What to say:**
All free, all open source. Point to the repo URL. "git clone, make level-1, make obs-up, make setup, make snapshot — you have a running demo in 15 minutes."

<details>
<summary>Slide content</summary>

## The tools — all free, all open source

<div class="cols">
<div>

| Tool | Role |
|---|---|
| **k6** | Load generator — scriptable, Prometheus remote-write |
| **Prometheus** | Metrics collection + storage |
| **Grafana** | 7 dashboards, auto-provisioned |
| **Loki + Promtail** | Container log aggregation |

</div>
<div>

| Tool | Role |
|---|---|
| **Nginx FastCGI** | Full-page cache (built-in) |
| **PHP OPcache** | Bytecode cache (built-in) |
| **Redis** | Object cache |
| **MariaDB 11** | Tuned DB config |
| **Docker Compose** | Reproducible demo — one file |

</div>
</div>

<br>
<div class="card" style="text-align:center;padding:20px">

🐙 **github.com/NedkoHristov/WordPress-Europe-2026**

```bash
git clone … && make level-1 && make obs-up && make setup && make snapshot
```
Every level. Every screenshot. Every number. Reproducible.

</div>

</details>

---

### SLIDE 42 — Thank you + Questions
> ⏱ `CLOSING · slide 3/3 · ~44:30`

**🗣 What to say:**
Open for Q&A. Repeat repo URL. Leave the slide up.

**💡 Speaker note:** Key phrases to remember:
- Slide 11: 'The server stopped responding. Not an error — arithmetic.'
- Slide 18: 'Same VPS. Same site. Three config changes.'
- Slide 28: 'This gap is PHP execution that never happened.'
- Slide 38: 'Every improvement except Cloudflare costs exactly zero dollars.'

<details>
<summary>Slide content</summary>

<!-- _class: title -->

# Thank you!

<br>

**Nedko Hristov**
Senior DevOps Engineer @ Nemetschek Bulgaria

🐙 `github.com/NedkoHristov/WordPress-Europe-2026`

<br><br>

### Questions?

<br>

> *"The best time to add monitoring was before the crash.*
> *The second best time is right now."*

</details>

---
