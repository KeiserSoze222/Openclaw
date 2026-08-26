# QA.md — 10-minute manual checklist (iPad/iPhone)

Run top to bottom. Every step should take seconds.

1. **Open the file.** AirDrop or save `index.html` to the Files app, tap it (or open via Safari share-sheet → Open in Safari). The dark one-page app loads with **Pick 1 · R1 · Colby** in the header and no network.
2. **Check settings.** Settings tab → draft order shows Colby…Oskar with slot 7 = you; keepers list shows Bijan Robinson … Luther Burden III; byes box shows `BUF 7`, `LAC 7`, `JAX 7`. Clock = 90.
3. **Self-test.** Settings → **Run self-test** → all tests green (24/24).
4. **Paste queue.** Queue tab → paste your 20-player dummy list → **Replace queue** → confirm. The SAMPLE pill disappears; your names replace Gibbs/fillers; keepers you pasted are reported as stripped.
5. **Protect Lamar.** Simulate tab → protect list: `Lamar Jackson` (works in live too: Lamar must be in your pasted queue for the 14 rehearsal — with the sample queue he is).
6. **Tap through picks 1–6.** Draft tab → tap **Other** on the top row five times (pick 5 auto-skips: Bijan keeper). Header flips to **Pick 7 — YOU ARE ON THE CLOCK**; clock resets.
7. **Verify pick 7 rec.** Rec card shows a RB/WR/TE primary; open **Do not take** — any QB is listed with **R1**.
8. **Pick and continue to 14.** Tap "I picked" on the primary, tap Other until pick 14. If Lamar is still on the board the card shows **Lamar Jackson [R1]** — the exception fired.
9. **Catch-up picks 15–33.** Available panel → Catch-up paste → enter the next picks comma-separated → Apply. Board tab shows them on the right teams; picks 27/28 (Allen, Bowers keepers) were skipped automatically.
10. **Verify QB2 at 34.** At pick 34 the card cites **R2** (pool QB primary — or "R2 satisfied" if you took Lamar at 14).
11. **Kill and reopen.** Swipe the app/tab away, reopen the file: same pick, roster, queue, log. (That's localStorage; if iOS ever evicts it, Import your last export.)
12. **Export.** Log tab → **Export State (JSON)** → copy the text (or save the file).
13. **Import round-trip.** Settings → Reset app (double confirm) → Log tab → paste the export → **Import State** → everything is back exactly.
14. **Undo.** Tap Undo twice — the last two picks pop off in order.
15. **Ghost mode.** Type `GHOST MODE` in search (or tap the button): card greys with "Recs frozen. Yahoo will use the saved pre-draft list." Tap again to resume.
