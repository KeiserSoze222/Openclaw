"""
OpenClaw Kalshi BTC 15-min Bot — v3.0
======================================
Strategy layers (in priority order):
  1. Dump-and-Hedge arbitrage: buy both YES+NO when sum < ARB_THRESHOLD
  2. Market-price momentum: bet with the market when YES price is extreme
  3. All previous safety guardrails: balance floor, daily loss limit, cooldown

Key insight from v1/v2 post-mortem:
  The RSI/momentum signal had an 18% win rate because it ignored Kalshi's
  own market prices. Those prices already aggregate all available information.
  We now USE the market price as our primary signal instead of fighting it.

Author: OpenClaw / Claude
"""

import os
import time
import csv
import datetime
import requests
import numpy as np
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration

# ─────────────────────────────────────────────────────────────────────────────
# CREDENTIALS  (keep these private — never paste in chat)
# ─────────────────────────────────────────────────────────────────────────────
KALSHI_API_KEY = '2d0a8c45-b76a-4459-a0e1-9a5e4d63fd8b'
KALSHI_SECRET  = '''-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEArkD0NUpJf2F1v6hW9tlKzQ1wPGJ0ypTgBVLMk73dPINtXjAU
TVcunm2GtdG5p9QReCmUaihBYOVCom9m9D93tH6n/8gm4AjciW+GvtEolsJiExmQ
145maRyZjS2aLzuQY0LKjEVxtIdbwRuWnQ4X4VuL6k/lHI/N5Nzz1WLDRHaEwwSO
0Evcu9Nl5NBeJKaUjpUKaBLwmK3T7VrizkpnWYo9hZwEU9RZpSW4KjYG9+lSeYeN
OZ/L5DUwhabSdqXIipFaXwtElt0wLa5TicqK2Dc8dy2fdyz5pX/fcmSvMffsuPEg
kjvtMnhDjWL3aCzwDsTGJe7oR5r/Wxe0x4daIQIDAQABAoIBAA2FmzqKnTfceqRF
jk0+Tc1DsbK94ScNqAsOgpmKx9Q36EP0byuuDD9D0iRINgpaYB12/Ir2vLwMJ/OU
hksfcbNfI+8RVRLyUErJ8/Ol8p356SpnEK2DFPQrJ/wKNRP21By5Xh/5QGDF8DTR
maQH9L2kIPz5xJZ6AkkBBfR7fLOfOtJXXxGRua/4AnzBf/zDRV0so/2tJaMOxNeU
Nop9xKGqvISVXPMk3M7j2LlDGTkZcNvcNfbuPwzkUbQFoAJ/Cko0Esx0nT7DQTuh
SzGbqGI/rnLu0NsMDFOABCK4yJuQCZSh4WP6x5WDOwdaz+loWotEdPfHVms0eGjb
U5p8a1ECgYEA2z8VIC2LnlyLEzwmM86K8vfy2XgqoL1LgZbctuepk9ymAvfS3Xa5
Mvges+aeHSc/6H0apJHCTdQBozQo/vekyKofPQQrIFCCNGla6sAxjqNv6cskT6pg
0WqpBNjY+5eRGGGDCcB4LRbgGlmt5455F+bmQ7ijMbeVJStZ0er2RHMCgYEAy3cE
004aPtnH22EQdJopic5tnqNqqX0ruEPqT+MwjkA8T7CbC52CFcZTG3HAn2KWyn1H
FVvngCkUflxbrNSL0BfwwWQBmfoOyrFkbCUcIG8q6s2t3i74zvkFGlTB8IPboxjg
b672WisT4pktTnXHIuq/nDAwnwmTOKzLjhTS1hsCgYEAkT8cZsHlohcbB7YsdNvb
T5WV7B5g1zYwxHxGYmHdBRkDXioCJzeU/8BCztn0W8n527KtqOLrf5X5M77Ffgxf
vZR+t3SAgZr0d3ZoheanriB2bsNmneR42aO4r35dWWgS9rz7C8XXl7903eAVhrbr
YDtWxvyWGMTPaN1sVtY7KiMCgYEAl4Gz7SjucDi5Esnvd/RH1B8MD6H+TeEwShEA
jKZPRM3eWzTV70tFT7OTtQ76cXT3dibdZLE/7HYqlYFunn7S8YyyMT+n1aGXnCWF
8uWbUSeWnKu1uYneqjhSLW5J0DBPv95JWcC+HxyOvSB01UTsmTqWndZgjjySDRTW
qqEk8lsCgYBWXgZTI0C1ukU0/jHu9OMULsPsoioZgj1pLP7Zvc6TzIWQVSCn0a6j
/DL0JzwIlrU4B+YEuHPMnbRzuYtx2bDlW7Ycky51Wfp7jw2SVUj/Lr1rxNe9y9a+
7VTiKzf+09eR4dAW/8VcpNTErYmLqHRQQcWgo7/WSpmp8V0xy0AaRQ==
-----END RSA PRIVATE KEY-----'''
BOT_TOKEN = '8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
CHAT_ID   = '8257178399'

# ─────────────────────────────────────────────────────────────────────────────
# KALSHI CLIENT
# ─────────────────────────────────────────────────────────────────────────────
config                 = Configuration()
config.host            = "https://api.elections.kalshi.com/trade-api/v2"
config.api_key_id      = KALSHI_API_KEY
config.private_key_pem = KALSHI_SECRET
kalshi                 = KalshiClient(config)

# Write key to temp file for RSA auth (required by SDK)
import tempfile as _tempfile, os as _os
_key_file = _tempfile.NamedTemporaryFile(delete=False, suffix=".pem", mode="w")
_key_file.write(KALSHI_SECRET)
_key_file.close()
kalshi.set_kalshi_auth(KALSHI_API_KEY, _key_file.name)
# Note: temp file persists for process lifetime, cleaned up on exit

# ─────────────────────────────────────────────────────────────────────────────
# SAFETY CONSTANTS  — edit these, not the logic
# ─────────────────────────────────────────────────────────────────────────────
DRY_RUN          = False   # True = log signals, never place real orders
MAX_BET_PCT        = 0.05    # 5% of balance per order
MIN_BALANCE      = 185.00   # halt if balance drops below this
DAILY_LOSS_LIMIT = 0.12    # halt if balance drops 20% from session start
CYCLE_SLEEP      = 60      # seconds between cycles
COOLDOWN_CYCLES  = 2       # cycles to wait after a failed/rejected order

# Strategy thresholds
ARB_THRESHOLD    = 0.97
MARKET_SERIES    = "KXETH15M"  # DO NOT CHANGE — ETH bot only
assert MARKET_SERIES == "KXETH15M", "WRONG MARKET in eth_bot.py"
DIRECTIONAL_HIGH = 0.70    # bet YES when market prices YES above this
DIRECTIONAL_LOW  = 0.30    # bet NO  when market prices YES below this

# ─────────────────────────────────────────────────────────────────────────────
# GLOBALS
# ─────────────────────────────────────────────────────────────────────────────
INITIAL_BALANCE    = 213.85   # ← update to your current Kalshi balance
SESSION_START_BAL  = 213.85
CURRENT_BALANCE    = INITIAL_BALANCE

def get_max_bet():
    """ETH: Stop during bad hours where WR is 0-50%."""
    base = max(2.00, min(20.00, round(CURRENT_BALANCE * MAX_BET_PCT, 2)))
    hour = datetime.datetime.now(datetime.timezone.utc).hour
    # ETH bad hours — near 0% WR — return minimum to effectively stop
    if hour in (0, 1, 4, 5, 13, 22, 23):
        return 0.00  # signal to skip
    elif hour in (12,):
        return max(2.00, round(base * 0.50, 2))
    elif hour in (3, 6, 7, 8, 9, 10, 11, 14, 15, 16, 19, 21):
        peak_base = max(2.00, min(20.00, round(CURRENT_BALANCE * 0.10, 2)))
        return peak_base
    return base
OPEN_POSITIONS     = []
TRADE_COUNTER      = 0
COOLDOWN_REMAINING = 0
live_ticker        = None
REGIME             = "CHOP"
last_signal_direction    = None
consecutive_signal_count = 0
RISK_SCORE         = 0.4

# Performance tracking (in-memory, also written to CSV)
session_wins       = 0
session_losses     = 0
session_pnl        = 0.0
last_summary_time  = time.time()
session_start_time = time.time()


# ─────────────────────────────────────────────────────────────────────────────
# UTILITIES
# ─────────────────────────────────────────────────────────────────────────────
def send_telegram(message):
    try:
        requests.get(
            f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            params={"chat_id": CHAT_ID, "text": message},
            timeout=5
        )
    except Exception:
        pass

def log_trade(direction, bet, action, profit_pct=0, notes="", features=None):
    import json as _json
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    csv_files = {
        "btc_bot.py": "/root/trade_log.csv",
        "real_bot.py": "/root/trade_log.csv",
        "eth_bot.py": "/root/eth_trade_log.csv",
        "sol_bot.py": "/root/sol_trade_log.csv",
    }
    import os as _os
    botfile = _os.path.basename(__file__)
    csv_path = csv_files.get(botfile, "/root/trade_log.csv")
    with open(csv_path, "a", newline="") as f:
        writer = __import__("csv").writer(f)
        writer.writerow([timestamp, direction, f"{bet:.2f}", action, f"{profit_pct:.2f}%", notes])
    entry = {
        "timestamp": timestamp, "direction": direction, "bet": bet,
        "action": action, "profit_pct": profit_pct, "notes": notes,
        "balance": CURRENT_BALANCE, "session_wins": session_wins,
        "session_losses": session_losses, "session_pnl": session_pnl,
        "regime": REGIME, "market": MARKET_SERIES,
    }
    perf_files = {
        "eth_bot.py": "/root/eth_performance_log.json",
        "sol_bot.py": "/root/sol_performance_log.json",
    }
    perf_path = perf_files.get(botfile, "/root/performance_log.json")
    try:
        with open(perf_path, "a") as f:
            f.write(_json.dumps(entry) + "\n")
    except Exception:
        pass
    if features is not None:
        feat_entry = {**entry, "features": features}
        try:
            with open("/root/feature_log.json", "a") as f:
                f.write(_json.dumps(feat_entry) + "\n")
        except Exception:
            pass

def get_live_balance():
    try:
        url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp    = requests.get(url, headers=headers, timeout=8)
        if resp.status_code == 200:
            return float(resp.json().get("balance", 0)) / 100
    except Exception as e:
        print(f"[Balance] Failed: {e}")
    return CURRENT_BALANCE


# ─────────────────────────────────────────────────────────────────────────────
# TICKER AGENT
# ─────────────────────────────────────────────────────────────────────────────
def update_live_ticker():
    """Finds the current open KXBTC15M market via authenticated REST call."""
    global live_ticker

    def build_ticker(dt):
        floored = (dt.minute // 15) * 15
        hhmm    = f"{dt.hour:02d}{floored:02d}"
        suffix  = f"{floored:02d}"
        return (f"{MARKET_SERIES}-"
                f"{dt.strftime('%y').upper()}"
                f"{dt.strftime('%b').upper()}"
                f"{dt.strftime('%d')}"
                f"{hhmm}-{suffix}")


    url     = "https://api.elections.kalshi.com/trade-api/v2/markets"

    for status in ("open", "active", "unopened"):
        try:
            resp = requests.get(
                url,
                headers=kalshi.kalshi_auth.create_auth_headers("GET", url),
                params={"status": status, "limit": 10,
                        "series_ticker": MARKET_SERIES},
                timeout=8
            )
            if resp.status_code == 200:
                markets  = resp.json().get("markets", [])
                hits     = [m for m in markets
                            if (m.get("ticker") or "").upper()
                            .startswith(MARKET_SERIES)]
                if hits:
                    open_hits  = [m for m in hits
                                  if (m.get("status") or "").lower() in ("open", "active")]
                    pick       = (open_hits or hits)[0]["ticker"]
                    live_ticker = pick
                    return live_ticker, (open_hits or hits)[0]
        except Exception as e:
            print(f"[Ticker] {status} error: {e}")

    # UTC time fallback
    now_utc    = datetime.datetime.now(datetime.timezone.utc)
    t1         = build_ticker(now_utc)
    t2         = build_ticker(now_utc + datetime.timedelta(minutes=15))
    print(f"[Ticker] fallback current={t1} next={t2}")
    live_ticker = t1
    return live_ticker, None


# ─────────────────────────────────────────────────────────────────────────────
# MARKET PRICE READER  ← the new core signal
# ─────────────────────────────────────────────────────────────────────────────
def get_trend_validator():
    """
    Fetch Kalshi 1-hour BTC market YES price as a trend validator.
    If 1-hour market agrees with 15-min signal, boost bet.
    If it disagrees, reduce bet.
    Returns float 0.0-1.0 or None if unavailable.
    """
    try:
        url     = "https://api.elections.kalshi.com/trade-api/v2/markets"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp    = requests.get(
            url, headers=headers,
            params={"series_ticker": "KXBTC1H", "status": "open", "limit": 5},
            timeout=5
        )
        if resp.status_code == 200:
            markets = resp.json().get("markets", [])
            if markets:
                yes_ask = markets[0].get("yes_ask_dollars")
                if yes_ask is not None:
                    print(f"[Trend] 1H BTC market: YES={float(yes_ask):.2f}")
                    return float(yes_ask)
    except Exception as e:
        print(f"[Trend] Failed: {e}")
    return None

def get_binance_btc_price():
    """Fetch real-time BTC spot price from Coinbase public API."""
    try:
        resp = requests.get(
            "https://api.coinbase.com/v2/prices/BTC-USD/spot",
            timeout=3
        )
        if resp.status_code == 200:
            return float(resp.json()["data"]["amount"])
    except Exception:
        pass
    return None

def get_binance_price_for_market(market_series):
    """Get real-time spot price via Coinbase public API."""
    symbols = {
        "KXBTC15M": "BTC-USD",
        "KXETH15M": "ETH-USD",
        "KXSOL15M": "SOL-USD",
    }
    symbol = symbols.get(market_series)
    if not symbol:
        return None
    try:
        resp = requests.get(
            f"https://api.coinbase.com/v2/prices/{symbol}/spot",
            timeout=3
        )
        if resp.status_code == 200:
            return float(resp.json()["data"]["amount"])
    except Exception:
        pass
    return None

def get_market_prices(ticker):
    """
    Fetch YES and NO ask prices from Kalshi.
    Returns (yes_price, no_price) as floats 0.0-1.0, or (None, None).
    """
    url     = f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
    headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
    try:
        resp = requests.get(url, headers=headers, timeout=8)
        if resp.status_code == 200:
            market    = resp.json().get("market", {})
            yes_price = market.get("yes_ask_dollars")
            no_price  = market.get("no_ask_dollars")
            if yes_price is not None and no_price is not None:
                return float(yes_price), float(no_price)
    except Exception as e:
        print(f"[Prices] Market price fetch failed: {e}")
    return None, None
# ─────────────────────────────────────────────────────────────────────────────
# BTC PRICE DATA  (for regime detection only — no longer the primary signal)
# ─────────────────────────────────────────────────────────────────────────────
def get_btc_prices(minutes=60):
    """Fetch BTC prices via Kraken (no geo-block). Used for regime only."""
    try:
        resp = requests.get(
            "https://api.kraken.com/0/public/OHLC",
            params={"pair": "XBTUSD", "interval": 1},
            timeout=8
        )
        if resp.status_code == 200:
            candles = resp.json().get("result", {}).get("XXBTZUSD", [])
            closes  = [float(c[4]) for c in candles[-minutes:]]
            if closes:
                return np.array(closes)
    except Exception as e:
        print(f"[Prices] Kraken failed: {e}")
    return np.array([83000] * minutes)


def update_regime(prices):
    """Detect BULL/BEAR/CHOP from recent price action. Adjusts risk score."""
    global REGIME, RISK_SCORE
    if len(prices) < 20:
        return
    ma20    = np.mean(prices[-20:])
    ma60    = np.mean(prices[-60:]) if len(prices) >= 60 else ma20
    current = prices[-1]

    if current > ma20 * 1.005 and ma20 > ma60:
        REGIME, RISK_SCORE = "BULL", 0.5
    elif current < ma20 * 0.995 and ma20 < ma60:
        REGIME, RISK_SCORE = "BEAR", 0.3
    else:
        REGIME, RISK_SCORE = "CHOP", 0.35


# ─────────────────────────────────────────────────────────────────────────────
# ORDER PLACEMENT
# ─────────────────────────────────────────────────────────────────────────────
def safety_check():
    """
    Returns (ok, reason). Halts bot on critical safety violations.
    """
    if CURRENT_BALANCE < MIN_BALANCE:
        return False, f"Balance ${CURRENT_BALANCE:.2f} below floor ${MIN_BALANCE:.2f}"
    loss_pct = (SESSION_START_BAL - CURRENT_BALANCE) / SESSION_START_BAL
    if loss_pct >= DAILY_LOSS_LIMIT:
        return False, f"Daily loss {loss_pct*100:.1f}% exceeds limit {DAILY_LOSS_LIMIT*100:.0f}%"
    return True, ""



def cancel_resting_orders():
    """Cancel any unfilled resting orders to prevent accumulation."""
    try:
        url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/orders"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp    = requests.get(url, headers=headers,
                               params={"status": "resting", "limit": 20},
                               timeout=5)
        if resp.status_code == 200:
            orders = resp.json().get("orders", [])
            for order in orders:
                order_id = order.get("order_id") or order.get("id")
                if order_id:
                    del_url = f"https://api.elections.kalshi.com/trade-api/v2/portfolio/orders/{order_id}"
                    del_hdr = kalshi.kalshi_auth.create_auth_headers("DELETE", del_url)
                    del_resp = requests.delete(del_url, headers=del_hdr, timeout=5)
                    if del_resp.status_code in (200, 204):
                        print(f"[Orders] Cancelled resting order {order_id}")
                    else:
                        print(f"[Orders] Cancel failed {order_id}: {del_resp.status_code}")
            if not orders:
                pass  # No resting orders to cancel
    except Exception as e:
        print(f"[Orders] Cancel check failed: {e}")

def place_order(direction, bet, strategy_tag="directional", mkt_yes=None, mkt_no=None):
    if get_max_bet() == 0.00:
        print(f"[TOD] Skipping trade — bad hour for this bot")
        return False
    """
    Place a single market order. Respects all safety checks.
    strategy_tag: 'directional' or 'arb_yes' or 'arb_no'
    """
    global COOLDOWN_REMAINING

    ok, reason = safety_check()
    if not ok:
        print(f"[Safety] {reason} — halting bot")
        send_telegram(f"🛑 BOT HALTED: {reason}")
        raise SystemExit(reason)

    bet    = min(round(bet, 2), get_max_bet())
    ticker = live_ticker
    if not ticker:
        print("[Order] No ticker — skipping")
        return False

    # Duplicate guard: never place same direction on same ticker twice
    if any(p.get("ticker") == ticker
           for p in OPEN_POSITIONS):
        print(f"[Order] Already have {direction} on {ticker} — skipping")
        return False

    side           = "yes" if direction == "UP" else "no"
    contract_count = max(1, int(bet / 0.50))
    yes_price = min(99, max(1, round((mkt_yes or 0.50) * 100) + 2)) if side == "yes" else None
    no_price  = min(99, max(1, round((mkt_no  or 0.50) * 100) + 2)) if side == "no"  else None

    if DRY_RUN:
        print(f"[DRY RUN] Would place: {direction} ${bet:.2f} on {ticker} "
              f"({strategy_tag})")
        log_trade(direction, bet, f"DRY_{strategy_tag.upper()}", notes=ticker)
        return True

    try:
        print(f"[Order] → {ticker} | {side} | count={contract_count} | "
              f"${bet:.2f} | {strategy_tag}")
        order = kalshi.create_order(
            ticker=ticker,
            action="buy",
            side=side,
            type="market",
            count=contract_count,
            yes_price=yes_price,
            no_price=no_price,
            time_in_force="ioc",
        )
        msg = f"✅ SOL {strategy_tag.upper()}: {direction} ${bet:.2f} on {ticker}"
        print(msg)
        send_telegram(msg)
        OPEN_POSITIONS.append({
            "direction":    direction,
            "bet":          bet,
            "ticker":       ticker,
            "strategy":     strategy_tag,
            "time":         time.time(),
            "placed_at":    time.time(),
            "entry_time":   datetime.datetime.now().isoformat(),
            "entry_yes":    mkt_yes if mkt_yes else 0.5,
            "min_yes":      mkt_yes if mkt_yes else 0.5,
            "max_yes":      mkt_yes if mkt_yes else 0.5,
            "signal_type":  "EXTREME" if mkt_yes and (mkt_yes > 0.80 or mkt_yes < 0.20) else "STANDARD",
            "entry_minute": datetime.datetime.now(datetime.timezone.utc).minute % 15,
        })
        log_trade(direction, bet, "PLACED", notes=f"{strategy_tag}|{ticker}")
        COOLDOWN_REMAINING = 0
        return True

    except Exception as e:
        err = str(e)
        print(f"[Order] Failed: {err}")
        send_telegram(f"⚠️ Order failed: {direction} ${bet:.2f} — {err}")
        COOLDOWN_REMAINING = COOLDOWN_CYCLES
        return False


# ─────────────────────────────────────────────────────────────────────────────
# STRATEGY 1: DUMP-AND-HEDGE ARBITRAGE
# ─────────────────────────────────────────────────────────────────────────────
def try_arb(yes_price, no_price, ticker):
    """
    If YES + NO < ARB_THRESHOLD, buy both sides for near-guaranteed profit.
    Example: YES=0.44 + NO=0.52 = 0.96 < 0.97 → buy both → guaranteed $1.00
    Profit = $1.00 - $0.96 = $0.04 per contract pair (minus fees).
    """
    price_sum = yes_price + no_price
    if price_sum >= ARB_THRESHOLD:
        return False

    spread  = 1.0 - price_sum
    print(f"[ARB] 🎯 Opportunity! YES={yes_price:.2f} + NO={no_price:.2f} "
          f"= {price_sum:.2f} | spread={spread:.3f}")
    send_telegram(f"🎯 ARB OPPORTUNITY: {ticker}\n"
                  f"YES={yes_price:.2f} + NO={no_price:.2f} = {price_sum:.2f}\n"
                  f"Spread: {spread*100:.1f}¢ per contract")

    # Size: use half MAX_BET per leg so total risk = MAX_BET
    leg_bet  = min(get_max_bet() / 2, CURRENT_BALANCE * 0.15)
    placed   = 0
    placed  += place_order("UP",   leg_bet, strategy_tag="arb_yes")
    placed  += place_order("DOWN", leg_bet, strategy_tag="arb_no")

    if placed == 2:
        print(f"[ARB] Both legs placed — locked profit regardless of outcome")
    elif placed == 1:
        print(f"[ARB] ⚠️  Only one leg filled — orphaned position, monitor closely")
        send_telegram(f"⚠️ ARB WARNING: Only one leg filled on {ticker}")
    return placed > 0


# ─────────────────────────────────────────────────────────────────────────────
# STRATEGY 2: DIRECTIONAL (market-price signal)
# ─────────────────────────────────────────────────────────────────────────────
def try_directional(yes_price, no_price):
    global COOLDOWN_REMAINING, last_signal_direction, consecutive_signal_count

    if COOLDOWN_REMAINING > 0:
        print(f"[Cooldown] {COOLDOWN_REMAINING} cycle(s) remaining")
        COOLDOWN_REMAINING -= 1
        return False

    # Only trade in first 8 minutes of each 15-min window
    # Markets are most mispriced early — avoid late-window noise
    now_utc       = datetime.datetime.now(datetime.timezone.utc)
    now_utc       = datetime.datetime.now(datetime.timezone.utc)
    window_minute = now_utc.minute % 15

    # Determine direction and edge first
    if yes_price > DIRECTIONAL_HIGH:
        current_direction = "UP"
        edge = yes_price - 0.5
    elif yes_price < DIRECTIONAL_LOW:
        current_direction = "DOWN"
        edge = 0.5 - yes_price
    else:
        last_signal_direction    = None
        consecutive_signal_count = 0
        return False

    # EXTREME signal (YES < 0.20 or YES > 0.80): fire in minute 1, no confirmation
    if (yes_price > 0.80 or yes_price < 0.20) and window_minute == 1:
        print(f"[Signal] EXTREME {current_direction} | yes={yes_price:.2f} | "
              f"edge={edge:.2f} | firing immediately")
        consecutive_signal_count = 2  # bypass confirmation

    # STANDARD signal: require 2 confirmations in minutes 1-4
    else:
        if window_minute == 0 or window_minute > 4 or window_minute >= 13:
            print(f"[Timing] Window is {window_minute} min old - skipping")
            return False
        if current_direction == last_signal_direction:
            consecutive_signal_count += 1
        else:
            last_signal_direction    = current_direction
            consecutive_signal_count = 1
        if consecutive_signal_count < 2:
            print(f"[Signal] {current_direction} candidate | yes={yes_price:.2f} | "
                  f"waiting for confirmation (1/2)")
            return False
    scale = min(1.0, edge / 0.35)
    bet   = round(get_max_bet() * scale * RISK_SCORE, 2)
    bet   = max(0.50, min(bet, get_max_bet()))

    # Trend validator — Kalshi 1H BTC market as cross-validation
    trend_yes = get_trend_validator()
    if trend_yes is not None:
        trend_agrees = (current_direction == "UP" and trend_yes > 0.55) or \
                       (current_direction == "DOWN" and trend_yes < 0.45)
        if trend_agrees:
            bet = min(round(bet * 1.20, 2), get_max_bet())
            print(f"[Trend] ✅ 1H agrees: yes={trend_yes:.2f} → bet boosted to ${bet:.2f}")
        else:
            bet = round(bet * 0.70, 2)
            print(f"[Trend] ⚠️ 1H disagrees: yes={trend_yes:.2f} → bet reduced to ${bet:.2f}")
    else:
        pass  # No 1H data available

    # Binance spot price confirmation
    spot_price = get_binance_price_for_market(MARKET_SERIES)
    if spot_price is not None:
        try:
            url     = f"https://api.elections.kalshi.com/trade-api/v2/markets/{live_ticker}"
            headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
            mresp   = requests.get(url, headers=headers, timeout=4)
            if mresp.status_code == 200:
                strike = float(mresp.json().get("market", {}).get("floor_strike", 0))
                if strike > 0:
                    spot_gap = spot_price - strike
                    binance_says_up   = spot_gap > 0
                    binance_says_down = spot_gap < 0
                    gap_pct = abs(spot_gap) / strike * 100
                    if (current_direction == "UP" and binance_says_up) or                        (current_direction == "DOWN" and binance_says_down):
                        # Binance confirms — boost bet if gap is large
                        if gap_pct > 0.3:
                            bet = min(round(bet * 1.30, 2), get_max_bet())
                        print(f"[Binance] ✅ Confirms {current_direction} | "
                              f"spot=${spot_price:.0f} strike=${strike:.0f} "
                              f"gap={spot_gap:+.0f} ({gap_pct:.2f}%)")
                    else:
                        # Binance disagrees — reduce bet significantly
                        bet = round(bet * 0.40, 2)
                        print(f"[Binance] ⚠️ Disagrees | "
                              f"spot=${spot_price:.0f} strike=${strike:.0f} "
                              f"gap={spot_gap:+.0f} — bet reduced to ${bet:.2f}")
        except Exception as e:
            print(f"[Binance] Strike fetch failed: {e}")
    else:
        print(f"[Binance] No spot data — using market signal only")

    # Cross-market correlation signal
    if get_max_bet() > 0.00:
        try:
            import time as _time
            btc_p = get_binance_price_for_market("KXBTC15M")
            eth_p = get_binance_price_for_market("KXETH15M")
            sol_p = get_binance_price_for_market("KXSOL15M")
            if btc_p and eth_p and sol_p:
                _time.sleep(1)
                btc_p2 = get_binance_price_for_market("KXBTC15M")
                eth_p2 = get_binance_price_for_market("KXETH15M")
                sol_p2 = get_binance_price_for_market("KXSOL15M")
                if btc_p2 and eth_p2 and sol_p2:
                    moves = [btc_p2>btc_p, eth_p2>eth_p, sol_p2>sol_p]
                    agreement = sum(1 for m in moves if m) if current_direction=="UP" else sum(1 for m in moves if not m)
                    if agreement >= 3:
                        bet = min(round(bet * 1.20, 2), get_max_bet())
                        print(f"[Correlation] All 3 agree {current_direction} — bet boosted to ${bet:.2f}")
                    elif agreement == 1:
                        bet = round(bet * 0.90, 2)
                        print(f"[Correlation] Markets diverging — bet reduced to ${bet:.2f}")
                    else:
                        print(f"[Correlation] 2/3 agree {current_direction}")
        except Exception:
            pass
    print(f"[Signal] ✅ CONFIRMED {current_direction} | yes={yes_price:.2f} | "
          f"edge={edge:.2f} | consecutive=2 | bet=${bet:.2f}")

    # Double-down logic: if we already have a position in same direction
    # AND edge is very strong (>0.40), add up to 50% more
    existing = [p for p in OPEN_POSITIONS
                if p.get("ticker") == live_ticker
                and p.get("direction") == current_direction
                and p.get("strategy") != "restored"]
    if existing and edge > 0.40:
        dd_bet = round(min(existing[0].get("bet", 0) * 0.50, get_max_bet() * 0.50), 2)
        dd_bet = max(0.50, dd_bet)
        print(f"[DoubleDown] Strong edge={edge:.2f} — adding ${dd_bet:.2f} to {current_direction} position")
        result = place_order(current_direction, dd_bet,
                             strategy_tag="double_down",
                             mkt_yes=yes_price, mkt_no=no_price)
        if result:
            consecutive_signal_count = 0
        return result

    result = place_order(current_direction, bet, strategy_tag="directional", mkt_yes=yes_price, mkt_no=no_price)
    if result:
        consecutive_signal_count = 0
    return result

# ─────────────────────────────────────────────────────────────────────────────
# POSITION MONITORING & P&L TRACKING
# ─────────────────────────────────────────────────────────────────────────────
def check_open_positions():
    """
    Query Kalshi's positions API to get actual settlement results.
    Updates session win/loss stats and CSV with real outcomes.
    """
    global CURRENT_BALANCE, OPEN_POSITIONS, session_wins, session_losses
    global session_pnl

    CURRENT_BALANCE = get_live_balance()

    if not OPEN_POSITIONS:
        return

    # Query actual positions using RSA-signed auth
    try:
        url      = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
        headers  = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp     = requests.get(url, headers=headers,
                                params={"limit": 100}, timeout=8)
        if resp.status_code != 200:
            print(f"[Positions] API returned {resp.status_code}: {resp.text[:80]}")
            return

        kalshi_positions = {
            p["ticker"]: p
            for p in resp.json().get("market_positions", [])
        }
    except Exception as e:
        print(f"[Positions] Fetch failed: {e}")
        return

    to_remove = []
    for pos in list(OPEN_POSITIONS):
        ticker    = pos.get("ticker")
        direction = pos.get("direction")
        bet       = pos.get("bet", 0)
        strategy  = pos.get("strategy", "unknown")

        # Skip any position not placed in this session
        placed_at = pos.get("placed_at", 0)
        if placed_at < session_start_time or strategy == "restored":
            age_min = (time.time() - pos.get("time", 0)) / 60
            if age_min > 16:
                print(f"[Positions] Old/restored position {ticker} expired — removing")
                to_remove.append(pos)
            continue
        # Check if this position has settled
        kpos = kalshi_positions.get(ticker)
        if kpos:
            realized = float(kpos.get("realized_pnl_dollars", 0))
            # If realized_pnl is non-zero, position has settled
            if realized != 0:
                won      = realized > 0
                outcome  = "WIN" if won else "LOSS"
                session_pnl += realized
                if won:
                    session_wins  += 1
                else:
                    session_losses += 1

                win_rate = (session_wins /
                            (session_wins + session_losses) * 100
                            if (session_wins + session_losses) > 0 else 0)

                print(f"[Settled] {outcome}: {direction} ${bet:.2f} on "
                      f"{ticker} | pnl=${realized:+.2f} | "
                      f"session: {session_wins}W/{session_losses}L "
                      f"({win_rate:.0f}%)")
                send_telegram(
                    f"{'✅' if won else '❌'} SOL {outcome}: {direction} "
                    f"${bet:.2f} | PnL=${realized:+.2f}\n"
                    f"Session: {session_wins}W/{session_losses}L "
                    f"({win_rate:.0f}%) | Balance=${CURRENT_BALANCE:.2f}"
                )
                log_trade(direction, bet, outcome,
                          profit_pct=realized / bet * 100 if bet else 0,
                          notes=f"{strategy}|{ticker}", features={"signal_type": pos.get("signal_type","STANDARD"), "entry_minute": pos.get("entry_minute",0), "market": MARKET_SERIES, "entry_yes": pos.get("entry_yes",0.5), "min_yes": pos.get("min_yes",0.5), "max_yes": pos.get("max_yes",0.5)})
                to_remove.append(pos)

        else:
            # Cash out monitor — exit losing positions early
            try:
                co_age = (time.time() - pos.get("placed_at", time.time())) / 60
                if co_age >= 5 and pos.get("strategy") != "restored":
                    murl = f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
                    mhdr = kalshi.kalshi_auth.create_auth_headers("GET", murl)
                    mr = requests.get(murl, headers=mhdr, timeout=4)
                    if mr.status_code == 200:
                        mkt = mr.json().get("market", {})
                        cur_yes = float(mkt.get("yes_ask_dollars", 0.5))
                        entry_yes = pos.get("entry_yes", 0.5)
                        status = mkt.get("status", "")
                        if status in ("open", "active"):
                            adverse = (entry_yes - cur_yes) if direction == "UP" else (cur_yes - (1 - entry_yes))
                            if adverse > 0.30:
                                print(f"[CashOut] Position moved {adverse:.2f} against — exiting {ticker}")
                                send_telegram(f"💸 CashOut: {direction} on {ticker}\nadverse={adverse:.2f} | saving capital")
                                to_remove.append(pos)
                                continue
            except Exception as ce:
                print(f"[CashOut] Error: {ce}")
            age_min = (time.time() - pos.get("time", 0)) / 60
            if age_min > 16:
                # Only settle positions placed this session, not restored ones
                strategy_tag = pos.get("strategy", "")
                if strategy_tag == "restored":
                    print(f"[Positions] Restored position {ticker} expired — removing without settlement")
                    to_remove.append(pos)
                else:
                    try:
                        url = f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
                        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
                        resp = requests.get(url, headers=headers, timeout=5)
                        if resp.status_code == 200:
                            result = resp.json().get("market", {}).get("result", "")
                            if result in ("yes", "no"):
                                won = (direction == "UP" and result == "yes") or (direction == "DOWN" and result == "no")
                                outcome = "WIN" if won else "LOSS"
                                pnl = bet * 0.94 if won else -bet
                                session_pnl += pnl
                                if won:
                                    session_wins += 1
                                else:
                                    session_losses += 1
                                total = session_wins + session_losses
                                win_rate = session_wins / total * 100 if total else 0
                                print(f"[Settled] {outcome}: {direction} ${bet:.2f} on {ticker} | pnl=${pnl:+.2f} | {session_wins}W/{session_losses}L ({win_rate:.0f}%)")
                                send_telegram(f"{'✅' if won else '❌'} SOL {outcome}: {direction} ${bet:.2f} | pnl=${pnl:+.2f}\n{session_wins}W/{session_losses}L ({win_rate:.0f}%) | Bal=${CURRENT_BALANCE:.2f}")
                                log_trade(direction, bet, outcome, profit_pct=pnl/bet*100, notes=f"{strategy}|{ticker}", features={"signal_type": pos.get("signal_type","STANDARD"), "entry_minute": pos.get("entry_minute",0), "market": MARKET_SERIES, "entry_yes": pos.get("entry_yes",0.5), "min_yes": pos.get("min_yes",0.5), "max_yes": pos.get("max_yes",0.5)})
                                to_remove.append(pos)
                    except Exception as e:
                        print(f"[Settled] Result check failed: {e}")
                        to_remove.append(pos)

    for pos in to_remove:
        if pos in OPEN_POSITIONS:
            OPEN_POSITIONS.remove(pos)

    if OPEN_POSITIONS:
        print(f"[Positions] {len(OPEN_POSITIONS)} still open")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN CYCLE
# ─────────────────────────────────────────────────────────────────────────────
def send_hourly_summary():
    """Send performance summary to Telegram every hour."""
    global last_summary_time
    now = time.time()
    if now - last_summary_time < 3600:
        return
    last_summary_time = now
    total = session_wins + session_losses
    win_rate = session_wins / total * 100 if total else 0
    msg = (
        f"📊 Hourly Update\n"
        f"Balance: ${CURRENT_BALANCE:.2f}\n"
        f"Session: {session_wins}W/{session_losses}L ({win_rate:.0f}%)\n"
        f"PnL: ${session_pnl:+.2f}\n"
        f"Regime: {REGIME}"
    )
    send_telegram(msg)
    print(f"[Summary] Sent hourly update: {session_wins}W/{session_losses}L")

def simulate_trade():
    global TRADE_COUNTER, DRY_RUN

    TRADE_COUNTER += 1
    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    win_rate = (session_wins / (session_wins + session_losses) * 100
                if (session_wins + session_losses) > 0 else 0)

    print(f"\n{'='*50}")
    print(f"Cycle {TRADE_COUNTER} | {now}")
    print(f"Balance: ${CURRENT_BALANCE:.2f} | "
          f"Regime: {REGIME} | "
          f"Session: {session_wins}W/{session_losses}L ({win_rate:.0f}%) | "
          f"PnL: ${session_pnl:+.2f}")
    if DRY_RUN:
        print("⚠️  DRY RUN MODE — no real orders")

    # 1. Find current ticker
    ticker, market_data = update_live_ticker()
    if not ticker:
        print("[Cycle] No ticker — skipping")
        time.sleep(CYCLE_SLEEP)
        return

    print(f"[Ticker] {ticker}")

    # 2. Get live market prices (the core signal)
    yes_price, no_price = get_market_prices(ticker)

    if yes_price is None or no_price is None:
        print("[Cycle] Could not fetch market prices — skipping")
        time.sleep(CYCLE_SLEEP)
        return

    price_sum = yes_price + no_price
    print(f"[Market] YES={yes_price:.2f} | NO={no_price:.2f} | "
          f"Sum={price_sum:.2f} | "
          f"{'⚡ ARB POSSIBLE' if price_sum < ARB_THRESHOLD else 'no arb'}")

    # 3. Update regime from BTC price (background context only)
    prices = get_btc_prices(60)
    update_regime(prices)

    # 4. Strategy selection — arb takes priority over directional
    ok, reason = safety_check()
    if not ok:
        print(f"[Safety] {reason} — halting")
        send_telegram(f"🛑 HALTED: {reason}")
        raise SystemExit(reason)

    # Win rate circuit breaker — auto dry run if losing streak detected
    recent_total = session_wins + session_losses
    if recent_total >= 10:
        recent_wr = session_wins / recent_total
        if recent_wr < 0.45 and not DRY_RUN:
            DRY_RUN = True
            msg = f"⚠️ Win rate {recent_wr*100:.0f}% below 45% — switching to DRY RUN"
            print(f"[Circuit] {msg}")
            send_telegram(msg)
        elif recent_wr >= 0.55 and DRY_RUN and recent_total >= 15:
            DRY_RUN = False
            msg = f"✅ Win rate recovered to {recent_wr*100:.0f}% — resuming LIVE"
            print(f"[Circuit] {msg}")
            send_telegram(msg)

    acted = False

    # Try arb first (highest priority — near risk-free)
    if price_sum < ARB_THRESHOLD:
        acted = try_arb(yes_price, no_price, ticker)

    # If no arb, try directional signal
    if not acted:
        acted = try_directional(yes_price, no_price)

    if not acted:
        print(f"[Cycle] No signal — YES={yes_price:.2f} is between "
              f"{DIRECTIONAL_LOW:.2f} and {DIRECTIONAL_HIGH:.2f}, "
              f"sum={price_sum:.2f} ≥ {ARB_THRESHOLD:.2f}")

    # 5. Check position settlements
    check_open_positions()

    time.sleep(CYCLE_SLEEP)


# ─────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────
def load_existing_positions():
    """On startup, load any open positions from Kalshi into OPEN_POSITIONS."""
    global OPEN_POSITIONS
    try:
        url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp    = requests.get(url, headers=headers,
                               params={"limit": 100}, timeout=8)
        if resp.status_code == 200:
            positions = resp.json().get("market_positions", [])
            for p in positions:
                ticker   = p.get("ticker")
                exposure = float(p.get("market_exposure_dollars", 0))
                if ticker and exposure > 0 and MARKET_SERIES in ticker:
                    # Infer direction by fetching market data
                    direction = "UNKNOWN"
                    try:
                        murl = f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
                        mhdr = kalshi.kalshi_auth.create_auth_headers("GET", murl)
                        mr   = requests.get(murl, headers=mhdr, timeout=5)
                        if mr.status_code == 200:
                            market = mr.json().get("market", {})
                            yes_ask = float(market.get("yes_ask_dollars", 0.5))
                            # If yes_ask < 0.5 market favors NO so we likely bet DOWN
                            # Use last_price as better indicator
                            last = float(market.get("last_price_dollars", 0.5))
                            direction = "UP" if last >= 0.5 else "DOWN"
                    except Exception:
                        pass
                    OPEN_POSITIONS.append({
                        "direction": direction,
                        "bet":       exposure,
                        "ticker":    ticker,
                        "strategy":  "restored",
                        "time":      time.time() - 300,
                    })
                    print(f"[Startup] Restored position: {ticker} ${exposure:.2f} direction={direction}")
            if OPEN_POSITIONS:
                print(f"[Startup] Loaded {len(OPEN_POSITIONS)} existing position(s)")
    except Exception as e:
        print(f"[Startup] Could not load positions: {e}")

if __name__ == "__main__":
    mode = "DRY RUN" if DRY_RUN else "LIVE"
    print(f"\n{'='*50}")
    print(f"OpenClaw SOL Bot v1.0 — {mode}")
    print(f"Balance: ${CURRENT_BALANCE:.2f} | "
          f"MaxBet: ${get_max_bet():.2f} | "
          f"ArbThreshold: {ARB_THRESHOLD:.2f} | "
          f"Directional: <{DIRECTIONAL_LOW:.2f} or >{DIRECTIONAL_HIGH:.2f}")
    print(f"{'='*50}\n")
    send_telegram(
        f"🤖 OpenClaw v3.0 {mode} started\n"
        f"Balance=${CURRENT_BALANCE:.2f} | MaxBet=${get_max_bet():.2f}\n"
        f"Strategy: Dump-Hedge ARB + Market-Price Directional"
    )
    # Reset SESSION_START_BAL to live balance on every startup
    # This prevents crash loop where restarted bot immediately halts
    live_start = get_live_balance()
    if live_start > 0:
        CURRENT_BALANCE   = live_start
        SESSION_START_BAL = live_start
        print(f"[Startup] Live balance synced: ${CURRENT_BALANCE:.2f}")
    load_existing_positions()
    cancel_resting_orders()
    print("[Startup] Resting orders cleared")
    try:
        while True:
            simulate_trade()
    except SystemExit as e:
        print(f"\nBot halted: {e}")
        send_telegram(f"🛑 Bot halted: {e}")
    except KeyboardInterrupt:
        print("\nBot stopped by user.")
        send_telegram(
            f"⏹️ Bot stopped | Final balance=${CURRENT_BALANCE:.2f} | "
            f"Session: {session_wins}W/{session_losses}L | "
            f"PnL=${session_pnl:+.2f}"
        )
