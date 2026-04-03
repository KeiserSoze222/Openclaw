# OpenClaw Trading System — Complete Guide
*Version 4.0 | April 2026 | Built with Claude AI*

---

## THE PITCH

OpenClaw is a fully autonomous algorithmic trading system that runs 24/7 on a cloud server, trading prediction market contracts on Kalshi — a federally regulated exchange. It requires zero manual intervention during normal operation.

Think of it as a tireless trader that never sleeps, never gets emotional, and executes the same disciplined strategy thousands of times. It watches Bitcoin, Ethereum, and Solana price markets every 60 seconds and places bets when the math says the edge is in our favor.

**Current performance: 78% win rate across 400+ trades.**

---

## SECTION 1: WHAT IS OPENCLAW?

OpenClaw is three trading bots, a whale intelligence scanner, a bond scanner, a watchdog, and a live dashboard — all running simultaneously on a DigitalOcean cloud server at 167.172.244.100.

### The Bots
- **BTC Bot** — trades 15-minute Bitcoin price contracts on Kalshi
- **ETH Bot** — trades 15-minute Ethereum price contracts
- **SOL Bot** — trades 15-minute Solana price contracts

Each bot runs as `python3 openclaw.py --market btc/eth/sol` — a single unified codebase that accepts a market argument. This means any improvement to the bot automatically applies to all three markets simultaneously.

### The Support Systems
- **Watchdog** — monitors all bots every 5 minutes and auto-restarts any that crash
- **Whale Scanner** — monitors Kalshi's public trade feed for large bets ($2,000+) and alerts when smart money hits our markets
- **Bond Scanner** — scans 20,000+ Kalshi markets for near-certain outcomes
- **Dashboard** — live web interface at http://167.172.244.100:8080

---

## SECTION 2: THE CORE STRATEGY

### Favorite-Longshot Bias
Prediction markets have a well-documented inefficiency. Contracts priced as heavy favorites (YES = 75-95¢) win more often than their price implies. OpenClaw exploits this by targeting 15-minute crypto contracts where the market has already reached high confidence.

**The math at YES=0.75:**
- Win: collect $1.00, profit = $0.25 (33% return)
- Loss: lose $0.75
- Break-even win rate needed: 75%
- Actual observed win rate: 77-82%
- Result: positive expected value on every trade

### Why 15-Minute Crypto Markets?
- High liquidity — trades fill instantly
- Frequent opportunities — 4 windows per hour per market = 12 opportunities/hour across all 3 bots
- Predictable behavior — crypto prices follow momentum patterns that Coinbase spot price confirms
- Kalshi's settlement is objective — based on CF Benchmarks RTI (60-second average)

---

## SECTION 3: HOW THE BOT DECIDES TO TRADE

Every 60 seconds each bot runs through this decision pipeline:

### Step 1: Timing Filter
Only trades in minutes 1-4 of each 15-minute window. Skips minutes 0 and 5-14. Early in the window prices are most mispriced. Late in the window the market has corrected itself.

### Step 2: Direction Detection
- YES > 0.70 → signal to bet UP (market thinks price will rise)
- YES < 0.30 → signal to bet DOWN (market thinks price will fall)
- YES between 0.30-0.70 → no trade, market is uncertain

### Step 3: Signal Classification
Three tiers of signal strength:

**EXTREME** (YES > 0.80 or YES < 0.20)
- Fires immediately in minute 1 without waiting for confirmation
- Highest win rate: 88%
- Bypasses time-of-day restrictions at 3% minimum bet

**STRONG_MIN1** (edge ≥ 0.30 in minute 1)
- Requires Coinbase spot price to confirm direction
- Fires early if confirmed

**STANDARD** (edge ≥ 0.20, minutes 1-4)
- Requires 2 consecutive 60-second readings in same direction
- Most common signal type: 82% win rate

### Step 4: Confidence Scoring (1-10)
Every signal gets scored before bet sizing:
- +3: extreme edge (≥0.45), +2: strong edge (≥0.30), +1: moderate
- +2: Coinbase strongly confirms direction
- +2: all 3 markets (BTC/ETH/SOL) moving same direction
- +1: peak trading hour
- +2: 1-hour trend validator agrees

Score 9+: bet doubled | Score 8+: bet +50% | Score 7+: bet +25%

### Step 5: Confirmation Stack
- **Coinbase spot price** — compares live BTC/ETH/SOL price to Kalshi strike price. If Coinbase confirms direction, bet increases 30%. If it contradicts, bet decreases 40%.
- **Cross-market correlation** — checks if all 3 crypto markets are moving the same direction. Agreement = stronger signal.
- **1-Hour trend validator** — checks the broader hourly trend to avoid fading momentum.

### Step 6: Bet Sizing
- Base: 7% of balance for BTC/ETH, 5% for SOL (more volatile)
- Minimum: $2.00 | Maximum: $20.00
- Scaled by edge strength and confidence score
- Time-of-day scaling: reduced bets during low-win-rate hours

### Step 7: Order Execution
Places a market order (IOC — immediate or cancel) on Kalshi. The order fills at the best available price or cancels instantly. Never leaves resting limit orders.

---

## SECTION 4: CASH OUT SYSTEM (3 LAYERS)

OpenClaw monitors all open positions every 60 seconds and exits early when conditions are met:

### Layer 1 — Profit Lock
If a position is winning (>70% probability) AND the market starts reversing direction (price moves 0.08 against us), exit immediately to lock in profit rather than risk giving it back.

### Layer 2 — Break-Even Exit
If a position was entered at >65% win probability but drops below 40% win probability after 3 minutes, exit to recover remaining value rather than ride to full loss.

### Layer 3 — Stop Loss
Per-market adverse move thresholds after 3 minutes:
- BTC: exit if market moves 0.35 against position
- ETH: exit if market moves 0.25 against position  
- SOL: exit if market moves 0.20 against position (most volatile)

---

## SECTION 5: WHALE SCANNER

The whale scanner monitors Kalshi's public trades feed (no API key required) every 15 seconds looking for large bets.

**Alert thresholds:**
- Any trade ≥ $2,000 on our BTC/ETH/SOL markets → immediate Telegram alert
- Any trade ≥ $5,000 on any Kalshi market → Telegram alert

**Why this matters:** Large traders ("whales") often have better information or models. When a whale bets $5,000+ in the same direction we're about to bet, it's a powerful confirmation signal. The whale log CSV accumulates data over time to identify which markets consistently attract smart money — this guides future bot development.

---

## SECTION 6: RISK MANAGEMENT

### Daily Loss Limit
If the session loses 12% of starting balance, all bots halt for the day.

### Minimum Balance Floor
If total balance drops below $150, all bots halt automatically.

### Circuit Breaker
If win rate drops below 45% over any 10-trade window, bots pause and alert via Telegram.

### Time-of-Day Schedule
Based on analysis of 400+ real trades, the bot applies scaling factors by UTC hour:
- Peak hours (100% bet size): 3, 6-11, 14-16, 19, 21 UTC
- Reduced hours (50-75%): 0, 4, 12-13, 17-18, 20, 22-23 UTC
- Stop hour (0%): 5 UTC
- EXTREME signals bypass TOD at 3% minimum

---

## SECTION 7: SYSTEM ARCHITECTURE

### Files
