// Node wrapper around the shared self-test suite (src/js/selftest.js).
// The same suite runs in the browser via Settings -> Run self-test.
const { test } = require('node:test');
const assert = require('node:assert');
const path = require('path');

// Load modules in dependency order onto the shared DraftOS namespace.
[
  'core', 'data', 'normalize', 'pickorder', 'parser', 'board', 'playbook',
  'survival', 'recommend', 'buildpath', 'simulator', 'statestore', 'selftest'
].forEach(m => require(path.join(__dirname, '..', 'src', 'js', `${m}.js`)));

const NS = globalThis.DraftOS;
const results = NS.runSelfTests();

for (const r of results) {
  test(r.name, () => {
    assert.ok(r.pass, r.detail || 'failed');
  });
}
