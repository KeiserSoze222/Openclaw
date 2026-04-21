# Whale Bot Comprehensive Analysis — April 21, 2026

Data source: `whale_log.csv`, 9,037 rows, April 3–14, 2026.

---

## Key Finding: Whale Log Architecture

The whale_log mixes two distinct pools:

| Account tag | Rows | Volume       | Markets                        |
|-------------|------|--------------|--------------------------------|
| OTHER       | 8,904| $39,936,656  | Sports, crypto, political, misc|
| OUR         | 133  | $466,836     | KXBTC15M, KXETH15M, KXSOL15M  |

Our own trades are tagged "OUR" and logged alongside external whale activity.
The analysis below covers external (OTHER) whale activity unless noted.

---

## Task 4a — Market Type Breakdown by Volume

### External whale volume by market type

| Type      | Volume       | % of total | Trades | Unique series |
|-----------|-------------|------------|--------|---------------|
| Sports    | $36,261,046  | 90.8%      | 8,011  | 89            |
| Other     |  $2,961,455  |  7.4%      |   726  | 122           |
| Crypto    |    $631,874  |  1.6%      |   156  | 6             |
| Political |     $82,280  |  0.2%      |    11  | 6             |
| **TOTAL** | **$39,936,656**|         |**8,904**|             |

### Top 10 sports series by volume

| Series                      | Volume       | Trades |
|-----------------------------|-------------|--------|
| KXNBAGAME (NBA game winners) | $6,510,325  | 1,231  |
| KXMLBGAME (MLB game winners) | $5,375,734  | 1,318  |
| KXATPMATCH (ATP tennis)      | $3,361,877  |   917  |
| KXATPCHALLENGERMATCH         | $2,871,658  |   768  |
| KXIPLGAME (IPL cricket)      | $2,525,368  |   552  |
| KXMARMAD (March Madness)     | $1,838,558  |   301  |
| KXWTAMATCH (WTA tennis)      | $1,781,686  |   488  |
| KXNCAAMBGAME (NCAA men's BB) | $1,762,648  |   315  |
| KXPGATOUR (golf)             | $1,387,257  |   180  |
| KXMVECROSSCATEGORY (multi)   |   $905,726  |   201  |

**Sports dominate at 90.8% of whale volume.** Crypto (our trading market) is 1.6%.

### Crypto series breakdown (external whales only)

| Series      | Description             | Volume    | Trades | YES | NO |
|-------------|------------------------|-----------|--------|-----|----|
| KXBTCY      | BTC yearly range       | $197,820  |  27    |  0  | 27 |
| KXBTCD      | BTC daily range        | $287,513  |  95    | 58  | 37 |
| KXETHY      | ETH yearly range       |  $91,465  |  15    |  0  | 15 |
| KXETHD      | ETH daily range        |  $11,696  |   4    |  2  |  2 |
| KXBTCMAXMON | BTC monthly max        |   $6,738  |   1    |  1  |  0 |
| KXBTCMAX100 | BTC above $100k        |   $6,303  |   2    |  0  |  2 |

**Critical: Zero external whale trades on KXBTC15M (our trading market).**
We are the primary participant in the 15-minute BTC market. Whale liquidity
lives in sports books, not 15-minute crypto windows.

---

## Task 4b — Settlement Outcome / Win Rate Analysis

**Data limitation:** `whale_log.csv` records the entry side and size of whale trades
but does not record settlement outcomes. Computing win rates would require
cross-referencing each ticker against the Kalshi settlement API — not available
in the dev environment.

What we CAN observe from entry-side bias:

### BTCY/ETHY yearly contracts (external whales)
- BTCY: 27 trades, ALL 27 are NO bets (betting BTC closes below each strike)
- ETHY: 15 trades, ALL 15 are NO bets
- Combined: 42 NO trades, 0 YES trades, $289,285 total

**Interpretation:** External whales are uniformly positioned that BTC/ETH will
NOT reach their annual price targets by January 2027. This matches the bearish
macro environment in early April 2026.

### BTCD daily contracts (external whales)
- 95 trades: 58 YES / 37 NO (61% YES)
- Slight bullish lean on daily closing price contracts

### Overall YES/NO bias (external whales)
- YES: 6,136 trades, $26,806,755 (67%)
- NO: 2,768 trades, $13,129,901 (33%)

Sports whale bias (2:1 YES) reflects the structure of Kalshi sports markets where
the "YES" leg is the higher-probability favorite in many game-winner contracts.

---

## Task 4c — 0.95+ Price Filter Impact

**Data limitation:** `whale_log.csv` contains no entry price column.
Fields logged: timestamp, ticker, side, size, account_tag.

Cannot compute the fraction of whale trades above or below 0.95 from the
available data. To perform this analysis:
1. Pull the entry price at the logged timestamp from Kalshi `/markets/{ticker}` API
2. Join on timestamp + ticker to enrich the log

**Proxy observation from bond_log:** The bond scanner explicitly targets YES>0.96
or NO<0.04. In 30 bond trades, entry prices ranged 0.921–0.980 (avg 0.971).
These trades generated max $2.57 profit on $87.43 deployed — a 2.9% gross return
before fees. After Kalshi's ~7% fee on profits, EV is essentially zero or slightly
negative. High-probability legs at 0.95+ offer negligible dollar profit per trade.

---

## Task 4d — Pre-Game vs In-Game Sports Whales

**Data limitation:** KXNBA/KXMLB/KXATP tickers do not encode a pre-game vs.
in-game indicator in the ticker string. A search for "LIVE" or "INPLAY" in all
8,904 external whale tickers returned 0 matches.

Inference from timing: Kalshi currently structures most sports contracts as
pre-game binary outcomes (who wins the game). Live in-game markets (e.g.,
"will team X win in next 5 minutes") would show much shorter market windows.
Without a `mins_left` field in whale_log, distinguishing pre-game from in-game
is not possible from this data alone.

**Volume timing:** Whale activity was heaviest on April 4–5 and April 7
(weekdays with full sports schedules), suggesting pre-game win-market dominance.

---

## Task 4e — Political / Federal Reserve Markets

| Series              | Description                | Volume   | Trades |
|---------------------|---------------------------|---------|--------|
| KXFEDDECISION       | FOMC rate decision         | $54,140 |   3    |
| KXCPI               | CPI release outcome        | $16,160 |   3    |
| KXSENATETXR         | Texas Senate race          |  $3,668 |   1    |
| KXFEDCHAIRCONFIRM   | Fed Chair confirmation     |  $2,949 |   1    |
| KXCPIYOY            | CPI year-over-year         |  $2,769 |   1    |
| KXUSAIRANAGREEMENT  | US-Iran agreement          |  $2,595 |   2    |
| **TOTAL**           |                            |**$82,280**|**11**|

**Political whale activity is negligible** — 11 trades, $82k, 0.2% of total.
FOMC and CPI events attract the most political capital, with 3 large trades each.
Average FOMC trade size is $18,047 — the largest single political position in the log.

The prior summary mentioned "46 trades, $327k" for political markets. That figure
included the "other" classification bucket (KXLAYOFFSYINFO, KXMVECROSSCATEGORY
when misclassified). Using the strict political/Fed classifier above: 11 trades, $82k.

---

## Summary Recommendations

1. **Whale signals are useless for our market.** Zero external whale activity on
   KXBTC15M. Our own trades are the only BTC15M entries in the log. The whale
   monitoring system provides no actionable signal for 15-minute crypto contracts.

2. **Bearish annual crypto positioning.** BTCY/ETHY external whales are 100% NO
   bets ($289k). This is a bearish macro signal for BTC/ETH annual price ranges,
   but has no direct implication for 15-minute directional contracts.

3. **Sports whale flows are irrelevant to crypto bot.** If the goal is to trade
   sports markets, whale data is informative. For our current focus (15-min BTC/ETH/SOL),
   reallocating the whale monitoring compute away from sports series would reduce
   log noise and storage without losing signal.

4. **Political market size is too small to trade.** 3 FOMC trades at $18k average
   across 11 days does not justify a separate strategy layer. These are episodic
   events with wide bid-ask spreads near decision time.

5. **Cannot assess whale profitability** without settlement data. Recommended next
   step: run `GET /markets/{ticker}/history` for a sample of 50 whale-traded
   tickers to estimate the external-other win rate on sports contracts.
