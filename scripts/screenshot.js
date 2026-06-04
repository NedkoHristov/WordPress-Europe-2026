const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const PREFIX  = process.argv[2] || 'snap';
const FROM    = process.argv[3] || (Date.now() - 15 * 60 * 1000);
const TO      = process.argv[4] || Date.now();
const OUT_DIR = path.join(__dirname, '..', 'screenshots');
const GRAFANA = 'http://localhost:3000';

const DASHBOARDS = [
  { uid: 'wp-demo',        label: '00-demo'       },  // primary presentation dashboard
  { uid: 'wp-k6-live',     label: '06-k6-live'    },
  { uid: 'wp-overview',    label: '01-overview'   },
  { uid: 'wp-php-fpm',     label: '02-php-fpm'    },
  { uid: 'wp-mysql',       label: '03-mysql'      },
  { uid: 'wp-nginx-cache', label: '04-nginx-cache' },
  { uid: 'wp-redis',       label: '05-redis'      },
];

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  // Rotate only the screenshots for this PREFIX into a dated backup folder
  const existing = fs.readdirSync(OUT_DIR).filter(f => f.endsWith('.png') && f.startsWith(PREFIX + '-'));
  if (existing.length > 0) {
    const now = new Date();
    const dd  = String(now.getDate()).padStart(2, '0');
    const mm  = String(now.getMonth() + 1).padStart(2, '0');
    const yy  = String(now.getFullYear()).slice(-2);
    const dateStr = dd + mm + yy;
    let idx = 1;
    let backupDir;
    do {
      backupDir = path.join(OUT_DIR, `screenshots-${dateStr}-${String(idx).padStart(3, '0')}`);
      idx++;
    } while (fs.existsSync(backupDir));
    fs.mkdirSync(backupDir, { recursive: true });
    for (const f of existing) {
      fs.renameSync(path.join(OUT_DIR, f), path.join(backupDir, f));
    }
    console.log(`Rotated ${existing.length} screenshot(s) → ${path.basename(backupDir)}/`);
  }

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await (await browser.newContext({ viewport: { width: 1920, height: 1080 } })).newPage();

  await page.goto(GRAFANA + '/login', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.fill('input[name="user"]', 'admin');
  await page.fill('input[name="password"]', 'grafana');
  await page.click('button[type="submit"]');
  await page.waitForTimeout(2000);

  for (const db of DASHBOARDS) {
    const url  = GRAFANA + '/d/' + db.uid + '?from=' + FROM + '&to=' + TO + '&refresh=';
    const file = path.join(OUT_DIR, PREFIX + '-' + db.label + '.png');
    console.log('-> ' + db.uid);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(7000);
    await page.screenshot({ path: file, fullPage: true });
    console.log('   saved: ' + file);
  }

  await browser.close();
  console.log('Done.');
})();
