// End-to-end smoke of the ESPN single-file app over file://.
const { test, expect } = require('@playwright/test');
const path = require('path');

const FILE_URL = 'file://' + path.join(__dirname, '..', 'index.html');

const QUEUE_20 = [
  'TIER 1',
  '1. Alpha RB One RB DET 6',
  '2. Alpha WR Two WR CIN 6',
  '3. Alpha RB Three RB SF 8',
  '4. Alpha WR Four WR LAR 11',
  '5. Alpha RB Five RB IND 13',
  'TIER 2',
  '6. Beta WR Six WR DET 6',
  '7. Beta RB Seven RB BUF 7',
  '8. Beta WR Eight WR DAL 14',
  '9. Beta RB Nine RB MIA 6',
  '10. Beta WR Ten WR ATL 11',
  '11. Beta RB Eleven RB CIN 6',
  '12. Beta WR Twelve WR LAC 7',
  '13. Beta RB Thirteen RB PHI 10',
  '14. Beta WR Fourteen WR NE 11',
  '15. Gamma RB Fifteen RB HOU 8',
  '16. Gamma WR Sixteen WR LV 13',
  '17. Gamma RB Seventeen RB DAL 14',
  '18. Gamma WR Eighteen WR MIN 6',
  '19. Gamma RB Nineteen RB CHI 10',
  '20. Gamma WR Twenty WR TEN 9'
].join('\n');

test('ESPN full draft flow over file://', async ({ page }) => {
  const dialogs = [];
  page.on('dialog', d => { dialogs.push(d.message()); d.accept(); });
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));

  await page.goto(FILE_URL);
  await page.evaluate(() => localStorage.clear());
  await page.reload();

  // 1. Boot: pick 1 on the clock, sample queue loaded, no keepers pre-filled
  await expect(page.locator('#pickInfo')).toContainText('Pick 1');
  await expect(page.locator('#main')).toContainText('Jahmyr Gibbs');
  await expect(page.locator('#rapidCard')).toBeVisible();

  // 2. Keepers tab: 10 preloaded blank rows; setting Jim/Warren to R8
  //    resolves pick 88; clearing it restores the pick
  await page.click('#tabbar button[data-tab="keepers"]');
  await expect(page.locator('#keeperRows .fieldRow')).toHaveCount(10);
  await expect(page.locator('#keeperRows input[data-kf="player"]').nth(3)).toHaveValue('Rashid Shaheed'); // Jeff row
  await expect(page.locator('#keeperRows')).toContainText('not kept');
  const jimRound = () => page.locator('#keeperRows .fieldRow').nth(8).locator('input[data-kf="round"]'); // Jim / Tyler Warren
  await expect(page.locator('#keeperRows input[data-kf="player"]').nth(8)).toHaveValue('Tyler Warren');
  await jimRound().fill('8');
  await jimRound().blur();
  await expect(page.locator('#keeperRows .fieldRow').nth(8)).toContainText('pick 88');
  await jimRound().fill('');
  await jimRound().blur();
  await expect(page.locator('#keeperRows .fieldRow').nth(8)).toContainText('not kept');

  // 3. Settings pre-filled: byes + ME radio on slot 4; in-page self-test green
  await page.click('#tabbar button[data-tab="settings"]');
  await expect(page.locator('#set_byes')).toHaveValue(/BUF 7/);
  await expect(page.locator('input[name="meRadio"][data-me="4"]')).toBeChecked();
  await page.click('#selfTestBtn');
  await expect(page.locator('#selfTestOut')).toContainText(/(\d+)\/\1 passed/, { timeout: 30000 });
  await expect(page.locator('#selfTestOut')).not.toContainText('FAIL');

  // 4. Paste a 20-player queue -> replaces the sample
  await page.click('#tabbar button[data-tab="queue"]');
  await page.fill('#queuePaste', QUEUE_20);
  await page.click('#queueReplace');
  await expect(page.locator('#main')).toContainText('Alpha RB One');
  await expect(page.locator('#main')).not.toContainText('Jahmyr Gibbs');

  // 5. Picks 1-3 to other teams -> my pick 4; five-name card + ESPN queue line
  await page.click('#tabbar button[data-tab="draft"]');
  for (let i = 0; i < 3; i++) {
    await page.locator('#availList .playerRow').first().locator('button', { hasText: 'Other' }).click();
  }
  await expect(page.locator('#pickInfo')).toContainText('Pick 4');
  await expect(page.locator('#pickInfo')).toContainText('YOU ARE ON THE CLOCK');
  await expect(page.locator('#recCard')).toContainText('ESPN queue should be:');
  await expect(page.locator('#recCard')).toContainText('Alt2');
  await expect(page.locator('#recCard')).toContainText('Alt5');

  // 6. "I picked" -> always-on confirm; roster + plan update; undo; persistence
  const primaryName = (await page.locator('#recCard .recName').first().textContent()).trim();
  await page.locator('#recCard button.primaryBtn').click();
  expect(dialogs.some(m => m.includes('Confirm YOUR pick'))).toBe(true);
  await expect(page.locator('#main')).toContainText('(1/16)');
  await expect(page.locator('#main')).toContainText(primaryName);
  await page.click('#undoBtn');
  await expect(page.locator('#pickInfo')).toContainText('Pick 4');
  await expect(page.locator('#main')).toContainText('(0/16)');
  await page.locator('#recCard button.primaryBtn').click();
  await expect(page.locator('#main')).toContainText('(1/16)');
  await page.reload();
  await expect(page.locator('#pickInfo')).toContainText('Pick 5');
  await expect(page.locator('#main')).toContainText('(1/16)');

  // 7. SETUP GUARD: changing my slot after marked picks prompts + recomputes
  await page.click('#tabbar button[data-tab="settings"]');
  await page.locator('input[name="meRadio"][data-me="5"]').check();
  const dialogCountBefore = dialogs.length;
  await page.click('#saveSettings');
  expect(dialogs.slice(dialogCountBefore).some(m => m.includes('recompute'))).toBe(true);
  await page.click('#tabbar button[data-tab="draft"]');
  await expect(page.locator('#pickInfo')).toContainText('Pick 5'); // board intact
  await expect(page.locator('#main')).toContainText('(0/16)');     // pick 4 no longer mine (I am TC now)

  // 8. Storage isolation: only espn:-prefixed keys; no SW over file://
  const keys = await page.evaluate(() => Object.keys(localStorage));
  expect(keys.length).toBeGreaterThan(0);
  expect(keys.every(k => k.startsWith('espn:'))).toBe(true);
  const hasSW = await page.evaluate(() => !!(navigator.serviceWorker && navigator.serviceWorker.controller));
  expect(hasSW).toBe(false);

  expect(errors).toEqual([]);
});
