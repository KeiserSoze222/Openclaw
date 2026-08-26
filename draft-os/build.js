#!/usr/bin/env node
// Build: inline CSS + JS modules into a single self-contained index.html.
// No bundler, no dependencies. `node build.js` emits index.html next to this file.
// `node build.js --watch` rebuilds on change (simple poll).
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, 'src');
// Load order matters: later modules read earlier ones off the shared namespace.
const JS_ORDER = [
  'js/core.js',
  'js/data.js',
  'js/normalize.js',
  'js/pickorder.js',
  'js/parser.js',
  'js/board.js',
  'js/playbook.js',
  'js/survival.js',
  'js/recommend.js',
  'js/buildpath.js',
  'js/simulator.js',
  'js/statestore.js',
  'js/selftest.js',
  'js/app.js'
];

function build() {
  const template = fs.readFileSync(path.join(SRC, 'template.html'), 'utf8');
  const css = fs.readFileSync(path.join(SRC, 'css', 'app.css'), 'utf8');
  const js = JS_ORDER.map(f => {
    const body = fs.readFileSync(path.join(SRC, f), 'utf8');
    return `/* ===== ${f} ===== */\n${body}`;
  }).join('\n');
  const out = template
    .replace('/*__INLINE_CSS__*/', () => css)
    .replace('/*__INLINE_JS__*/', () => js);
  fs.writeFileSync(path.join(__dirname, 'index.html'), out);
  console.log(`built index.html (${(out.length / 1024).toFixed(1)} KB)`);
}

build();

if (process.argv.includes('--watch')) {
  console.log('watching src/ for changes... open index.html directly in a browser (file:// works).');
  let last = 0;
  setInterval(() => {
    let latest = 0;
    const walk = d => fs.readdirSync(d).forEach(f => {
      const p = path.join(d, f);
      const st = fs.statSync(p);
      if (st.isDirectory()) walk(p);
      else latest = Math.max(latest, st.mtimeMs);
    });
    walk(SRC);
    if (latest > last) { last = latest; try { build(); } catch (e) { console.error(e.message); } }
  }, 500);
}
