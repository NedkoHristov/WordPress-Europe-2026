# Lecture Plan — Stress Testing and Scaling WordPress on a $12 VPS

> **Event:** WordPress Europe 2026, Kraków
> **Duration:** ~50 min talk + 10 min Q&A
> **Speaker:** Nedko Hristov, Senior DevOps Engineer @ Nemetschek Bulgaria
> **Format:** Slide deck with live Grafana screenshots. No live demo — all screenshots pre-captured.

---

## Pre-lecture checklist

```bash
# Run this ONCE before you leave — fully autonomous, ~25 min
bash scripts/full-run.sh

# Outputs:
#   screenshots/l0-*.png          Level 0 Apache baseline (7 dashboards)
#   screenshots/l0-crash-*.png    Level 0 crash under 500 VU (7 dashboards)
#   screenshots/l1-*.png          Level 1 Nginx+FPM+Redis (7 dashboards)
#   screenshots/l2-*.png          Level 2 FastCGI cache (7 dashboards)
#   SLIDES-RICH.html              HTML presentation (arrow keys + F for fullscreen)
#   SLIDES-RICH.pdf               PDF with embedded images
#   SLIDES-RICH.pptx              Pixel-perfect PPTX (images)
#   SLIDES-RICH-editable.pptx     Editable PPTX (LibreOffice conversion)
```

**Present from:** `SLIDES-RICH.html` in browser (best quality) or upload to Google Slides via PPTX.

---

## Lecture structure — slide by slide

### OPENING (~3 min, slides 1–6)

| # | Slide title | What to say | Screenshot |
|---|-------------|-------------|------------|
| 1 | **Title** | "Stress Testing and Scaling WordPress on a $12 VPS" — introduce yourself, the talk, the repo. Everything is reproducible with `docker compose up`. | — |
| 2 | **The setup** | Walk through what we're testing: WordPress + WooCommerce, 2,500 posts, 500 products. A real site, not a toy. 2 GB RAM, 2 vCPU — this is a €12/month VPS. | — |
| 3 | **The journey** | Preview the 4 levels as a table. Key message: same VPS, same site, same k6 script. Every improvement is configuration, not hardware. p95 goes from "crash" to 3 ms. | — |
| 4 | **Key concept: VU** | Explain Virtual Users. 50 VUs ≠ 50 visitors. 50 VUs = 50 concurrent loops each making ~1 req/s = ~50 req/s sustained. Real traffic is bursty; this is worst case. | — |
| 5 | **Key metric definitions** | Quick glossary: p95, RPS, error rate, OPcache hit rate. "When I say p95 = 800ms, it means 95% of requests finished in under 800ms." | — |
| 6 | **Observability stack** | Show the stack: Prometheus, Grafana, 8 exporters, Loki. "Every number on screen is a real metric from a real process. No synthetic benchmarks." | — |

---

### ACT I — THE CRASH (~10 min, slides 7–11)

| # | Slide title | What to say | Screenshot |
|---|-------------|-------------|------------|
| 7 | **ACT I — The Crash** | Act title card. Build tension: "Let's see what happens when real traffic hits a default WordPress install." | — |
| 8 | **How Apache prefork works** | Explain the process model: 1 process per request. MaxRequestWorkers=150. Each WP request = 300+ DB queries, 30-50 MB RAM. "This model was designed for static files in 1996." | — |
| 9 | **The Apache math** | Show the formula: `Max safe workers = (RAM - overhead) / RAM per worker = (2048 - 512) / 32 = 47`. "The crash happens at a completely predictable, calculable user count." | — |
| 10 | **📸 Level 0 — The Crash** | This is the money shot. Walk through: green line (req/s) goes up then DOWN while blue VUs keep climbing. "The server stopped responding. Not an error — arithmetic." | **→ PUT `screenshots/l0-crash-00-demo.png` HERE** — shows Apache crashing under 500 VU ramp, the moment req/s drops while VUs keep rising |
| 11 | **Reading the crash** | Table of 8 metrics from the crash dashboard. Point to each: Error Rate 42%, p95 9.2s, DB threads 50 (max). "Every metric tells the same story: saturation." | — |

> **Speaker note for slide 10:** Pause here. Let the audience absorb the chart. Point to the exact moment req/s starts falling while VUs keep rising. That's the crash. Ask: "Who has seen this in production?"

---

### ACT II — STOP THE BLEEDING (~12 min, slides 12–20)

| # | Slide title | What to say | Screenshot |
|---|-------------|-------------|------------|
| 12 | **ACT II — Stop the Bleeding** | Act title card. "Three changes. Zero cost. No code." | — |
| 13 | **Level 1 — Three changes** | List: (1) Replace Apache with Nginx+PHP-FPM, (2) Enable OPcache, (3) Add Redis object cache. All `apt install` + config. | — |
| 14 | **OPcache — biggest free win** | Two-panel comparison. Without: `stat()` + parse + compile every request. With: compile once → shared memory → skip 60% of CPU. "This is the single biggest free performance win in PHP." | — |
| 15 | **📸 Level 1 — Demo Dashboard** | Walk through: RPS stable at ~200, p95 ~800ms, 0% errors. "The crash is gone. But every request still hits PHP and MySQL." | **→ PUT `screenshots/l1-00-demo.png` HERE** — shows Level 1 stable at 50 VU: RPS ~200, p95 ~800ms, 0% errors |
| 16 | **Reading Level 1** | Detailed metric breakdown table. 10 active workers / 10 idle. MySQL 12.5 threads. "Workers are busy but not saturated." | — |
| 17 | **L0 → L1: the jump** | Comparison table: p95 from 9.2s to 800ms, RPS from 8→200, errors from 42%→0%. "Same VPS. Same site. Three config changes." | — |
| 18 | **📸 Level 1 — PHP-FPM Workers** | Show the FPM worker chart. "10 active, 10 idle. Queue depth zero. We have headroom. But we can do better." | **→ PUT `screenshots/l1-02-php-fpm.png` HERE** — shows FPM workers: 10 active / 10 idle, queue depth 0 |
| 19 | **📸 Level 1 — Redis** | Show 82% hit rate, 6K ops/s. "82% of database lookups never hit MySQL." | **→ PUT `screenshots/l1-05-redis.png` HERE** — shows Redis: 82% hit rate, 6K ops/s |
| 20 | **What Redis is doing** | Explain: WP_Query → Redis HIT → 0.1ms (vs 8ms from MySQL). "Redis didn't prevent the L0 crash — it delays the crash, doesn't eliminate it." | — |

> **Speaker note for slide 17:** This is a powerful moment. Same hardware, same code, but p95 went from 9.2 seconds to 800 milliseconds. Let that sink in.

---

### ACT III — CACHE EVERYTHING (~12 min, slides 21–31)

| # | Slide title | What to say | Screenshot |
|---|-------------|-------------|------------|
| 21 | **ACT III — Cache Everything** | Act title card. "Most WordPress pages return identical HTML for every anonymous visitor." | — |
| 22 | **The key insight** | "Home page. Category. Blog post. Shop. PHP runs. MySQL queries. The output is the same HTML every time. Why keep generating it?" | — |
| 23 | **Level 2 — nginx config** | Show the `fastcgi_cache` config. Key parts: `fastcgi_cache_key`, `$skip_cache` for logged-in users/WooCommerce, `add_header X-Cache-Status`. | — |
| 24 | **📸 Level 2 — Demo Dashboard** | Walk through: RPS 2000+, p95 3ms, 0% errors. "Same 50 VUs. Same VPS. p95 went from 800ms to 3ms." | **→ PUT `screenshots/l2-00-demo.png` HERE** — shows Level 2 at 50 VU: RPS 2000+, p95 3ms, 0% errors |
| 25 | **Reading Level 2** | Detailed metrics. Key callout: FPM workers only 3 active (vs 10 at L1). "70% of requests never leave nginx." | — |
| 26 | **L0 → L1 → L2: progression** | Three-level comparison table. The story in one slide: crash → stable → fast. DB threads: 50 → 12.5 → 3. | — |
| 27 | **📸 Level 2 — Nginx Cache** | "This is the money slide." Show the gap between total requests and FPM requests. "That gap is PHP execution that never happened." | **→ PUT `screenshots/l2-04-nginx-cache.png` HERE** — shows the gap between nginx total requests and FPM pass-through — **the money slide** |
| 28 | **FPM offload explained** | Walk through the math: 9.94K total requests, only 3K hit FPM. "Scale that to a Black Friday spike — 10× traffic hits nginx, not your server." | — |
| 29 | **📸 Level 2 — PHP-FPM** | "Steady at 10-11 workers. Queue depth zero. CPU idle. The bottleneck is gone." | **→ PUT `screenshots/l2-02-php-fpm.png` HERE** — shows FPM workers steady at 10-11, queue 0, CPU idle |
| 30 | **MariaDB tuning** | Side-by-side: baseline (128MB buffer pool) vs tuned (512MB buffer pool, slow queries logged at 1s). "Two config lines." | — |
| 31 | **L1 vs L2 — real numbers** | L2 does more work with less resources. 70% of requests cached. MariaDB has headroom. | — |

> **Speaker note for slide 27:** Point at the gap between the two lines on the nginx cache chart. Say: "This gap is PHP execution that never happened. Every request in this gap was served as a static file from nginx's memory. Zero PHP. Zero MySQL."

---

### ACT IV — WHAT'S NEXT (~8 min, slides 32–38)

| # | Slide title | What to say | Screenshot |
|---|-------------|-------------|------------|
| 32 | **What's Next? — The Static Leap** | Act title card. "What if we remove PHP from the picture entirely?" | — |
| 33 | **Level 4 — Simply Static concept** | `wp plugin install simply-static --activate` + `wp simply-static run`. Crawls every URL → flat HTML. "WordPress becomes a CMS, not a runtime." | — |
| 34 | **Level 4 — expected numbers** | Comparison table: L2 vs L4. p95 from 3ms to sub-1ms. RPS from 2K to 10K+. CPU near zero. "The trade-off: content is stale until next export." | — |
| 35 | **Level 3 — Cloudflare CDN** | DNS cutover, zero code changes. VPS becomes the origin handling 10-20% of peak load. Free plan. | — |
| 36 | **Cloudflare Free Plan** | What you get: cache rules, HTTPS, 100K worker requests/day. Show the cache rule config. "Same bypass logic as FastCGI cache." | — |
| 37 | **The full picture** | All 5 levels in one table. Key message: "Every improvement except Cloudflare costs exactly $0. Configuration, architecture, understanding the bottleneck." | — |
| 38 | **Cache hierarchy** | Visual: Browser → Cloudflare → Nginx FastCGI → Redis → MariaDB. Each layer absorbs 70-95% of what reaches it. | — |

---

### CLOSING (~5 min, slides 39–41)

| # | Slide title | What to say | Screenshot |
|---|-------------|-------------|------------|
| 39 | **Lessons learned** | Key takeaways — configuration before code, measure before optimising, automate everything. | — |
| 40 | **The tools** | All free, all open source. Docker, k6, Prometheus, Grafana, nginx, Redis, MariaDB. | — |
| 41 | **Thank you + Questions** | Repo link, QR code, social links. Open for Q&A. | — |

---

## Screenshot quick reference

| Screenshot file | Slide | Shows |
|-----------------|-------|-------|
| `screenshots/l0-crash-00-demo.png` | 10 (ACT I) | Apache crashing under 500 VU — the moment req/s drops while VUs rise |
| `screenshots/l1-00-demo.png` | 15 (ACT II) | Level 1 stable at 50 VU — RPS ~200, p95 ~800ms, 0% errors |
| `screenshots/l1-02-php-fpm.png` | 18 (ACT II) | FPM workers: 10 active / 10 idle, queue depth 0 |
| `screenshots/l1-05-redis.png` | 19 (ACT II) | Redis: 82% hit rate, 6K ops/s |
| `screenshots/l2-00-demo.png` | 24 (ACT III) | Level 2 at 50 VU — RPS 2000+, p95 3ms, 0% errors |
| `screenshots/l2-04-nginx-cache.png` | 27 (ACT III) | Nginx cache: the gap between total req and FPM — **money slide** |
| `screenshots/l2-02-php-fpm.png` | 29 (ACT III) | FPM workers steady at 10-11, queue 0, CPU idle |

---

## Timing guide

| Section | Duration | Cumulative |
|---------|----------|------------|
| Opening (slides 1–6) | 3 min | 3 min |
| ACT I — The Crash (slides 7–11) | 10 min | 13 min |
| ACT II — Stop the Bleeding (slides 12–20) | 12 min | 25 min |
| ACT III — Cache Everything (slides 21–31) | 12 min | 37 min |
| ACT IV — What's Next (slides 32–38) | 8 min | 45 min |
| Closing + Q&A (slides 39–41) | 5 + 10 min | 60 min |

---

## Key phrases to remember

- **Slide 10 (the crash):** "The server stopped responding. Not an error — arithmetic."
- **Slide 17 (the jump):** "Same VPS. Same site. Three config changes."
- **Slide 22 (the insight):** "Most WordPress pages return identical HTML for every visitor. Why keep generating it?"
- **Slide 27 (money slide):** "This gap is PHP execution that never happened."
- **Slide 37 (closing):** "Every improvement except Cloudflare costs exactly zero dollars."
