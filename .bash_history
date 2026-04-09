 
     # Extreme signals always get a minimum bet even in bad hours
     if tod_scale == 0.0:
         if is_extreme:
             return max(2.00, round(CURRENT_BALANCE * 0.03, 2))
         return 0.0
 
     pct  = PEAK_BET_PCT if hour in PEAK_HOURS else MAX_BET_PCT
     base = CURRENT_BALANCE * pct * tod_scale
     return max(2.00, min(20.00, round(base, 2)))
 
 # ─────────────────────────────────────────────────────────────────────────────
 # TELEGRAM
 # ─────────────────────────────────────────────────────────────────────────────
 def send_telegram(msg):
     try:
         requests.get(
             f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
             params={"chat_id": CHAT_ID, "text": str(msg)},
             timeout=5
         )
     except Exception:
         pass
 
 # ─────────────────────────────────────────────────────────────────────────────
 # LOGGING
 # ─────────────────────────────────────────────────────────────────────────────
 def log_trade(direction, bet, action, profit_pct=0, notes="", features=None):
     ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
     try:
         with open(LOG_CSV, "a", newline="") as f:
             csv.writer(f).writerow([ts, direction, f"{bet:.2f}",
                                      action, f"{profit_pct:.2f}%", notes])
     except Exception:
         pass
     entry = {
         "timestamp": ts, "direction": direction, "bet": bet,
         "action": action, "profit_pct": profit_pct, "notes": notes,
         "balance": CURRENT_BALANCE, "session_wins": session_wins,
         "session_losses": session_losses, "session_pnl": session_pnl,
         "regime": REGIME, "market": MARKET_SERIES,
     }
     try:
         with open(PERF_LOG, "a") as f:
             f.write(json.dumps(entry) + "\n")
     except Exception:
         pass
     if features is not None:
         try:
             with open(FEAT_LOG, "a") as f:
                 f.write(json.dumps({**entry, "features": features}) + "\n")
         except Exception:
             pass
 
 # ─────────────────────────────────────────────────────────────────────────────
 # BALANCE
 # ─────────────────────────────────────────────────────────────────────────────
 def get_live_balance():
     try:
         url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
         headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
         resp    = requests.get(url, headers=headers, timeout=8)
         if resp.status_code == 200:
             d   = resp.json()
             bal = (d.get("balance", 0) + d.get("portfolio_value", 0)) / 100
             if bal > 0:
                 return round(bal, 2)
     except Exception as e:
         print(f"[Balance] Failed: {e}")
     return CURRENT_BALANCE
 
 # ─────────────────────────────────────────────────────────────────────────────
 # PRICE FEEDS
 # ─────────────────────────────────────────────────────────────────────────────
 def get_coinbase_price(market_series):
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
             timeout=3)
         if resp.status_code == 200:
             return float(resp.json()["data"]["amount"])
     except Exception:
         pass
     return None
 
 def get_btc_prices(minutes=60):
     """Fetch BTC OHLC from Kraken for regime detection."""
     try:
         resp = requests.get(
             "https://api.kraken.com/0/public/OHLC",
             params={"pair": "XBTUSD", "interval": 1},
             timeout=8)
         if resp.status_code == 200:
             candles = resp.json().get("result", {}).get("XXBTZUSD", [])
             closes  = [float(c[4]) for c in candles[-minutes:]]
             if closes:
                 return np.array(closes)
     except Exception as e:
         print(f"[Prices] Kraken failed: {e}")
     return np.array([83000] * minutes)
 
 def get_kraken_btc():
     """Current BTC price from Kraken for cross-check."""
     try:
         resp = requests.get(
             "https://api.kraken.com/0/public/Ticker",
             params={"pair": "XBTUSD"}, timeout=3)
         if resp.status_code == 200:
             result = resp.json().get("result", {})
             if result:
                 return float(list(result.values())[0]["c"][0])
     except Exception:
         pass
     return None
 
 def get_market_prices(ticker):
     """Fetch YES ask, NO ask, and strike from Kalshi."""
     try:
         url     = f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
         headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
         resp    = requests.get(url, headers=headers, timeout=5)
         if resp.status_code == 200:
             m       = resp.json().get("market", {})
             yes_ask = m.get("yes_ask_dollars")
             no_ask  = m.get("no_ask_dollars")
             strike  = m.get("floor_strike", 0)
             if yes_ask is not None and no_ask is not None:
                 return float(yes_ask), float(no_ask), float(strike or 0)
     except Exception as e:
         print(f"[Prices] {e}")
     return None, None, None
 
 def get_trend_validator():
     """
     Fetch Kalshi 1-hour BTC market as trend validator.
     Returns YES price 0-1 or None.
     """
     try:
         url     = "https://api.elections.kalshi.com/trade-api/v2/markets"
         headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
         resp    = requests.get(url, headers=headers,
                                params={"series_ticker": "KXBTC1H",
                                        "status": "open", "limit": 5},
                                timeout=5)
         if resp.status_code == 200:
             markets = resp.json().get("markets", [])
             if markets:
                 yes_ask = markets[0].get("yes_ask_dollars")
                 if yes_ask is not None:
                     print(f"[Trend] 1H BTC: YES={float(yes_ask):.2f}")
                     return float(yes_ask)
     except Exception as e:
         print(f"[Trend] Failed: {e}")
     return None
 
 # ─────────────────────────────────────────────────────────────────────────────
 # REGIME DETECTION
 # ─────────────────────────────────────────────────────────────────────────────
 def update_regime(prices):
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
 # TICKER AGENT
 # ─────────────────────────────────────────────────────────────────────────────
 def update_live_ticker():
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
 
     for status in ("open", "closed"):
         try:
             url     = "https://api.elections.kalshi.com/trade-api/v2/markets"
             headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
             resp    = requests.get(url, headers=headers,
                                    params={"status": status,
                                            "series_ticker": MARKET_SERIES,
                                            "limit": 5},
                                    timeout=8)
             if resp.status_code == 200:
                 markets  = resp.json().get("markets", [])
                 hits     = [m for m in markets
                             if (m.get("ticker") or "").upper()
                             .startswith(MARKET_SERIES)]
                 if hits:
                     open_hits   = [m for m in hits
                                    if (m.get("status") or "").lower()
                                    in ("open", "active")]
                     pick        = (open_hits or hits)[0]["ticker"]
                     live_ticker = pick
                     return live_ticker, (open_hits or hits)[0]
         except Exception as e:
             print(f"[Ticker] {status} error: {e}")
 
     # Fallback: build from current UTC time
     now_utc     = datetime.datetime.now(datetime.timezone.utc)
     t1          = build_ticker(now_utc)
     live_ticker = t1
     return live_ticker, None
 
 # ─────────────────────────────────────────────────────────────────────────────
 # SAFETY
 # ─────────────────────────────────────────────────────────────────────────────
 def safety_check():
     global CURRENT_BALANCE
     CURRENT_BALANCE = get_live_balance()
 
     if CURRENT_BALANCE < MIN_BALANCE:
         return False, f"Balance ${CURRENT_BALANCE:.2f} below floor ${MIN_BALANCE:.2f}"
 
     if SESSION_START_BAL > 0:
         loss_pct = (SESSION_START_BAL - CURRENT_BALANCE) / SESSION_START_BAL
         if loss_pct >= DAILY_LOSS_LIMIT:
             return False, f"Daily loss {loss_pct*100:.1f}% exceeds limit {DAILY_LOSS_LIMIT*100:.0f}%"
 
     total = session_wins + session_losses
     if total >= 10:
         wr = session_wins / total
         if wr < 0.45:
             return False, f"Circuit breaker: {wr*100:.0f}% WR over {total} trades"
 
     return True, "OK"
 
 # ─────────────────────────────────────────────────────────────────────────────
 # ORDER MANAGEMENT
 # ─────────────────────────────────────────────────────────────────────────────
 def cancel_resting_orders():
     try:
         url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/orders"
         headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
         resp    = requests.get(url, headers=headers,
                                params={"status": "resting", "limit": 50},
                                timeout=8)
         if resp.status_code == 200:
             orders = resp.json().get("orders", [])
             for order in orders:
                 oid = order.get("order_id") or order.get("id")
                 if not oid:
                     continue
                 del_url = (f"https://api.elections.kalshi.com"
                            f"/trade-api/v2/portfolio/orders/{oid}")
                 del_hdr = kalshi.kalshi_auth.create_auth_headers("DELETE", del_url)
                 requests.delete(del_url, headers=del_hdr, timeout=5)
     except Exception as e:
         print(f"[Orders] Cancel failed: {e}")
 
 def place_order(direction, bet, strategy_tag="directional",
                 mkt_yes=None, mkt_no=None):
     global COOLDOWN_REMAINING
 
     ok, reason = safety_check()
     if not ok:
         print(f"[Safety] {reason}")
         send_telegram(f"🛑 HALTED: {reason}")
         raise SystemExit(reason)
 
     is_extreme = (mkt_yes is not None and
                   (mkt_yes < EXTREME_LOW or mkt_yes > EXTREME_HIGH))
     max_bet    = get_max_bet(is_extreme=is_extreme)
 
     if max_bet == 0.0:
         print(f"[TOD] Skipping — bad hour for this bot")
         return False
 
     bet    = min(round(bet, 2), max_bet)
     bet    = max(2.00, bet)
     ticker = live_ticker
 
     if not ticker:
         print("[Order] No ticker — skipping")
         return False
 
     # Prevent duplicate positions on same ticker+direction
     if any(p.get("ticker") == ticker and p.get("direction") == direction
            for p in OPEN_POSITIONS):
         print(f"[Order] Already have {direction} on {ticker} — skipping")
         return False
 
     side           = "yes" if direction == "UP" else "no"
     contract_count = max(1, int(bet / 0.50))
     yes_price      = (min(99, max(1, round((mkt_yes or 0.50) * 100) + 2))
                       if side == "yes" else None)
     no_price       = (min(99, max(1, round((mkt_no  or 0.50) * 100) + 2))
                       if side == "no"  else None)
 
     if DRY_RUN:
         print(f"[DRY RUN] {direction} ${bet:.2f} on {ticker} ({strategy_tag})")
         log_trade(direction, bet, f"DRY_{strategy_tag.upper()}", notes=ticker)
         return True
 
     try:
         print(f"[Order] {ticker} | {side} | count={contract_count} | ${bet:.2f}")
         order  = kalshi.create_order(
             ticker=ticker, action="buy", side=side, type="market",
             count=contract_count, yes_price=yes_price, no_price=no_price,
             time_in_force="ioc",
         )
         filled = ((order or {}).get("order", {}).get("status", "")
                   in ("filled", "executed"))
         if not filled:
             print(f"[Order] Not filled: {order}")
             COOLDOWN_REMAINING = COOLDOWN_CYCLES
             return False
 
         msg = f"✅ BTC {strategy_tag.upper()}: {direction} ${bet:.2f} on {ticker}"
         print(msg)
         send_telegram(msg)
 
         entry_yes = mkt_yes if mkt_yes is not None else 0.5
         now_utc   = datetime.datetime.now(datetime.timezone.utc)
         OPEN_POSITIONS.append({
             "direction":    direction,
             "bet":          bet,
             "ticker":       ticker,
             "strategy":     strategy_tag,
             "time":         time.time(),
             "placed_at":    time.time(),
             "entry_time":   now_utc.isoformat(),
             "entry_yes":    entry_yes,
             "min_yes":      entry_yes,
             "max_yes":      entry_yes,
             "signal_type":  "EXTREME" if is_extreme else "STANDARD",
             "entry_minute": now_utc.minute % 15,
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
 # ARB STRATEGY
 # ─────────────────────────────────────────────────────────────────────────────
 def try_arb(yes_price, no_price, ticker):
     price_sum = yes_price + no_price
     if price_sum >= ARB_THRESHOLD:
         return False
     spread = 1.0 - price_sum
     print(f"[ARB] YES={yes_price:.2f}+NO={no_price:.2f}={price_sum:.2f} spread={spread:.3f}")
     send_telegram(f"🎯 ARB: {ticker}\n"
                   f"YES={yes_price:.2f}+NO={no_price:.2f}={price_sum:.2f}")
     leg_bet = min(get_max_bet() / 2, CURRENT_BALANCE * 0.15)
     placed  = 0
     placed += place_order("UP",   leg_bet, "arb_yes", mkt_yes=yes_price, mkt_no=no_price)
     placed += place_order("DOWN", leg_bet, "arb_no",  mkt_yes=yes_price, mkt_no=no_price)
     return placed > 0
 
 # ─────────────────────────────────────────────────────────────────────────────
 # DIRECTIONAL STRATEGY
 # ─────────────────────────────────────────────────────────────────────────────
 def try_directional(yes_price, no_price):
     global last_signal_direction, consecutive_signal_count
 
     now_utc       = datetime.datetime.now(datetime.timezone.utc)
     window_minute = now_utc.minute % 15
 
     # Determine direction and edge
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
 
     # Skip weak signals — not worth the risk at thin payout ratios
     if edge < MIN_EDGE:
         print(f"[Signal] Edge {edge:.2f} below minimum {MIN_EDGE} — skipping")
         return False
 
     is_extreme = yes_price > EXTREME_HIGH or yes_price < EXTREME_LOW
 
     # ── SIGNAL TYPE CLASSIFICATION ────────────────────────────────────────────
 
     if is_extreme and window_minute == 1:
         # EXTREME: fire immediately, no confirmation
         print(f"[Signal] EXTREME {current_direction} | yes={yes_price:.2f} | "
               f"edge={edge:.2f} | firing immediately")
         consecutive_signal_count = 2
 
     elif window_minute == 1 and edge >= STRONG_MIN1_EDGE:
         # STRONG_MIN1: fire in minute 1 if Coinbase confirms
         spot = get_coinbase_price(MARKET_SERIES)
         confirmed = False
         if spot is not None:
             try:
                 _, _, strike = get_market_prices(live_ticker)
                 if strike > 0:
                     spot_gap  = spot - strike
                     confirmed = ((current_direction == "UP" and spot_gap > 0) or
                                  (current_direction == "DOWN" and spot_gap < 0))
             except Exception:
                 pass
         if confirmed:
             print(f"[Signal] STRONG_MIN1 {current_direction} | yes={yes_price:.2f} | "
                   f"edge={edge:.2f} | Coinbase confirms | firing early")
             consecutive_signal_count = 2
         else:
             # Fall through to STANDARD
             if window_minute == 0 or window_minute > 4:
                 print(f"[Timing] Window {window_minute} — skipping")
                 return False
             if current_direction == last_signal_direction:
                 consecutive_signal_count += 1
             else:
                 last_signal_direction    = current_direction
                 consecutive_signal_count = 1
             if consecutive_signal_count < 2:
                 print(f"[Signal] {current_direction} candidate | yes={yes_price:.2f} | "
                       f"waiting (1/2)")
                 return False
 
     else:
         # STANDARD: require 2 confirmations in minutes 1-4
         if window_minute == 0 or window_minute > 4 or window_minute >= 13:
             print(f"[Timing] Window {window_minute} min old — skipping")
             return False
         if current_direction == last_signal_direction:
             consecutive_signal_count += 1
         else:
             last_signal_direction    = current_direction
             consecutive_signal_count = 1
         if consecutive_signal_count < 2:
             print(f"[Signal] {current_direction} candidate | yes={yes_price:.2f} | "
                   f"waiting (1/2)")
             return False
 
     # ── BET SIZING ────────────────────────────────────────────────────────────
     scale = min(1.0, edge / 0.35)
     bet   = round(get_max_bet(is_extreme=is_extreme) * scale * RISK_SCORE, 2)
     bet   = max(2.00, min(bet, get_max_bet(is_extreme=is_extreme)))
 
     # ── COINBASE SPOT CONFIRMATION ────────────────────────────────────────────
     spot_price = get_coinbase_price(MARKET_SERIES)
     cb_confirmed = False
     if spot_price is not None:
         try:
             _, _, strike = get_market_prices(live_ticker)
             if strike > 0:
                 spot_gap = spot_price - strike
                 gap_pct  = abs(spot_gap) / strike * 100
                 cb_confirmed = ((current_direction == "UP" and spot_gap > 0) or
                                 (current_direction == "DOWN" and spot_gap < 0))
                 if cb_confirmed:
                     if gap_pct > 0.3:
                         bet = min(round(bet * 1.30, 2),
                                   get_max_bet(is_extreme=is_extreme))
                     print(f"[Coinbase] Confirms {current_direction} | "
                           f"${spot_price:.0f} gap={spot_gap:+.0f} ({gap_pct:.2f}%)")
                 else:
                     bet = round(bet * 0.40, 2)
                     bet = max(2.00, bet)
                     print(f"[Coinbase] Disagrees | ${spot_price:.0f} — "
                           f"bet reduced to ${bet:.2f}")
         except Exception as e:
             print(f"[Coinbase] Strike fetch failed: {e}")
 
     # ── KRAKEN CROSS-CHECK (BTC only) ─────────────────────────────────────────
     kraken_price = get_kraken_btc()
     if kraken_price and spot_price:
         diff_pct = abs(kraken_price - spot_price) / spot_price * 100
         if diff_pct > 0.5:
             bet = round(bet * 0.90, 2)
             print(f"[Kraken] Price divergence {diff_pct:.2f}% — bet trimmed")
 
     # ── TREND VALIDATOR (1H BTC market) ──────────────────────────────────────
     trend_yes = get_trend_validator()
     if trend_yes is not None:
         trend_agrees = ((current_direction == "UP" and trend_yes > 0.55) or
                         (current_direction == "DOWN" and trend_yes < 0.45))
         if trend_agrees:
             bet = min(round(bet * 1.10, 2), get_max_bet(is_extreme=is_extreme))
             print(f"[Trend] 1H agrees {current_direction} — bet boosted slightly")
         elif ((current_direction == "UP" and trend_yes < 0.40) or
               (current_direction == "DOWN" and trend_yes > 0.60)):
             bet = round(bet * 0.85, 2)
             print(f"[Trend] 1H disagrees — bet trimmed")
 
     # ── CROSS-MARKET CORRELATION ──────────────────────────────────────────────
     if get_max_bet(is_extreme=is_extreme) > 0:
         try:
             btc1 = get_coinbase_price("KXBTC15M")
             eth1 = get_coinbase_price("KXETH15M")
             sol1 = get_coinbase_price("KXSOL15M")
             if btc1 and eth1 and sol1:
                 time.sleep(1)
                 btc2 = get_coinbase_price("KXBTC15M")
                 eth2 = get_coinbase_price("KXETH15M")
                 sol2 = get_coinbase_price("KXSOL15M")
                 if btc2 and eth2 and sol2:
                     moves = [btc2 > btc1, eth2 > eth1, sol2 > sol1]
                     agree = (sum(1 for m in moves if m)
                              if current_direction == "UP"
                              else sum(1 for m in moves if not m))
                     if agree >= 3:
                         bet = min(round(bet * 1.20, 2),
                                   get_max_bet(is_extreme=is_extreme))
                         print(f"[Correlation] All 3 agree — bet boosted")
                     elif agree == 1:
                         bet = round(bet * 0.90, 2)
                         print(f"[Correlation] Markets diverging — bet trimmed")
                     else:
                         print(f"[Correlation] 2/3 agree {current_direction}")
         except Exception:
             pass
 
     print(f"[Signal] CONFIRMED {current_direction} | yes={yes_price:.2f} | "
           f"edge={edge:.2f} | bet=${bet:.2f}")
 
     # ── DOUBLE DOWN on existing position ──────────────────────────────────────
     existing = [p for p in OPEN_POSITIONS
                 if p.get("ticker") == live_ticker
                 and p.get("direction") == current_direction
                 and p.get("strategy") != "restored"]
     if existing and edge > 0.40:
         dd_bet = round(min(existing[0].get("bet", 0) * 0.50,
                            get_max_bet(is_extreme=is_extreme) * 0.50), 2)
         dd_bet = max(2.00, dd_bet)
         print(f"[DoubleDown] edge={edge:.2f} — adding ${dd_bet:.2f}")
         result = place_order(current_direction, dd_bet, "double_down",
                              mkt_yes=yes_price, mkt_no=no_price)
         if result:
             consecutive_signal_count = 0
         return result
 
     result = place_order(current_direction, bet, "directional",
                          mkt_yes=yes_price, mkt_no=no_price)
     if result:
         consecutive_signal_count = 0
     return result
 
 # ─────────────────────────────────────────────────────────────────────────────
 # POSITION TRACKING & SETTLEMENT
 # ─────────────────────────────────────────────────────────────────────────────
 def check_open_positions():
     global CURRENT_BALANCE, session_wins, session_losses, session_pnl
 
     if not OPEN_POSITIONS:
         return
 
     to_remove = []
 
     for pos in list(OPEN_POSITIONS):
         ticker    = pos.get("ticker")
         direction = pos.get("direction")
         bet       = pos.get("bet", 0)
         strategy  = pos.get("strategy", "unknown")
         placed_at = pos.get("placed_at", 0)
         age_sec   = time.time() - pos.get("time", time.time())
         age_min   = age_sec / 60
 
         if not ticker:
             to_remove.append(pos)
             continue
 
         # ── MAE TRACKING ──────────────────────────────────────────────────────
         try:
             murl    = (f"https://api.elections.kalshi.com"
                        f"/trade-api/v2/markets/{ticker}")
             mheader = kalshi.kalshi_auth.create_auth_headers("GET", murl)
             mr      = requests.get(murl, headers=mheader, timeout=4)
             if mr.status_code == 200:
                 cur_yes = float(mr.json().get("market", {})
                                 .get("yes_ask_dollars", 0.5))
                 pos["min_yes"] = min(pos.get("min_yes", cur_yes), cur_yes)
                 pos["max_yes"] = max(pos.get("max_yes", cur_yes), cur_yes)
         except Exception:
             pass
 
         # ── CASH OUT MONITOR ──────────────────────────────────────────────────
         # Only for live positions (not restored), placed this session
         age_placed = (time.time() - placed_at) / 60 if placed_at > 0 else 999
         if (age_placed >= CASHOUT_MINUTES
                 and strategy != "restored"
                 and placed_at >= session_start_time):
             try:
                 murl    = (f"https://api.elections.kalshi.com"
                            f"/trade-api/v2/markets/{ticker}")
                 mheader = kalshi.kalshi_auth.create_auth_headers("GET", murl)
                 mr      = requests.get(murl, headers=mheader, timeout=4)
                 if mr.status_code == 200:
                     mkt     = mr.json().get("market", {})
                     status  = mkt.get("status", "")
                     cur_yes = float(mkt.get("yes_ask_dollars", 0.5))
                     if status in ("open", "active"):
                         entry_yes = pos.get("entry_yes", 0.5)
                         adverse   = ((entry_yes - cur_yes) if direction == "UP"
                                      else (cur_yes - (1 - entry_yes)))
                         if adverse > CASHOUT_ADVERSE:
                             print(f"[CashOut] {direction} on {ticker} moved "
                                   f"{adverse:.2f} against — exiting early")
                             send_telegram(f"💸 CashOut: {direction} {ticker}\n"
                                           f"adverse={adverse:.2f} | saving capital")
                             to_remove.append(pos)
                             continue
             except Exception as ce:
                 print(f"[CashOut] Error: {ce}")
 
         # ── RESTORED POSITION EXPIRY ──────────────────────────────────────────
         if strategy == "restored" and age_min > 16:
             print(f"[Positions] Restored {ticker} expired — removing")
             to_remove.append(pos)
             continue
 
         # ── SETTLEMENT CHECK (positions > 16 min old) ─────────────────────────
         if age_min <= 16:
             continue
 
         try:
             url     = (f"https://api.elections.kalshi.com"
                        f"/trade-api/v2/portfolio/positions")
             headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
             resp    = requests.get(url, headers=headers,
                                    params={"limit": 100}, timeout=8)
             if resp.status_code != 200:
                 continue
 
             open_tickers = {p.get("ticker")
                             for p in resp.json().get("market_positions", [])}
             if ticker in open_tickers:
                 continue  # still open
 
             # Position closed — check result
             murl    = (f"https://api.elections.kalshi.com"
                        f"/trade-api/v2/markets/{ticker}")
             mheader = kalshi.kalshi_auth.create_auth_headers("GET", murl)
             mr      = requests.get(murl, headers=mheader, timeout=5)
             if mr.status_code != 200:
                 if age_min > 20:
                     to_remove.append(pos)
                 continue
 
             mkt    = mr.json().get("market", {})
             result = mkt.get("result", "")
             if not result:
                 if age_min > 20:
                     to_remove.append(pos)
                 continue
 
             # Calculate payout correctly
             won           = ((result == "yes" and direction == "UP") or
                              (result == "no"  and direction == "DOWN"))
             contracts     = max(1, int(bet / 0.50))
             realized      = round(contracts * 1.0 - bet, 2) if won else -bet
             outcome       = "WIN" if won else "LOSS"
 
             session_pnl    += realized
             CURRENT_BALANCE = round(CURRENT_BALANCE + realized, 2)
             if won:
                 session_wins += 1
             else:
                 session_losses += 1
 
             total = session_wins + session_losses
             wr    = session_wins / total * 100 if total else 0
             print(f"[Settled] {outcome}: {direction} ${bet:.2f} on {ticker} | "
                   f"pnl=${realized:+.2f} | {session_wins}W/{session_losses}L ({wr:.0f}%)")
             send_telegram(
                 f"{'✅' if won else '❌'} BTC {outcome}: {direction} ${bet:.2f} | "
                 f"pnl=${realized:+.2f}\n"
                 f"{session_wins}W/{session_losses}L ({wr:.0f}%) | "
                 f"Bal=${CURRENT_BALANCE:.2f}"
             )
 
             features = {
                 "signal_type":   pos.get("signal_type", "STANDARD"),
                 "entry_minute":  pos.get("entry_minute", 0),
                 "market":        MARKET_SERIES,
                 "entry_yes":     pos.get("entry_yes", 0.5),
                 "min_yes":       pos.get("min_yes", 0.5),
                 "max_yes":       pos.get("max_yes", 0.5),
                 "adverse_move":  abs(pos.get("min_yes", 0.5) -
                                      pos.get("entry_yes", 0.5)),
                 "coinbase_confirmed": pos.get("signal_type") != "RESTORED",
             }
             log_trade(direction, bet, outcome,
                       profit_pct=realized / bet * 100 if bet else 0,
                       notes=f"{strategy}|{ticker}",
                       features=features)
             to_remove.append(pos)
 
         except Exception as e:
             print(f"[Settled] Check failed: {e}")
             if age_min > 20:
                 to_remove.append(pos)
 
     for pos in to_remove:
         if pos in OPEN_POSITIONS:
             OPEN_POSITIONS.remove(pos)
 
 # ─────────────────────────────────────────────────────────────────────────────
 # HOURLY SUMMARY
 # ─────────────────────────────────────────────────────────────────────────────
 def send_hourly_summary():
     global _last_summary_hour
     hour = datetime.datetime.now(datetime.timezone.utc).hour
     if hour == _last_summary_hour:
         return
     _last_summary_hour = hour
     total = session_wins + session_losses
     wr    = session_wins / total * 100 if total else 0
     send_telegram(
         f"📊 BTC Hourly ({hour:02d}:00 UTC)\n"
         f"{session_wins}W/{session_losses}L ({wr:.0f}%) | "
         f"PnL: ${session_pnl:+.2f} | Bal: ${CURRENT_BALANCE:.2f}"
     )
 
 # ─────────────────────────────────────────────────────────────────────────────
 # LOAD EXISTING POSITIONS
 # ─────────────────────────────────────────────────────────────────────────────
 def load_existing_positions():
     """Restore open BTC positions from Kalshi on startup."""
     try:
         url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
         headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
         resp    = requests.get(url, headers=headers,
                                params={"limit": 100}, timeout=8)
         if resp.status_code != 200:
             return
         positions = resp.json().get("market_positions", [])
         for p in positions:
             ticker   = p.get("ticker", "")
             exposure = float(p.get("market_exposure_dollars", 0))
             # CRITICAL: only restore positions matching THIS bot's market
             if not ticker or exposure <= 0:
                 continue
             if MARKET_SERIES not in ticker:
                 continue
             direction = "UNKNOWN"
             try:
                 murl = (f"https://api.elections.kalshi.com"
                         f"/trade-api/v2/markets/{ticker}")
                 mhdr = kalshi.kalshi_auth.create_auth_headers("GET", murl)
                 mr   = requests.get(murl, headers=mhdr, timeout=5)
                 if mr.status_code == 200:
                     last      = float(mr.json().get("market", {})
                                       .get("last_price_dollars", 0.5))
                     direction = "UP" if last >= 0.5 else "DOWN"
             except Exception:
                 pass
             OPEN_POSITIONS.append({
                 "direction": direction,
                 "bet":       exposure,
                 "ticker":    ticker,
                 "strategy":  "restored",
                 "time":      time.time() - 300,
                 "placed_at": 0,  # zero = cash out monitor ignores it
                 "entry_yes": 0.5,
                 "min_yes":   0.5,
                 "max_yes":   0.5,
                 "signal_type":  "RESTORED",
                 "entry_minute": 0,
             })
             print(f"[Startup] Restored: {ticker} ${exposure:.2f} {direction}")
         if OPEN_POSITIONS:
             print(f"[Startup] Loaded {len(OPEN_POSITIONS)} BTC position(s)")
     except Exception as e:
         print(f"[Startup] Could not load positions: {e}")
 
 # ─────────────────────────────────────────────────────────────────────────────
 # MAIN CYCLE
 # ─────────────────────────────────────────────────────────────────────────────
 def simulate_trade():
     global COOLDOWN_REMAINING, CURRENT_BALANCE
 
     if os.path.exists(STOP_FILE):
         print(f"[Stop] {STOP_FILE} detected — halting")
         raise SystemExit("Stop file detected")
 
     if COOLDOWN_REMAINING > 0:
         print(f"[Cooldown] {COOLDOWN_REMAINING} cycles remaining")
         COOLDOWN_REMAINING -= 1
         check_open_positions()
         return
 
     ticker, market_data = update_live_ticker()
     if not ticker:
         print("[Ticker] No ticker — skipping")
         return
 
     yes_price, no_price, _ = get_market_prices(ticker)
     if yes_price is None or no_price is None:
         print("[Market] Could not fetch prices")
         check_open_positions()
         return
 
     price_sum = yes_price + no_price
     print(f"[Ticker] {ticker}")
     print(f"[Market] YES={yes_price:.2f} | NO={no_price:.2f} | Sum={price_sum:.2f}")
 
     CURRENT_BALANCE = get_live_balance()
     prices          = get_btc_prices(60)
     update_regime(prices)
 
     total = session_wins + session_losses
     wr    = session_wins / total * 100 if total else 0
     print(f"{'='*50}")
     print(f"Balance: ${CURRENT_BALANCE:.2f} | Regime: {REGIME} | "
           f"Session: {session_wins}W/{session_losses}L ({wr:.0f}%) | "
           f"PnL: ${session_pnl:+.2f}")
 
     # ARB first, then directional
     if price_sum < ARB_THRESHOLD:
         print(f"[ARB] Opportunity: sum={price_sum:.2f}")
         try_arb(yes_price, no_price, ticker)
     else:
         print(f"[Cycle] No arb — sum={price_sum:.2f}")
         signal_fired = try_directional(yes_price, no_price)
         if not signal_fired:
             print(f"[Cycle] No signal — YES={yes_price:.2f}")
 
     check_open_positions()
     send_hourly_summary()
 
     if OPEN_POSITIONS:
         print(f"[Positions] {len(OPEN_POSITIONS)} still open")
 
 # ─────────────────────────────────────────────────────────────────────────────
 # ENTRY POINT
 # ─────────────────────────────────────────────────────────────────────────────
 if __name__ == "__main__":
     global SESSION_START_BAL, CURRENT_BALANCE
 
     mode = "DRY RUN" if DRY_RUN else "LIVE"
     print(f"\n{'='*50}")
     print(f"{BOT_NAME} — {mode}")
 
     # CRITICAL: sync live balance on every startup
     # Prevents crash loop where restarted bot sees stale SESSION_START_BAL
     live_start = get_live_balance()
     if live_start > 0:
         CURRENT_BALANCE   = live_start
         SESSION_START_BAL = live_start
         print(f"[Startup] Live balance synced: ${CURRENT_BALANCE:.2f}")
     else:
         CURRENT_BALANCE   = INITIAL_BALANCE
         SESSION_START_BAL = INITIAL_BALANCE
         print(f"[Startup] Using initial balance: ${CURRENT_BALANCE:.2f}")
 
     print(f"MaxBet: ${get_max_bet():.2f} | "
           f"Threshold: <{DIRECTIONAL_LOW:.2f} or >{DIRECTIONAL_HIGH:.2f}")
     print(f"{'='*50}\n")
 
     # Load existing BTC positions only
     load_existing_positions()
 
     # Cancel any resting orders from previous session
     cancel_resting_orders()
     print("[Startup] Resting orders cleared")
 
     send_telegram(
         f"🤖 {BOT_NAME} {mode} started\n"
         f"Balance=${CURRENT_BALANCE:.2f} | MaxBet=${get_max_bet():.2f}\n"
         f"Threshold: <{DIRECTIONAL_LOW:.2f} or >{DIRECTIONAL_HIGH:.2f}"
     )
 
     try:
         while True:
             cycle_start = time.time()
             try:
                 simulate_trade()
             except SystemExit:
                 raise
             except Exception as e:
                 print(f"[Cycle] Unexpected error: {e}")
                 send_telegram(f"⚠️ BTC cycle error: {e}")
             elapsed = time.time() - cycle_start
             sleep_t = max(0, CYCLE_SLEEP - elapsed)
             time.sleep(sleep_t)
     except SystemExit as e:
         msg = f"🛑 {BOT_NAME} halted: {e}"
         print(msg)
         send_telegram(msg)
 ENDOFFILE

python3 -m py_compile /root/openclaw_btc_v4.py && echo "CLEAN COMPILE OK"
python3 /tmp/write_bot_p1.py
nano /tmp/p1.py
python3 /tmp/p1.py
nano /tmp/p2.py
python3 /tmp/p2.py
nano /tmp/p3.py
source kalshi_env/bin/activate
nano /tmp/fix_status.py
python3 /tmp/fix_status.py
nano /tmp/fix_status2.py
python3 /tmp/fix_status2.py
nano /tmp/write_status.py
python3 /tmp/write_status.py
nano /tmp/write_status2.py
python3 /tmp/write_status2.py
grep -E "Settled|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log 2>/dev/null | tail -10
sed -i 's/True P\\&amp;L:/True P\&amp;L:/g' /root/dashboard.py
nano /tmp/fix_dashboard_creds.py
python3 /tmp/fix_dashboard_creds.py
grep "Settled\|PLACED" /root/bot.log | tail -5
nano /tmp/fix_dash2.py
python3 /tmp/fix_dash2.py
grep -n "raw\.split\|KALSHI_KEY\|BOT_TOKEN\|CHAT_ID\|KALSHI_SECRET\|KALSHI_API" /root/dashboard.py | head -15
nano /tmp/fix_dash3.py
python3 /tmp/fix_dash3.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
python3 /tmp/status_all.py
grep -n "TOD\|is_extreme\|get_max_bet" /root/sol_bot.py | head -10
sed -n '376,400p' /root/sol_bot.py
grep "EXTREME\|bet=\$0.00" /root/sol_bot.log | head -10
grep -B1 "bet=\$0.00" /root/sol_bot.log | grep "Cycle\|2026" | head -5
source kalshi_env/bin/activate
nano /tmp/fix_order_response.py
python3 /tmp/fix_order_response.py
pkill -f watchdog.py
python3 /tmp/check_positions.py
sed -i 's|open("/root/real_bot.py")|open("/root/real_bot_pre_v4_backup.py")|g' /tmp/check_positions.py /tmp/check_balance.py
cp /root/real_bot.py /root/real_bot_v4_stable.py
nano /tmp/check_positions.py
python3 -c "
 import requests, tempfile
 from kalshi_python import KalshiClient
 from kalshi_python.configuration import Configuration
 raw = open('/root/real_bot_pre_v4_backup.py').read()
 key = raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]
 sec = raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]
 tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
 tf.write(sec); tf.close()
 config = Configuration()
 config.host = 'https://api.elections.kalshi.com/trade-api/v2'
 kalshi = KalshiClient(config)
 kalshi.set_kalshi_auth(key, tf.name)
 url = 'https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'
 headers = kalshi.kalshi_auth.create_auth_headers('GET', url)
 resp = requests.get(url, headers=headers, params={'limit':20}, timeout=8)
 for p in resp.json().get('market_positions', []):
     print(p.get('ticker'), p.get('market_exposure_dollars'))
 " 2>/dev/null
grep -E "Settled|WIN|LOSS|PLACED|Order failed" /root/bot.log /root/eth_bot.log /root/sol_bot.log | tail -10
source kalshi_env/bin/activate
source kalshi_env/bin/activate
wc -l /root/openclaw_btc_v4.py
python3 /tmp/p4.py && python3 -m py_compile /root/openclaw_btc_v4.py && echo "OK"
nano /tmp/p5.py
python3 /tmp/p5.py && python3 -m py_compile /root/openclaw_btc_v4.py && echo "OK"
nano /tmp/p6.py
python3 /tmp/p6.py && python3 -m py_compile /root/openclaw_btc_v4.py && echo "OK"
nano /tmp/p7.py
python3 /tmp/p7.py && python3 -m py_compile /root/openclaw_btc_v4.py && echo "COMPLETE OK"
source kalshi_env/bin/activate
python3 -c "
 code = open('/root/openclaw_btc_v4.py').read()
 code = code.replace('    global SESSION_START_BAL,CURRENT_BALANCE\n', '')
 open('/root/openclaw_btc_v4.py', 'w').write(code)
 print('Fixed')
 "
nano /tmp/fix_global.py
python3 /tmp/fix_global.py
sed 's/DRY_RUN=False/DRY_RUN=True/' /root/openclaw_btc_v4.py > /tmp/btc_v4_dryrun.py
grep -n "if __name__" /root/openclaw_btc_v4.py
sed -n '1,60p' /root/openclaw_btc_v4.py
sed -n '55,65p' /root/openclaw_btc_v4.py
nano /tmp/p3b.py
python3 /tmp/p3b.py
sed 's/DRY_RUN=False/DRY_RUN=True/' /root/openclaw_btc_v4.py > /tmp/btc_v4_dryrun.py
python3 -c "
 import tempfile
 raw = open('/root/real_bot.py').read()
 key = raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]
 sec = raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]
 tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
 tf.write(sec); tf.close()
 print('Key:', key[:8], '...')
 print('PEM file:', tf.name)
 print('Auth OK')
 "
nano /tmp/test_auth.py
python3 /tmp/test_auth.py
ps aux | grep -E "real_bot|eth_bot|sol_bot|watchdog" | grep -v grep
nano /tmp/test_kalshi.py
timeout 15 python3 /tmp/test_kalshi.py
grep -n "get_live_balance\|kalshi.kalshi_auth\|requests.get" /root/openclaw_btc_v4.py | head -5
nano /tmp/test_network.py
timeout 30 python3 /tmp/test_network.py
timeout 10 python3 /root/openclaw_btc_v4.py 2>&1 | head -20
python3 -c "import inspect; from kalshi_python import KalshiClient; print(inspect.getsource(KalshiClient.set_kalshi_auth))"
grep -n "^kalshi=\|^_config=\|^_tf=" /root/openclaw_btc_v4.py
nano /tmp/test_client.py
timeout 15 python3 /tmp/test_client.py
nano /tmp/test_v4_startup.py
timeout 15 python3 /tmp/test_v4_startup.py
sed -n '17,25p' /root/openclaw_btc_v4.py
grep -n "^[a-zA-Z]" /root/openclaw_btc_v4.py | grep -v "^[0-9]*:def \|^[0-9]*:import\|^[0-9]*:from\|^[0-9]*:assert\|^[0-9]*:if " | head -20
timeout 10 python3 -v /root/openclaw_btc_v4.py 2>&1 | tail -20
nano /tmp/test_full.py
timeout 10 python3 /tmp/test_full.py
grep -n "def " /root/openclaw_btc_v4.py
grep -c "def \|return \|if \|for \|try:" /root/openclaw_btc_v4.py
grep -n "MARKET_SERIES\|DRY_RUN\|MAX_BET_PCT\|DIRECTIONAL_HIGH\|MIN_BALANCE\|SESSION_START_BAL\|CASHOUT\|EXTREME_HIGH" /root/openclaw_btc_v4.py | head -15
sed -n '469,510p' /root/openclaw_btc_v4.py
sed -n '655,691p' /root/openclaw_btc_v4.py
pkill -f watchdog.py
# Create ETH bot
cp /root/real_bot.py /root/real_bot_v4_stable.py
ps aux | grep -E "real_bot|eth_bot|sol_bot|watchdog" | grep -v grep
tail -5 /root/eth_bot.log
nano /tmp/test_pem.py
python3 /tmp/test_pem.py
nano /tmp/fix_creds.py
python3 /tmp/fix_creds.py
pkill -f watchdog.py
nano /tmp/check_pem.py
python3 /tmp/check_pem.py
grep -c "BEGIN RSA PRIVATE KEY\|END RSA PRIVATE KEY" /root/real_bot_pre_v4_backup.py
nano /tmp/check_pem2.py
python3 /tmp/check_pem2.py
find /root -name "*.pyc" -delete
timeout 30 python3 /root/real_bot.py 2>&1 | grep -v "SyntaxWarning\|invalid escape\|markets_api" | head -15
timeout 90 python3 /root/real_bot.py > /tmp/realbot_test.txt 2>&1 &
cat /tmp/realbot_test.txt | head -30
timeout 90 python3 -u /root/real_bot.py 2>&1 | head -20
pkill -f watchdog.py
cat /root/watchdog.log
grep "KALSHI\|kalshi\|KalshiAuth\|set_kalshi" /root/watchdog.py | head -5
nano /tmp/fix_watchdog_creds.py
python3 /tmp/fix_watchdog_creds.py
tail -8 /root/bot.log
cp /root/real_bot.py /root/real_bot_v4_stable.py
source kalshi_env/bin/activate
python3 /tmp/status_all.py
exit
source kalshi_env/bin/activate
python3 /tmp/status_all.py
grep -n "BTC {outcome}\|BTC {strategy\|BTC DIRECTIONAL\|BTC WIN\|BTC LOSS\|BTC Hourly" /root/eth_bot.py | head -5
for f in /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/f"✅ BTC {strategy_tag/f"✅ {BOT_NAME.split()[1]} {strategy_tag/' $f;      sed -i 's/} BTC {outcome}:/} {BOT_NAME.split()[1]} {outcome}:/' $f;      sed -i 's/f"📊 BTC Hourly/f"📊 {BOT_NAME.split()[1]} Hourly/' $f;      sed -i 's/f"{"✅" if won else "❌"} BTC/f"{"✅" if won else "❌"} {BOT_NAME.split()[1]}/' $f;  done
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do       sed -i 's/f"⚠️ BTC cycle error/f"⚠️ {BOT_NAME.split()[1]} cycle error/' $f;      sed -i 's/f"🛑 {BOT_NAME} halted/f"🛑 {BOT_NAME} halted/' $f;  done
nano /tmp/fix_entry_yes.py 
python3 /tmp/fix_entry_yes.py
nano /tmp/fix_cashout_thresholds.py
python3 /tmp/fix_cashout_thresholds.py
nano /tmp/fix_profit_lock.py
python3 /tmp/fix_profit_lock.py
grep -n "CASH OUT\|CashOut\|cash_out\|cashout" /root/real_bot.py | head -5
sed -n '520,535p' /root/real_bot.py
nano /tmp/fix_profit_lock2.py
python3 /tmp/fix_profit_lock2.py
pkill -f watchdog.py
grep -n "window_minute==1\|EXTREME\|STRONG_MIN1\|consecutive_signal" /root/real_bot.py | head -10
sed -n '369,420p' /root/real_bot.py
nano /tmp/add_confidence.py
python3 /tmp/add_confidence.py
nano /tmp/fix_conf_sizing.py
python3 /tmp/fix_conf_sizing.py
cp /root/real_bot.py /root/real_bot_v4_stable.py
cd /root
git config --global user.email "openclaw@bot.com"
git add -A && git commit -m "description of change"
nano /tmp/write_status3.py
python3 /tmp/write_status3.py
grep -n "True P\|amp;L\|Deposited" /root/dashboard.py | head -8
nano /tmp/fix_dashboard_pnl.py
python3 /tmp/fix_dashboard_pnl.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
grep -n "def \|series\|limit\|yes_ask\|threshold" /root/bond_scanner.py | head -15
sed -n '72,145p' /root/bond_scanner.py
grep -n "YES_HIGH\|YES_LOW\|MIN_MINUTES\|MAX_MINUTES\|MIN_BET\|MAX_BET" /root/bond_scanner.py | head -10
grep -E "Found|opportunities|bond|BOND|scan" /root/bond_scanner.log | tail -20
tail -20 /root/bond_scanner.log
nano /tmp/debug_bond.py
python3 /tmp/debug_bond.py
sed -i 's/if not yes_ask or not no_ask or not close_ts:/if not yes_ask or not no_ask or not close_ts:/' /root/bond_scanner.py
nano /tmp/fix_bond.py
python3 /tmp/fix_bond.py
python3 /tmp/debug_bond2.py
nano /tmp/debug_bond2.py
python3 /tmp/debug_bond2.py
nano /tmp/fix_bond2.py
python3 /tmp/fix_bond2.py
grep -n "Skip markets already at 0\|yes_ask.*0.01\|yes_ask.*0.99" /root/bond_scanner.py | head -5
sed -i 's/            if float(yes_ask) <= 0.01 or float(yes_ask) >= 0.99:/            if float(yes_ask) <= 0.01 or float(yes_ask) >= 0.99:\n                continue\n            if float(yes_ask) + float(no_ask) > 1.05:/' /root/bond_scanner.py
pkill -f bond_scanner.py
python3 /tmp/debug_bond2.py 2>/dev/null | head -10
sed -i 's|open("/root/real_bot.py").read()|open("/root/real_bot_pre_v4_backup.py").read()|g' /root/bond_scanner.py
sed -i 's/if float(yes_ask) + float(no_ask) > 1.05:/if float(yes_ask) + float(no_ask) > 1.02:/' /root/bond_scanner.py
pkill -f bond_scanner.py
grep -n "open.*read\|KALSHI_KEY\|KALSHI_SEC" /root/bond_scanner.py | head -8
sed -i "s|open('/root/real_bot.py').read()|open('/root/real_bot_pre_v4_backup.py').read()|g" /root/bond_scanner.py
pkill -f bond_scanner.py
sleep 60
git add /root/bond_scanner.py
python3 /tmp/check_balance.py
grep -E "Settled|WIN|LOSS|PLACED|CashOut|ProfitLock|BreakEven|HALTED|Error" /root/eth_bot.log | tail -20
grep -E "Settled|WIN|LOSS|PLACED" /root/bot.log | grep "26APR02" | tail -20
grep -E "Settled|WIN|LOSS" /root/eth_bot.log | grep "26APR02" | tail -20
grep "PLACED\|Confidence\|HighConf\|bet=" /root/bot.log | grep "03:\|02:" | tail -10
grep "PLACED" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR02" | wc -l
python3 /tmp/check_balance.py
grep -n "log_trade.*PLACED\|PLACED.*log_trade" /root/real_bot.py | head -5
python3 -c "
 import csv
 total = 0
 for f in ['/root/trade_log.csv', '/root/eth_trade_log.csv', '/root/sol_trade_log.csv']:
     try:
         with open(f) as fp:
             for row in csv.reader(fp):
                 if len(row)<5 or '26APR02' not in str(row): continue
                 if 'WIN' in row[3]:
                     try: total += float(row[4].replace('%',''))*float(row[2])/100
                     except: pass
                 elif 'LOSS' in row[3]:
                     try: total -= float(row[2])
                     except: pass
     except: pass
 print(f'Net PnL from CSV for today: \${total:+.2f}')
 "
nano /tmp/calc_pnl.py
python3 /tmp/calc_pnl.py
grep "HALTED\|below floor\|MIN_BALANCE" /root/bot.log /root/eth_bot.log /root/sol_bot.log | tail -5
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/MIN_BALANCE=185.00/MIN_BALANCE=175.00/' $f;  done
pkill -f watchdog.py
source kalshi_env/bin/activate
python3 /tmp/status_all.py
pkill -f watchdog.py
grep -E "WIN|LOSS|PLACED|Settled" /root/bot.log | grep "26APR03" | tail -20
python3 /tmp/check_positions.py
grep -E "Error|error|failed|Failed|Exception|Traceback" /root/bot.log | grep "26APR03" | tail -20
grep "Balance:" /root/bot.log | grep "26APR03" | head -20
ls /root/real_bot_pre_v4_backup.py
grep -n "filled\|OPEN_POSITIONS.append\|CreateOrder" /root/real_bot.py | head -10
else:   filled = order is not None
nano /tmp/fix_order_check.py
python3 /tmp/fix_order_check.py
sed -n '317,330p' /root/real_bot.py
nano /tmp/fix_order_check2.py
python3 /tmp/fix_order_check2.py
nano /tmp/test_order_status.py
python3 /tmp/test_order_status.py
nano /tmp/test_order_fields.py
python3 /tmp/test_order_fields.py
nano /tmp/fix_order_check3.py
python3 /tmp/fix_order_check3.py
sed 's/DRY_RUN=False/DRY_RUN=True/' /root/real_bot.py > /tmp/btc_dryrun2.py
cp /root/real_bot.py /root/real_bot_v4_stable.py
sleep 120 && grep -E "Order.*status|Order.*filled|PLACED|Settled|WIN|LOSS|Confidence" /root/bot.log /root/eth_bot.log /root/sol_bot.log | tail -15
tail -10 /root/sol_bot.log
# Fix 1: Lower MIN_BALANCE further
pkill -f watchdog.py
tail -3 /root/bot.log
sleep 120 && grep -E "Order.*status|Order.*remaining|PLACED|Settled|WIN|LOSS|Signal.*CONFIRMED" /root/bot.log /root/eth_bot.log /root/sol_bot.log | tail -10
source kalshi_env/bin/activate
python3 /tmp/status_all.py
view /mnt/skills/public/frontend-design/SKILL.md
grep -n "create_order" /root/openclaw.py | head -5
sed -n '320,326p' /root/openclaw.py
sed -i 's/order=kalshi.create_order(ticker=ticker,action="buy",side=side,type="market",\n            count=contract_count,time_in_force="ioc")/order=kalshi.create_order(ticker=ticker,action="buy",side=side,type="market",count=contract_count,time_in_force="ioc")/' /root/openclaw.py
nano /tmp/fix_order_price.py
python3 /tmp/fix_order_price.py
grep -n "win_prob<0.40\|BreakEven\|entry_win_prob" /root/openclaw.py | head -8
sed -n '608,630p' /root/openclaw.py
nano /tmp/fix_breakeven.py
python3 /tmp/fix_breakeven.py
sed -i 's/MIN_ALERT_SIZE = 500/MIN_ALERT_SIZE = 2000/' /root/whale_scanner.py
nano /tmp/fix_whale_alerts.py
python3 /tmp/fix_whale_alerts.py
sleep 120 && grep -E "Order.*status|Order.*filled|PLACED|WIN|LOSS|Order failed" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR03 1[7-9]" | tail -10
git add -A && git commit -m "Raise whale alert threshold, only alert our markets or $5k+ whales"
tail -5 /root/bot.log
cp /mnt/user-data/outputs/dashboard_v4.py /root/dashboard.py
nano /root/dashboard_v4.py
python3 -m py_compile /root/dashboard_v4.py && echo "OK"
nano /root/dashboard_v4.html
python3 -m py_compile /root/dashboard_v4.py && echo "OK"
sed -i 's/VERSION_BALANCE = 159.02/VERSION_BALANCE = 159.84/' /root/dashboard.py
pkill -f dashboard.py
python3 /tmp/status_all.py
nano /tmp/test_order_fix.py
python3 /tmp/test_order_fix.py
nano /root/dashboard_v4.html
find /root -name "*bible*" -o -name "*Bible*" -o -name "*BIBLE*" 2>/dev/null
wc -l /root/OPENCLAW_GUIDE.md
nano /tmp/add_bible_route.py
python3 /tmp/add_bible_route.py
sed -i 's|<div class="header-right">|<div class="header-right"><a href="/bible" target="_blank" style="font-family:Orbitron,monospace;font-size:10px;letter-spacing:2px;color:var(--accent);text-decoration:none;border:1px solid var(--accent);padding:6px 12px;border-radius:6px;opacity:0.8;">📖 BIBLE</a>|' /root/dashboard_v4.html
git add -A && git commit -m "Add Bible route and button to dashboard"
nano /root/OPENCLAW_GUIDE.md
wc -l /root/OPENCLAW_GUIDE.md
tail -20 /root/OPENCLAW_GUIDE.md
cat >> /root/OPENCLAW_GUIDE.md << 'EOF'
nano /root/OPENCLAW_GUIDE.md
wc -l /root/OPENCLAW_GUIDE.md
grep -n "SECTION 7\|### Files\|### Monitor\|### Restart" /root/OPENCLAW_GUIDE.md
sed -n '159,190p' /root/OPENCLAW_GUIDE.md
source kalshi_env/bin/activate
nano /tmp/fix_mobile.py
python3 /tmp/fix_mobile.py
sed -i 's/.span3{grid-column:1\/-1;}/.span3{grid-column:1\/-1;} @media(max-width:768px){.grid{grid-template-columns:1fr;padding:8px;}.balance-card{grid-template-columns:1fr 1fr;gap:16px;}.divider{display:none;}.balance-main{font-size:28px;}.proc-grid{grid-template-columns:repeat(3,1fr);}.header{padding:10px 16px;}.logo-text{font-size:14px;}.logo-sub{display:none;}.card{padding:14px;}}/' /root/dashboard_v4.html
python3 /tmp/status_all.py
source kalshi_env/bin/activate
python3 /tmp/status_all.py
nano /tmp/fix_two_bugs.py
python3 /tmp/fix_two_bugs.py
nano /tmp/fix_market_order.py
python3 /tmp/fix_market_order.py
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/if win_prob<0.48 and age_placed>=2.0 and entry_win_prob>0.55:/if win_prob<0.40 and age_placed>=3.0 and entry_win_prob>0.65:/' $f;  done
pkill -f watchdog.py
sleep 120 && grep -E "Order.*status|Order.*Not filled|PLACED|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR03" | tail -10
sleep 120 && grep -E "Order.*status|Order.*remaining|PLACED|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR03" | grep -v "5feac314\|59a61366" | tail -10
grep "PLACED" /root/trade_log.csv | tail -3
grep "Order.*status\|Order.*remaining" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep -v "5feac314\|59a61366" | tail -5
nano /root/calibration_scanner.py 
python3 -m py_compile /root/calibration_scanner.py && echo "OK"
timeout 60 python3 -u /root/calibration_scanner.py 2>&1 | grep -v "SyntaxWarning\|markets_api\|escape" | head -20
timeout 30 python3 -u /root/calibration_scanner.py > /tmp/cal_test.txt 2>&1 &
sed -i 's/send_telegram("🔬 Calibration Scanner started")/print("[Cal] Sending startup message...")/' /root/calibration_scanner.py
timeout 60 python3 -u /root/calibration_scanner.py > /tmp/cal_test.txt 2>&1 &
nano /tmp/test_cal.py
timeout 30 python3 -u /tmp/test_cal.py
nano /tmp/cal_debug.py
timeout 120 python3 -u /tmp/cal_debug.py
python3 /tmp/status_all.py
nano /tmp/test_unified.py
python3 /tmp/test_unified.py --market btc
nano /tmp/build_unified.py
python3 /tmp/build_unified.py
sed 's/DRY_RUN=False/DRY_RUN=True/' /root/openclaw.py > /tmp/openclaw_dry.py
timeout 90 python3 -u /tmp/openclaw_dry.py --market eth > /tmp/unified_eth.txt 2>&1 &
nano /tmp/update_watchdog.py
python3 /tmp/update_watchdog.py
sed -i 's|"script":  "/root/real_bot.py"|"script":  "/root/openclaw.py --market btc"|' /root/watchdog.py
grep -A5 "def is_running" /root/watchdog.py
nano /tmp/fix_watchdog_unified.py
python3 /tmp/fix_watchdog_unified.py
echo "__pycache__/" > /root/.gitignore 
python3 /tmp/status_all.py
grep -E "Order.*executed|Order.*status|PLACED" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR03 1[6-9]" | tail -10
source kalshi_env/bin/activate
nano /root/whale_scanner.py
python3 -m py_compile /root/whale_scanner.py && echo "OK"
sed -i 's/send_telegram("🐋 Whale Scanner v2 started\\nAuto-follow enabled on BTC\/ETH\/SOL")/print("[Whale] Startup complete")/' /root/whale_scanner.py
nano /tmp/test_whale.py
timeout 15 python3 -u /tmp/test_whale.py
nano /tmp/fix_whale.py
python3 /tmp/fix_whale.py
nano /tmp/whale_debug.py
timeout 20 python3 -u /tmp/whale_debug.py
grep -n "Startup complete\|min_ts\|scan_once\|scan_count\|while True" /root/whale_scanner.py | head -10 
sed -n '160,185p' /root/whale_scanner.py
#!/usr/bin/env python3
sed -n '160,185p' /root/whale_scanner.py
nano /root/whale_scanner.py
python3 -m py_compile /root/whale_scanner.py && echo "OK"
nano /tmp/add_whale_watchdog.py
python3 /tmp/add_whale_watchdog.py
sed -i 's|"name":    "BOND"|"name":    "WHALE", "script":  "/root/whale_scanner.py", "log":     "/root/whale_scanner.log", "stop":    "/root/STOP_WHALE"},\n    {"name":    "BOND"|' /root/watchdog.py
pkill -f watchdog.py
tail -10 /root/whale_scanner.log
source kalshi_env/bin/activate
grep -n "feature\|equity\|cashout\|extreme\|signal\|hourly\|position\|frequency\|news\|legend" /root/dashboard_v3_stable.py | head -30
grep -n "cashout\|CashOut\|extreme\|EXTREME\|confirmed\|CONFIRMED\|legend\|icon" /root/dashboard_v3_stable.py | head -20
nano /root/dashboard_v4.html
nano /tmp/update_dashboard_api.py
python3 /tmp/update_dashboard_api.py
nano /tmp/add_dashboard_funcs.py
python3 /tmp/add_dashboard_funcs.py
python3 /tmp/status_all.py
nano /root/OPENCLAW_GUIDE.md
wc -l /root/OPENCLAW_GUIDE.md
python3 /tmp/status_all.py
source kalshi_env/bin/activate
python3 /tmp/status_all.py
cat /root/watchdog.log | tail -10
grep -n "entry_yes" /root/openclaw.py | head -15
sed -i 's/                    cur_yes=float(ya) if ya and 0.02<float(ya)<0.98 else entry_yes/                    cur_yes=float(ya) if ya and 0.02<float(ya)<0.98 else pos.get("entry_yes",0.5)/' /root/openclaw.py
pkill -f watchdog.py
grep -E "Error|entry_yes" /root/sol_bot.log | grep "$(date -u +%Y-%m-%d)" | tail -5
source kalshi_env/bin/activate
grep -E "WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR04" | tail -10
source kalshi_env/bin/activate
grep -E "WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR04" | tail -10
grep -n "send_telegram\|BOT_NAME" /root/openclaw.py | head -15
send_telegram(f"{"✅" if won else "❌"} BTC {outcome}...
nano /tmp/fix_unified_bugs.py
python3 /tmp/fix_unified_bugs.py
sed -n '719,720p' /root/openclaw.py
sed -i 's/send_telegram(f"📊 BTC Hourly ({hour:02d}:00 UTC)/send_telegram(f"📊 {BOT_NAME.split()[1]} Hourly ({hour:02d}:00 UTC)/' /root/openclaw.py
sed -n '45,75p' /root/dashboard.py
nano /tmp/fix_stats.py
python3 /tmp/fix_stats.py
nano /tmp/check_positions2.py
python3 /tmp/check_balance.py
grep -n "Not filled\|resting\|COOLDOWN" /root/openclaw.py | head -10
sed -n '340,360p' /root/openclaw.py
nano /tmp/fix_resting.py
python3 /tmp/fix_resting.py
sleep 120 && grep -E "Cancelled resting|Not filled|Order.*executed|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR04 1[2-9]\|26APR04 2" | tail -10
source kalshi_env/bin/activate
sleep 120 && grep -E "Cancelled resting|Not filled|Order.*executed|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR04 1[2-9]\|26APR04 2" | tail -10
grep -E "Cancelled resting|Not filled|Order.*executed|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR04 1[2-9]\|26APR04 2" | tail -10
python3 /tmp/status_all.py
sleep 120 && grep -E "WIN|LOSS|Settled" /root/bot.log | grep "26APR04" | tail -5
grep -E "WIN|LOSS|Settled|resting|Cancelled" /root/bot.log | grep "41100\|41115\|41130" | tail -5
nano /tmp/check_positions2.py
python3 /tmp/check_positions2.py
sleep 60 && grep -E "WIN|LOSS|Settled" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "41100" | tail -5
source kalshi_env/bin/activatesource kalshi_env/bin/activatesource kalshi_env/bin/activsource kalshi_env/bin/activatesource kalshi_env/bin/activatesource kalshi_env/bin/activatesource kalshi_env/bin/activate
exit
source kalshi_env/bin/activate
sleep 60 && grep -E "WIN|LOSS|Settled" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "41100" | tail -5
grep -E "WIN|LOSS|Settled" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR04 1[1-9]" | tail -10 
grep -E "WIN|LOSS|Settled" /root/bot.log /root/eth_bot.log /root/sol_bot.log | tail -15 
grep -E "WIN|LOSS|Settled" /root/bot.log | grep "26APR04" | tail -10
grep -E "Settled|WIN|LOSS|PLACED|Order.*exec" /root/eth_bot.log | grep "26APR04 1[01]" | tail -10
grep "Startup\|LIVE started\|Session" /root/eth_bot.log | tail -5 
cat /root/watchdog.log | grep -E "ETH|crashed|restarted" | tail -10
grep -E "Traceback|Error|Exception" /root/bot.log | tail -5 
ps aux | grep -E "real_bot|eth_bot|sol_bot|openclaw" | grep -v grep
sed -n '610,635p' /root/openclaw.py
sed -n '635,660p' /root/openclaw.py
nano /tmp/fix_entry_yes2.py
python3 /tmp/fix_entry_yes2.py
grep -E "Error|entry_yes" /root/bot.log | grep "$(date -u +%H)" | tail -5
sleep 180 && grep -E "Order.*executed|WIN|LOSS|CashOut|ProfitLock" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "$(date -u +%Y-%m-%d)" | tail -10
sleep 180 && grep -E "Order.*executed|WIN|LOSS|CashOut|ProfitLock" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "$(date -u +%Y-%m-%d)" | tail -10 
grep -E "entry_yes|Error|Traceback" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "$(date -u +%Y-%m-%d %H)" | tail -5
nano /root/check_health.py
python3 /root/check_health.py
exit
source kalshi_env/bin/activate
pkill -f watchdog.py && pkill -f "openclaw.py"
python3 /tmp/fix_health_check.py
python3 /root/check_health.py
source kalshi_env/bin/activate
python3 /root/check_health.py && python3 /tmp/status_all.py
sleep 120 && grep -E "Cancelled resting|Not filled|Order.*executed|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR04 1[2-9]\|26APR04 2" | tail -10
source kalshi_env/bin/activate
python3 /root/check_health.py && python3 /tmp/status_all.py
grep "HALTED\|below floor\|MIN_BALANCE" /root/bot.log /root/eth_bot.log /root/sol_bot.log | tail -5
source kalshi_env/bin/activate
python3 /root/check_health.py
python3 /tmp/status_all.
python3 /tmp/status_all.python3 /tmp/status_all.py
python3 /tmp/status_all.py
grep -E "WIN|LOSS|Settled" /root/eth_bot.log | grep "26APR04 22" | tail -5
grep -E "CashOut|ProfitLock|BreakEven" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR05" | tail -10
grep -E "age_placed|CASHOUT|ProfitLock|entry_yes" /root/bot.log | grep "26APR05" | tail -10
tail -20 /root/bot.log
grep -n "check_open_positions\|OPEN_POSITIONS\|to_remove" /root/openclaw.py | head -10
source kalshi_env/bin/activate
python3 /root/check_health.py
nano /tmp/add_correlation_guard.py
python3 /tmp/add_correlation_guard.py
grep -n "def place_order" /root/openclaw.py
sed -i 's/def place_order(direction,bet,strategy_tag="directional",mkt_yes=None,mkt_no=None):/def place_order(direction,bet,strategy_tag="directional",mkt_yes=None,mkt_no=None):\n    # CORRELATION GUARD\n    try:\n        import glob as _gl, time as _t, os as _os\n        locks = _gl.glob("\/tmp\/openclaw_firing_*.lock")\n        recent = [f for f in locks if _t.time()-_os.path.getmtime(f) < 90]\n        if len(recent) >= 2:\n            print(f"[CorrGuard] {len(recent)} bots firing — skipping correlated bet")\n            return False\n        open(f"\/tmp\/openclaw_firing_{MARKET_SERIES}.lock","w").write(str(_t.time()))\n    except Exception as _cge:\n        print(f"[CorrGuard] {_cge}")/' /root/openclaw.py
git checkout /root/openclaw.py
grep -n "TOD_SCHEDULE\|STOP_HOUR\|tod_scale==0" /root/openclaw.py | head -5
nano /tmp/fix_tod_and_sizing.py
python3 /tmp/fix_tod_and_sizing.py
pkill -f watchdog.py && pkill -f "openclaw.py"
python3 /tmp/status_all.py
python3 /root/check_health.py
sed -n '291,295p' /root/openclaw.py
grep -n "def place_order\|def try_directional\|def try_bond" /root/openclaw.py | head -5
nano /tmp/add_corr_guard.py
python3 /tmp/add_corr_guard.py
pkill -f watchdog.py && pkill -f "openclaw.py"
source kalshi_env/bin/activate
python3 /root/check_health.py
source kalshi_env/bin/activate
python3 /root/check_health.py
exit
source kalshi_env/bin/activate
grep -E "WIN|LOSS|CashOut|ProfitLock|BreakEven" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR05" | tail -20
grep -E "entry_yes|Error|Traceback" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR05" | tail -10
sed -n '640,670p' /root/openclaw.py
sed -n '670,710p' /root/openclaw.py
nano /tmp/fix_cashout_sell.py
python3 /tmp/fix_cashout_sell.py
grep -n "OPEN_POSITIONS.append" /root/openclaw.py | head -3
sed -n '378,392p' /root/openclaw.py
sed -i 's/"entry_minute":now_utc.minute%15})/"entry_minute":now_utc.minute%15,"contracts":contract_count})/' /root/openclaw.py
pkill -f watchdog.py && pkill -f "openclaw.py"
sleep 120 && grep -E "CashOut|ProfitLock|BreakEven|Sell order|WIN|LOSS" /root/bot.log /root/eth_bot.log | grep "26APR05 22" | tail -10
grep -E "WIN|LOSS|Settled" /root/bot.log /root/eth_bot.log | grep "26APR05 22" | tail -5
cat /root/watchdog.log | tail -10
nano /tmp/fix_restored.py
python3 /tmp/fix_restored.py
pkill -f watchdog.py && pkill -f "openclaw.py"
python3 /root/check_health.py
python3 /tmp/status_all.py
grep -E "CashOut|ProfitLock|BreakEven|Sell order|WIN|LOSS" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR06" | tail -20
grep -E "CashOut|ProfitLock|BreakEven|Sell order" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR06" | tail -10
grep -E "WIN|LOSS|PLACED" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR05 2\|26APR06" | tail -15 
sed -i 's/if win_prob<0.40 and age_placed>=3.0 and entry_win_prob>0.65:/if win_prob<0.45 and age_placed>=2.5 and entry_win_prob>0.60:/' /root/openclaw.py
python3 /tmp/status_all.py
source kalshi_env/bin/activate
python3 /root/check_health.py && python3 /tmp/status_all.py
grep -E "HALTED|below floor|crashed" /root/bot.log /root/eth_bot.log /root/sol_bot.log | tail -10
ps aux | grep -E "openclaw|watchdog" | grep -v grep
source kalshi_env/bin/activate
pkill -f watchdog.py && pkill -f "openclaw.py"
source kalshi_env/bin/activate
sleep 300 && grep -E "WIN|LOSS|CashOut|ProfitLock|BreakEven|Sell order|resting" /root/bot.log /root/eth_bot.log /root/sol_bot.log | grep "26APR06 19\|26APR06 20" | tail -15
tail -5 /root/bot.log
pkill -f watchdog.py && pkill -f "openclaw.py"
sed -n '653,665p' /root/openclaw.py
sed -n '653,665p' /root/openclaw.py 
sed -n '684,696p' /root/openclaw.py
sed -n '729,741p' /root/openclaw.py
nano /tmp/fix_sell_limit.py
python3 /tmp/fix_sell_limit.py
source kalshi_env/bin/activate
grep "26APR06 0[6-9]\|26APR06 1[012]" /root/bot.log | tail -20
grep "HALTED\|below floor\|Startup\|LIVE started" /root/bot.log | tail -10
grep "HALTED\|below floor\|Startup\|LIVE started" /root/eth_bot.log | tail -10
grep "26APR06 0[2-5]" /root/sol_bot.log | tail -20
cp /root/openclaw.py /root/openclaw_stable.py
sed -i 's/elif bal >= 140:/elif bal >= 125:/' /root/check_health.py
head -30 /root/bot.log
head -30 /root/eth_bot.log
head -30 /root/sol_bot.log
nano /tmp/check_kalshi_history.py
python3 /tmp/check_kalshi_history.py
nano /tmp/check_kalshi_history.py
python3 /tmp/check_kalshi_history.py 2>/dev/null | head -5
nano /tmp/check_kalshi_history.py
python3 /tmp/check_kalshi_history.py 2>/dev/null
grep -n "TOD_SCHEDULE\|MARKET_SERIES\|elif MARKET" /root/openclaw.py | head -10
sed -i 's/TOD_SCHEDULE={0:0.25,1:0.00,2:0.00,3:0.25,4:0.00,5:0.00,6:1.00,7:1.00,8:1.00,9:1.00,10:1.00,11:1.00,12:0.50,13:0.50,14:1.00,15:1.00,16:1.00,17:0.75,18:0.75,19:1.00,20:0.75,21:1.00,22:0.00,23:0.50}/TOD_SCHEDULE={0:0.00,1:0.00,2:0.00,3:0.00,4:0.00,5:0.00,6:1.00,7:1.00,8:1.00,9:1.00,10:1.00,11:1.00,12:0.50,13:0.50,14:1.00,15:1.00,16:1.00,17:0.75,18:0.75,19:1.00,20:0.75,21:1.00,22:0.00,23:0.00}/' /root/openclaw.py
grep "0:0.00\|23:0.00" /root/openclaw.py
pkill -f watchdog.py && pkill -f "openclaw.py"
python3 /root/check_health.py
tail -15 /root/bot.log
python3 /tmp/status_all.py
grep -E "PLACED|✅ BTC|Order.*exec" /root/bot.log | tail -5
grep "KXBTC15M-26APR061300\|KXBTC15M-26APR061100" /root/bot.log | tail -10
grep -n "session_start_time\|placed_at>=session" /root/openclaw.py | head -5
nano /tmp/fix_session_time.py
python3 /tmp/fix_session_time.py
sed -i 's/if bal >= 140:/if bal >= 120:/' /root/check_health.py
grep -E "KXBTC15M-26APR061300|BreakEven|CashOut|ProfitLock" /root/bot.log | tail -15
nano /tmp/fix_sell_resting.py
python3 /tmp/fix_sell_resting.py
nano /tmp/fix_all_sell_resting.py
python3 /tmp/fix_all_sell_resting.py
grep -n "CashOut.*Sell order" /root/openclaw.py
sed -n '737,748p' /root/openclaw.py
sed -i 's/                                    print(f"\[CashOut\] Sell order: {sell_order.order.status}")/                                    o=sell_order.order\n                                    print(f"[CashOut] Sell order: {o.status}")\n                                    if o.status=="resting" and o.order_id:\n                                        try:\n                                            du=f"https:\/\/api.elections.kalshi.com\/trade-api\/v2\/portfolio\/orders\/{o.order_id}"\n                                            dh=kalshi.kalshi_auth.create_auth_headers("DELETE",du)\n                                            requests.delete(du,headers=dh,timeout=5)\n                                            print(f"[CashOut] Cancelled resting sell {o.order_id}")\n                                        except Exception as de:\n                                            print(f"[CashOut] Cancel failed: {de}")/' /root/openclaw.py
grep -n "CashOut.*Cancelled\|CashOut.*resting" /root/openclaw.py
pkill -f watchdog.py && pkill -f "openclaw.py"
source kalshi_env/bin/activate
# Copy arena.py to server
grep -n "yes_ask\|window_age\|confidence_score\|REGIME\|Confidence\|Score=" ~/openclaw.py | head -30
cat > ~/arena.py << 'ARENAEOF'
scp arena.py root@167.172.244.100:~/arena.py
nano ~/arena.py
head -20 ~/openclaw.py
nano ~/arena.py
wc -l ~/arena.py
head -20 ~/openclaw.py
sed -i "s/KALSHI_API_KEY = os.environ.get(\"KALSHI_API_KEY\", \"\")/KALSHI_API_KEY='2d0a8c45-b76a-4459-a0e1-9a5e4d63fd8b'/" ~/arena.py
head -30 ~/openclaw.py | grep -A 20 "KALSHI_API_KEY"
cp ~/openclaw.py ~/arena_creds_temp.py
python3 -c "
 import re
 creds = open('/root/openclaw.py').read()
 arena = open('/root/arena.py').read()
 m = re.search(r\"KALSHI_API_KEY='[^']+'\", creds)
 if m: arena = re.sub(r\"KALSHI_API_KEY = os.environ.get\([^)]+\)\", m.group(), arena)
 s = re.search(r\"KALSHI_SECRET='''.*?'''\", creds, re.DOTALL)
 if s: arena = re.sub(r\"KALSHI_SECRET\s*=\s*os.environ.get\([^)]+\)\", s.group(), arena)
 b = re.search(r\"BOT_TOKEN='[^']+'\", creds)
 if b: arena = re.sub(r\"BOT_TOKEN\s*=\s*os.environ.get\([^)]+\)\", b.group(), arena)
 open('/root/arena.py','w').write(arena)
 print('Credentials merged successfully')
 "
grep -n "KALSHI_API_KEY\|BOT_TOKEN\|KALSHI_SECRET" ~/arena.py | head -5
cat > /tmp/merge_creds.py << 'EOF'
 import re
 creds = open('/root/openclaw.py').read()
 arena = open('/root/arena.py').read()
 m = re.search(r"KALSHI_API_KEY='[^']+'", creds)
 if m: arena = re.sub(r"KALSHI_API_KEY = os\.environ\.get\([^)]+\)", m.group(), arena)
 s = re.search(r"KALSHI_SECRET='''.*?'''", creds, re.DOTALL)
 if s: arena = re.sub(r"KALSHI_SECRET\s*=\s*os\.environ\.get\([^)]+\)", s.group(), arena)
 b = re.search(r"BOT_TOKEN='[^']+'", creds)
 if b: arena = re.sub(r"BOT_TOKEN\s*=\s*os\.environ\.get\([^)]+\)", b.group(), arena)
 open('/root/arena.py','w').write(arena)
 print('Done')
 EOF
 python3 /tmp/merge_creds.py

cat > /tmp/merge_creds.py << 'EOF'
 import re
 creds = open('/root/openclaw.py').read()
 arena = open('/root/arena.py').read()
 m = re.search(r"KALSHI_API_KEY='[^']+'", creds)
 if m: arena = re.sub(r"KALSHI_API_KEY = os\.environ\.get\([^)]+\)", m.group(), arena)
 s = re.search(r"KALSHI_SECRET='''.*?'''", creds, re.DOTALL)
 if s: arena = re.sub(r"KALSHI_SECRET\s*=\s*os\.environ\.get\([^)]+\)", s.group(), arena)
 b = re.search(r"BOT_TOKEN='[^']+'", creds)
 if b: arena = re.sub(r"BOT_TOKEN\s*=\s*os\.environ\.get\([^)]+\)", b.group(), arena)
 open('/root/arena.py','w').write(arena)
 print('Done')
 EOF

python3 /root/openclaw.py --help 2>/dev/null; python3 - << 'PYEOF'
 import re
 creds = open('/root/openclaw.py').read()
 arena = open('/root/arena.py').read()
 m = re.search(r"KALSHI_API_KEY='[^']+'", creds)
 if m: arena = re.sub(r"KALSHI_API_KEY = os\.environ\.get\([^)]+\)", m.group(), arena)
 s = re.search(r"KALSHI_SECRET='''.*?'''", creds, re.DOTALL)
 if s: arena = re.sub(r"KALSHI_SECRET\s*=\s*os\.environ\.get\([^)]+\)", s.group(), arena)
 b = re.search(r"BOT_TOKEN='[^']+'", creds)
 if b: arena = re.sub(r"BOT_TOKEN\s*=\s*os\.environ\.get\([^)]+\)", b.group(), arena)
 open('/root/arena.py','w').write(arena)
 print('Done')
 PYEOF

nano ~/arena.py
sed -n '7,20p' ~/openclaw.py
nano ~/arena.py
grep "BOT_TOKEN" ~/openclaw.py | head -1
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('Syntax OK')"
sed -i 's/\u201c/"/g; s/\u201d/"/g; s/\u2018/'"'"'/g; s/\u2019/'"'"'/g' ~/arena.py
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('Syntax OK')"
kalshi_env) root@OpenClaw-bot:~# sed -i 's/\u201c/"/g; s/\u201d/"/g; s/\u2018/'"'"'/g; s/\u2019/'"'"'/g' ~/arena.py
grep -n $'\u201c\|\u201d\|\u2018\|\u2019' ~/arena.py | head -20
python3 << PYEOF
 content = open('/root/openclaw.py').read()
 import re
 
 # Extract credentials from openclaw.py
 api_key = re.search(r"KALSHI_API_KEY='([^']+)'", content).group(1)
 secret = re.search(r"KALSHI_SECRET='''(.*?)'''", content, re.DOTALL).group(1)
 bot_token = re.search(r"BOT_TOKEN='([^']+)'", content).group(1)
 
 print(f"API Key: {api_key[:8]}...")
 print(f"Bot Token: {bot_token[:8]}...")
 print(f"Secret lines: {len(secret.splitlines())}")
 PYEOF

nano /tmp/fix_arena.py
python3 /tmp/fix_arena.py
sed -n '95,105p' ~/arena.py
rm ~/arena.py
scp /path/to/arena.py root@167.172.244.100:~/arena.py
scp ~/Downloads/arena.py root@167.172.244.100:~/arena.py
which wget
pm2 logs openclaw-btc --lines 15 --nostream
grep -n "ENTRY_THRESHOLD\|MIN_CONF\|min_conf\|threshold" ~/openclaw.py | head -20
grep -n "waiting (1/2)\|waiting (2/2)\|confirmation" ~/openclaw.py | head -10
sed -n '490,540p' ~/openclaw.py
source kalshi_env/bin/activate
pm2 list
# Step out of venv, find pm2 
# Step out of venv, find pm2
source kalshi_env/bin/activate
# Reinstall pm2
ls ~/
source ~/kalshi_env/bin/activate
head -50 ~/openclaw.py
diff ~/openclaw.py ~/real_bot_v4_stable.py | head -30
# Check what the two improved functions look like in openclaw.py
sed -n '230,270p' ~/openclaw.py
pm2 stop openclaw-btc openclaw-eth openclaw-sol
source kalshi_env/bin/activate
pm2 stop openclaw-btc openclaw-eth openclaw-sol
pm2 logs openclaw-btc --lines 30 --nostream
source kalshi_env/bin/activate
grep -n "ENTRY_THRESHOLD\|MAX_BET_PCT\|MIN_CONFIDENCE\|PROFIT_LOCK\|CHOP\|TOD\|CYCLE_SLEEP\|MAX_WINDOW\|HEDGE\|NEWS" ~/openclaw.py | head -40
source kalshi_env/bin/activate
sed -n '490,540p' ~/openclaw.py
sed -n '470,490p' ~/openclaw.py 
curl -o ~/arena.py https://gist.githubusercontent.com/raw/arena.py
printf '\e[?2004h'
echo "test"
python3 /tmp/build_arena.py << 'EOF'
 line1
 line2
 line3
 EOF

python3 -c "open('/root/arena.py','w').write(open('/root/openclaw.py').read())"
sed -i 's/OpenClaw BTC Bot v4.0 — Clean Rebuild/OpenClaw Arena v1.0 — Self-Adjusting Tournament Engine/' ~/arena.py
sed -i 's/CYCLE_SLEEP=60/CYCLE_SLEEP=60\nARENA_LOG="\/root\/arena_log.json"\nGENOME_FILE="\/root\/genome.json"\nARENA_STATE_FILE="\/root\/arena_state.json"\nARENA_BUDGET=3.00\nMIN_TRADES_EVAL=8\nMAX_VARIANTS=12\nPROMOTE_THRESHOLD=0.68\nKILL_THRESHOLD=0.35\nTOURNAMENT_MODE=False/' ~/arena.py
grep -n "ARENA_LOG\|GENOME_FILE\|TOURNAMENT_MODE\|Arena" ~/arena.py | head -10
sed -i 's/ARENA_BUDGET=3.00/ARENA_BUDGET=3.00\nARENA_STATE_FILE="\/root\/arena_state.json"/' ~/arena.py
sed -i 's/def safety_check/def write_arena_signal(market, yes_prob, regime, confidence, window_age, ticker, news_score=0, bond_score=0, whale_score=0):\n    signal={"yes_prob":yes_prob,"regime":regime,"confidence":confidence,"window_age":window_age,"ticker":ticker,"news_score":news_score,"bond_score":bond_score,"whale_score":whale_score,"ts":datetime.datetime.utcnow().isoformat()}\n    path=f"\/root\/arena_signal_{market}.json"\n    try:\n        open(path,"w").write(__import__("json").dumps(signal))\n    except Exception as e:\n        print(f"[ArenaSignal] write error: {e}")\n\ndef safety_check/' ~/arena.py
grep -n "write_arena_signal\|ARENA_STATE_FILE" ~/arena.py | head -5
grep -n "window_minute\|yes_ask\|yes_price" ~/arena.py | head -20
sed -n '428,445p' ~/arena.py
sed -i 's/window_minute=now_utc.minute%15/window_minute=now_utc.minute%15\n    write_arena_signal(market=_args.market,yes_prob=yes_price,regime=REGIME,confidence=0,window_age=window_minute,ticker=live_ticker)/' ~/arena.py
sed -n '430,435p' ~/arena.py
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('Syntax OK')"
sed -i 's/window_minute=now_utc.minute%15/window_minute=now_utc.minute%15\n    write_arena_signal(market=_args.market,yes_prob=yes_price,regime=REGIME,confidence=0,window_age=window_minute,ticker=live_ticker)/' ~/openclaw.py
sed -i 's/def safety_check/def write_arena_signal(market, yes_prob, regime, confidence, window_age, ticker, news_score=0, bond_score=0, whale_score=0):\n    signal={"yes_prob":yes_prob,"regime":regime,"confidence":confidence,"window_age":window_age,"ticker":ticker,"news_score":news_score,"bond_score":bond_score,"whale_score":whale_score,"ts":datetime.datetime.utcnow().isoformat()}\n    path=f"\/root\/arena_signal_{market}.json"\n    try:\n        open(path,"w").write(__import__("json").dumps(signal))\n    except Exception as e:\n        print(f"[ArenaSignal] write error: {e}")\n\ndef safety_check/' ~/openclaw.py
python3 -c "import ast; ast.parse(open('/root/openclaw.py').read()); print('openclaw OK')"
pm2 restart openclaw-btc openclaw-eth openclaw-sol
pm2 logs arena --lines 30 --nostream
grep -n "if __name__\|while True\|def main\|LIVE\|Startup" ~/arena.py | tail -20
tail -50 ~/arena.py
head -940 ~/arena.py > /tmp/arena_head.py
wc -l /tmp/arena_head.py
cat >> /tmp/arena_head.py << 'EOF'
 def load_json(path, default):
     try:
         if os.path.exists(path):
             with open(path) as f:
                 return json.load(f)
     except Exception:
         pass
     return default
 EOF

tail -10 /tmp/arena_head.py
python3 /tmp/write_loop.py
nano /tmp/write_loop.py 
source kalshi_env/bin/activate
echo 'if __name__=="__main__":' >> /tmp/arena_head.py
cp /tmp/arena_head.py ~/arena.py
sleep 65 && pm2 logs arena --lines 15 --nostream
wc -l /tmp/arena_head.py
head -940 /tmp/arena_head.py > /tmp/arena_base.py
echo 'def load_json(p,d):' >> /tmp/arena_base.py
echo 'if __name__=="__main__":' >> /tmp/arena_base.py
cp /tmp/arena_base.py ~/arena.py
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('OK')"
pm2 restart arena
sleep 70 && pm2 logs arena --lines 20 --nostream
sed -i 's/v\["mutations"\].append(f"tightened threshold to {v\[\\"entry_threshold\\"\]:.2f} wr={wr:.0%}")/v["mutations"].append("tightened threshold wr="+str(round(wr,2)))/' ~/arena.py
sed -i 's/v\["mutations"\].append(f"boosted bet to {v\[\\"max_bet_pct\\"\]:.2f} wr={wr:.0%}")/v["mutations"].append("boosted bet wr="+str(round(wr,2)))/' ~/arena.py
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('OK')"
sed -i 's/print(f"\[Arena\] {v\[\\"id\\"\]} {direction} {outcome} | WR={wr:.0%} T={v\[\\"trades\\"\]} PnL=\${v\[\\"pnl\\"\]:+.2f}")/print("[Arena] "+v["id"]+" "+direction+" "+outcome+" WR="+str(round(wr,2))+" T="+str(v["trades"])+" PnL="+str(v["pnl"]))/' ~/arena.py
sed -i 's/print(f"\[Arena\] Mutated {v\[\\"id\\"\]}: {v\[\\"mutations\\"\]\[-1\]}")/print("[Arena] Mutated "+v["id"])/' ~/arena.py
grep -n '\\"' ~/arena.py | grep -v "^Binary"
sed -i 's/print(f"\[Arena\] Cycle {cycle} done | {len(\[v for v in pool if v\[\\"status\\"\]==\\"active\\"\]\)} active variants")/print("[Arena] Cycle "+str(cycle)+" done | "+str(len([v for v in pool if v["status"]=="active"]))+" active variants")/' ~/arena.py
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('OK')"
python3 -c "
 content = open('/root/arena.py').read()
 old = '''        print(f\"[Arena] Cycle {cycle} done | {len([v for v in pool if v[\\\"status\\\"]==\\\"active\\\"])} active variants\")'''
 new = '        print(\"[Arena] Cycle \"+str(cycle)+\" done | \"+str(len([v for v in pool if v[\"status\"]==\"active\"]))+\" active variants\")'
 content = content.replace(old, new)
 open('/root/arena.py', 'w').write(content)
 print('Done')
 "
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('OK')"
nano +1002 ~/arena.py 
nano +1002 ~/arena.py
python3 -c "import ast; ast.parse(open('/root/arena.py').read()); print('OK')"
pm2 restart arena
cat ~/genome.json | python3 -m json.tool | head -40
cat ~/arena_state.json | python3 -m json.tool
sed -i 's/if age>5: continue/if age>13: continue/' ~/arena.py
sleep 90 && pm2 logs arena --lines 20 --nostream
sed -i 's/if conf<v.get("min_confidence",6): continue/if conf<0: continue/' ~/arena.py
cat ~/arena_state.json | python3 -m json.tool | grep -A 5 '"trades": [^0]' 
cat ~/arena_signal_btc.json
grep -n "def.*route\|@app.route\|flask\|Flask" ~/dashboard_v4.py | head -20
head -30 ~/dashboard_v4.py
grep -n "port\|run\|server\|listen\|http" ~/dashboard_v4.py | head -20
sed -n '89,130p' ~/dashboard_v4.py
sed -i "s|elif self.path == '/api/data':|elif self.path == '/arena_state':\n            try:\n                d = json.load(open('/root/arena_state.json'))\n                self.send_response(200)\n                self.send_header('Content-Type','application/json')\n                self.send_header('Access-Control-Allow-Origin','*')\n                self.end_headers()\n                self.wfile.write(json.dumps(d).encode())\n            except Exception as e:\n                self.send_response(500); self.end_headers(); self.wfile.write(str(e).encode())\n        elif self.path == '/api/data':|" ~/dashboard_v4.py
nano +103 ~/dashboard_v4.py
grep -n "arena_state\|arena_signal\|arena'" ~/dashboard_v4.py | head -10
sed -i "s|        else:|        elif self.path == '/arena':\n            self.send_response(200)\n            self.send_header('Content-Type','text/html')\n            self.end_headers()\n            self.wfile.write(open('/root/arena_dashboard.html','rb').read())\n        elif self.path.startswith('/arena_signal/'):\n            mkt=self.path.split('/')[-1]\n            try:\n                d=json.load(open(f'/root/arena_signal_{mkt}.json'))\n                self.send_response(200)\n                self.send_header('Content-Type','application/json')\n                self.send_header('Access-Control-Allow-Origin','*')\n                self.end_headers()\n                self.wfile.write(json.dumps(d).encode())\n            except: self.send_response(500); self.end_headers()\n        else:|" ~/dashboard_v4.py
grep -n "arena" ~/dashboard_v4.py
sed -n '100,140p' ~/dashboard_v4.py 
nano /tmp/fix_dashboard.py
python3 /tmp/fix_dashboard.py
sed -n '108,125p' ~/dashboard_v4.py
nano /tmp/fix_dashboard.py
python3 /tmp/fix_dashboard.py
echo '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>OpenClaw Arena</title>' > /root/arena_dashboard.html
pm2 restart dashboard
pm2 save
curl -s http://localhost:8080/arena | head -3
sed -n '89,125p' ~/dashboard_v4.py
curl -s http://localhost:8080/arena | head -3
curl -s http://localhost:8080/arena | grep -i "arena\|ARENA"
cat ~/arena_dashboard.html
curl -v http://localhost:8080/arena 2>&1 | grep "< HTTP\|Content-Type\|Location"
curl -s http://localhost:8080/arena | head -8
grep -n "self.path\|arena" ~/dashboard_v4.py | head -20
grep -n "dashboard_v4.html\|dashboard.html" ~/dashboard_v4.py
sed -i 's/if self.path == .\/api\/data.:/if self.path.split("?")[0] == "\/api\/data":/' ~/dashboard_v4.py
sed -i "s|elif self.path.split..Q...\[0\] == '/arena':|elif self.path.split('?')[0] == '/arena_state':\n            try:\n                d=json.load(open('/root/arena_state.json'))\n                self.send_response(200)\n                self.send_header('Content-Type','application/json')\n                self.send_header('Access-Control-Allow-Origin','*')\n                self.end_headers()\n                self.wfile.write(json.dumps(d).encode())\n            except: self.send_response(500); self.end_headers()\n        elif self.path.split('?')[0] == '/arena':|" ~/dashboard_v4.py
python3 -c "import ast; ast.parse(open('/root/dashboard_v4.py').read()); print('OK')"
sed -n '89,130p' ~/dashboard_v4.py
pm2 stop dashboard
nano /tmp/test_handler.py
python3 /tmp/test_handler.py &
md5sum ~/dashboard_v4.py
kill 546833
pm2 list
pm2 restart dashboard
grep -r "dashboard.py" /etc/systemd/ 2>/dev/null
curl -s http://localhost:8080/arena_state | head -3
nano +103 ~/dashboard_v4.py
nano /tmp/add_arena_state.py
python3 /tmp/add_arena_state.py
curl -v http://localhost:8080/arena_state 2>&1 | head -15
grep -n "arena_state" ~/dashboard_v4.py
python3 -c "import json; d=json.load(open('/root/arena_state.json')); print('OK', d['cycle'])"
sed -n '103,115p' ~/dashboard_v4.py
pm2 logs arena --lines 10 --nostream
ls -la ~/arena_state.json
curl -s -w "\nHTTP_STATUS:%{http_code}\n" http://localhost:8080/arena_state
sed -i 's/    return v,False$/    return v, False/' ~/arena.py
pm2 save
sed -i 's|<a href="/bible"|<a href="/arena" style="font-family:Orbitron,sans-serif;font-size:10px;letter-spacing:2px;padding:6px 12px;border:1px solid #00ffe0;color:#00ffe0;text-decoration:none;margin-right:8px;">⚔ ARENA</a><a href="/bible"|' ~/dashboard_v4.html
source kalshi_env/bin/activate
pm2 list
python3 /tmp/status_all.py
pm2 delete watchdog
source kalshi_env/bin/activate
pm2 list
python3 /tmp/status_all.py
cat /root/arena_state.json | python3 -m json.tool | head -30
cat /root/arena_state.json | python3 -m json.tool | grep -A 8 "v004"
pm2 logs arena --lines 20 --nostream
grep -n "def evaluate" /root/arena.py
sed -n '956,990p' /root/arena.py
sed -i 's/        v\["mutations"\].append("tightened threshold wr="+str(round(wr,2)))/        v["mutations"].append("tightened threshold wr="+str(round(wr,2)))\n        return v,True\n    return v,False/' /root/arena.py
grep -n "write_arena_signal" /root/openclaw.py | head -3
grep -n "conf_score\|confidence_score\|Score=" /root/openclaw.py | head -10
sed -n '460,490p' /root/openclaw.py
nano /root/openclaw.py
grep -n "arena signal\|write_arena_signal" /root/openclaw.py
sed -i 's/write_arena_signal(market=_args.market,yes_prob=yes_price,regime=REGIME,confidence=0,window_age=window_minute,ticker=live_ticker)/write_arena_signal(market=_args.market,yes_prob=yes_price,regime=REGIME,confidence=confidence,window_age=window_minute,ticker=live_ticker)/' /root/openclaw.py
nano /root/openclaw.py +485
python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 restart openclaw-btc openclaw-eth openclaw-sol arena
pm2 save
git add -A && git commit -m "Fix arena: wire real confidence score, fix evaluate() return bug"
pm2 logs arena --lines 10 --nostream
grep -n "DIRECTIONAL_HIGH\|DIRECTIONAL_LOW\|REGIME\|CHOP" /root/openclaw.py | head -10
grep -n "CHOP\|regime\|REGIME" /root/openclaw.py | grep -v "^82:\|^118:\|^217:\|^224:\|^226:\|^228:" | head -10 
sed -i 's/DIRECTIONAL_HIGH=0.70/DIRECTIONAL_HIGH=0.68/' /root/openclaw.py
sed -i 's/DIRECTIONAL_LOW=0.30/DIRECTIONAL_LOW=0.32/' /root/openclaw.py
python3 -m py_compile /root/openclaw.py && echo "OK"
grep -n "DIRECTIONAL_HIGH\|DIRECTIONAL_LOW" /root/openclaw.py | head -4
pm2 restart openclaw-btc openclaw-eth openclaw-sol
scp /path/to/arena_v2.html root@167.172.244.100:/root/arena_dashboard.html
nano /root/arena_dashboard.html 
nano /root/arena_dashboard.html
cp /root/arena_dashboard.html /root/arena_dashboard_backup.html
nano /root/arena_dashboard.html
python3 << 'PYEOF'
 content = open('/mnt/user-data/outputs/arena_v4.html').read() if False else None
 PYEOF

nano /root/arena_dashboard.html
exit
source kalshi_env/bin/activate
nano /root/arena_dashboard.html
pm2 restart dashboard
source kalshi_env/bin/activate
cp /root/arena_dashboard.html /root/arena_dashboard_backup.html
pm2 restart dashboard
python3 /tmp/status_all.py
nano /root/arena_dashboard.html
pm2 restart dashboard
sed -i 's/MIN_BALANCE=120/MIN_BALANCE=100/' /root/openclaw.py
cat /root/bond_scanner.py
cp /root/bond_scanner.py /root/bond_scanner_backup.py
pm2 restart bond-scanner
python3 -c "
 content = open('/root/bond_scanner.py').read()
 print(repr(content[:200]))
 "
sed -i '1,6d' /root/bond_scanner.py
cp /root/bond_scanner_backup.py /root/bond_scanner.py
python3 << 'PYEOF'
 with open('/root/bond_scanner_backup.py', 'r') as f:
     content = f.read()
 
 arb_config = "\nARB_MIN_PROFIT_PCT = 2.0\nARB_MAX_COST = 10.0\nARB_LOG_FILE = '/root/arb_log.json'\n"
 content = content.replace("LOG_FILE        = '/root/bond_log.json'", "LOG_FILE        = '/root/bond_log.json'" + arb_config)
 
 fetch_fn = "\ndef fetch_markets():\n    url = 'https://api.elections.kalshi.com/trade-api/v2/markets'\n    headers = get_auth_headers('GET', url)\n    all_markets = []\n    cursor = ''\n    while True:\n        params = {'status': 'open', 'limit': 100}\n        if cursor:\n            params['cursor'] = cursor\n        resp = requests.get(url, headers=headers, params=params, timeout=10)\n        if resp.status_code != 200:\n            break\n        data = resp.json()\n        markets = data.get('markets', [])\n        if not markets:\n            break\n        all_markets.extend(markets)\n        cursor = data.get('cursor', '')\n        if not cursor:\n            break\n    return all_markets\n\n"
 content = content.replace('def scan_markets():', fetch_fn + 'def scan_markets():')
 
 arb_fns = "\ndef scan_bundle_arb(markets):\n    arbs = []\n    for m in markets:\n        ticker = m.get('ticker', '')\n        yes_ask = m.get('yes_ask_dollars')\n        no_ask = m.get('no_ask_dollars')\n        close_ts = m.get('close_time') or m.get('expiration_time')\n        volume = m.get('volume', 0) or 0\n        if not yes_ask or not no_ask or not close_ts:\n            continue\n        if ticker in placed_markets:\n            continue\n        if volume < 1000:\n            continue\n        yes_price = float(yes_ask)\n        no_price = float(no_ask)\n        combined = yes_price + no_price\n        if combined >= 0.97 or combined <= 0.50:\n            continue\n        try:\n            close_dt = datetime.datetime.fromisoformat(close_ts.replace('Z', '+00:00'))\n            now_utc = datetime.datetime.now(datetime.timezone.utc)\n            mins_left = (close_dt - now_utc).total_seconds() / 60\n        except Exception:\n            continue\n        if mins_left < MIN_MINUTES or mins_left > MAX_MINUTES:\n            continue\n        gross = 1.0 - combined\n        net = gross - (0.07 * gross)\n        net_pct = (net / combined) * 100\n        if net_pct < ARB_MIN_PROFIT_PCT:\n            continue\n        arbs.append({'ticker': ticker, 'yes_price': yes_price, 'no_price': no_price, 'combined': combined, 'net_profit_pct': net_pct, 'mins_left': mins_left, 'volume': volume})\n    return sorted(arbs, key=lambda x: x['net_profit_pct'], reverse=True)\n\ndef place_bundle_arb(arb):\n    ticker = arb['ticker']\n    yes_price = arb['yes_price']\n    no_price = arb['no_price']\n    contracts = max(1, int(ARB_MAX_COST / arb['combined']))\n    yes_cents = min(99, max(1, round(yes_price * 100) + 1))\n    no_cents = min(99, max(1, round(no_price * 100) + 1))\n    try:\n        kalshi.create_order(ticker=ticker, action='buy', side='yes', type='market', count=contracts, yes_price=yes_cents, time_in_force='ioc')\n        kalshi.create_order(ticker=ticker, action='buy', side='no', type='market', count=contracts, no_price=no_cents, time_in_force='ioc')\n        placed_markets.add(ticker)\n        total_cost = contracts * arb['combined']\n        net_profit = contracts * (1.0 - arb['combined'])\n        msg = 'ARB: ' + ticker + ' YES@' + str(round(yes_price,3)) + ' + NO@' + str(round(no_price,3)) + ' combined=' + str(round(arb['combined'],3)) + ' contracts=' + str(contracts) + ' cost=$' + str(round(total_cost,2)) + ' profit=$' + str(round(net_profit,2)) + ' (' + str(round(arb['net_profit_pct'],1)) + '%) ' + str(round(arb['mins_left'],0)) + 'min'\n        print(msg)\n        send_telegram(msg)\n        import json as _j\n        with open(ARB_LOG_FILE, 'a') as f:\n            f.write(_j.dumps({'timestamp': datetime.datetime.now().isoformat(), 'ticker': ticker, 'yes_price': yes_price, 'no_price': no_price, 'combined': arb['combined'], 'contracts': contracts, 'total_cost': total_cost, 'expected_profit': net_profit}) + '\\n')\n        return True\n    except Exception as e:\n        print('[Arb] Failed: ' + str(e))\n        return False\n\n"
 content = content.replace('# ── MAIN LOOP', arb_fns + '# ── MAIN LOOP')
 
 old_loop = "            opps = scan_markets()\n            bal  = get_balance()\n            print(f\"[{datetime.datetime.now().strftime('%H:%M')}] \"\n                  f\"Scanned markets | Found {len(opps)} opportunities | \"\n                  f\"Balance: ${bal:.2f}\")\n\n            for opp in opps[:3]:  # max 3 bets per scan\n                print(f\"  -> {opp['ticker']} | {opp['side']} @ {opp['price']:.3f} | \"\n                      f\"{opp['mins_left']:.0f}min left | +{opp['profit_pct']:.1f}%\")\n                place_bond_bet(opp)"
 new_loop = "            markets = fetch_markets()\n            bal = get_balance()\n            opps = scan_markets()\n            arbs = scan_bundle_arb(markets)\n            print('[' + datetime.datetime.now().strftime('%H:%M') + '] Scanned ' + str(len(markets)) + ' markets | ' + str(len(opps)) + ' bond | ' + str(len(arbs)) + ' arb | Balance: $' + str(round(bal,2)))\n            if arbs:\n                a = arbs[0]\n                print('  TOP ARB: ' + a['ticker'] + ' combined=' + str(round(a['combined'],3)) + ' net=' + str(round(a['net_profit_pct'],1)) + '%')\n            for arb in arbs[:2]:\n                place_bundle_arb(arb)\n            for opp in opps[:3]:\n                print('  BOND: ' + opp['ticker'] + ' ' + opp['side'] + ' @' + str(round(opp['price'],3)))\n                place_bond_bet(opp)"
 
 if old_loop in content:
     content = content.replace(old_loop, new_loop)
     print('Loop replaced OK')
 else:
     print('Loop pattern not found - check manually')
 
 with open('/root/bond_scanner.py', 'w') as f:
     f.write(content)
 print('Written OK')
 PYEOF
 python3 -m py_compile /root/bond_scanner.py && echo "SYNTAX OK"
 pm2 restart bond-scanner
 pm2 logs bond-scanner --lines 5 --nostream

cat > /root/arb_scanner.py << 'EOF'
 import requests, time, datetime, json, os, tempfile
 raw=open('/root/real_bot_pre_v4_backup.py').read()
 KALSHI_KEY=raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
 KALSHI_SEC=raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
 BOT_TOKEN=raw.split("BOT_TOKEN = '")[1].split("'")[0]
 CHAT_ID=raw.split("CHAT_ID   = '")[1].split("'")[0]
 ARB_LOG='/root/arb_log.json'
 MIN_MINUTES=5
 MAX_MINUTES=45
 ARB_MAX_COST=10.0
 placed=set()
 tf=tempfile.NamedTemporaryFile(delete=False,suffix=".pem",mode="w")
 tf.write(KALSHI_SEC)
 tf.close()
 from kalshi_python import KalshiClient
 from kalshi_python.configuration import Configuration
 config=Configuration()
 config.host="https://api.elections.kalshi.com/trade-api/v2"
 kalshi=KalshiClient(config)
 kalshi.set_kalshi_auth(KALSHI_KEY,tf.name)
 def hdrs(m,u): return kalshi.kalshi_auth.create_auth_headers(m,u)
 def tg(msg):
     try: requests.get(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",params={"chat_id":CHAT_ID,"text":msg},timeout=5)
     except: pass
 def bal():
     r=requests.get("https://api.elections.kalshi.com/trade-api/v2/portfolio/balance",headers=hdrs("GET","https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"),timeout=5)
     if r.status_code==200:
         d=r.json(); return (d.get('balance',0)+d.get('portfolio_value',0))/100
     return 0
 def scan():
     url="https://api.elections.kalshi.com/trade-api/v2/markets"
     arbs=[]
     cursor=""
     while True:
         p={"status":"open","limit":100}
         if cursor: p["cursor"]=cursor
         r=requests.get(url,headers=hdrs("GET",url),params=p,timeout=10)
         if r.status_code!=200: break
         d=r.json()
         for m in d.get("markets",[]):
             tk=m.get("ticker","")
             ya=m.get("yes_ask_dollars")
             na=m.get("no_ask_dollars")
             ct=m.get("close_time") or m.get("expiration_time")
             vol=m.get("volume",0) or 0
             if not ya or not na or not ct or tk in placed or vol<1000: continue
             yp=float(ya); np2=float(na); cb=yp+np2
             if cb>=0.97 or cb<=0.50: continue
             try:
                 cd=datetime.datetime.fromisoformat(ct.replace("Z","+00:00"))
                 ml=(cd-datetime.datetime.now(datetime.timezone.utc)).total_seconds()/60
             except: continue
             if ml<MIN_MINUTES or ml>MAX_MINUTES: continue
             gross=1.0-cb; net=gross*0.93; pct=(net/cb)*100
             if pct<2.0: continue
             arbs.append({"ticker":tk,"yp":yp,"np":np2,"cb":cb,"pct":pct,"ml":ml,"vol":vol})
         cursor=d.get("cursor","")
         if not cursor: break
     return sorted(arbs,key=lambda x:x["pct"],reverse=True)
 def execute(arb):
     tk=arb["ticker"]; yp=arb["yp"]; np2=arb["np"]
     n=max(1,int(ARB_MAX_COST/arb["cb"]))
     yc=min(99,max(1,round(yp*100)+1)); nc=min(99,max(1,round(np2*100)+1))
     try:
         kalshi.create_order(ticker=tk,action="buy",side="yes",type="market",count=n,yes_price=yc,time_in_force="ioc")
         kalshi.create_order(ticker=tk,action="buy",side="no",type="market",count=n,no_price=nc,time_in_force="ioc")
         placed.add(tk)
         cost=n*arb["cb"]; profit=n*(1.0-arb["cb"])
         msg=f"ARB {tk} YES@{yp:.3f}+NO@{np2:.3f}={arb['cb']:.3f} x{n} cost=${cost:.2f} profit=${profit:.2f} ({arb['pct']:.1f}%) {arb['ml']:.0f}min"
         print(msg); tg(msg)
         with open(ARB_LOG,"a") as f:
             f.write(json.dumps({"ts":datetime.datetime.now().isoformat(),"ticker":tk,"yp":yp,"np":np2,"cb":arb["cb"],"n":n,"cost":cost,"profit":profit})+"\n")
     except Exception as e: print(f"[Arb] fail: {e}")
 print("Arb scanner started")
 tg("Arb scanner started - hunting bundle arb opportunities")
 while True:
     if os.path.exists('/root/STOP_ARB'): break
     try:
         arbs=scan()
         b=bal()
         print(f"[{datetime.datetime.now().strftime('%H:%M')}] {len(arbs)} arbs found | bal=${b:.2f}")
         if arbs: print(f"  TOP: {arbs[0]['ticker']} cb={arbs[0]['cb']:.3f} net={arbs[0]['pct']:.1f}%")
         for arb in arbs[:2]: execute(arb)
     except Exception as e: print(f"[Arb] scan err: {e}")
     time.sleep(120)
 EOF
 python3 -m py_compile /root/arb_scanner.py && echo "OK"

cd /root
python3 -c "import urllib.request; open('arb_scanner.py','wb').write(urllib.request.urlopen('http://167.172.244.100:8080/bible').read())"
curl -s http://167.172.244.100:8080/ > /dev/null && echo "server up"
sed -n '1,5p' /root/bond_scanner.py
# Fix the curly quotes in the docstring first
# Add arb config after LOG_FILE line
grep -c "def scan_markets" /root/bond_scanner.py
# Add fetch_markets and scan_bundle_arb functions before the main loop
python3 -c "
 lines=[
 'import requests,time,datetime,json,os,tempfile',
 'raw=open(\"/root/real_bot_pre_v4_backup.py\").read()',
 'KALSHI_KEY=raw.split(\"KALSHI_API_KEY = \x27\")[1].split(\"\x27\")[0]',
 'KALSHI_SEC=raw.split(\"KALSHI_SECRET  = \x27\x27\x27\")[1].split(\"\x27\x27\x27\")[0]',
 'BOT_TOKEN=raw.split(\"BOT_TOKEN = \x27\")[1].split(\"\x27\")[0]',
 'CHAT_ID=raw.split(\"CHAT_ID   = \x27\")[1].split(\"\x27\")[0]',
 'ARB_LOG,MIN_MIN,MAX_MIN,MAX_COST=\"/root/arb_log.json\",5,45,10.0',
 'placed=set()',
 'import tempfile as _tf',
 'tf=_tf.NamedTemporaryFile(delete=False,suffix=\".pem\",mode=\"w\")',
 'tf.write(KALSHI_SEC)',
 'tf.close()',
 'from kalshi_python import KalshiClient',
 'from kalshi_python.configuration import Configuration',
 'cfg=Configuration()',
 'cfg.host=\"https://api.elections.kalshi.com/trade-api/v2\"',
 'k=KalshiClient(cfg)',
 'k.set_kalshi_auth(KALSHI_KEY,tf.name)',
 'def h(m,u): return k.kalshi_auth.create_auth_headers(m,u)',
 'def tg(msg):\n try: requests.get(f\"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage\",params={\"chat_id\":CHAT_ID,\"text\":msg},timeout=5)\n except: pass',
 'def bal():\n r=requests.get(\"https://api.elections.kalshi.com/trade-api/v2/portfolio/balance\",headers=h(\"GET\",\"https://api.elections.kalshi.com/trade-api/v2/portfolio/balance\"),timeout=5)\n if r.status_code==200:\n  d=r.json();return (d.get(\"balance\",0)+d.get(\"portfolio_value\",0))/100\n return 0',
 'def scan():\n url=\"https://api.elections.kalshi.com/trade-api/v2/markets\"\n arbs=[];cursor=\"\"\n while True:\n  p={\"status\":\"open\",\"limit\":100}\n  if cursor: p[\"cursor\"]=cursor\n  r=requests.get(url,headers=h(\"GET\",url),params=p,timeout=10)\n  if r.status_code!=200: break\n  d=r.json()\n  for m in d.get(\"markets\",[]):\n   tk=m.get(\"ticker\",\"\");ya=m.get(\"yes_ask_dollars\");na=m.get(\"no_ask_dollars\")\n   ct=m.get(\"close_time\") or m.get(\"expiration_time\");vol=m.get(\"volume\",0) or 0\n   if not ya or not na or not ct or tk in placed or vol<1000: continue\n   yp=float(ya);np2=float(na);cb=yp+np2\n   if cb>=0.97 or cb<=0.50: continue\n   try:\n    cd=datetime.datetime.fromisoformat(ct.replace(\"Z\",\"+00:00\"))\n    ml=(cd-datetime.datetime.now(datetime.timezone.utc)).total_seconds()/60\n   except: continue\n   if ml<MIN_MIN or ml>MAX_MIN: continue\n   net=(1.0-cb)*0.93;pct=(net/cb)*100\n   if pct<2.0: continue\n   arbs.append({\"tk\":tk,\"yp\":yp,\"np\":np2,\"cb\":cb,\"pct\":pct,\"ml\":ml})\n  cursor=d.get(\"cursor\",\"\")\n  if not cursor: break\n return sorted(arbs,key=lambda x:x[\"pct\"],reverse=True)',
 'def go(arb):\n tk=arb[\"tk\"];yp=arb[\"yp\"];np2=arb[\"np\"]\n n=max(1,int(MAX_COST/arb[\"cb\"]))\n yc=min(99,max(1,round(yp*100)+1));nc=min(99,max(1,round(np2*100)+1))\n try:\n  k.create_order(ticker=tk,action=\"buy\",side=\"yes\",type=\"market\",count=n,yes_price=yc,time_in_force=\"ioc\")\n  k.create_order(ticker=tk,action=\"buy\",side=\"no\",type=\"market\",count=n,no_price=nc,time_in_force=\"ioc\")\n  placed.add(tk)\n  cost=n*arb[\"cb\"];profit=n*(1.0-arb[\"cb\"])\n  msg=\"ARB \"+tk+\" \"+str(round(yp,3))+\"+\"+str(round(np2,3))+\"=\"+str(round(arb[\"cb\"],3))+\" x\"+str(n)+\" $\"+str(round(cost,2))+\" pft $\"+str(round(profit,2))+\" (\"+str(round(arb[\"pct\"],1))+\"%)\"\n  print(msg);tg(msg)\n  with open(ARB_LOG,\"a\") as f: f.write(json.dumps({\"ts\":datetime.datetime.now().isoformat(),\"tk\":tk,\"cb\":arb[\"cb\"],\"n\":n,\"cost\":cost,\"profit\":profit})+\"\\n\")\n except Exception as e: print(\"[Arb] \"+str(e))',
 'print(\"Arb scanner v1 started\")',
 'tg(\"Arb scanner started\")',
 'while True:\n if os.path.exists(\"/root/STOP_ARB\"): break\n try:\n  arbs=scan();b=bal()\n  print(\"[\"+datetime.datetime.now().strftime(\"%H:%M\")+\"] \"+str(len(arbs))+\" arbs | bal=$\"+str(round(b,2)))\n  if arbs: print(\"  TOP: \"+arbs[0][\"tk\"]+\" cb=\"+str(round(arbs[0][\"cb\"],3))+\" \"+str(round(arbs[0][\"pct\"],1))+\"%\")\n  for arb in arbs[:2]: go(arb)\n except Exception as e: print(\"[Arb] \"+str(e))\n time.sleep(120)',
 ]
 open('/root/arb_scanner.py','w').write('\n'.join(lines)+'\n')
 print('written')
 "
python3 -c "
 lines=[
 'import requests,time,datetime,json,os,tempfile',
 'raw=open(\"/root/real_bot_pre_v4_backup.py\").read()',
 'KALSHI_KEY=raw.split(\"KALSHI_API_KEY = \x27\")[1].split(\"\x27\")[0]',
 'KALSHI_SEC=raw.split(\"KALSHI_SECRET  = \x27\x27\x27\")[1].split(\"\x27\x27\x27\")[0]',
 'BOT_TOKEN=raw.split(\"BOT_TOKEN = \x27\")[1].split(\"\x27\")[0]',
 'CHAT_ID=raw.split(\"CHAT_ID   = \x27\")[1].split(\"\x27\")[0]',
 'ARB_LOG,MIN_MIN,MAX_MIN,MAX_COST=\"/root/arb_log.json\",5,45,10.0',
 'placed=set()',
 'import tempfile as _tf',
 'tf=_tf.NamedTemporaryFile(delete=False,suffix=\".pem\",mode=\"w\")',
 'tf.write(KALSHI_SEC)',
 'tf.close()',
 'from kalshi_python import KalshiClient',
 'from kalshi_python.configuration import Configuration',
 'cfg=Configuration()',
 'cfg.host=\"https://api.elections.kalshi.com/trade-api/v2\"',
 'k=KalshiClient(cfg)',
 'k.set_kalshi_auth(KALSHI_KEY,tf.name)',
 'def h(m,u): return k.kalshi_auth.create_auth_headers(m,u)',
 'def tg(msg):\n try: requests.get(f\"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage\",params={\"chat_id\":CHAT_ID,\"text\":msg},timeout=5)\n except: pass',
 'def bal():\n r=requests.get(\"https://api.elections.kalshi.com/trade-api/v2/portfolio/balance\",headers=h(\"GET\",\"https://api.elections.kalshi.com/trade-api/v2/portfolio/balance\"),timeout=5)\n if r.status_code==200:\n  d=r.json();return (d.get(\"balance\",0)+d.get(\"portfolio_value\",0))/100\n return 0',
 'def scan():\n url=\"https://api.elections.kalshi.com/trade-api/v2/markets\"\n arbs=[];cursor=\"\"\n while True:\n  p={\"status\":\"open\",\"limit\":100}\n  if cursor: p[\"cursor\"]=cursor\n  r=requests.get(url,headers=h(\"GET\",url),params=p,timeout=10)\n  if r.status_code!=200: break\n  d=r.json()\n  for m in d.get(\"markets\",[]):\n   tk=m.get(\"ticker\",\"\");ya=m.get(\"yes_ask_dollars\");na=m.get(\"no_ask_dollars\")\n   ct=m.get(\"close_time\") or m.get(\"expiration_time\");vol=m.get(\"volume\",0) or 0\n   if not ya or not na or not ct or tk in placed or vol<1000: continue\n   yp=float(ya);np2=float(na);cb=yp+np2\n   if cb>=0.97 or cb<=0.50: continue\n   try:\n    cd=datetime.datetime.fromisoformat(ct.replace(\"Z\",\"+00:00\"))\n    ml=(cd-datetime.datetime.now(datetime.timezone.utc)).total_seconds()/60\n   except: continue\n   if ml<MIN_MIN or ml>MAX_MIN: continue\n   net=(1.0-cb)*0.93;pct=(net/cb)*100\n   if pct<2.0: continue\n   arbs.append({\"tk\":tk,\"yp\":yp,\"np\":np2,\"cb\":cb,\"pct\":pct,\"ml\":ml})\n  cursor=d.get(\"cursor\",\"\")\n  if not cursor: break\n return sorted(arbs,key=lambda x:x[\"pct\"],reverse=True)',
 'def go(arb):\n tk=arb[\"tk\"];yp=arb[\"yp\"];np2=arb[\"np\"]\n n=max(1,int(MAX_COST/arb[\"cb\"]))\n yc=min(99,max(1,round(yp*100)+1));nc=min(99,max(1,round(np2*100)+1))\n try:\n  k.create_order(ticker=tk,action=\"buy\",side=\"yes\",type=\"market\",count=n,yes_price=yc,time_in_force=\"ioc\")\n  k.create_order(ticker=tk,action=\"buy\",side=\"no\",type=\"market\",count=n,no_price=nc,time_in_force=\"ioc\")\n  placed.add(tk)\n  cost=n*arb[\"cb\"];profit=n*(1.0-arb[\"cb\"])\n  msg=\"ARB \"+tk+\" \"+str(round(yp,3))+\"+\"+str(round(np2,3))+\"=\"+str(round(arb[\"cb\"],3))+\" x\"+str(n)+\" $\"+str(round(cost,2))+\" pft $\"+str(round(profit,2))+\" (\"+str(round(arb[\"pct\"],1))+\"%)\"\n  print(msg);tg(msg)\n  with open(ARB_LOG,\"a\") as f: f.write(json.dumps({\"ts\":datetime.datetime.now().isoformat(),\"tk\":tk,\"cb\":arb[\"cb\"],\"n\":n,\"cost\":cost,\"profit\":profit})+\"\\n\")\n except Exception as e: print(\"[Arb] \"+str(e))',
 'print(\"Arb scanner v1 started\")',
 'tg(\"Arb scanner started\")',
 'while True:\n if os.path.exists(\"/root/STOP_ARB\"): break\n try:\n  arbs=scan();b=bal()\n  print(\"[\"+datetime.datetime.now().strftime(\"%H:%M\")+\"] \"+str(len(arbs))+\" arbs | bal=$\"+str(round(b,2)))\n  if arbs: print(\"  TOP: \"+arbs[0][\"tk\"]+\" cb=\"+str(round(arbs[0][\"cb\"],3))+\" \"+str(round(arbs[0][\"pct\"],1))+\"%\")\n  for arb in arbs[:2]: go(arb)\n except Exception as e: print(\"[Arb] \"+str(e))\n time.sleep(120)',
 ]
 open('/root/arb_scanner.py','w').write('\n'.join(lines)+'\n')
 print('written')
 "
grep -n "arena_dashboard" /root/dashboard_v4.py | head -5
python3 -c "open('/root/arb_scanner.py','w').write(open('/root/bond_scanner.py').read())"
python3 -m py_compile /root/arb_scanner.py && echo "OK"
cp /root/bond_scanner_backup.py /root/bond_scanner.py
pm2 logs openclaw-btc --lines 20 --nostream
exit
