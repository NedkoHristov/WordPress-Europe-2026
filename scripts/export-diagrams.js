#!/usr/bin/env node
/**
 * export-diagrams.js
 * Converts every diagrams/*.excalidraw → diagrams/*.png
 * Uses Playwright + Excalidraw UMD bundle from CDN.
 *
 * Usage:  node scripts/export-diagrams.js [--force]
 */
'use strict';

const { chromium } = require('playwright');
const fs   = require('fs');
const path = require('path');

const DIAGRAMS_DIR = path.join(__dirname, '..', 'diagrams');
const CHROME_PATH  = process.env.CHROME_PATH || undefined;
const FORCE        = process.argv.includes('--force');

const EXCALIDRAW_CDN = 'https://unpkg.com/@excalidraw/excalidraw@0.17.6/dist/excalidraw.production.min.js';

const RENDER_HTML = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>* { margin:0; padding:0; } body { background:#fff; }</style>
  <script src="https://unpkg.com/react@18.3.1/umd/react.production.min.js"></script>
  <script src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js"></script>
  <script src="${EXCALIDRAW_CDN}"></script>
</head>
<body>
  <div id="root"></div>
  <script>
    window.__exportDone = false;
    window.__pngBytes   = null;
    window.__exportError = null;
    window.runExport = async function(elementsJson, appStateJson) {
      const elements = JSON.parse(elementsJson).map(el => {
        // Normalize elements for Excalidraw v0.17 compatibility
        const base = {
          angle: 0, opacity: 100, seed: 1,
          strokeStyle: 'solid', strokeWidth: el.strokeWidth || 1,
          roughness: el.roughness !== undefined ? el.roughness : 1,
          fillStyle: el.fillStyle || 'hachure',
          backgroundColor: el.backgroundColor || 'transparent',
          strokeColor: el.strokeColor || '#000000',
          ...el,
        };
        // Linear elements need a points array
        if ((el.type === 'arrow' || el.type === 'line') && !el.points) {
          base.points = [[0, 0], [el.width || 0, el.height || 0]];
        }
        return base;
      });
      const appState = JSON.parse(appStateJson);
      try {
        const blob = await ExcalidrawLib.exportToBlob({
          elements,
          appState: {
            ...appState,
            exportBackground: false,
            exportWithDarkMode: false,
          },
          files: null,
          // No getDimensions — Excalidraw computes natural bounding box automatically
        });
        const buf = await blob.arrayBuffer();
        window.__pngBytes = Array.from(new Uint8Array(buf));
        window.__exportDone = true;
      } catch (e) {
        window.__exportError = e.message;
        window.__exportDone  = true;
      }
    };
  </script>
</body>
</html>`;

async function main() {
  const files = fs.readdirSync(DIAGRAMS_DIR)
    .filter(f => f.endsWith('.excalidraw'))
    .sort();

  if (files.length === 0) {
    console.log('No .excalidraw files found in diagrams/');
    return;
  }

  const browser = await chromium.launch({
    executablePath: CHROME_PATH,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();
  console.log('  Loading Excalidraw renderer (CDN)...');
  await page.setContent(RENDER_HTML, { waitUntil: 'networkidle', timeout: 60000 });

  const libOk = await page.evaluate(() =>
    typeof ExcalidrawLib !== 'undefined' && typeof ExcalidrawLib.exportToBlob === 'function');
  if (!libOk) {
    console.error('  ERROR: ExcalidrawLib did not load. Check network connectivity.');
    await browser.close();
    process.exit(1);
  }
  console.log('  Excalidraw ready');

  let ok = 0, skip = 0, fail = 0;

  for (const file of files) {
    const inPath  = path.join(DIAGRAMS_DIR, file);
    const outPath = path.join(DIAGRAMS_DIR, file.replace(/\.excalidraw$/, '.png'));

    if (!FORCE && fs.existsSync(outPath)) {
      const inMtime  = fs.statSync(inPath).mtimeMs;
      const outMtime = fs.statSync(outPath).mtimeMs;
      if (outMtime >= inMtime) {
        console.log('  skip  ' + file + '  (PNG up to date)');
        skip++;
        continue;
      }
    }

    let data;
    try {
      data = JSON.parse(fs.readFileSync(inPath, 'utf8'));
    } catch (e) {
      console.error('  ERROR parsing ' + file + ': ' + e.message);
      fail++;
      continue;
    }

    if (!data.elements || data.elements.length === 0) {
      console.warn('  WARN  ' + file + ': no elements, skipping');
      skip++;
      continue;
    }

    await page.evaluate(() => {
      window.__exportDone = false;
      window.__pngBytes   = null;
      window.__exportError = null;
    });

    await page.evaluate(
      ([el, as]) => window.runExport(el, as),
      [JSON.stringify(data.elements), JSON.stringify(data.appState || {})]
    );

    await page.waitForFunction(() => window.__exportDone === true, { timeout: 15000 });

    const exportError = await page.evaluate(() => window.__exportError);
    if (exportError) {
      console.error('  ERROR  ' + file + ': ' + exportError);
      fail++;
      continue;
    }

    const bytes = await page.evaluate(() => window.__pngBytes);
    if (!bytes || bytes.length === 0) {
      console.error('  ERROR  ' + file + ': empty output');
      fail++;
      continue;
    }

    fs.writeFileSync(outPath, Buffer.from(bytes));
    console.log('  export  ' + file + '  ->  ' + path.basename(outPath) + '  (' + (bytes.length / 1024).toFixed(0) + ' KB)');
    ok++;
  }

  await browser.close();

  console.log('\n  Done: ' + ok + ' exported, ' + skip + ' skipped, ' + fail + ' failed');
  if (fail > 0) process.exit(1);
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
