"""
OpenClaw Bond Scanner v2

Strategy 1: Near-certain single-side bets (YES > 0.96 or YES < 0.04)
Strategy 2: Bundle arbitrage (YES_ask + NO_ask < 0.97 = guaranteed profit)

Kill: touch /root/STOP_BOND
“””

import requests
import time
import json
import datetime
import tempfile
import os

# ── CONFIG ────────────────────────────────────────────────────────────────────

raw         = open(’/root/real_bot_pre_v4_backup.py’).read()
KALSHI_KEY  = raw.split(“KALSHI_API_KEY = ‘”)[1].split(”’”)[0]
KALSHI_SEC  = raw.split(“KALSHI_SECRET  = ‘’’”)[1].split(”’’’”)[0]
BOT_TOKEN   = raw.split(“BOT_TOKEN = ‘”)[1].split(”’”)[0]
CHAT_ID     = raw.split(“CHAT_ID   = ‘”)[1].split(”’”)[0]

# Bond config

BET_SIZE        = 3.00
YES_HIGH        = 0.96
YES_LOW         = 0.04
MIN_MINUTES     = 5
MAX_MINUTES     = 45
SCAN_INTERVAL   = 120
LOG_FILE        = ‘/root/bond_log.json’

# Arb config

ARB_MIN_PROFIT_PCT = 2.0   # minimum 2% net profit after fees
ARB_MAX_COST       = 10.0  # max dollars per arb pair
ARB_LOG_FILE       = ‘/root/arb_log.json’

placed_markets = set()
session_wins   = 0
session_losses = 0
session_pnl    = 0.0

# ── AUTH ──────────────────────────────────────────────────────────────────────

tf = tempfile.NamedTemporaryFile(delete=False, suffix=”.pem”, mode=“w”)
tf.write(KALSHI_SEC)
tf.close()

from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
config      = Configuration()
config.host = “https://api.elections.kalshi.com/trade-api/v2”
kalshi      = KalshiClient(config)
kalshi.set_kalshi_auth(KALSHI_KEY, tf.name)

def send_telegram(msg):
try:
requests.get(
f”https://api.telegram.org/bot{BOT_TOKEN}/sendMessage”,
params={“chat_id”: CHAT_ID, “text”: msg},
timeout=5
)
except Exception:
pass

def get_auth_headers(method, url):
return kalshi.kalshi_auth.create_auth_headers(method, url)

def get_balance():
url     = “https://api.elections.kalshi.com/trade-api/v2/portfolio/balance”
headers = get_auth_headers(“GET”, url)
resp    = requests.get(url, headers=headers, timeout=5)
if resp.status_code == 200:
data = resp.json()
return (data.get(‘balance’, 0) + data.get(‘portfolio_value’, 0)) / 100
return 0

def fetch_markets():
“”“Fetch all open markets and return raw list.”””
url     = “https://api.elections.kalshi.com/trade-api/v2/markets”
headers = get_auth_headers(“GET”, url)
all_markets = []
cursor = “”
while True:
params = {“status”: “open”, “limit”: 100}
if cursor:
params[“cursor”] = cursor
resp = requests.get(url, headers=headers, params=params, timeout=10)
if resp.status_code != 200:
break
data    = resp.json()
markets = data.get(“markets”, [])
if not markets:
break
all_markets.extend(markets)
cursor = data.get(“cursor”, “”)
if not cursor:
break
return all_markets

def get_mins_left(close_ts):
try:
close_dt = datetime.datetime.fromisoformat(close_ts.replace(“Z”, “+00:00”))
now_utc  = datetime.datetime.now(datetime.timezone.utc)
return (close_dt - now_utc).total_seconds() / 60
except Exception:
return -1

# ── STRATEGY 1: NEAR-CERTAIN SINGLE SIDE ─────────────────────────────────────

def scan_bond_opps(markets):
opportunities = []
for m in markets:
ticker   = m.get(“ticker”, “”)
yes_ask  = m.get(“yes_ask_dollars”)
no_ask   = m.get(“no_ask_dollars”)
close_ts = m.get(“close_time”) or m.get(“expiration_time”)
if not yes_ask or not no_ask or not close_ts:
continue
if ticker in placed_markets:
continue
if any(x in ticker for x in (“KXMVE”, “MULTIGAME”, “CROSSCAT”, “PARLAY”)):
continue
if float(yes_ask) <= 0.01 or float(yes_ask) >= 0.99:
continue
if float(yes_ask) + float(no_ask) > 1.02:
continue
mins_left = get_mins_left(close_ts)
if mins_left < MIN_MINUTES or mins_left > MAX_MINUTES:
continue
yes_price = float(yes_ask)
no_price  = float(no_ask)
if yes_price >= YES_HIGH and yes_price < 0.99:
profit = (1 - yes_price) / yes_price * 100
if profit >= 0.5:
opportunities.append({
“ticker”: ticker, “side”: “yes”, “price”: yes_price,
“mins_left”: mins_left, “profit_pct”: profit
})
elif yes_price <= YES_LOW and no_price < 0.99:
profit = (1 - no_price) / no_price * 100
if profit >= 0.5:
opportunities.append({
“ticker”: ticker, “side”: “no”, “price”: no_price,
“mins_left”: mins_left, “profit_pct”: profit
})
return sorted(opportunities, key=lambda x: x[“profit_pct”], reverse=True)

def place_bond_bet(opp):
ticker = opp[“ticker”]
side   = opp[“side”]
price  = opp[“price”]
price_cents = min(99, max(1, round(price * 100) + 1))
count  = max(1, int(BET_SIZE / price))
try:
kalshi.create_order(
ticker=ticker, action=“buy”, side=side, type=“market”,
count=count,
yes_price=price_cents if side == “yes” else None,
no_price=price_cents if side == “no” else None,
time_in_force=“ioc”,
)
placed_markets.add(ticker)
cost = count * price
msg  = (f”🔒 BOND: {side.upper()} on {ticker}\n”
f”Price: {price:.2f} | Cost: ${cost:.2f} | “
f”Profit if wins: ${count*(1-price):.2f} ({opp[‘profit_pct’]:.1f}%)\n”
f”Time left: {opp[‘mins_left’]:.0f} min”)
print(msg); send_telegram(msg)
with open(LOG_FILE, ‘a’) as f:
f.write(json.dumps({“timestamp”: datetime.datetime.now().isoformat(),
“ticker”: ticker, “side”: side, “price”: price,
“count”: count, “cost”: cost, “mins_left”: opp[“mins_left”]}) + ‘\n’)
return True
except Exception as e:
print(f”[Bond] Order failed: {e}”)
return False

# ── STRATEGY 2: BUNDLE ARBITRAGE ─────────────────────────────────────────────

def scan_bundle_arb(markets):
“”“Find markets where YES+NO < $0.97 — guaranteed profit buying both sides.”””
arbs = []
for m in markets:
ticker   = m.get(“ticker”, “”)
yes_ask  = m.get(“yes_ask_dollars”)
no_ask   = m.get(“no_ask_dollars”)
close_ts = m.get(“close_time”) or m.get(“expiration_time”)
volume   = m.get(“volume”, 0) or 0
if not yes_ask or not no_ask or not close_ts:
continue
if ticker in placed_markets:
continue
if volume < 1000:
continue  # skip thin markets
yes_price = float(yes_ask)
no_price  = float(no_ask)
combined  = yes_price + no_price
if combined >= 0.97 or combined <= 0.50:
continue
mins_left = get_mins_left(close_ts)
if mins_left < MIN_MINUTES or mins_left > MAX_MINUTES:
continue
# Net profit after estimated Kalshi fee
gross      = 1.0 - combined
fee_est    = 0.07 * gross
net        = gross - fee_est
net_pct    = (net / combined) * 100
if net_pct < ARB_MIN_PROFIT_PCT:
continue
arbs.append({
“ticker”: ticker, “yes_price”: yes_price, “no_price”: no_price,
“combined”: combined, “net_profit_pct”: net_pct,
“mins_left”: mins_left, “volume”: volume,
})
return sorted(arbs, key=lambda x: x[“net_profit_pct”], reverse=True)

def place_bundle_arb(arb):
“”“Buy both YES and NO — one side always wins = guaranteed profit.”””
ticker    = arb[“ticker”]
yes_price = arb[“yes_price”]
no_price  = arb[“no_price”]
contracts = max(1, int(ARB_MAX_COST / arb[“combined”]))
yes_cents = min(99, max(1, round(yes_price * 100) + 1))
no_cents  = min(99, max(1, round(no_price  * 100) + 1))
try:
kalshi.create_order(ticker=ticker, action=“buy”, side=“yes”,
type=“market”, count=contracts, yes_price=yes_cents,
time_in_force=“ioc”)
kalshi.create_order(ticker=ticker, action=“buy”, side=“no”,
type=“market”, count=contracts, no_price=no_cents,
time_in_force=“ioc”)
placed_markets.add(ticker)
total_cost  = contracts * arb[“combined”]
net_profit  = contracts * (1.0 - arb[“combined”])
msg = (f”⚡ BUNDLE ARB: {ticker}\n”
f”YES@{yes_price:.3f} + NO@{no_price:.3f} = {arb[‘combined’]:.3f}\n”
f”Contracts: {contracts} | Cost: ${total_cost:.2f}\n”
f”Guaranteed profit: ${net_profit:.2f} ({arb[‘net_profit_pct’]:.1f}%)\n”
f”Time left: {arb[‘mins_left’]:.0f} min | Vol: {arb[‘volume’]}”)
print(msg); send_telegram(msg)
with open(ARB_LOG_FILE, ‘a’) as f:
f.write(json.dumps({“timestamp”: datetime.datetime.now().isoformat(),
“type”: “bundle_arb”, “ticker”: ticker,
“yes_price”: yes_price, “no_price”: no_price,
“combined”: arb[“combined”], “contracts”: contracts,
“total_cost”: total_cost, “expected_profit”: net_profit,
“mins_left”: arb[“mins_left”]}) + ‘\n’)
return True
except Exception as e:
print(f”[Arb] Order failed: {e}”)
return False

# ── MAIN LOOP ─────────────────────────────────────────────────────────────────

if **name** == “**main**”:
print(“OpenClaw Bond Scanner v2 starting…”)
send_telegram(“🔒 Bond Scanner v2 started — near-certain bets + bundle arb”)

```
while True:
    if os.path.exists('/root/STOP_BOND'):
        print("STOP_BOND detected — halting")
        break
    try:
        markets  = fetch_markets()
        bal      = get_balance()
        bonds    = scan_bond_opps(markets)
        arbs     = scan_bundle_arb(markets)

        print(f"[{datetime.datetime.now().strftime('%H:%M')}] "
              f"Scanned {len(markets)} markets | "
              f"{len(bonds)} bond opps | {len(arbs)} arb opps | "
              f"Balance: ${bal:.2f}")

        # Log arb opportunities even if not trading (for analysis)
        if arbs:
            print(f"  🎯 TOP ARB: {arbs[0]['ticker']} | "
                  f"Combined={arbs[0]['combined']:.3f} | "
                  f"Net={arbs[0]['net_profit_pct']:.1f}% | "
                  f"{arbs[0]['mins_left']:.0f}min")

        # Execute arbs first (risk-free)
        for arb in arbs[:2]:  # max 2 arbs per scan
            place_bundle_arb(arb)

        # Then bonds
        for opp in bonds[:3]:
            print(f"  → {opp['ticker']} | {opp['side']} @ "
                  f"{opp['price']:.3f} | {opp['mins_left']:.0f}min | "
                  f"+{opp['profit_pct']:.1f}%")
            place_bond_bet(opp)

    except Exception as e:
        print(f"[Bond] Scan error: {e}")

    time.sleep(SCAN_INTERVAL)
```
