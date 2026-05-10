[//]: # (─────────────────────────────────────────────────────────────────)
[//]: # (  HOW TO EXPORT THESE SLIDES)
[//]: # (─────────────────────────────────────────────────────────────────)
[//]: # ()
[//]: # (  STEP 1 — Install Marp CLI)
[//]: # ()
[//]: # (    npm install -g @marp-team/marp-cli)
[//]: # ()
[//]: # (  STEP 2 — Export)
[//]: # ()
[//]: # (    # PowerPoint — import into Google Slides via File → Import slides)
[//]: # (    marp --pptx SLIDES.md)
[//]: # ()
[//]: # (    # PDF — for sharing / printing)
[//]: # (    marp --pdf SLIDES.md)
[//]: # ()
[//]: # (    # HTML — open in browser, present live)
[//]: # (    marp --html SLIDES.md && open SLIDES.html)
[//]: # ()
[//]: # (  STEP 3 — Google Slides import)
[//]: # (    1. Open slides.google.com → New presentation)
[//]: # (    2. File → Import slides → Upload → choose SLIDES.pptx)
[//]: # (    3. Select all slides → Import)
[//]: # ()
[//]: # (  VS Code: install the "Marp for VS Code" extension for live preview)
[//]: # (─────────────────────────────────────────────────────────────────)

---
marp: true
theme: default
paginate: true
backgroundColor: "#ffffff"
color: "#1a1a2e"
style: |
  section {
    font-family: 'Inter', 'Segoe UI', sans-serif;
    font-size: 28px;
  }
  section.title {
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 60%, #0f3460 100%);
    color: white;
    text-align: center;
  }
  section.act {
    background: #0f3460;
    color: white;
    text-align: center;
    justify-content: center;
  }
  section.crash { background: #2d1b1b; color: #ff6b6b; }
  section.win   { background: #1b2d1b; color: #51cf66; }
  h1 { color: inherit; }
  h2 { color: #0f3460; border-bottom: 3px solid #e94560; padding-bottom: 8px; }
  .columns { display: grid; grid-template-columns: 1fr 1fr; gap: 2rem; }
  table { font-size: 22px; }
  code { background: #f0f4ff; padding: 2px 6px; border-radius: 4px; }
  pre  { font-size: 20px; }
---

<!-- _class: title -->

# Stress Testing and Scaling WordPress on a $12 VPS

### From server crash to enterprise scale — a live-fire DevOps exercise

<br>

**Nedko Hristov** · Senior DevOps Engineer @ Nemetschek Bulgaria
WordPress Europe 2026 · Kraków

> 🐙 github.com/NedkoHristov/WordPress-Europe-2026

<!--
Speaker notes: Welcome everyone. Today we're going to crash a WordPress server — on purpose — and then fix it, layer by layer, while watching everything in real time on Grafana dashboards. Every command I run is in the GitHub repo. You can reproduce every number I show you.
-->

---

## Who am I?

- **Nedko Hristov** — Senior DevOps Engineer @ Nemetschek Bulgaria
- Building and breaking WordPress infrastructure since 2012
- Contributor to the Bulgarian WordPress community
- Speaker at dev.bg, WordCamp Sofia, and now — WordPress Europe 🎉

<br>

**Today's promise:**
> By the end of this talk, you'll know exactly which knob to turn when your WordPress site falls over — and why it works.

<!--
Speaker notes: Quick intro. I've been running WordPress at scale for over a decade. I've seen every failure mode. Today I want to share the playbook I wish I had early on.
-->

---

## What we're working with

<div class="columns">
<div>

**The "VPS"**
- 2 vCPU · 2 GB RAM · 20 GB SSD
- ~$12/month (Hetzner CX22 equivalent)
- Docker Desktop (local, same constraints)

**The WordPress site**
- 2,500 posts + 500 products
- WooCommerce active
- ~6,000 revisions in the database
- "Real" bloat — expired transients, orphaned meta

</div>
<div>

**The load generator**
- k6 · open source · Grafana Labs
- Ramping VU scenario: 10 → 500 VUs
- Named: **Black Friday ramp**
- All metrics live in Grafana

**The repo**
```bash
git clone github.com/NedkoHristov/WordPress-Europe-2026
docker compose up   # everything starts
```

</div>
</div>

<!--
Speaker notes: We're simulating a real $12 VPS by running Docker with constrained resources. The WordPress database has realistic bloat — not just empty tables. k6 handles the load and pushes metrics to Prometheus in real time.
-->

---

## The 4-level scaling journey

| Level | Stack | Key change |
|---|---|---|
| **0** | Apache + mod_php | Baseline — we crash it here |
| **1** | Nginx + PHP-FPM + OPcache + Redis | Event model + bytecode cache |
| **2** | Level 1 + FastCGI page cache + MariaDB tuning | 95% of requests skip PHP |
| **3** | Level 2 + Cloudflare CDN | Edge absorbs the load |
| **4** | Level 2 + Simply Static export | WordPress as a CMS, not a runtime |

<br>

> Same hardware. Same site. Same load. Wildly different results.

<!--
Speaker notes: Every level is a real, actionable change you can make to a production site. We go from "it crashes at 50 users" to "500 users, 0% errors, CPU barely moving."
-->

---

## Observability stack

```
k6 ──remote-write──▶ Prometheus ──▶ Grafana dashboards (live)
                          ▲
node-exporter (CPU/RAM) ──┤
cadvisor (containers) ────┤
mysqld-exporter ──────────┤
php-fpm-exporter ─────────┤
nginx-exporter ───────────┤
redis-exporter ───────────┘
```

**6 dashboards auto-provisioned:**
Overview · PHP-FPM · MariaDB · Nginx Cache · Redis · k6 Live

> Everything you see on screen is real data from the running containers.

<!--
Speaker notes: I want you to trust the numbers. Every metric is from an actual exporter scraping the real process. The k6 results go directly into Prometheus via remote write — the same Prometheus that's graphing the server health. One source of truth.
-->

---

<!-- _class: act -->

# ACT I
## The Crash

### Level 0 — Apache + mod_php

<!--
Speaker notes: Let's start where most WordPress sites start. The default. The thing your hosting provider sets up for you. Apache prefork with mod_php.
-->

---

## Level 0 architecture

```
Browser
   │
   ▼
Apache prefork (port 80)
   │  mod_php embedded in every worker process
   ▼
MariaDB
```

**What this means:**
- Each Apache worker = 1 full PHP process in RAM
- 2 GB RAM → ~40–50 usable workers
- Worker 51 = **wait in queue**
- Queue full = **503 Service Unavailable**

<!--
Speaker notes: Apache prefork was designed in 1995. Each connection gets its own process. Each process loads PHP into memory. On a 2GB VPS with a WordPress site, you realistically get about 40-50 slots. The 51st visitor waits. And the 100th visitor gets a 503.
-->

---

## DEMO — Black Friday ramp begins

```bash
make load-crash   # 0→500 VUs over 14 minutes
```

**Watch: http://localhost:3000/d/wp-overview**

| Minute | VUs | What's happening |
|---|---|---|
| 1 | 10 | All green ✅ p95 < 200ms |
| 3 | 50 | CPU climbing, load > 2 ⚠️ |
| 4 | 80–100 | FPM saturated, queue forming 🔴 |
| 4:30 | 100 | MySQL threads spike 🔴 |
| 5 | 100–150 | **CRASH** — 503s, load > 10 💀 |

<!--
Speaker notes: [Run make load-crash, switch to Grafana Overview]. Watch the load average. The moment it crosses 2.0 on a 2-core machine, we're in trouble. When it hits 10, the machine is effectively frozen from the web server's perspective.
-->

---

<!-- _class: crash -->

## 📸 The money shot

**CPU: 100% · Load: >10 · RAM: near zero · Error rate: >50%**

*(screenshot: act1-crash-overview.png)*

<br>

### What killed it?

1. **Apache prefork** — every idle connection holds a PHP process
2. **mod_php** — no opcode cache, compiles every request
3. **No Redis** — every `get_option()` hits the database
4. **Untuned MariaDB** — 128MB buffer pool on a bloated DB

<!--
Speaker notes: [Point to the dashboard]. This is what a crash looks like in Grafana. CPU pegged at 100%. Load average of 10 on a 2-core machine — that means 8 processes in the queue for every 2 running. RAM near zero because the OS is desperately trying to free memory for the next Apache worker.
-->

---

## The Apache prefork math

$$\text{Max safe workers} = \frac{\text{RAM} - \text{OS overhead}}{\text{RAM per PHP process}}$$

$$= \frac{2048 \text{ MB} - 512 \text{ MB}}{32 \text{ MB}} = \textbf{47 workers}$$

> Worker 48 goes into the queue.
> Worker 100 gets a 503.

**The real problem:** Apache keeps idle workers alive — fully loaded PHP processes doing nothing, consuming 32MB each.

<!--
Speaker notes: This is the core issue. Apache prefork is a process-per-connection model. Even a visitor who's just reading a page, with their browser open and coffee in hand — that's 32MB of RAM doing nothing but waiting for them to click. 47 visitors. That's your limit.
-->

---

<!-- _class: act -->

# ACT II
## Stop the Bleeding

### Level 1 — Nginx + PHP-FPM + OPcache + Redis

<!--
Speaker notes: The fixes aren't exotic. They're well-known. They're just not the default. Let's apply them one by one and watch the dashboard react in real time.
-->

---

## Level 1 architecture

```
Browser
   │
   ▼
Nginx (event-driven, port 80)
   │  handles 10,000+ connections with minimal RAM
   │  static files served directly
   ▼
PHP-FPM pool (pm.max_children=20)
   │  only invoked for dynamic requests
   ▼
Redis (object cache)          MariaDB (tuned)
   │  70% of DB queries       512MB buffer pool
   │  served from RAM         slow log enabled
   ▼
OPcache (shared memory)
   compiled PHP bytecode — zero disk reads
```

<!--
Speaker notes: Three changes. Nginx replaces Apache. PHP-FPM decouples PHP from the web server. OPcache keeps compiled bytecode in shared memory. Redis caches DB queries. All four work together.
-->

---

## OPcache: the biggest single win

**Without OPcache (Level 0):**
```
Request → PHP reads file from disk → lexer → parser → compiler → execute
          ↑ repeated EVERY. SINGLE. REQUEST.
```

**With OPcache (Level 1):**
```
Request → PHP reads bytecode from shared memory → execute
          ↑ compiled once, cached forever (until deploy)
```

**Result: 98%+ cache hit rate within 30 seconds**

> `opcache.validate_timestamps=0` — never re-check disk in production

<!--
Speaker notes: OPcache is free, ships with PHP 5.5+, and is probably already installed on your server. If it's not enabled — enable it right now. Your server will immediately feel like you upgraded the CPU.
-->

---

## Redis object cache

**Without Redis:**
```
Every wp_query → MySQL → disk I/O → parse → PHP array
wp_get_option() called 300+ times per request
```

**With Redis:**
```
wp_get_option() → Redis GET → RAM → done (microseconds)
~70% of DB queries served from memory
```

**FPM pool math:**

$$\text{Concurrent PHP workers} = \frac{\text{RAM for PHP}}{32 \text{ MB}} = \frac{512 \text{ MB}}{32 \text{ MB}} = 20 \text{ workers}$$

> 20 workers handle 200 VUs because Nginx queues connections.
> Workers do real work — they don't idle holding connections.

<!--
Speaker notes: Redis-Cache plugin, wp redis enable, done. The object cache stores the result of every database query in Redis. The next request gets it from RAM. On a typical WordPress site with WooCommerce, about 70% of DB calls are cache-able.
-->

---

## DEMO — Same load, Level 1

```bash
make level-1   # stops Apache, starts Nginx + FPM + Redis
make load-crash
```

| Metric | Level 0 | Level 1 |
|---|---|---|
| Max VUs before crash | ~80 | 350+ |
| p95 latency at 100 VU | timeout | ~180ms |
| PHP-FPM queue depth | N/A (crash) | 0 |
| OPcache hit rate | 0% | 98%+ |
| Redis hit rate | 0% | ~70% |
| CPU at 200 VU | 100% (dead) | ~60% |

*(screenshot: act2-level1-fpm-workers.png)*

<!--
Speaker notes: [Switch to PHP-FPM dashboard]. See the Active Workers line — it's staying below 15 even at 200 VUs. Queue Depth is zero. That zero is the whole story. Nginx is absorbing the connections; FPM workers are only busy when there's real PHP work to do.
-->

---

<!-- _class: act -->

# ACT III
## Cache Everything

### Level 2 — FastCGI page cache + MariaDB tuning

<!--
Speaker notes: We've stopped the crash. Now let's make the server "bored" — so bored that 95% of requests never wake up PHP at all.
-->

---

## FastCGI page cache

**The insight:** most WordPress pages are **identical** for every anonymous visitor.

```nginx
fastcgi_cache_path /var/cache/nginx
    keys_zone=WORDPRESS:100m
    inactive=60m;

fastcgi_cache_key "$scheme$request_method$host$request_uri";
```

**Bypass rules (the important part):**
```nginx
# Never cache: logged-in users, cart, checkout, POST requests
if ($http_cookie ~* "wordpress_logged_in|woocommerce_cart") {
    set $skip_cache 1;
}
```

**Result: `X-Cache-Status: HIT` — PHP never runs**

<!--
Speaker notes: The cache lives on disk (or tmpfs). First visitor generates the page — FPM runs, PHP executes, MySQL queries, page rendered, stored in cache. Every visitor after that for the next hour: Nginx reads from disk, returns in 8ms. PHP is completely bypassed.
-->

---

## Watching the cache warm up

**http://localhost:3000/d/wp-nginx-cache**

| Time | HIT % | What's happening |
|---|---|---|
| 0:00 | 0% | Cache cold — all MISS |
| 0:30 | ~40% | k6 starting to re-request URLs |
| 1:00 | ~70% | Frequently visited pages cached |
| 2:00 | 90%+ | Cache hot ← **KEY SCREENSHOT** |

**PHP-FPM Offload panel:**
- Total RPS line: high (all traffic)
- PHP-FPM RPS line: near zero (only MISSes)

> The gap between the two lines = **your cache doing its job**

<!--
Speaker notes: [Open Nginx Cache dashboard]. Watch the donut chart. It starts solid red — all MISS. As k6 keeps hitting the same URLs, the green HIT slice grows. Within 2 minutes you'll see 90%+ HIT. The PHP-FPM workers drop to near idle. The server is practically bored.
-->

---

## MariaDB tuning

**Level 0 (baseline):**
```ini
innodb_buffer_pool_size = 128M   # too small for our bloated DB
```

**Level 2 (tuned):**
```ini
innodb_buffer_pool_size = 512M          # fits most of the DB in RAM
innodb_flush_log_at_trx_commit = 2      # fsync once/sec vs every commit
slow_query_log = 1
long_query_time = 0.5                   # catch queries > 500ms
```

**Result on Grafana MariaDB dashboard:**
- Buffer Pool Hit %: **> 99%** (reads from RAM, not disk)
- Threads Running: **< 5** (was spiking to 50+ at crash)

<!--
Speaker notes: The buffer pool is MySQL's RAM cache for table data and indexes. If it's too small, every query triggers a disk read. 512MB fits most of our 2500-post, 500-product database in RAM. Threads Running is the crash indicator — when it spikes, the DB is overwhelmed.
-->

---

<!-- _class: win -->

## 📸 Level 2 results

**500 VU · CPU: 15% · Load: 0.8 · Error rate: 0% · TTFB: 8ms**

*(screenshot: act3-cache-hot.png)*

<br>

> "95% of requests never touch PHP.
> The remaining 5% are admin, cart, logged-in users.
> TTFB went from 800ms to 8ms.
> The $12 VPS is practically bored."

<!--
Speaker notes: Same hardware. Same site. Same load — actually MORE load than what crashed Level 0. The difference is architectural. We're not asking PHP to do work it doesn't need to do.
-->

---

<!-- _class: act -->

# ACT IV
## The Hybrid Static Leap

### Level 4 — WordPress as a CMS, not a runtime

<!--
Speaker notes: For some content sites — blogs, documentation, marketing pages — we can go even further. What if WordPress never served a single page at all?
-->

---

## The static export concept

```bash
make static-build   # wget crawls every page → static/export/
make level-4        # Nginx serves static files from export/
```

**What happens:**
```
Build time:   WordPress renders every page once → saves HTML to disk
Runtime:      Nginx reads HTML from disk → zero PHP, zero MySQL
              Dynamic parts (cart, checkout) → proxied to WP origin
```

**The "dynamic islands" pattern:**
```
Static Nginx (port 8090)
   ├── /               → static HTML (0ms PHP)
   ├── /shop/          → static HTML (0ms PHP)
   └── /wp-json/       → proxy to WordPress origin (dynamic)
       /wc/store/cart  → proxy to WordPress origin (dynamic)
```

<!--
Speaker notes: Simply Static plugin crawls your WordPress site at build time — just like a search engine would — and saves every page as a static HTML file. Then you serve those files with Nginx. WordPress only runs when someone actually adds something to their cart.
-->

---

## DEMO — Side by side

Open two tabs:
- **http://localhost:8080** — WordPress origin (Level 2)
- **http://localhost:8090** — Static export

```bash
# Hammer only the static site
k6 run --vus 500 --duration 2m browse.js
  --env BASE_URL=http://static-site:80
```

| Metric | Level 2 | Level 4 (static) |
|---|---|---|
| p95 latency | 45ms | **< 5ms** |
| CPU at 500 VU | 15% | **< 2%** |
| PHP processes running | ~8 | **0** |
| Cart works? | ✅ | ✅ (dynamic island) |

<!--
Speaker notes: [Open both tabs]. You can see the static site loads before the spinner even starts on the WordPress tab. And the cart still works — because checkout and cart pages are proxied to the live WordPress instance. You get the best of both worlds.
-->

---

<!-- _class: win -->

## 📸 The mic drop

**500 VU · p95: 4ms · Error rate: 0% · WordPress CPU: 0%**

*(screenshot: act4-k6-static.png)*

<br>

> "WordPress as a CMS, not a runtime.
> Write your content in WordPress.
> Serve it from Nginx."

<!--
Speaker notes: 500 virtual users. 4ms p95 latency. Zero errors. The WordPress container is completely idle. This is the maximum you can get from a $12 VPS — and it's genuinely indistinguishable from a $5,000/month CDN setup for static content.
-->

---

## The full picture

| Level | Stack | Max stable VUs | p95 latency | Cost change |
|---|---|---|---|---|
| 0 | Apache + mod_php | ~50 | crashes | baseline |
| 1 | Nginx + FPM + OPcache + Redis | 300+ | ~180ms | $0 |
| 2 | Level 1 + FastCGI cache + MariaDB | 500+ | ~45ms | $0 |
| 3 | Level 2 + Cloudflare CDN | ∞ (edge) | ~20ms | ~$0–20/mo |
| 4 | Static export | 500+ | ~4ms | $0 |

<br>

> **Every improvement cost $0 in hardware.**
> It was configuration, architecture, and understanding bottlenecks.

<!--
Speaker notes: Let's recap. We went from crashing at 50 users to serving 500 users with sub-5ms response times. On the same $12 VPS. Without touching the hardware. Every single change was software — configuration, architecture, understanding where the bottleneck actually was.
-->

---

## Lessons learned

### 1. Measure first, optimize second
> "You can't fix what you can't see."
> Install Grafana + Prometheus before you need it.

### 2. The three layers of WordPress caching

```
OPcache     → PHP bytecode in shared memory   (always on)
Redis       → DB query results in RAM         (WP object cache)
FastCGI     → Full HTML pages on disk         (anonymous visitors)
```

### 3. pm.max_children is not "more = better"

$$\text{pm.max\_children} = \frac{\text{Available RAM for PHP}}{\text{RAM per worker}}$$

> Over-provision = OOM killer. Under-provision = queue. Do the math.

<!--
Speaker notes: Three things I want you to remember. First: you need dashboards before you need them — set up monitoring before Black Friday, not during. Second: WordPress has three distinct caching layers — most sites only use one. Third: FPM pool size is a math problem, not a guess.
-->

---

## Lessons learned (cont.)

### 4. The database is usually the real bottleneck
- Check `innodb_buffer_pool_size` — should be 70% of available RAM
- Enable `slow_query_log` — find queries > 500ms
- Watch **Threads Running** — if it spikes, you're in trouble
- Run `wp db optimize` regularly — orphaned meta and revisions add up

### 5. Static ≠ broken dynamic
> The "dynamic island" pattern: serve 95% of pages statically,
> proxy 5% (cart, checkout, account) to WordPress.

### 6. Cloudflare is free for personal sites
> Zero Trust tunnel + cache rules = your laptop serves the world.

<!--
Speaker notes: The database is almost always where WordPress falls over at scale. Not PHP. Not Nginx. MySQL. If you only do one thing after this talk: set your innodb_buffer_pool_size to 70% of available RAM and enable the slow query log.
-->

---

## The tools (all free, all open source)

| Tool | What it does |
|---|---|
| **k6** | Load generator — scriptable, Prometheus output |
| **Prometheus** | Time-series metrics storage |
| **Grafana** | Dashboards — 6 pre-built in the repo |
| **Redis** | Object cache — `wp redis enable` |
| **PHP OPcache** | Bytecode cache — already in your PHP |
| **Nginx FastCGI** | Full-page cache — built into Nginx |
| **Simply Static** | WP plugin — static site export |
| **Cloudflare** | CDN + Zero Trust tunnel — free tier |

> **Repo:** `github.com/NedkoHristov/WordPress-Europe-2026`
> `docker compose up` — everything starts. Every demo is reproducible.

<!--
Speaker notes: Everything I used today is free and open source. The repo has the full setup — docker compose up and you have WordPress, Grafana, Prometheus, k6, Redis, all 6 dashboards, all load test scripts. Clone it, run the demos, show your team.
-->

---

<!-- _class: title -->

# Thank you!

<br>

**Nedko Hristov**
Senior DevOps Engineer @ Nemetschek Bulgaria

🐙 github.com/NedkoHristov/WordPress-Europe-2026
🐦 @nedkohristov
💼 linkedin.com/in/nedkohristov

<br>

### Questions?

> *"The best time to add monitoring was before the crash.*
> *The second best time is now."*

<!--
Speaker notes: That's it. The repo is public, every file is documented, every command is in the Makefile. If you want to reproduce any of these numbers on your own machine, clone the repo and run make level-0. Thank you for being here!
-->
