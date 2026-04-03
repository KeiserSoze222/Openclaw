# OpenClaw Trading System — Complete User Guide
*Version 3.1 | April 2026*

---

## SECTION 1: WHAT IS OPENCLAW?

OpenClaw is an automated algorithmic trading system that trades prediction market contracts on Kalshi, a CFTC-regulated exchange. It runs 24/7 on a DigitalOcean cloud server and requires no manual intervention during normal operation.

The system currently runs three trading bots simultaneously:
- **BTC Bot** — trades 15-minute Bitcoin price contracts
- **ETH Bot** — trades 15-minute Ethereum price contracts  
- **SOL Bot** — trades 15-minute Solana price contracts

Each bot independently evaluates market conditions every 60 seconds and decides whether to place a bet.

---

## SECTION 2: THE CORE STRATEGY — FAVORITE-LONGSHOT BIAS

### What is it?
Prediction markets have a well-documented inefficiency called the **favorite-longshot bias**. Contracts priced as heavy favorites (YES = 80-95¢) win more often than their price implies. Contracts priced as long shots (YES = 5-20¢) win less often than their price implies.

### Why does it exist?
Human traders overvalue uncertainty and excitement. A contract at 90¢ feels "boring" so traders price it slightly too low. A contract at 10¢ feels like a lottery ticket so traders price it slightly too high.

### How OpenClaw exploits it
OpenClaw specifically targets 15-minute contracts where the market has already reached high confidence (YES > 75¢ or YES < 25¢). At these prices:
- A YES=0.80 contract implies 80% probability
- The true probability based on observed win rates is closer to 85-90%
- That 5-10 percentage point gap is the edge

### The math
At YES=0.75 (75¢ entry):
- Win: collect $1.00, profit = $0.25 (33% return)
- Loss: lose $0.75 (100% loss of bet)
- Break-even win rate: 75%
- Actual observed win rate: ~77-82%
- Expected value: POSITIVE

---

## SECTION 3: SIGNAL LOGIC — HOW THE BOT DECIDES TO TRADE

Every 60 seconds each bot checks the current market price and runs through this decision tree:

### Step 1: Timing Filter
The bot only trades in minutes 1-4 of each 15-minute window. Minutes 0, 5-12, and 13-14 are skipped. Why? Early in the window prices are most mispriced. Late in the window the market has corrected itself.

### Step 2: Direction Detection
- If YES price > 0.75 → signal is **UP** (bet YES)
- If YES price < 0.25 → signal is **DOWN** (bet NO)
- Between 0.25-0.75 → no signal, skip

### Step 3: Signal Classification

**EXTREME Signal** (highest priority)
- Fires when YES < 0.20 or YES > 0.80 AND it's minute 1
- No confirmation required — fires immediately
- These are the highest expected value trades

**STRONG MIN1 Signal**
- Fires when edge ≥ 0.30 AND it's minute 1 AND Coinbase confirms direction
- No second confirmation required
- Captures strong early signals before price adjusts

**STANDARD Signal**
- Requires 2 consecutive readings above/below threshold
- Fires in minutes 1-4
- Most common signal type

### Step 4: Coinbase Price Confirmation
Before placing any bet, the bot fetches the real-time BTC/ETH/SOL spot price from Coinbase and compares it to the Kalshi strike price.
- If Coinbase confirms direction → bet boosted 30%
- If Coinbase disagrees → bet reduced 60%
- No data → bet unchanged

### Step 5: Cross-Market Correlation
Fetches all three spot prices (BTC, ETH, SOL) and checks if they're moving in the same direction.
- All 3 agree → bet boosted 20%
- Only 1 agrees → bet reduced 10%
- 2 agree → no change

### Step 6: Kraken Cross-Check
Compares Coinbase and Kraken prices. If they diverge by more than 0.5%, reduces bet as a market instability signal.

---

## SECTION 4: BET SIZING

### Base calculation
`bet = balance × MAX_BET_PCT × edge_scale × risk_score`

- **BTC/ETH**: MAX_BET_PCT = 7% of balance
- **SOL**: MAX_BET_PCT = 5% of balance (lower due to higher volatility)
- **Edge scale**: 0-1 based on how far price is from 50¢
- **Minimum bet**: $2.00
- **Maximum bet**: $20.00

### Time-of-Day Scaling
Based on real historical win rate data, bet sizes are automatically scaled by hour (UTC):

| Hours (UTC) | Scale | Win Rate | Reason |
|-------------|-------|----------|--------|
| 03, 06-11, 14-16, 19, 21 | 100% | 87-100% | Peak performance |
| 17, 18, 20, 23 | 75% | 65-69% | Moderate |
| 00, 04, 12, 13 | 40-50% | 60-67% | Below average |
| 01, 22 | 25% | 55-56% | Poor |
| 05 | 0% (STOP) | 43% | Net negative |

**ETH and SOL stop completely** during hours 0, 1, 4, 5, 13, 22, 23.
**BTC continues** at reduced size during all hours.

### Double-Down Logic
If a position already exists in the same direction AND edge > 0.40, the bot adds 50% more to the position. This compounds winning positions.

---

## SECTION 5: RISK MANAGEMENT

### Daily Loss Limit
If balance drops 12% from session start, all bots halt automatically.

### Minimum Balance Floor
If balance drops below $200, bots halt.

### Circuit Breaker
If win rate drops below 45% over 10 trades, bot switches to dry-run (no real money).

### Cash Out Monitor
After minute 8, if an open position has moved 35+ points against us, the bot exits the position early to recover partial capital.

### Kill Switches
Emergency stop files. Create these files to immediately halt bots:
- `touch /root/STOP` — stops BTC bot
- `touch /root/STOP_ETH` — stops ETH bot
- `touch /root/STOP_SOL` — stops SOL bot
- `touch /root/STOP_BOND` — stops bond scanner

---

## SECTION 6: ALL RUNNING PROCESSES

| Process | File | Purpose | Log |
|---------|------|---------|-----|
| BTC Bot | real_bot.py | Trades KXBTC15M contracts | bot.log |
| ETH Bot | eth_bot.py | Trades KXETH15M contracts | eth_bot.log |
| SOL Bot | sol_bot.py | Trades KXSOL15M contracts | sol_bot.log |
| Bond Scanner | bond_scanner.py | Finds near-certain market outcomes | bond_scanner.log |
| Watchdog | watchdog.py | Restarts crashed bots every 5 min | watchdog.log |
| Dashboard | dashboard.py | Web UI at port 8080 | dashboard.log |
| News Agent | news_agent.py | Monitors Reddit/RSS for signals | news_log.json |

---

## SECTION 7: THE DASHBOARD

Access at: **http://167.172.244.100:8080**
Auto-refreshes every 20 seconds.

### Dashboard Sections

**Balance** — Live Kalshi portfolio value (cash + open positions)

**TOD Badge** — Current bet size scaling based on time of day

**Summary Stats** — Combined win rate, total trades, session PnL, extreme signals, Coinbase confirms, cash outs

**Bot Cards (BTC/ETH/SOL)**
- Win rate percentage (color coded: green ≥75%, yellow ≥55%, red <55%)
- W/L count
- PnL
- EV per $1 (expected value calculation)
- Streak indicator (🔥 winning streak, ❄️ losing streak)
- Icon row: 🛰️ Coinbase confirms | ⚠️ Coinbase disagrees | ⚡ Extreme signals | 💸 Cash outs

**Equity Curve** — Balance trend over last 80 trades

**Trade Frequency** — Bar chart showing trades per hour of day

**Win Rate by Hour** — Historical win rate for each UTC hour

**Open Positions** — Live positions currently held on Kalshi

**Recent Trades** — Last 12 settled trades across all bots

**Feature Attribution** — Statistical analysis of which signal types, entry minutes, and edge ranges perform best

**Bot Intelligence** — Rule-based insights about current session performance

**Top News** — High-scoring items from news agent feed

**System Status** — Green/red indicators for all 7 processes

---

## SECTION 8: DAILY OPERATING PROCEDURE

### Morning Check (5 minutes)
```bash
python3 /tmp/status_all.py
grep -E "Correlation|STRONG MIN1|CashOut|EXTREME" /root/bot.log | tail -20
python3 /root/analyze_features.py
```

### What to look for
- Win rate > 75% = strategy working well
- Win rate 65-75% = acceptable, monitor
- Win rate < 65% = investigate, consider pausing
- Balance trending down 3+ days = something is wrong

### Weekly maintenance
```bash
python3 /root/auto_tune_tod.py  # updates TOD schedule
python3 /root/analyze_features.py  # full feature report
```

### Restarting bots after changes
```bash
pkill -f real_bot.py && pkill -f eth_bot.py && pkill -f sol_bot.py
sleep 3
nohup python3 -u /root/real_bot.py > /root/bot.log 2>&1 &
nohup python3 -u /root/eth_bot.py > /root/eth_bot.log 2>&1 &
nohup python3 -u /root/sol_bot.py > /root/sol_bot.log 2>&1 &
```

### Checking if bots are running
```bash
ps aux | grep -E "real_bot|eth_bot|sol_bot|bond|watchdog|dashboard|news" | grep -v grep
```

---

## SECTION 9: PERFORMANCE TRACKING

### Key files
- `/root/trade_log.csv` — every BTC trade ever placed
- `/root/eth_trade_log.csv` — every ETH trade
- `/root/sol_trade_log.csv` — every SOL trade
- `/root/feature_log.json` — feature attribution data
- `/root/performance_log.json` — session performance snapshots
- `/root/tod_analysis.json` — latest time-of-day analysis

### True P&L calculation
The dashboard PnL reflects trading performance since March 25, 2026 (post-bug-fix clean start). To calculate true net profit:
`True P&L = Current Balance - Total Deposited`

Deposits made:
- Initial deposit: ~$143.90 baseline
- Additional deposit: ~$134.63
- Most recent deposit: TBD (confirm amount)

### Interpreting win rates
- Overall: 77% (274W/82L since March 25)
- By market: BTC 77%, ETH 82%, SOL 74%
- Best hours: 03, 06-11, 14-16, 19, 21 UTC
- Worst hours: 01, 05, 22 UTC

---

## SECTION 10: GLOSSARY

**Edge** — The difference between the market-implied probability and the true probability. Edge = YES price - 0.50 for UP bets.

**Favorite-Longshot Bias** — Market inefficiency where high-probability outcomes are underpriced and low-probability outcomes are overpriced.

**EXTREME Signal** — Signal type that fires immediately in minute 1 when YES < 0.20 or YES > 0.80. Highest confidence trades.

**STANDARD Signal** — Requires 2 consecutive confirmations before firing. Most common signal type.

**STRONG MIN1** — Fires in minute 1 when edge ≥ 0.30 and Coinbase confirms. Captures early strong signals.

**TOD Filter** — Time-of-day bet size scaling based on historical hourly win rates.

**MAE (Maximum Adverse Excursion)** — How far a position moves against us before resolving. Tracked via min_yes/max_yes fields.

**Feature Attribution** — Statistical analysis of which bot features contribute to wins vs losses.

**Dry Run** — Test mode where bot logs trades but doesn't place real orders. Used for testing changes.

**Cash Out Monitor** — Checks positions after minute 8 and exits early if price moved 35+ points against us.

**Coinbase Confirmation** — Real-time spot price check that validates the signal direction before betting.

**Cross-Market Correlation** — Checks if BTC, ETH, and SOL are all moving in the same direction to boost confidence.

**Bond Scanner** — Separate process that scans all Kalshi markets for near-certain outcomes (YES > 96% or YES < 4%).

**Watchdog** — Process that monitors all bots and restarts any that crash within 5 minutes.

**DIRECTIONAL_HIGH/LOW** — Threshold values (currently 0.75/0.25) that trigger a directional signal.

**Session PnL** — Profit/loss since the bot was last restarted.

**Regime** — Market condition classification (BULL/BEAR/CHOP) based on recent price action.

---

## SECTION 11: TROUBLESHOOTING

### Bot not trading
1. Check kill switch files: `ls /root/STOP*`
2. Check daily loss limit: compare balance to session start
3. Check timing: bots only trade minutes 1-4 of each window
4. Check thresholds: YES must be > 0.75 or < 0.25

### Dashboard not loading
```bash
pkill -f dashboard.py
nohup python3 -u /root/dashboard.py > /root/dashboard.log 2>&1 &
cat /root/dashboard.log | tail -10
```

### Wrong market being traded
```bash
grep "MARKET_SERIES" /root/real_bot.py | head -1
# Should show KXBTC15M for real_bot.py
```

### Restoring from backup
```bash
cp /root/real_bot_v3_stable.py /root/real_bot.py
cp /root/eth_bot_v1_stable.py /root/eth_bot.py
cp /root/sol_bot_v1_stable.py /root/sol_bot.py
```

### SSH connection issues
```bash
ssh-keygen -R 167.172.244.100
ssh root@167.172.244.100
```
If still failing, force close and restart the SSH app.

---

*Last updated: April 1, 2026*
*Server: 167.172.244.100 (DigitalOcean Ubuntu droplet)*
*Dashboard: http://167.172.244.100:8080*
