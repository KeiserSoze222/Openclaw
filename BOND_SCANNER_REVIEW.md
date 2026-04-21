# Bond Scanner Review — April 21, 2026

Data source: `bond_log.json`, 30 entries, March 31–April 14, 2026.

---

## Activity Summary

| Metric                  | Value               |
|------------------------|---------------------|
| Trades placed          | 30                  |
| Total deployed         | $87.43              |
| Avg cost per trade     | $2.91               |
| Avg contracts per trade| 3.0                 |
| Entry price range      | 0.921 – 0.980       |
| Entry price (avg)      | 0.971               |
| Avg mins remaining     | 25.1 min            |
| Max profit (pre-fee)   | $2.57               |
| Max profit (post-fee)  | $2.39               |
| Break-even win rate    | 97.1%               |

---

## Market Type Breakdown

| Series                          | Trades | Cost    | Description              |
|---------------------------------|--------|---------|--------------------------|
| KXBTCD                          |  10    | $29.25  | BTC daily range          |
| KXTEMPNYCH                      |   9    | $26.19  | NYC temperature          |
| KXMVESPORTSMULTIGAMEEXTENDED    |   3    |  $8.76  | Multi-sport parlay       |
| KXBTC15M                        |   2    |  $5.83  | BTC 15-min (our market!) |
| KXBNB15M                        |   1    |  $2.94  | BNB 15-min               |
| KXETHD                          |   1    |  $2.94  | ETH daily range          |
| KXBTC                           |   1    |  $2.94  | BTC unspecified          |
| KXETH15M                        |   1    |  $2.93  | ETH 15-min               |
| KXXRP15M                        |   1    |  $2.88  | XRP 15-min               |
| KXMVECROSSCATEGORY              |   1    |  $2.76  | Multi-event cross-cat    |

### Notable: KXBTC15M bond trades

Two bond trades were placed on BTC15M contracts — the same series our main
bot trades directionally. These are near-certainty bets (price ~0.97) on
outcomes where the bot apparently saw a very high-probability resolution.
This raises a coordination question: if the main bot is also trading the
same ticker directionally, the bond scanner may be double-counting exposure.

---

## Side Distribution

| Side | Trades | Cost    |
|------|--------|---------|
| YES  |  18    | $52.24  |
| NO   |  12    | $35.19  |

Roughly 2:1 YES bias, consistent with the scanner targeting markets where
the YES outcome is nearly certain (e.g., BTC staying above a floor).

---

## Win Rate and P&L

**No outcome log exists.** The bond_log records entries only; there is no
corresponding bond_outcomes.json or settlement field.

Reconstructing outcomes would require querying:
`GET /markets/{ticker}` for each of 30 tickers to retrieve `result` field.

### Expected value calculation (assuming market price = true probability)

At avg entry price 0.971, buying YES contracts:
- Win probability: 0.971
- Profit per contract if win: $(1.00 - 0.971) \times 0.93 = $0.027 (after 7% fee)
- Loss per contract if lose: $0.971

EV per contract = 0.971 × $0.027 − 0.029 × $0.971 = $0.026 − $0.028 = **−$0.002**

Total EV across 90 contracts: **−$0.17**

**If market prices are accurate, the bond scanner has negative expected value
due to Kalshi's fee.** The strategy only makes money when the scanner identifies
markets where the true probability exceeds the stated price by more than the
fee margin (approximately 1–2% edge required).

---

## Activity Timeline

| Date        | Trades | Notes                              |
|------------|--------|------------------------------------|
| 2026-03-31 |   1    | First trade (KXMVECROSSCATEGORY)   |
| 2026-04-01 |   2    |                                    |
| 2026-04-02 |   3    |                                    |
| 2026-04-04 |   2    |                                    |
| 2026-04-05 |   4    |                                    |
| 2026-04-07 |   1    |                                    |
| 2026-04-09 |   1    |                                    |
| 2026-04-13 |  15    | **Half of all trades in one day**  |
| 2026-04-14 |   1    |                                    |

April 13 spike (15 trades, $43.65) is the largest single-day activity —
possibly triggered by a batch of markets simultaneously reaching high-certainty
territory near settlement.

---

## Scale Assessment

At current pace: ~2.2 trades/day, $6.39/day deployed.
- Monthly capital deployed: ~$192
- Monthly max profit (pre-fee): ~$5.70 (~3%)
- Monthly max profit (post-fee): ~$5.30 (~2.8%)

**The bond scanner is economically immaterial at current scale.** $87.43
over 15 days and max $2.39 total profit is smaller than a single main-bot
trade. Even if win rate were 100%, the annual profit ceiling at this scale
is ~$160.

---

## Recommendation: Do NOT feed into main bot

### Arguments against integration

1. **Negative EV at market prices.** Without confirmed edge (settlement data
   showing >98% win rate), the scanner is consuming capital at a loss after fees.

2. **Negligible scale.** $2.91 average trade with max $0.087 profit per trade
   has no meaningful impact on overall portfolio performance.

3. **Exposes BTC15M double-booking.** Two bond trades entered our own directional
   market. If we hold a directional YES position and also a bond YES position on
   the same ticker, the bond adds exposure but is counted as separate P&L.

4. **Distorts main bot metrics.** Integrating bond results would pollute win rate,
   P&L, and fill rate statistics with a fundamentally different strategy.

### What to do instead

| Action | Rationale |
|--------|-----------|
| **Collect settlement data for 30 existing trades** | Verify actual win rate; if >98%, scanner has edge |
| **Raise entry price threshold to 0.985+** | Reduces fee drag; only targets near-certainties |
| **Exclude KXBTC15M and KXETH15M** | Avoid double-booking with main bot's market |
| **Increase contract size** | If edge confirmed, scale from 3 to 10–20 contracts/trade |
| **Keep as standalone system** | Separate P&L tracking; never merge with main bot |

**Bottom line:** The bond scanner is a valid concept (exploit near-certainty mispricings)
but needs settlement data to confirm edge before any capital commitment increases.
Run it in parallel for another 60 days at current scale, log outcomes, then
re-evaluate. Do not integrate into `openclaw.py`.
