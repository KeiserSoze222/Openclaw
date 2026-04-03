#!/usr/bin/env python3
"""OpenClaw Whale Scanner v3 — lightweight, no auth hangups"""
import requests, time, datetime, csv, os, threading

raw       = open('/root/real_bot_pre_v4_backup.py').read()
BOT_TOKEN = raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID   = raw.split("CHAT_ID   = '")[1].split("'")[0]
del raw

TRADES_URL     = "https://api.elections.kalshi.com/trade-api/v2/markets/trades"
MIN_ALERT_SIZE = 2000
SCAN_INTERVAL  = 15
LOG_CSV        = "/root/whale_log.csv"
STOP_FILE      = "/root/STOP_WHALE"
OUR_MARKETS    = ("KXBTC15M", "KXETH15M", "KXSOL15M")

seen_ids     = set()
total_whales = 0
total_volume = 0.0

def send_telegram(msg):
    def _send():
        try:
            requests.post(
                f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
                json={"chat_id": CHAT_ID, "text": str(msg)},
                timeout=8)
        except Exception:
            pass
    threading.Thread(target=_send, daemon=True).start()

def fetch_trades(min_ts):
    try:
        resp = requests.get(TRADES_URL,
            params={"limit": 100, "min_ts": min_ts}, timeout=10)
        if resp.status_code == 200:
            return resp.json().get("trades", [])
    except Exception as e:
        print(f"[Whale] Fetch error: {e}")
    return []

def scan_once(min_ts):
    global total_whales, total_volume
    trades = fetch_trades(min_ts)
    for trade in trades:
        tid = trade.get("trade_id","")
        if not tid or tid in seen_ids:
            continue
        seen_ids.add(tid)

        ticker = trade.get("ticker","")
        side   = trade.get("taker_side","").upper()
        count  = float(trade.get("count_fp") or 0)
        yes_p  = float(trade.get("yes_price_dollars") or 0.50)
        size   = round(count*yes_p if side=="YES" else count*(1-yes_p), 2)

        if size < MIN_ALERT_SIZE:
            continue

        total_whales += 1
        total_volume += size
        is_our = any(m in ticker for m in OUR_MARKETS)
        ts = datetime.datetime.now().strftime("%H:%M:%S")
        print(f"[{ts}] {'🎯' if is_our else '🐋'} {side} ${size:,.2f} | {ticker}")

        with open(LOG_CSV, "a", newline="") as f:
            csv.writer(f).writerow([
                datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                ticker, side, f"{size:.2f}", "OUR" if is_our else "OTHER"
            ])

        # Only alert on our markets OR very large whales ($5k+)
        if is_our:
            send_telegram(f"🎯 OUR MARKET!\n{side} ${size:,.0f} on {ticker}")
        elif size >= 5000:
            send_telegram(f"🐋 BIG Whale\n{side} ${size:,.0f} on {ticker}")

if __name__ == "__main__":
    print("🐋 OpenClaw Whale Scanner v3 starting...")
    print(f"Alert >= ${MIN_ALERT_SIZE:,} | Scan every {SCAN_INTERVAL}s")
    min_ts = int(time.time()) - 60
    scan_count = 0

    while True:
        if os.path.exists(STOP_FILE):
            print("[Whale] Stop file — exiting")
            break
        try:
            scan_once(min_ts)
            min_ts = int(time.time()) - 5
            scan_count += 1
            if scan_count % 20 == 0:
                print(f"[{datetime.datetime.now().strftime('%H:%M')}] "
                      f"Whales: {total_whales} | Vol: ${total_volume:,.0f}")
        except Exception as e:
            print(f"[Whale] Error: {e}")
        time.sleep(SCAN_INTERVAL)
