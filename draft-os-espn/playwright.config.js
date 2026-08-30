// Headless e2e against the built index.html over file://.
const { defineConfig } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Prefer the environment's pre-installed Chromium when the @playwright/test
// version doesn't match the browsers on disk (never download in CI).
function findChromium() {
  if (process.env.CHROMIUM_PATH) return process.env.CHROMIUM_PATH;
  const base = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  try {
    for (const dir of fs.readdirSync(base)) {
      if (dir.startsWith('chromium-')) {
        const p = path.join(base, dir, 'chrome-linux', 'chrome');
        if (fs.existsSync(p)) return p;
      }
    }
    const plain = path.join(base, 'chromium');
    if (fs.existsSync(plain)) return plain;
  } catch (e) { /* fall through to Playwright's default resolution */ }
  return null;
}

const exe = findChromium();

module.exports = defineConfig({
  testDir: './e2e',
  timeout: 60000,
  use: {
    launchOptions: exe ? { executablePath: exe } : {}
  }
});
