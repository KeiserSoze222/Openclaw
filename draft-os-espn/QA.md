# QA.md — ESPN app manual checklist (10 minutes)

1. **Open the file.** AirDrop/Files → `index.html` → opens in Safari. Header shows **Pick 1** and the dark one-page app. (For Add-to-Home-Screen offline: `npm run serve` → http://<your-ip>:8091/index.html → Share → Add to Home Screen.)
2. **Self-test.** Settings → **Run self-test** → all green.
3. **Type the real setup.** Settings → enter the 12 team names in slot order, tap **ME** next to your name (that sets your slot), set rounds if not 16 → Save. No dialog appears (no picks marked yet).
4. **Keepers in under 2 minutes.** Keepers tab: every league keeper is pre-loaded with a blank round. Type the round for each team that's actually keeping. Watch each row flip from "not kept" to "pick N". A typo'd team name shows a red **unmatched team** badge — fix the name, never lose the row. Your own row (ME) with a round set puts the player straight onto your roster.
5. **Paste your queue.** Queue tab → paste → Replace. Kept players are reported and stay hidden from available.
6. **Draft-tab spot checks.** Rounds 1–4: no QB anywhere on the card (long-press Allen → R1). At your 5th live pick with elite tiers gone, watch the R2 exception. Card always shows Primary + Alt2–Alt5 and the **ESPN queue should be:** line.
7. **Mark picks.** Other / I picked (confirm fires on yours) / rapid catch-up / Undo.
8. **Setup guard.** After any marked pick, change anything structural in Settings or Keepers → confirm dialog → clean recompute.
9. **Kill and reopen** → state persists. Log → Export JSON; Import restores it. The Yahoo app's state is a different storage namespace — the two never mix.
