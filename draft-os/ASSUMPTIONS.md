# ASSUMPTIONS — 4th & Optimized Draft OS v1

Decisions made where the spec was silent (or two parts of it disagreed). Nothing here changes a hard rule.

1. **App location.** The repo root contains an unrelated project, so the app lives in `draft-os/`. Open `draft-os/index.html` — it is fully self-contained.
2. **Pick 26 team.** Addendum B2 says the catch-up walk shows "26 (Andrew)", but the §3 snake formula (odd round: `(r-1)*10 + slot`) puts pick 26 in round 3 at **slot 6 = Hugo**. §3 explicitly says to compute picks from the formula and assert them against the keeper table (which matches: Jeff K 27, Nolan 28), so the formula wins. Tests assert 26 = Hugo, 29 = Bibhor, 30 = Oskar — 27/28 keeper-skips exactly as both sections require.
3. **No bundler.** `build.js` concatenates `src/` into one `index.html` (committed pre-built). `npm run dev` = rebuild-on-change; `npm run build` = one-shot. No dependencies except `@playwright/test` (dev-only, for e2e).
4. **Rule 8 "next two skill picks".** Implemented as: the lean applies while the empty side's count is 0. After the first pick of that position the side is no longer empty, which is when the lean's job is done. The 10-ranks-better exception and the R9 full-tier override are checked before leaning.
5. **Rule 2 scope.** R2 forces a pool QB at pick 34 only while QB2 is not yet rostered. If Lamar was taken at 14 (R1 exception), pick 34 cites "R2 satisfied — QB2 already rostered" and falls back to queue order, so the rule name still shows on the card during the §17 rehearsal.
6. **Rule 3 / R6 pick numbers track settings.** The forced-QB picks are my 6th and 7th live picks (67/74 by default) and the K/DST window is my last two live picks (174/187 by default), so editing the draft order in Settings keeps the rules attached to the right turns. Season-ending IR names share the final pick's legality (187).
7. **K/DST order.** At 174 the higher-queued of K/DST is primary; at 187 the remaining one (Addendum C). Sample fillers include 2 K / 2 DST rows so this is exercisable before a real queue paste.
8. **Survival heuristic formula** (shown in the UI tooltip): `margin = (ADP rank if pasted, else queue rank) − current pick`; `likely` if `margin ≥ picksBetween × 1.0`, `coin-flip` if `≥ × 0.5`, else `gone`. Factors editable in Settings.
9. **Monte Carlo (A1).** Simulates opponents only; my own unfilled picks inside the window are skipped (no one removed) — it answers "who is left if I wait". N=200 with a 900 ms budget; if the device is slower it stops early and the card says "(capped for speed)". Cached by board signature, recomputed only when the board changes.
10. **Opponent model.** Candidates = top 12 remaining by ADP (else my queue); selection weight = `exp(-i/1.3) × (0.2 + need)`. QB need uses Addendum C's Superflex probabilities (70% first QB in 4 rounds, 50% second by round 8, editable). Handcuff-marked players are never simulated before pick 100 unless their starter went in the previous 2 picks (Confirmed Defaults).
11. **"Fallen elite"** = tier 1–2 by my queue's tier breaks AND strictly lower tier number than the best remaining pool QB ("a full tier above").
12. **A6 defaults** *(revised in the v1.1 fix pass)*: the confirm-dialog on "I picked", next-pick precompute, safe mode, and state migration are ALWAYS on. Only the post-draft **Draft Grade** stays behind the A6 flag.
13. **Undo** keeps 30 levels (> the 20 required) and is per-session: the undo stack is not persisted/exported (state itself is saved after every action).
14. **Catch-up paste** on a single line splits on commas, so "Last, First" formatted names must be pasted one per line there (the parser handles the flip per line).
15. **Queue markers (A5)** cycle per tap: none → Target → Avoid → Handcuff-of (prompted) → none.
16. **FP compare** measures FP rank vs the player's position in my *available* queue; ±3 is the "likes more" threshold; a playbook conflict at the current pick is pilled next to the row.
17. **Board counts** include all keepers from pick 1 (they are locked), per B2.
18. **Roster slotting** is a greedy fill (QB, WR×2, RB×2, TE, FLEX×2, SFLX, K, DST, rest BN) for display only; it never feeds the engine. IR slots are not counted (Addendum C).
19. **Playwright** ran headless against the pre-installed Chromium in this build environment and passed; the spec's fallback note ("write it anyway") was not needed.
20. **`npm test` order** builds first, then runs the same self-test suite the in-page button runs, wrapped in `node --test`.

## v1.1 fix pass

21. **Rule 8 window mechanics.** The trigger arms at my first pick after 34 where WR (checked first) or RB is at 0; the lean then covers my next **two skill picks** (RB/WR/TE — a QB pick does not consume the window), even after the count leaves zero. If the side is still empty when the window closes, the trigger re-arms. The 10-ranks-better exception and the R9 full-tier override still apply inside the window.
22. **PWA scope.** `sw.js`, `manifest.webmanifest`, and `icon.svg` are sidecar files next to `index.html`; the service worker registers **only over http(s)** (`location.protocol` guard), so opening via `file://` is untouched and needs only `index.html`. Offline Add-to-Home-Screen requires serving the four files from one directory once; the SW cache name carries a build hash so a rebuild replaces the cached copy. The e2e asserts no SW controller exists over `file://`.
23. **Rapid catch-up "N picks behind".** The app cannot know the live draft's position on its own, so the card has an optional "Live draft is at pick #" field: N = live pick − app current pick, recomputed after every assignment ("Caught up." at 0); with the field empty the counter is hidden. Matches assign to the on-the-clock team (keeper picks are pre-filled, hence skipped); if the on-the-clock pick is mine, the entry counts as my pick and goes through the same confirm dialog.
24. **Yahoo queue line** = Primary, Alt, Panic, then the next legal player by queue order, deduplicated to exactly 4 names.
25. **Yahoo pre-draft list export** = one plain name per line in queue order, keepers stripped, all K/DST moved to the bottom preserving their relative order (no rank numbers — cleaner to paste into Yahoo's pre-draft ranking search).
