// Node wrapper around the shared self-test suite (src/js/selftest.js).
// The same suite runs in the browser via Settings -> Run self-test.
const { test } = require('node:test');
const assert = require('node:assert');
const path = require('path');

// Load modules in dependency order onto the shared DraftOS namespace.
[
  'core', 'data', 'normalize', 'pickorder', 'parser', 'board', 'playbook',
  'survival', 'overlay', 'recommend', 'buildpath', 'simulator', 'statestore', 'selftest'
].forEach(m => require(path.join(__dirname, '..', 'src', 'js', `${m}.js`)));

const NS = globalThis.DraftOS;
const results = NS.runSelfTests();

for (const r of results) {
  test(r.name, () => {
    assert.ok(r.pass, r.detail || 'failed');
  });
}

// Node-only: PWA build artifacts (npm test builds before running this file).
test('build artifacts: sw.js/manifest/icon emitted; SW registration is protocol-guarded', () => {
  const fs = require('fs');
  const root = path.join(__dirname, '..');
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  assert.ok(fs.existsSync(path.join(root, 'manifest.webmanifest')), 'manifest emitted');
  assert.ok(fs.existsSync(path.join(root, 'icon.svg')), 'icon emitted');
  assert.match(sw, /draftos-espn-[0-9a-f]{10}/, 'distinct ESPN cache name with the build hash');
  assert.ok(!sw.includes('__HASH__'), 'hash placeholder replaced');
  assert.ok(html.includes('manifest.webmanifest'), 'manifest linked');
  assert.ok(html.includes('serviceWorker') && html.includes('location.protocol'),
    'SW registration exists and checks the protocol (file:// stays SW-free)');
});
