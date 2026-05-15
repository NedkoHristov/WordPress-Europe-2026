#!/usr/bin/env node
/**
 * normalize-diagrams.js
 * Adds all fields required by excalidraw.com v0.17 to every diagrams/*.excalidraw file.
 * Run once (or after editing a diagram) to make files importable in excalidraw.com.
 *
 * Usage:  node scripts/normalize-diagrams.js
 */
'use strict';

const fs   = require('fs');
const path = require('path');

const DIAGRAMS_DIR = path.join(__dirname, '..', 'diagrams');
const NOW = Date.now();

function normalizeElement(el) {
  const base = {
    // Required by all element types
    isDeleted:     false,
    groupIds:      el.groupIds      ?? [],
    boundElements: el.boundElements ?? [],
    updated:       el.updated       ?? NOW,
    link:          el.link          ?? null,
    locked:        el.locked        ?? false,
    frameId:       el.frameId       ?? null,
    // Geometry defaults
    angle:         el.angle         ?? 0,
    opacity:       el.opacity       ?? 100,
    seed:          el.seed          ?? Math.floor(Math.random() * 2 ** 31),
    version:       el.version       ?? 1,
    versionNonce:  el.versionNonce  ?? Math.floor(Math.random() * 2 ** 31),
    // Stroke / fill defaults
    strokeColor:   el.strokeColor   ?? '#000000',
    backgroundColor: el.backgroundColor ?? 'transparent',
    fillStyle:     el.fillStyle     ?? 'hachure',
    strokeWidth:   el.strokeWidth   ?? 1,
    strokeStyle:   el.strokeStyle   ?? 'solid',
    roughness:     el.roughness     ?? 1,
    ...el,
  };

  if (el.type === 'text') {
    base.containerId  = el.containerId  ?? null;
    base.originalText = el.originalText ?? el.text ?? '';
    base.lineHeight   = el.lineHeight   ?? 1.25;
    base.autoResize   = el.autoResize   ?? true;
    base.textAlign    = el.textAlign    ?? 'left';
    base.verticalAlign = el.verticalAlign ?? 'top';
    // text elements don't use fillStyle/strokeWidth visually, but schema requires them
  }

  if (el.type === 'arrow' || el.type === 'line') {
    if (!base.points || base.points.length < 2) {
      base.points = [[0, 0], [el.width ?? 0, el.height ?? 0]];
    }
    base.lastCommittedPoint = el.lastCommittedPoint ?? null;
    base.startBinding       = el.startBinding       ?? null;
    base.endBinding         = el.endBinding         ?? null;
    base.startArrowhead     = el.startArrowhead     ?? null;
    base.endArrowhead       = el.endArrowhead       ?? (el.type === 'arrow' ? 'arrow' : null);
    base.elbowed            = el.elbowed            ?? false;
  }

  if (el.type === 'rectangle' || el.type === 'ellipse' || el.type === 'diamond') {
    base.roundness = el.roundness ?? null;
  }

  return base;
}

const files = fs.readdirSync(DIAGRAMS_DIR).filter(f => f.endsWith('.excalidraw')).sort();
let changed = 0;

for (const file of files) {
  const inPath = path.join(DIAGRAMS_DIR, file);
  let data;
  try {
    data = JSON.parse(fs.readFileSync(inPath, 'utf8'));
  } catch (e) {
    console.error('  ERROR parsing ' + file + ': ' + e.message);
    continue;
  }

  const normalized = {
    type:     'excalidraw',
    version:  2,
    source:   'https://excalidraw.com',
    elements: (data.elements || []).map(normalizeElement),
    appState: {
      viewBackgroundColor: '#ffffff',
      ...data.appState,
    },
    files: data.files ?? {},
  };

  const out = JSON.stringify(normalized, null, 2);
  fs.writeFileSync(inPath, out, 'utf8');
  console.log('  normalized  ' + file);
  changed++;
}

console.log('\n  Done: ' + changed + ' files normalized');
