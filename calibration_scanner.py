#!/usr/bin/env python3
"""
OpenClaw Calibration Scanner
Scans ALL Kalshi markets for systematic mispricing.
Buys underpriced contracts based on calibration bias.
Separate from the directional bots - runs independently.
"""
import requests, tempfile, time, datetime, json, csv
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration

raw = open('/root/real_bot_pre_v4_backup.py').read()
KALSHI_API_KEY = raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
KALSHI_SECRET  = raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
BOT_TOKEN      = raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID        = raw.split("CHAT_ID   = '")[1].split("'")[0]
del raw

_tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
_tf.write(KALSHI_SECRET); _tf.close()
_config = Configuration()
_config.host = "https://api.elections.kalshi.com/trade-api/v2"
kalshi = KalshiClient(_config)
kalshi.set_kalshi_auth(KALSHI_API_KEY, _tf.name)

STOP_FILE    = "/root/STOP_CAL"
SCAN_INTERVAL = 120   # seconds between scans
MIN_EDGE     = 0.04   # minimum calibration edge to trade
MAX_BET      = 5.00   # max bet per trade
MIN_BET      = 2.00   # min bet per trade
MIN_MINUTES  = 10     # min minutes remaining
MAX_MINUTES  = 180    # max minutes remaining
LOG_CSV      = "/root/calibration_log.csv"

# Calibration table: actual win rates by price bucket
# Based on academic research (Whelan et al., 300k+ Kalshi contracts)
# Key insight: cheap contracts (under 10c) lose ~60% of capital
# Contracts above 50c earn small positive returns
CALIBRATION = {
    (0.00, 0.05): 0.03,   # market says 0-5%, reality ~3% — slight NO edge
    (0.05, 0.10): 0.07,   # market says 5-10%, reality ~7%
    (0.10, 0.20): 0.15,   # market says 10-20%, reality ~15%
    (0.20, 0.35): 0.28,   # market says 20-35%, reality ~28%
    (0.35, 0.50): 0.43,   # market says 35-50%, reality ~43%
    (0.50, 0.65): 0.57,   # market says 50-65%, reality ~57%
    (0.65, 0.80): 0.72,   # market says 65-80%, reality ~72%
    (0.80, 0.90): 0.84,   # market says 80-90%, reality ~84% — YES edge
    (0.90, 0.95): 0.91,   # market says 90-95%, reality ~91%
    (0.95, 1.00): 0.96,   # market says 95%+, reality ~96%
}

placed_tickers = set()
session_wins = 0
session_losses = 0
session_pnl = 0.0

def send_telegram(msg):
    try:
        requests.get(
            f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            params={"chat_id": CHAT_ID, "text": str(msg)}, timeout=5)
    except Exception:
        pass

def get_live_balance():
    try:
        url = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp = requests.get(url, headers=headers, timeout=8)
        if resp.status_code == 200:
            d = resp.json()
            return (d.get("balance", 0) + d.get("portfolio_value", 0)) / 100
    except Exception:
        pass
    return 0

def get_calibrated_prob(market_price):
    for (lo, hi), true_prob in CALIBRATION.items():
        if lo <= market_price < hi:
            return true_prob
    return market_price

def scan_markets():
    url = "https://api.elections.kalshi.com/trade-api/v2/markets"
    headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
    opportunities = []
    cursor = ""

    while True:
        params = {"status": "open", "limit": 100}
        if cursor:
            params["cursor"] = cursor
        try:
            resp = requests.get(url, headers=headers, params=params, timeout=10)
            if resp.status_code != 200:
                break
            data = resp.json()
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
                if ticker in placed_tickers:
                    continue
                # Skip sports parlays and multi-outcome markets
                if any(x in ticker for x in ("KXMVE", "MULTIGAME", "CROSSCAT")):
                    continue

                yp = float(yes_ask)
                np_ = float(no_ask)

                # Skip if sum > 1.02 (multi-outcome)
                if yp + np_ > 1.02:
                    continue
                # Skip near-zero or near-certain
                if yp <= 0.02 or yp >= 0.98:
                    continue

                # Calculate minutes remaining
                try:
                    close_dt = datetime.datetime.fromisoformat(
                        close_ts.replace("Z", "+00:00"))
                    now_utc  = datetime.datetime.now(datetime.timezone.utc)
                    mins_left = (close_dt - now_utc).total_seconds() / 60
                except Exception:
                    continue

                if mins_left < MIN_MINUTES or mins_left > MAX_MINUTES:
                    continue

                # Get calibrated probability
                true_prob = get_calibrated_prob(yp)
                edge_yes  = true_prob - yp    # positive = YES underpriced
                edge_no   = (1 - true_prob) - np_  # positive = NO underpriced

                # Find best edge
                if edge_yes >= MIN_EDGE:
                    opportunities.append({
                        "ticker":    ticker,
                        "side":      "yes",
                        "price":     yp,
                        "true_prob": true_prob,
                        "edge":      edge_yes,
                        "mins_left": mins_left,
                    })
                elif edge_no >= MIN_EDGE:
                    opportunities.append({
                        "ticker":    ticker,
                        "side":      "no",
                        "price":     np_,
                        "true_prob": 1 - true_prob,
                        "edge":      edge_no,
                        "mins_left": mins_left,
                    })

            cursor = data.get("cursor", "")
            if not cursor:
                break
        except Exception as e:
            print(f"[Scan] Error: {e}")
            break

    return sorted(opportunities, key=lambda x: x["edge"], reverse=True)

def place_bet(opp, balance):
    bet = min(MAX_BET, max(MIN_BET, round(balance * 0.02, 2)))
    ticker = opp["ticker"]
    side   = opp["side"]
    price  = opp["price"]
    edge   = opp["edge"]

    try:
        contracts = max(1, int(bet / 0.50))
        print(f"[Cal] Placing {side.upper()} ${bet:.2f} on {ticker} | price={price:.2f} edge={edge:.3f}")
        order = kalshi.create_order(
            ticker=ticker, action="buy", side=side,
            type="market", count=contracts, time_in_force="ioc"
        )
        if order and hasattr(order, "order") and order.order:
            status = str(order.order.status) if order.order.status else ""
            if status in ("filled", "executed"):
                placed_tickers.add(ticker)
                send_telegram(
                    f"🎯 CAL {side.upper()}: {ticker}\n"
                    f"price={price:.2f} edge={edge:.3f} bet=${bet:.2f}"
                )
                with open(LOG_CSV, "a", newline="") as f:
                    csv.writer(f).writerow([
                        datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                        ticker, side, f"{bet:.2f}", f"{price:.2f}", f"{edge:.3f}",
                        f"{opp['mins_left']:.0f}", "PLACED"
                    ])
                return True
    except Exception as e:
        print(f"[Cal] Order failed: {e}")
    return False

if __name__ == "__main__":
    import os
    print("[Cal] Sending startup message...")
    print("[Cal] Calibration Scanner starting...")

    while True:
        if os.path.exists(STOP_FILE):
            print("[Cal] Stop file detected")
            break
        try:
            balance = get_live_balance()
            opps    = scan_markets()
            print(f"[{datetime.datetime.now().strftime('%H:%M')}] Scanned | "
                  f"Found {len(opps)} opportunities | Balance: ${balance:.2f}")

            # Place top opportunity only (conservative)
            if opps and balance > 150:
                best = opps[0]
                print(f"[Cal] Best: {best['ticker']} {best['side']} "
                      f"edge={best['edge']:.3f} mins={best['mins_left']:.0f}")
                if best["edge"] >= MIN_EDGE:
                    place_bet(best, balance)

        except Exception as e:
            print(f"[Cal] Scan error: {e}")

        time.sleep(SCAN_INTERVAL)
