"""
OpenClaw Bond Scanner
=====================
Scans all open Kalshi markets for near-certain outcomes (YES < 0.04 or YES > 0.96)
and places small bets on the near-certain side.
3-5% return per trade, very high win rate, runs alongside main bots.
Kill: touch /root/STOP_BOND
"""

import requests
import time
import json
import datetime
import tempfile
import os

# ── CONFIG ────────────────────────────────────────────────────────────────────
raw         = open('/root/real_bot_pre_v4_backup.py').read()
KALSHI_KEY  = raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
KALSHI_SEC  = raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
BOT_TOKEN   = raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID     = raw.split("CHAT_ID   = '")[1].split("'")[0]

BET_SIZE        = 3.00   # dollars per bond trade
YES_HIGH        = 0.96   # bet YES when above this
YES_LOW         = 0.04   # bet NO when below this
MIN_MINUTES     = 5      # minimum minutes remaining to place bet
MAX_MINUTES     = 45     # skip if more than 60 min remaining (too long to wait)
SCAN_INTERVAL   = 120    # scan every 2 minutes
LOG_FILE        = '/root/bond_log.json'

# Track placed positions to avoid duplicates
placed_markets = set()
session_wins   = 0
session_losses = 0
session_pnl    = 0.0

# ── AUTH SETUP ────────────────────────────────────────────────────────────────
tf = tempfile.NamedTemporaryFile(delete=False, suffix=".pem", mode="w")
tf.write(KALSHI_SEC)
tf.close()

from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
config      = Configuration()
config.host = "https://api.elections.kalshi.com/trade-api/v2"
kalshi      = KalshiClient(config)
kalshi.set_kalshi_auth(KALSHI_KEY, tf.name)

def send_telegram(msg):
    try:
        requests.get(
            f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            params={"chat_id": CHAT_ID, "text": msg},
            timeout=5
        )
    except Exception:
        pass

def get_auth_headers(method, url):
    return kalshi.kalshi_auth.create_auth_headers(method, url)

def get_balance():
    url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
    headers = get_auth_headers("GET", url)
    resp    = requests.get(url, headers=headers, timeout=5)
    if resp.status_code == 200:
        data = resp.json()
        return (data.get('balance', 0) + data.get('portfolio_value', 0)) / 100
    return 0

def scan_markets():
    """Fetch all open markets and find near-certain outcomes."""
    url     = "https://api.elections.kalshi.com/trade-api/v2/markets"
    headers = get_auth_headers("GET", url)
    opportunities = []
    cursor = ""

    while True:
        params = {"status": "open", "limit": 100}
        if cursor:
            params["cursor"] = cursor
        resp = requests.get(url, headers=headers, params=params, timeout=10)
        if resp.status_code != 200:
            break
        data    = resp.json()
        markets = data.get("markets", [])
        if not markets:
            break

        for m in markets:
            ticker   = m.get("ticker", "")
            yes_ask  = m.get("yes_ask_dollars")
            no_ask   = m.get("no_ask_dollars")
            close_ts = m.get("close_time") or m.get("expiration_time")

            if not yes_ask or not no_ask or not close_ts:
                continue
            if ticker in placed_markets:
                continue
            # Skip sports parlay/multi-event markets (already resolved, no edge)
            if any(x in ticker for x in ("KXMVE", "MULTIGAME", "CROSSCAT", "PARLAY")):
                continue
            # Skip markets already at 0 or 1 (no cash out value)
            if float(yes_ask) <= 0.01 or float(yes_ask) >= 0.99:
                continue
            if float(yes_ask) + float(no_ask) > 1.02:
                continue

            yes_price = float(yes_ask)
            no_price  = float(no_ask)

            # Calculate minutes remaining
            try:
                close_dt  = datetime.datetime.fromisoformat(
                    close_ts.replace("Z", "+00:00"))
                now_utc   = datetime.datetime.now(datetime.timezone.utc)
                mins_left = (close_dt - now_utc).total_seconds() / 60
            except Exception:
                continue

            if mins_left < MIN_MINUTES or mins_left > MAX_MINUTES:
                continue

            # Check for near-certain outcome
            if yes_price >= YES_HIGH and yes_price < 0.99:
                profit = (1 - yes_price) / yes_price * 100
                if profit >= 0.5:  # minimum 0.5% profit
                    opportunities.append({
                        "ticker":    ticker,
                        "side":      "yes",
                        "price":     yes_price,
                        "mins_left": mins_left,
                        "profit_pct": profit,
                    })
            elif yes_price <= YES_LOW and no_price < 0.99:
                profit = (1 - no_price) / no_price * 100
                if profit >= 0.5:
                    opportunities.append({
                        "ticker":    ticker,
                        "side":      "no",
                        "price":     no_price,
                        "mins_left": mins_left,
                        "profit_pct": profit,
                    })

        cursor = data.get("cursor", "")
        if not cursor:
            break

    return sorted(opportunities, key=lambda x: x["profit_pct"], reverse=True)

def place_bond_bet(opp):
    """Place a bond bet on a near-certain outcome."""
    global session_wins, session_losses, session_pnl

    ticker = opp["ticker"]
    side   = opp["side"]
    price  = opp["price"]
    price_cents = min(99, max(1, round(price * 100) + 1))
    count  = max(1, int(BET_SIZE / price))

    try:
        order = kalshi.create_order(
            ticker=ticker,
            action="buy",
            side=side,
            type="market",
            count=count,
            yes_price=price_cents if side == "yes" else None,
            no_price=price_cents if side == "no" else None,
            time_in_force="ioc",
        )
        placed_markets.add(ticker)
        cost = count * price
        msg  = (f"🔒 BOND: {side.upper()} on {ticker}\n"
                f"Price: {price:.2f} | Cost: ${cost:.2f} | "
                f"Profit if wins: ${count*(1-price):.2f} ({opp['profit_pct']:.1f}%)\n"
                f"Time left: {opp['mins_left']:.0f} min")
        print(msg)
        send_telegram(msg)

        # Log it
        entry = {
            "timestamp": datetime.datetime.now().isoformat(),
            "ticker":    ticker,
            "side":      side,
            "price":     price,
            "count":     count,
            "cost":      cost,
            "mins_left": opp["mins_left"],
        }
        with open(LOG_FILE, 'a') as f:
            f.write(json.dumps(entry) + '\n')
        return True
    except Exception as e:
        print(f"[Bond] Order failed: {e}")
        return False

def check_settled():
    """Check if any placed markets have settled."""
    global session_wins, session_losses, session_pnl
    if not placed_markets:
        return

    url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
    headers = get_auth_headers("GET", url)
    resp    = requests.get(url, headers=headers,
                           params={"limit": 100}, timeout=8)
    if resp.status_code != 200:
        return

    settled = {p["ticker"] for p in resp.json().get("market_positions", [])}
    for ticker in list(placed_markets):
        if ticker not in settled:
            # Check if it finalized
            murl    = f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
            mheader = get_auth_headers("GET", murl)
            mr      = requests.get(murl, headers=mheader, timeout=5)
            if mr.status_code == 200:
                result = mr.json().get("market", {}).get("result", "")
                if result in ("yes", "no"):
                    placed_markets.discard(ticker)

# ── MAIN LOOP ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("OpenClaw Bond Scanner starting...")
    send_telegram("🔒 Bond Scanner started — hunting near-certain outcomes")

    while True:
        if os.path.exists('/root/STOP_BOND'):
            print("STOP_BOND detected — halting")
            break

        try:
            opps = scan_markets()
            bal  = get_balance()
            print(f"[{datetime.datetime.now().strftime('%H:%M')}] "
                  f"Scanned markets | Found {len(opps)} opportunities | "
                  f"Balance: ${bal:.2f}")

            for opp in opps[:3]:  # max 3 bets per scan
                print(f"  → {opp['ticker']} | {opp['side']} @ {opp['price']:.3f} | "
                      f"{opp['mins_left']:.0f}min left | +{opp['profit_pct']:.1f}%")
                place_bond_bet(opp)

        except Exception as e:
            print(f"[Bond] Scan error: {e}")

        time.sleep(SCAN_INTERVAL)
