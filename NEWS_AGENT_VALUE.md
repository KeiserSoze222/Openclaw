# News Agent Value Assessment — April 21, 2026

Data source: `news_log.json`, 1,828 entries, March 26–April 14, 2026.

---

## What the Agent Captures

### Source breakdown

| Source             | Entries | % of total |
|--------------------|---------|------------|
| r/kalshi           |    690  |   37.7%    |
| r/polymarket       |    624  |   34.1%    |
| r/cryptotrading    |    137  |    7.5%    |
| r/algotrading      |    133  |    7.3%    |
| CoinTelegraph      |    122  |    6.7%    |
| TheBlock           |     63  |    3.4%    |
| Decrypt            |     35  |    1.9%    |
| r/algotrading-new  |     24  |    1.3%    |
| **TOTAL**          |  **1,828**|          |

**72% of content comes from Reddit prediction market communities** (r/kalshi
+ r/polymarket). These communities discuss market structure, strategy, and
specific positions — not real-time price-moving news.

### Content classification

- Crypto-related (BTC/ETH/SOL mentioned): 398 entries (21.8%)
- BTC-specific price news: 36 entries (2.0%)
- High keyword-score content (score ≥5): 219 entries (12.0%)

### Top matched keywords (frequency)
kalshi (712), polymarket (680), edge (211), win rate (111),
prediction market (110), trading bot (93), arbitrage (70),
backtesting (55), nba (40), automated trading (32)

---

## Scoring System Analysis

The log records a `score` field based on keyword matching:

| Score | Entries | Interpretation                       |
|-------|---------|--------------------------------------|
|  1    |    95   | Weak match (1 low-value keyword)     |
|  2    |   189   | Moderate match                       |
|  3    | 1,300   | Standard match (e.g., "kalshi" alone = +3) |
|  4    |    25   | Good match                           |
| 5–11  |   219   | Strong multi-keyword match           |

**Critical finding:** The `score` field encodes keyword overlap, not news
actionability. A post titled "How do retail algo traders run their systems?"
scores 3 because it mentions "algo trading" and "automation." This is noise
for our purposes — it reveals nothing about short-term BTC direction.

A genuine relevance score (e.g., "BTC is about to pump" = high, "Polymarket
arbitrage strategy" = low) does not exist in the log. The field the summary
called `relevance_score=0` was a misread of the `score` field, which is
uniformly populated but measures keyword density rather than trading signal.

---

## Crypto-to-Price Correlation

**No price history file found.** A search for `price_history.jsonl`, `btc_price.csv`,
and similar filenames in `/home/user/Openclaw/` returned no results.

Without a timestamped price series, lag analysis (30–90 second news-to-trade
window) cannot be performed quantitatively.

**Qualitative assessment of BTC-specific news items:**

The 36 BTC-price-specific entries observed include:
- "Bitcoin price models point to $40K–$50K as potential BTC bottom" (Apr 2026)
- "Peter Brandt, Polymarket traders don't see new Bitcoin highs this year"
- "Bitcoin, Gold, and U.S. Stocks Dive as Trump Pledges to Hit Iran 'Extremely Hard'"
- "Bitcoin Up/Down 5min is Scam?" (r/polymarket)
- "Little Bitcoin Luck Today Small Bets" (r/kalshi)

These are **analytical or editorial** — published hours to days after price moves.
They are not pre-event signals. The one potentially useful category ("Iran threat
→ BTC dive") lags the price move by the time Reddit processes and our agent scrapes it.

---

## Source Quality Assessment

| Source           | Signal type        | Lag estimate   | Actionability |
|------------------|--------------------|----------------|---------------|
| r/kalshi         | Community sentiment| Hours–days     | Low           |
| r/polymarket     | Arb/strategy posts | Hours–days     | Low           |
| r/cryptotrading  | Retail opinion     | Minutes–hours  | Very low      |
| r/algotrading    | Methodology posts  | N/A (evergreen)| Zero          |
| CoinTelegraph    | News articles      | 30–120 minutes | Low–medium    |
| TheBlock         | Breaking news      | 5–30 minutes   | Medium        |
| Decrypt          | News articles      | 30–60 minutes  | Low–medium    |

**TheBlock** is the only source that occasionally breaks news fast enough to
be actionable on 15-minute windows. It represents 3.4% of the corpus.

---

## Why the Agent Adds No Current Value

1. **Source mix is wrong.** 72% Reddit content is community sentiment, not news.
   For 15-minute crypto contracts, we need feeds with sub-5-minute latency.

2. **Keyword scoring is not signal scoring.** High-score entries discuss trading
   theory ("arbitrage on polymarket", "edge in prediction markets") — not events
   that move 15-minute BTC price.

3. **No action pipeline exists.** Even if a high-quality news item appeared,
   there is no mechanism to convert it to an entry signal. The news_log is
   read-only; no code in `openclaw.py` ingests it at trade time.

4. **15-minute windows are too granular.** A CoinTelegraph article posted
   15–60 minutes after a macro event cannot influence a trade placed in the
   current 15-minute window.

---

## Recommendations

| Recommendation | Rationale |
|----------------|-----------|
| **Suspend Reddit feeds** (r/kalshi, r/polymarket, r/algotrading) | 72% of corpus, zero trading signal for our timeframe |
| **Upgrade TheBlock to WebSocket/RSS** | Only source with <30min latency |
| **Add CryptoCompare/Messari live feeds** | Real-time BTC/ETH news with event tags |
| **Build action pipeline before expanding feeds** | News is useless without code to act on it |
| **Use news for post-hoc analysis only, currently** | Log the BTC-specific subset to identify recurring price-move catalysts over 60+ days |

**Verdict:** The news agent in its current form has **zero trading impact** on the
live bot. No entry decisions in `openclaw.py` consume the news_log. The capture
pipeline is functional but the source selection, scoring logic, and
action pathway all need rework before this adds value.
