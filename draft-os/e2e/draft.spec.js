// End-to-end smoke of the single-file app over file:// (Addendum B1).
const { test, expect } = require('@playwright/test');
const path = require('path');

const FILE_URL = 'file://' + path.join(__dirname, '..', 'index.html');

const QUEUE_20 = [
  'TIER 1',
  '1. Alpha RB One RB DET 6',
  '2. Alpha WR Two WR CIN 6',
  '3. Alpha RB Three RB SF 8',
  '4. Alpha WR Four WR LAR 11',
  '5. Alpha QB Five QB BAL 13',
  'TIER 2',
  '6. Beta RB Six RB IND 13',
  '7. Beta WR Seven WR DET 6',
  '8. Beta TE Eight TE ARI 14',
  '9. Beta QB Nine QB PHI 10',
  '10. Beta RB Ten RB BUF 7',
  '11. Beta WR Eleven WR DAL 14',
  '12. Beta RB Twelve RB PHI 10',
  '13. Beta WR Thirteen WR HOU 8',
  '14. Beta QB Fourteen QB CIN 6',
  '15. Gamma RB Fifteen RB LAC 7',
  '16. Gamma WR Sixteen WR ATL 11',
  '17. Gamma TE Seventeen TE CHI 10',
  '18. Gamma WR Eighteen WR MIN 6',
  '19. Gamma RB Nineteen RB MIA 6',
  '20. Gamma WR Twenty WR NE 11'
].join('\n');

test('full draft flow over file://', async ({ page }) => {
  const dialogs = [];
  page.on('dialog', d => { dialogs.push(d.message()); d.accept(); });
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));

  await page.goto(FILE_URL);
  await page.evaluate(() => localStorage.clear());
  await page.reload();

  // 1. Pre-filled facts: pick 1 on the clock, sample queue loaded
  await expect(page.locator('#pickInfo')).toContainText('Pick 1');
  await expect(page.locator('#main')).toContainText('Jahmyr Gibbs'); // sample queue

  // Draft order + keepers + byes pre-filled (Board tab: keeper counts from pick 1)
  await page.click('#tabbar button[data-tab="board"]');
  const boardTable = page.locator('table');
  await expect(boardTable).toContainText('Andrew');
  const andrewRow = page.locator('tr', { hasText: 'Andrew' });
  await expect(andrewRow.locator('td').nth(1)).toHaveText('0');  // QB
  await expect(andrewRow.locator('td').nth(2)).toHaveText('1');  // RB keeper (Bijan)
  await page.click('#tabbar button[data-tab="settings"]');
  await expect(page.locator('#set_byes')).toHaveValue(/BUF 7/);
  await expect(page.locator('#keeperEdit input').first()).toHaveValue('Bijan Robinson');

  // In-page self-test: the same engine suite passes in the browser
  await page.click('#selfTestBtn');
  await expect(page.locator('#selfTestOut')).toContainText(/(\d+)\/\1 passed/, { timeout: 30000 });
  await expect(page.locator('#selfTestOut')).not.toContainText('FAIL');

  // 2. Paste a 20-player queue -> replaces the sample
  await page.click('#tabbar button[data-tab="queue"]');
  await page.fill('#queuePaste', QUEUE_20);
  await page.click('#queueReplace');
  await expect(page.locator('#main')).toContainText('Alpha RB One');
  await expect(page.locator('#main')).not.toContainText('Jahmyr Gibbs');
  await expect(page.locator('#main')).not.toContainText('Filler');

  // 3. Mark picks 1-6 as other teams' (pick 5 is Bijan's keeper, auto-skipped,
  //    so five live picks) -> clock says pick 7 is mine
  await page.click('#tabbar button[data-tab="draft"]');
  for (let i = 0; i < 5; i++) {
    await page.locator('#availList .playerRow').first().locator('button', { hasText: 'Other' }).click();
  }
  await expect(page.locator('#pickInfo')).toContainText('Pick 7');
  await expect(page.locator('#pickInfo')).toContainText('YOU ARE ON THE CLOCK');

  // 4. Rec card shows the Yahoo queue line, then tap "I picked" on the
  //    primary -> always-on confirm dialog fires, roster + Next Plan update
  await expect(page.locator('#recCard')).toContainText('Yahoo queue should be:');
  const primaryName = (await page.locator('#recCard .recName').first().textContent()).trim();
  await page.locator('#recCard button.primaryBtn').click();
  expect(dialogs.some(m => m.includes('Confirm YOUR pick'))).toBe(true);
  await expect(page.locator('#main')).toContainText('My Roster (2/19)'); // keeper Allen + this pick
  await expect(page.locator('#main')).toContainText(primaryName);
  await expect(page.locator('#recCard')).toContainText('Plan: Pick 14');

  // 5. Undo -> my pick comes back off the board
  await page.click('#undoBtn');
  await expect(page.locator('#pickInfo')).toContainText('Pick 7');
  await expect(page.locator('#main')).toContainText('My Roster (1/19)');

  // 6. Redo the pick, reload -> state persisted across the reload
  await page.locator('#recCard button.primaryBtn').click();
  await expect(page.locator('#main')).toContainText('My Roster (2/19)');
  await page.reload();
  await expect(page.locator('#pickInfo')).toContainText('Pick 8');
  await expect(page.locator('#main')).toContainText('My Roster (2/19)');
  await expect(page.locator('#main')).toContainText(primaryName);

  // 7. Rapid catch-up: 3+ letters, tap the match, assigned to the on-the-clock
  //    team; "picks behind" counter tracks the live pick number
  await page.locator('#rapidCard summary').click();
  await page.fill('#rapidTarget', '12');
  await page.locator('#rapidTarget').blur();
  await expect(page.locator('#rapidCard')).toContainText('You are 4 picks behind'); // live 12, app at 8
  await page.fill('#rapidInput', 'seven');
  await page.locator('#rapidMatches button', { hasText: 'Beta WR Seven' }).click();
  await expect(page.locator('#pickInfo')).toContainText('Pick 9');
  await expect(page.locator('#rapidCard')).toContainText('You are 3 picks behind');
  await page.click('#tabbar button[data-tab="board"]');
  await expect(page.locator('#main')).toContainText('Beta WR Seven');

  // 8. Settings: Export Yahoo pre-draft list (keepers stripped)
  await page.click('#tabbar button[data-tab="settings"]');
  await page.click('#yahooExportBtn');
  const listText = await page.locator('#yahooOut').inputValue();
  expect(listText).toContain('Alpha RB One');
  expect(listText).not.toContain('Josh Allen');

  // No service worker over file://
  const hasSW = await page.evaluate(() => !!(navigator.serviceWorker && navigator.serviceWorker.controller));
  expect(hasSW).toBe(false);

  expect(errors).toEqual([]);
});
