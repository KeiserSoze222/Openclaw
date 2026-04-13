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
source kalshi_env/bin/activate
pm2 logs openclaw-btc --lines 20 --nostream
grep "MIN_BALANCE" /root/openclaw.py 
grep -n "v012\|pool\|DEMO_POOL\|genome" /root/arena.py | head -10
python3 -c "
 import json
 pool = json.load(open('/root/genome.json'))
 for v in pool:
     print(v['id'], v['market'], 'thresh='+str(v.get('entry_threshold',0)), 'trades='+str(v.get('trades',0)))
 "
python3 -c "import json; pool=json.load(open('/root/genome.json')); [print(v['id'],v['market'],'thresh='+str(v.get('entry_threshold',0)),'trades='+str(v.get('trades',0))) for v in pool]"
python3 -c "import json; pool=json.load(open('/root/genome.json')); [print(v['id'],v['market'],'wr='+str(round(v['wins']/v['trades'],3) if v['trades']>0 else 0),'trades='+str(v['trades']),'pnl='+str(v['pnl'])) for v in pool]"
python3 -c "import json; pool=json.load(open('/root/genome.json')); v4=[v for v in pool if v['id']=='v004'][0]; print('thresh='+str(v4['entry_threshold']),'bet='+str(v4['max_bet_pct']),'chop='+str(v4['chop_allowed']),'conf='+str(v4['min_confidence']))"
grep -E "DIRECTIONAL_HIGH|DIRECTIONAL_LOW|MIN_CONFIDENCE|MAX_BET_PCT" /root/openclaw.py | head -6
git add -A && git commit -m "Restore bond scanner - arb scanner backlogged for file transfer fix"
grep -n "def evaluate\|save_json\|cycle+=1\|print.*Cycle.*done" /root/arena.py | head -10
sed -n '998,1010p' /root/arena.py
sed -i '1002a\        auto_promote(pool)' /root/arena.py
sed -n '956,966p' /root/arena.py
python3 -c "import subprocess; content=open('/root/arena.py').read(); fn='\ndef auto_promote(pool):\n    try:\n        candidates=[v for v in pool if v.get(\"trades\",0)>=50]\n        if not candidates: return\n        leader=max(candidates,key=lambda v:v.get(\"wins\",0)/v.get(\"trades\",1))\n        wr=leader.get(\"wins\",0)/leader.get(\"trades\",1)\n        if wr<0.70: return\n        thresh=leader.get(\"entry_threshold\",0.70)\n        cur=subprocess.check_output([\"grep\",\"DIRECTIONAL_HIGH\",\"/root/openclaw.py\"]).decode()\n        cur_thresh=float([x for x in cur.split() if \"=\" in x][0].split(\"=\")[1])\n        if abs(thresh-cur_thresh)<0.001: return\n        subprocess.run([\"sed\",\"-i\",\"s/DIRECTIONAL_HIGH=\"+str(cur_thresh)+\"/DIRECTIONAL_HIGH=\"+str(thresh)+\"/\",\"/root/openclaw.py\"])\n        subprocess.run([\"pm2\",\"restart\",\"openclaw-btc\",\"openclaw-eth\",\"openclaw-sol\"])\n        msg=\"[AutoPromote] \"+leader[\"id\"]+\" WR=\"+str(round(wr,3))+\" thresh=\"+str(thresh)+\" promoted\"\n        print(msg)\n        raw=open(\"/root/real_bot_pre_v4_backup.py\").read()\n        tok=raw.split(\"BOT_TOKEN = \x27\")[1].split(\"\x27\")[0]\n        cid=raw.split(\"CHAT_ID   = \x27\")[1].split(\"\x27\")[0]\n        import requests as _r\n        _r.get(\"https://api.telegram.org/bot\"+tok+\"/sendMessage\",params={\"chat_id\":cid,\"text\":msg},timeout=5)\n    except Exception as e: print(\"[AutoPromote] err:\"+str(e))\n'; content=content.replace('if __name__==\"__main__\":',fn+'if __name__==\"__main__\":'); open('/root/arena.py','w').write(content); print('done')"
python3 -m py_compile /root/arena.py && echo "OK"
python3 /tmp/status_all.py
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/markets'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/markets',headers=hdrs,params={'status':'open','limit':100,'series_ticker':'KXFOMC'},timeout=10); print(r.status_code); [print(m.get('ticker'),str(m.get('yes_ask_dollars')),m.get('title','')[:50]) for m in r.json().get('markets',[])]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/markets'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/markets',headers=hdrs,params={'status':'open','limit':100,'series_ticker':'KXEARNINGS'},timeout=10); print('EARNINGS:',r.status_code,len(r.json().get('markets',[]))); [print(m.get('ticker'),str(m.get('yes_ask_dollars')),m.get('title','')[:50]) for m in r.json().get('markets',[])[:10]]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/markets'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/markets',headers=hdrs,params={'status':'open','limit':100,'category':'mentions'},timeout=10); print('MENTIONS:',r.status_code,len(r.json().get('markets',[]))); [print(m.get('ticker'),str(m.get('yes_ask_dollars')),m.get('title','')[:50]) for m in r.json().get('markets',[])[:15]]"
python3 -c "open('/root/mentions_scanner.py','w').write('import requests,time,datetime,json,os,tempfile\nraw=open(\"/root/real_bot_pre_v4_backup.py\").read()\nKALSHI_KEY=raw.split(\"KALSHI_API_KEY = \x27\")[1].split(\"\x27\")[0]\nKALSHI_SEC=raw.split(\"KALSHI_SECRET  = \x27\x27\x27\")[1].split(\"\x27\x27\x27\")[0]\nBOT_TOKEN=raw.split(\"BOT_TOKEN = \x27\")[1].split(\"\x27\")[0]\nCHAT_ID=raw.split(\"CHAT_ID   = \x27\")[1].split(\"\x27\")[0]\ntf=tempfile.NamedTemporaryFile(delete=False,suffix=\".pem\",mode=\"w\")\ntf.write(KALSHI_SEC)\ntf.close()\nfrom kalshi_python import KalshiClient\nfrom kalshi_python.configuration import Configuration\ncfg=Configuration()\ncfg.host=\"https://api.elections.kalshi.com/trade-api/v2\"\nk=KalshiClient(cfg)\nk.set_kalshi_auth(KALSHI_KEY,tf.name)\nSCAN_INTERVAL=60\nalerted=set()\nBASE_RATES={\"inflation\":0.95,\"recession\":0.45,\"rate\":0.92,\"employment\":0.88,\"gdp\":0.72,\"tariff\":0.65,\"uncertainty\":0.55,\"data\":0.98,\"balance\":0.60,\"mandate\":0.75}\ndef hdrs(m,u): return k.kalshi_auth.create_auth_headers(m,u)\ndef tg(msg):\n try: requests.get(\"https://api.telegram.org/bot\"+BOT_TOKEN+\"/sendMessage\",params={\"chat_id\":CHAT_ID,\"text\":msg},timeout=5)\n except: pass\ndef get_mentions_markets():\n url=\"https://api.elections.kalshi.com/trade-api/v2/markets\"\n r=requests.get(url,headers=hdrs(\"GET\",url),params={\"status\":\"open\",\"limit\":200},timeout=10)\n if r.status_code!=200: return []\n markets=[]\n for m in r.json().get(\"markets\",[]):\n  tk=m.get(\"ticker\",\"\")\n  title=m.get(\"title\",\"\").lower()\n  series=m.get(\"series_ticker\",\"\")\n  if any(x in series.upper() for x in [\"FOMC\",\"POWELL\",\"FED\",\"EARNINGS\",\"MENTION\",\"SPEECH\",\"PRESS\"]):\n   markets.append(m)\n  elif any(x in title for x in [\"mentioned\",\"mention\",\"says\",\"said\",\"word\",\"times\"]):\n   markets.append(m)\n return markets\ndef analyze(m):\n title=m.get(\"title\",\"\").lower()\n ticker=m.get(\"ticker\",\"\")\n yes_ask=m.get(\"yes_ask_dollars\") or 0.5\n yp=float(yes_ask)\n word_found=None\n for word,base in BASE_RATES.items():\n  if word in title:\n   word_found=word\n   base_rate=base\n   break\n if not word_found: return None\n edge=base_rate-yp\n if abs(edge)<0.08: return None\n side=\"yes\" if edge>0 else \"no\"\n price=yp if side==\"yes\" else 1-yp\n return {\"ticker\":ticker,\"title\":m.get(\"title\",\"\")[:60],\"word\":word_found,\"base_rate\":base_rate,\"market_price\":yp,\"edge\":edge,\"side\":side,\"price\":price}\nprint(\"Mentions scanner started - watching for FOMC/earnings markets\")\ntg(\"Mentions scanner started - watching for FOMC/earnings/speech markets\")\nwhile True:\n if os.path.exists(\"/root/STOP_MENTIONS\"): break\n try:\n  markets=get_mentions_markets()\n  if markets:\n   print(\"[\"+datetime.datetime.now().strftime(\"%H:%M\")+\"] Found \"+str(len(markets))+\" mentions markets\")\n   for m in markets:\n    tk=m.get(\"ticker\",\"\")\n    analysis=analyze(m)\n    if analysis and tk not in alerted:\n     alerted.add(tk)\n     msg=\"MENTIONS EDGE: \"+analysis[\"ticker\"]+\"\\nWord: \"+analysis[\"word\"]+\" | Base rate: \"+str(round(analysis[\"base_rate\"]*100))+\"%\\nMarket price: \"+str(round(analysis[\"market_price\"]*100))+\"% | Edge: \"+str(round(analysis[\"edge\"]*100,1))+\"%\\nTrade: \"+analysis[\"side\"].upper()+\" @ \"+str(round(analysis[\"price\"]*100))+\"c\\n\"+analysis[\"title\"]\n     print(msg)\n     tg(msg)\n  else:\n   print(\"[\"+datetime.datetime.now().strftime(\"%H:%M\")+\"] No mentions markets open yet\")\n except Exception as e: print(\"[Mentions] \"+str(e))\n time.sleep(SCAN_INTERVAL)\n')"
python3 -m py_compile /root/mentions_scanner.py && echo "OK"
sed -n '65,70p' /root/mentions_scanner.py
python3 -c "
 content=open('/root/mentions_scanner.py').read()
 old='     msg=\"MENTIONS EDGE: \"+analysis[\"ticker\"]+\"\nWord: \"+analysis[\"word\"]+\" | Base rate: \"+str(round(analysis[\"base_rate\"]*100))+\"%\nMarket price: \"+str(round(analysis[\"market_price\"]*100))+\"% | Edge: \"+str(round(analysis[\"edge\"]*100,1))+\"%\nTrade: \"+analysis[\"side\"].upper()+\" @ \"+str(round(analysis[\"price\"]*100))+\"c\n\"+analysis[\"title\"]'
 new='     msg=\"MENTIONS EDGE: \"+analysis[\"ticker\"]+\" | \"+analysis[\"word\"]+\" base=\"+str(round(analysis[\"base_rate\"]*100))+\"% mkt=\"+str(round(analysis[\"market_price\"]*100))+\"% edge=\"+str(round(analysis[\"edge\"]*100,1))+\"% trade=\"+analysis[\"side\"].upper()+\"@\"+str(round(analysis[\"price\"]*100))+\"c | \"+analysis[\"title\"]'
 print('found' if old in content else 'NOT FOUND')
 " 
python3 -c "c=open('/root/mentions_scanner.py').read(); print('found' if '     msg=\"MENTIONS EDGE: \"+analysis[\"ticker\"]+\"\nWord:' in c else 'NOT FOUND')"
python3 -c "c=open('/root/mentions_scanner.py').read(); c=c.replace('     msg=\"MENTIONS EDGE: \"+analysis[\"ticker\"]+\"\nWord: \"+analysis[\"word\"]+\" | Base rate: \"+str(round(analysis[\"base_rate\"]*100))+\"%\nMarket price: \"+str(round(analysis[\"market_price\"]*100))+\"% | Edge: \"+str(round(analysis[\"edge\"]*100,1))+\"%\nTrade: \"+analysis[\"side\"].upper()+\" @ \"+str(round(analysis[\"price\"]*100))+\"c\n\"+analysis[\"title\"]','     msg=\"MENTIONS: \"+analysis[\"ticker\"]+\" \"+analysis[\"word\"]+\" base=\"+str(round(analysis[\"base_rate\"]*100))+\"% mkt=\"+str(round(analysis[\"market_price\"]*100))+\"% edge=\"+str(round(analysis[\"edge\"]*100,1))+\"% \"+analysis[\"side\"].upper()+\"@\"+str(round(analysis[\"price\"]*100))+\"c\"'); open('/root/mentions_scanner.py','w').write(c); print('done')"
python3 -m py_compile /root/mentions_scanner.py && echo "OK"
sed -n '65,70p' /root/mentions_scanner.py
pm2 flush mentions-scanner && pm2 restart mentions-scanner && sleep 3 && pm2 logs mentions-scanner --lines 5 --nostream
git add -A && git commit -m "Mentions scanner running - will alert on FOMC May 7 and earnings markets"
pm2 logs openclaw-btc --lines 30 --nostream | grep -E "BET|LOSS|WIN|Balance|HALT|floor"
pm2 logs openclaw-eth --lines 20 --nostream | grep -E "BET|LOSS|WIN|Balance|HALT"
pm2 stop openclaw-btc openclaw-eth openclaw-sol
python3 -c "import json; pool=json.load(open('/root/genome.json')); print(len(pool),'variants'); [print(v['id'],v['market'],'wr='+str(round(v['wins']/v['trades'],3) if v['trades']>0 else 0),'trades='+str(v['trades'])) for v in pool]"
python3 -c "import json; pool=json.load(open('/root/genome.json')); v007=next(v for v in pool if v['id']=='v007'); v007['market']='btc'; v007['entry_threshold']=0.65; v007['max_bet_pct']=0.11; v007['min_confidence']=5; v007['chop_allowed']=True; v007['wins']=0; v007['losses']=0; v007['trades']=0; v007['pnl']=0.0; v007['generation']=1; v007['mutations']=[]; v005=next(v for v in pool if v['id']=='v005'); v005['entry_threshold']=0.72; v005['max_bet_pct']=0.09; v005['min_confidence']=7; v005['chop_allowed']=False; v005['wins']=0; v005['losses']=0; v005['trades']=0; v005['pnl']=0.0; v005['generation']=1; v005['mutations']=[]; json.dump(pool,open('/root/genome.json','w'),indent=2); print('done'); [print(v['id'],v['market'],'thresh='+str(v['entry_threshold']),'ch​​​​​​​​​​​​​​​​
python3 -c "import json; pool=json.load(open('/root/genome.json')); v=next(x for x in pool if x['id']=='v007'); v.update({'market':'btc','entry_threshold':0.65,'max_bet_pct':0.11,'min_confidence':5,'chop_allowed':True,'wins':0,'losses':0,'trades':0,'pnl':0.0,'generation':1,'mutations':[]}); json.dump(pool,open('/root/genome.json','w'),indent=2); print('v007 updated')"
python3 -c "import json; pool=json.load(open('/root/genome.json')); v=next(x for x in pool if x['id']=='v005'); v.update({'entry_threshold':0.72,'max_bet_pct':0.09,'min_confidence':7,'chop_allowed':False,'wins':0,'losses':0,'trades':0,'pnl':0.0,'generation':1,'mutations':[]}); json.dump(pool,open('/root/genome.json','w'),indent=2); print('v005 updated')"
python3 -c "import json; pool=json.load(open('/root/genome.json')); [print(v['id'],v['market'],'thresh='+str(v['entry_threshold']),'chop='+str(v['chop_allowed']),'trades='+str(v['trades'])) for v in pool]"
grep -n "MIN_BALANCE\|v4.0\|arena\|AUTO" /root/OPENCLAW_GUIDE.md | head -10
python3 -c "
 content=open('/root/OPENCLAW_GUIDE.md').read()
 update='\n\n---\n## UPDATE — April 9, 2026\n\n### System Changes\n- MIN_BALANCE lowered from 120 to 100 (then bots stopped at 95.66, awaiting deposit)\n- DIRECTIONAL_HIGH=0.68 / DIRECTIONAL_LOW=0.32 (promoted from v004 arena winner)\n- Bots currently STOPPED — resuming after deposit\n\n### New Processes (PM2)\n- mentions-scanner: watches for FOMC/earnings word frequency markets, alerts on edge\n- arena now has auto-promote: promotes leader to live bot when WR>=70% and 50+ trades\n\n### Arena v5 Deployed\n- Full space background with planets, shooting stars, parallax scroll\n- Bot SVG character faces, thought bubbles with competitive monologue\n- Scoreboard jumbotron, narrative leaderboard, rivalry panels\n- URL: http://167.172.244.100:8080/arena\n\n### Genome Pool Updates\n- v004: CHAMPION — 1058 trades, 89% WR, thresh=0.68, chop=True\n- v007: REPLACED — was weak ETH 58% WR, now aggressive BTC thresh=0.65 chop=True\n- v005: RETUNED — thresh=0.72 chop=False (sniper variant)\n\n### Priority Backlog\n1. Arb scanner (file transfer issue — needs solution)\n2. Cross-platform arb (needs network unblock)\n3. Fade-the-headlines strategy\n4. Macro signal integration\n5. Weather between-bracket NO scanner\n'
 open('/root/OPENCLAW_GUIDE.md','w').write(content+update)
 print('done')
 "
python3 -c "content=open('/root/OPENCLAW_GUIDE.md').read(); update='\n\n---\n## UPDATE April 9 2026\n\n### System Changes\n- MIN_BALANCE=100 (bots stopped at 95.66, awaiting deposit)\n- DIRECTIONAL_HIGH=0.68/LOW=0.32 promoted from v004\n- Bots STOPPED - resume after deposit with: pm2 start openclaw-btc openclaw-eth openclaw-sol\n\n### New PM2 Processes\n- mentions-scanner: watches FOMC/earnings word markets, alerts on Telegram\n- arena auto-promote: promotes leader to live bot when WR>=70% 50+ trades\n\n### Arena v5\n- Space background, planets, shooting stars, parallax scroll\n- SVG bot faces, thought bubbles, scoreboard, narrative leaderboard\n- http://167.172.244.100:8080/arena\n\n### Genome Updates\n- v004: CHAMPION 1058T 89%WR thresh=0.68 chop=True\n- v007: REPLACED weak ETH, now aggressive BTC thresh=0.65 chop=True\n- v005: RETUNED thresh=0.72 chop=False sniper\n\n### Backlog\n1. Arb scanner (file transfer issue)\n2. Cross-platform arb (needs network unblock)\n3. Fade-the-headlines\n4. Macro signal integration\n5. Weather NO scanner\n'; open('/root/OPENCLAW_GUIDE.md','w').write(content+update); print('done')"
git add -A && git commit -m "Bible update April 9 2026 - arena v5, mentions scanner, auto-promote, genome"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/markets'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/markets',headers=hdrs,params={'status':'open','limit':10,'series_ticker':'KXBTC5M'},timeout=10); print(r.status_code,len(r.json().get('markets',[]))); [print(m.get('ticker'),m.get('yes_ask_dollars')) for m in r.json().get('markets',[])[:5]]"
git remote -v
curl -s https://api.github.com | head -5
git remote add origin https://YOURUSERNAME:YOUR_TOKEN@github.com/YOURUSERNAME/Openclaw.git
git remote add origin https://KeiserSoze222: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@github.com/KeiserSoze222/Openclaw.git
git remote set-url origin https://KeiserSoze222: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@github.com/KeiserSoze222/Openclaw.git
git push -u origin main
git push -u origin master
curl -H "Authorization: token YOUR_TOKEN" -H "Accept: application/vnd.github.v3.raw" https://api.github.com/repos/KeiserSoze222/Openclaw/contents/arb_scanner.py -o /root/arb_scanner_test.py 2>&1 | head -5
curl -s https://raw.githubusercontent.com/KeiserSoze222/Openclaw/master/arb_scanner.py 2>&1 | head -3
pm2 start /root/arb_scanner.py --name arb-scanner --interpreter python3
curl -H "Authorization: token YOUR_TOKEN" -H "Accept: application/vnd.github.v3.raw" -L "https://api.github.com/repos/KeiserSoze222/Openclaw/contents/arb_scanner.py" -o /tmp/arb_check.txt && cat /tmp/arb_check.txt | head -5
python3 -c "open('/root/arb_scanner.py','w').write(open('/root/bond_scanner_backup.py').read().split('# ── MAIN LOOP')[0])"
python3 -c "
 s='import requests,time,datetime,json,os,tempfile\nraw=open(\"/root/real_bot_pre_v4_backup.py\").read()\nKEY=raw.split(\"KALSHI_API_KEY = \x27\")[1].split(\"\x27\")[0]\nSEC=raw.split(\"KALSHI_SECRET  = \x27\x27\x27\")[1].split(\"\x27\x27\x27\")[0]\nTOK=raw.split(\"BOT_TOKEN = \x27\")[1].split(\"\x27\")[0]\nCID=raw.split(\"CHAT_ID   = \x27\")[1].split(\"\x27\")[0]\nLOG,MIN_M,MAX_M,MAXC,MINP,SLP=\"/root/arb_log.json\",5,45,10.0,2.0,120\nplaced=set()\ntf=tempfile.NamedTemporaryFile(delete=False,suffix=\".pem\",mode=\"w\")\ntf.write(SEC);tf.close()\nfrom kalshi_python import KalshiClient\nfrom kalshi_python.configuration import Configuration\ncfg=Configuration();cfg.host=\"https://api.elections.kalshi.com/trade-api/v2\"\nk=KalshiClient(cfg);k.set_kalshi_auth(KEY,tf.name)\ndef H(m,u): return k.kalshi_auth.create_auth_headers(m,u)\ndef tg(msg):\n    try: requests.get(\"https://api.telegram.org/bot\"+TOK+\"/sendMessage\",params={\"chat_id\":CID,\"text\":msg},timeout=5)\n    except: pass\ndef bal():\n    url=\"https://api.elections.kalshi.com/trade-api/v2/portfolio/balance\"\n    r=requests.get(url,headers=H(\"GET\",url),timeout=5)\n    if r.status_code==200:\n        d=r.json();return (d.get(\"balance\",0)+d.get(\"portfolio_value\",0))/100\n    return 0\ndef scan():\n    url=\"https://api.elections.kalshi.com/trade-api/v2/markets\"\n    arbs=[];cursor=\"\"\n    while True:\n        p={\"status\":\"open\",\"limit\":100}\n        if cursor: p[\"cursor\"]=cursor\n        r=requests.get(url,headers=H(\"GET\",url),params=p,timeout=10)\n        if r.status_code!=200: break\n        d=r.json()\n        for m in d.get(\"markets\",[]):\n            tk=m.get(\"ticker\",\"\");ya=m.get(\"yes_ask_dollars\");na=m.get(\"no_ask_dollars\")\n            ct=m.get(\"close_time\") or m.get(\"expiration_time\");vol=m.get(\"volume\",0) or 0\n            if not ya or not na or not ct or tk in placed or vol<1000: continue\n            yp=float(ya);np2=float(na);cb=yp+np2\n            if cb>=0.97 or cb<=0.50: continue\n            try:\n                cd=datetime.datetime.fromisoformat(ct.replace(\"Z\",\"+00:00\"))\n                ml=(cd-datetime.datetime.now(datetime.timezone.utc)).total_seconds()/60\n            except: continue\n            if ml<MIN_M or ml>MAX_M: continue\n            net=(1.0-cb)*0.93;pct=(net/cb)*100\n            if pct<MINP: continue\n            arbs.append({\"tk\":tk,\"yp\":yp,\"np\":np2,\"cb\":cb,\"pct\":pct,\"ml\":ml})\n        cursor=d.get(\"cursor\",\"\")\n        if not cursor: break\n    return sorted(arbs,key=lambda x:x[\"pct\"],reverse=True)\ndef go(arb):\n    tk=arb[\"tk\"];yp=arb[\"yp\"];np2=arb[\"np\"]\n    n=max(1,int(MAXC/arb[\"cb\"]))\n    yc=min(99,max(1,round(yp*100)+1));nc=min(99,max(1,round(np2*100)+1))\n    try:\n        k.create_order(ticker=tk,action=\"buy\",side=\"yes\",type=\"market\",count=n,yes_price=yc,time_in_force=\"ioc\")\n        k.create_order(ticker=tk,action=\"buy\",side=\"no\",type=\"market\",count=n,no_price=nc,time_in_force=\"ioc\")\n        placed.add(tk)\n        cost=n*arb[\"cb\"];profit=n*(1.0-arb[\"cb\"])\n        msg=\"ARB \"+tk+\" \"+str(round(yp,3))+\"+\"+str(round(np2,3))+\"=\"+str(round(arb[\"cb\"],3))+\" x\"+str(n)+\" $\"+str(round(cost,2))+\" pft $\"+str(round(profit,2))+\" (\"+str(round(arb[\"pct\"],1))+\"%)\"\n        print(msg);tg(msg)\n        with open(LOG,\"a\") as f: f.write(json.dumps({\"ts\":datetime.datetime.now().isoformat(),\"tk\":tk,\"cb\":arb[\"cb\"],\"n\":n,\"cost\":cost,\"profit\":profit})+\"\\n\")\n    except Exception as e: print(\"[Arb] \"+str(e))\nprint(\"Arb scanner started\");tg(\"Arb scanner started\")\nwhile True:\n    if os.path.exists(\"/root/STOP_ARB\"): break\n    try:\n        arbs=scan();b=bal()\n        print(\"[\"+datetime.datetime.now().strftime(\"%H:%M\")+\"] \"+str(len(arbs))+\" arbs | $\"+str(round(b,2)))\n        if arbs: print(\"  TOP: \"+arbs[0][\"tk\"]+\" cb=\"+str(round(arbs[0][\"cb\"],3))+\" \"+str(round(arbs[0][\"pct\"],1))+\"%\")\n        for arb in arbs[:2]: go(arb)\n    except Exception as e: print(\"[Arb] \"+str(e))\n    time.sleep(SLP)\n'
 open('/root/arb_scanner.py','w').write(s)
 print('written')
 " && python3 -m py_compile /root/arb_scanner.py && echo "OK"
git config --global credential.helper store
git remote set-url origin https://KeiserSoze222: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@github.com/KeiserSoze222/Openclaw.git
python3 -c "import base64; open('/root/arb_scanner.py','wb').write(base64.b64decode('aW1wb3J0IHJlcXVlc3RzLHRpbWUsZGF0ZXRpbWUsdGltZSxqc29uLG9zLHRlbXBmaWxlCnJhdz1vcGVuKCcvcm9vdC9yZWFsX2JvdF9wcmVfdjRfYmFja3VwLnB5JykucmVhZCgpCktFWT1yYXcuc3BsaXQoIktBTFNISV9BUElfS0VZID0gJyIpWzFdLnNwbGl0KCInIilbMF0KU0VDPXJhdy5zcGxpdCgiS0FMU0hJX1NFQ1JFVCB9ID0gJycnIilbMV0uc3BsaXQoIicnJyIpWzBd'))"
git config --global credential.helper store
git pull
sed -i "s/KALSHI_SECRET } = '''/KALSHI_SECRET  = '''/" /root/arb_scanner.py
git checkout arb_scanner.py
sed -i "s/KALSHI_SECRET } = '''/KALSHI_SECRET  = '''/" /root/arb_scanner.py
SEC=raw.split("KALSHI_SECRET } = '''")[1].split("'''")[0]
sed -i 's/\xe2\x80\x9c/"/g; s/\xe2\x80\x9d/"/g; s/\xe2\x80\x98/'"'"'/g; s/\xe2\x80\x99/'"'"'/g' /root/arb_scanner.py
sed -n '25,30p' /root/arb_scanner.py
sed -i 's/^return k.kalshi_auth/    return k.kalshi_auth/' /root/arb_scanner.py 
sed -n '28,45p' /root/arb_scanner.py
python3 -c "
 b=open('/root/bond_scanner_backup.py').read()
 creds=b.split('def send_telegram')[0]
 arb=creds+'def tg(m):\n    try: requests.get(\"https://api.telegram.org/bot\"+BOT_TOKEN+\"/sendMessage\",params={\"chat_id\":CHAT_ID,\"text\":m},timeout=5)\n    except: pass\nprint(\"Arb scanner started\")\ntg(\"Arb scanner started\")\n'
 open('/root/arb_scanner.py','w').write(arb)
 print('done')
 " && python3 -m py_compile /root/arb_scanner.py && echo "OK"
pm2 stop arb-scanner
source kalshi_env/bin/activate
python3 /tmp/status_all.py
wc -l /root/openclaw.py
sed -n '405,435p' /root/openclaw.py
sed -n '890,965p' /root/openclaw.py
sed -n '845,890p' /root/openclaw.py
grep -n "ARB_THRESHOLD" /root/openclaw.py | head -10
grep -n "simulate_trade\|try_arb\|try_directional" /root/openclaw.py | head -20 
sed -n '1,92p' /root/openclaw.py
sed -i 's/ARB_THRESHOLD=0.97/ARB_THRESHOLD=0.50/' /root/openclaw.py
sed -i 's/INITIAL_BALANCE=200.29/INITIAL_BALANCE=295.66/' /root/openclaw.py
python3 -m py_compile /root/openclaw.py && echo "OK"
pip install ruff vulture --break-system-packages
ruff check /root/openclaw.py
vulture /root/openclaw.py
sed -i 's/session_start_time=time.time()//' /root/openclaw.py
sed -i 's/ticker,market_data=update_live_ticker()/ticker,_=update_live_ticker()/' /root/openclaw.py
ruff check /root/openclaw.py --select F541,F841 --fix
sed -i 's/no_price=min(99,max(1,round((mkt_no or 0.50)\*100)+2)) if side=="no" else None/_=None/' /root/openclaw.py
python3 -c "open('/root/.gitignore','w').write('kalshi_env/\n.cache/\n__pycache__/\n*.pyc\n.pm2/logs/\n.pm2/pids/\n*.pid\n')" 
ruff check /root/openclaw.py
ruff check /root/openclaw.py --fix 
python3 -c "content=open('/root/.gitignore').read(); open('/root/.gitignore','w').write(content+'*.log\narena_state.json\nbond_log.json\narb_log.json\nfeature_log.json\nperformance_log.json\neth_performance_log.json\nsol_performance_log.json\n')"
python3 -c "content=open('/root/.gitignore').read(); open('/root/.gitignore','w').write(content+'.pm2/logs/\n__pycache__/\ngenome.json\nbond_scanner.log\narena_state.json\n')"
git rm -r --cached .pm2/logs/ __pycache__/ arena_state.json bond_scanner.log genome.json 2>/dev/null; echo "done"
python3 -m py_compile /root/openclaw.py && echo "openclaw OK"
python3 -m py_compile /root/openclaw.py
python3 -c "bal=295.66; print('Normal bet: $'+str(round(bal*0.07,2))); print('Peak bet: $'+str(round(bal*0.10,2))); print('ETH bet: $'+str(round(bal*0.09,2))); print('SOL bet: $'+str(round(bal*0.05,2)))"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':100},timeout=8); pos=r.json().get('market_positions',[]); active=[p for p in pos if float(p.get('market_exposure_dollars',0))>0]; print(str(len(active))+' open positions'); [print(p.get('ticker'),p.get('market_exposure_dollars')) for p in active]"
python3 -c "import csv,collections; rows=list(csv.DictReader(open('/root/trade_log.csv'))); wins_by_hour=collections.defaultdict(int); loss_by_hour=collections.defaultdict(int); [wins_by_hour[r.get('hour','?')].__class__ or None for r in rows]; hours={}; [hours.update({r.get('hour','?'): hours.get(r.get('hour','?'), {'w':0,'l':0})}) for r in rows]; [hours[r.get('hour','?')].update({'w':hours[r.get('hour','?')]['w']+1}) if r.get('result','')=='win' else hours[r.get('hour','?')].update({'l':hours[r.get('hour','?')]['l']+1}) for r in rows]; [print('H'+str(h).zfill(2)+' '+str(v['w'])+'W/'+str(v['l'])+'L '+str(round(v['w']/(v['w']+v['l'])*100))+'% ('+str(v['w']+v['l'])+'T)') for h,v in sorted(hours.items()) if v['w']+v['l']>0]"
python3 -c "import csv,collections; hours={}; [hours.update({r.get('hour','?'): hours.get(r.get('hour','?'), {'w':0,'l':0})}) for r in csv.DictReader(open('/root/eth_trade_log.csv'))]; [hours[r.get('hour','?')].update({'w':hours[r.get('hour','?')]['w']+1}) if r.get('result','')=='win' else hours[r.get('hour','?')].update({'l':hours[r.get('hour','?')]['l']+1}) for r in csv.DictReader(open('/root/eth_trade_log.csv'))]; [print('H'+str(h).zfill(2)+' '+str(v['w'])+'W/'+str(v['l'])+'L '+str(round(v['w']/(v['w']+v['l'])*100))+'% ('+str(v['w']+v['l'])+'T)') for h,v in sorted(hours.items()) if v['w']+v['l']>0]"
head -1 /root/trade_log.csv
head -3 /root/trade_log.csv 
grep -v "PLACED" /root/trade_log.csv | head -10
wc -l /root/trade_log.csv
head -5 /root/performance_log.json 
python3 -c "import json; data=json.load(open('/root/performance_log.json')); print(type(data)); print(str(data)[:500])"
python3 -c "import json; hours={}; [hours.update({r['timestamp'][11:13]: hours.get(r['timestamp'][11:13],{'w':0,'l':0})}) or (hours[r['timestamp'][11:13]].update({'w':hours[r['timestamp'][11:13]]['w']+1}) if r.get('action')=='WIN' else hours[r['timestamp'][11:13]].update({'l':hours[r['timestamp'][11:13]]['l']+1})) for line in open('/root/performance_log.json') for r in [json.loads(line.strip()
python3 -c "import json; d=[json.loads(l) for l in open('/root/performance_log.json') if l.strip()]; wins=[r for r in d if r.get('action')=='WIN']; losses=[r for r in d if r.get('action')=='LOSS']; print(str(len(wins))+'W '+str(len(losses))+'L total')"
python3 -c "import json; d=[json.loads(l) for l in open('/root/performance_log.json') if l.strip() and json.loads(l.strip()).get('action') in ('WIN','LOSS')]; h={}; [(h.setdefault(r['timestamp'][11:13],{'w':0,'l':0}), h[r['timestamp'][11:13]].__setitem__('w',h[r['timestamp'][11:13]]['w']+1) if r['action']=='WIN' else h[r['timestamp'][11:13]].__setitem__('l',h[r['timestamp'][11:13]]['l']+1)) for r in d]; print([(k,v) for k,v in sorted(h.items())])"
grep "5:0.00" /root/openclaw.py 
pm2 start openclaw-btc openclaw-eth openclaw-sol
pm2 logs openclaw-btc --lines 15 --nostream | grep -v "DeprecationWarning\|datetime.utcnow\|signal=
git add -A && git commit -m "System live - bots restarted with clean codebase, balance 295.66" && git push
source kalshi_env/bin/activate
python3 /tmp/status_all.py
grep -n "768\|mobile\|flex-wrap\|hbtns\|hbtn\|#hdr" /root/arena_dashboard.html | head -20
sed -i 's/@media(max-width:768px){#lower{grid-template-columns:1fr}#pl,#pr{border:none;border-bottom:1px solid var(--border)}#bfw{height:52vw;min-height:240px}.tb{max-width:90px;font-size:7px}.sc{min-width:160px}}/@media(max-width:768px){#lower{grid-template-columns:1fr}#pl,#pr{border:none;border-bottom:1px solid var(--border)}#bfw{height:70vw;min-height:320px}.tb{max-width:90px;font-size:7px}.sc{min-width:140px}#hdr{height:auto;padding:8px 10px;flex-direction:column;align-items:flex-start;gap:6px}.hc{width:100%;justify-content:space-between}.hbtns{width:100%;display:grid;grid-template-columns:1fr 1fr;gap:4px}.hbtn{text-align:center;font-size:7px;padding:6px 4px}.logo-t{font-size:16px}.logo-s{display:none}}/' /root/arena_dashboard.html
python3 -m py_compile /root/arena_dashboard.html 2>/dev/null; grep -c "768" /root/arena_dashboard.html 
grep -n "getTgt\|getTarget\|domination\|0.38\|0.57\|0.78\|0.62" /root/arena_dashboard.html | head -15
python3 -c "
 c=open('/root/arena_dashboard.html').read()
 old='function getTgt(bot){var w=document.getElementById(\'bfw\');if(wc -l /root/trade_log.csv)return {x:200,y:200};var W=w.offsetWidth,H=w.offsetHeight,wr=bot.wr||0,t=bot.trades||0,idx=parseInt(bot.id.replace(\'v\',\'\'))||1;if(t===0){var g=GR[bot.id]||{x:.1+((idx-1)%4)*.25,y:.2+Math.floor((idx-1)/4)*.3};return {x:g.x*W,y:g.y*H};}var x=(0.38+wr*.57)*W,y=(0.78-Math.min(t,300)/300*.62)*H,jit=((idx*7)%11-5)*.038;return {x:x,y:Math.max(.1*H,Math.min(.9*H,y+jit*H)));}'
 new='function getTgt(bot){var w=document.getElementById(\'bfw\');if(wc -l /root/trade_log.csv)return {x:200,y:200};var W=w.offsetWidth,H=w.offsetHeight,wr=bot.wr||0,t=bot.trades||0,idx=parseInt(bot.id.replace(\'v\',\'\'))||1;var mktOff={btc:0,eth:.28,sol:.56};var mktBase=mktOff[bot.market]||0;if(t===0){var g=GR[bot.id]||{x:.08+(mktBase)+((idx-1)%4)*.18,y:.25+Math.floor((idx-1)/4)*.22};return {x:Math.min(.88*W,g.x*W),y:Math.max(.15*H,Math.min(.82*H,g.y*H))};}var xBase=.12+(mktBase*.9);var xWr=wr*.52;var x=(xBase+xWr)*W;var jitX=((idx*13)%17-8)*.025;var yBase=.75;var yTrades=Math.min(t,500)/500*.52;var y=(yBase-yTrades)*H;var jitY=((idx*7)%11-5)*.04;x=Math.max(.08*W,Math.min(.88*W,x+jitX*W));y=Math.max(.15*H,Math.min(.82*H,y+jitY*H));return {x:x,y:y};}'
 print('found' if old in c else 'NOT FOUND')
 "
python3 -c "c=open('/root/arena_dashboard.html').read(); start=c.find('function getTgt'); end=c.find('}',c.find('return {x:x,y:y',start))+1; print(repr(c[start:end]))"
python3 -c "c=open('/root/arena_dashboard.html').read(); start=c.find('function getTgt'); print('getTgt at:',start); start2=c.find('0.38+wr'); print('0.38+wr at:',start2); start3=c.find('.57)*W'); print('.57)*W at:',start3)"
python3 -c "c=open('/root/arena_dashboard.html').read(); start=c.find('function getTgt'); end=c.find(';}',start)+2; print(repr(c[start:end]))"
python3 -c "
 c=open('/root/arena_dashboard.html').read()
 old=\"function getTgt(bot){var w=document.getElementById('bfw');if(wc -l /root/trade_log.csv)return {x:200,y:200};var W=w.offsetWidth,H=w.offsetHeight,wr=bot.wr||0,t=bot.trades||0,idx=parseInt(bot.id.replace('v',''))||1;if(t===0){var g=GR[bot.id]||{x:.1+((idx-1)%4)*.25,y:.2+Math.floor((idx-1)/4)*.3};return {x:g.x*W,y:g.y*H};}\"
 new=\"function getTgt(bot){var w=document.getElementById('bfw');if(wc -l /root/trade_log.csv)return {x:200,y:200};var W=w.offsetWidth,H=w.offsetHeight,wr=bot.wr||0,t=bot.trades||0,idx=parseInt(bot.id.replace('v',''))||1;var mktOff={btc:0,eth:.28,sol:.56};var mktBase=mktOff[bot.market]||0;if(t===0){var g=GR[bot.id]||{x:.08+mktBase+((idx-1)%4)*.18,y:.25+Math.floor((idx-1)/4)*.22};return {x:Math.min(.88*W,g.x*W),y:Math.max(.15*H,Math.min(.82*H,g.y*H))};};\"
 print('found' if old in c else 'NOT FOUND')
 open('/root/arena_dashboard.html','w').write(c.replace(old,new))
 " && echo "done"
python3 -c "c=open('/root/arena_dashboard.html').read(); old=\"function getTgt(bot){var w=document.getElementById('bfw');if(wc -l /root/trade_log.csv)return {x:200,y:200};var W=w.offsetWidth,H=w.offsetHeight,wr=bot.wr||0,t=bot.trades||0,idx=parseInt(bot.id.replace('v',''))||1;if(t===0){var g=GR[bot.id]||{x:.1+((idx-1)%4)*.25,y:.2+Math.floor((idx-1)/4)*.3};return {x:g.x*W,y:g.y*H};}\"; new=\"function getTgt(bot){var w=document.getElementById('bfw');if(wc -l /root/trade_log.csv)return {x:200,y:200};var W=w.offsetWidth,H=w.offsetHeight,wr=bot.wr||0,t=bot.trades||0,idx=parseInt(bot.id.replace('v',''))||1;var mo={btc:0,eth:.28,sol:.56};var mb=mo[bot.market]||0;if(t===0){var g=GR[bot.id]||{x:.08+mb+((idx-1)%4)*.18,y:.25+Math.floor((idx-1)/4)*.22};return {x:Math.min(.88*W,g.x*W),y:Math.max(.15*H,Math.min(.82*H,g.y*H))};};\"; print('found' if old in c else 'NOT FOUND'); open('/root/arena_dashboard.html','w').write(c.replace(old,new))"
set +H 
python3 -c "c=open('/root/arena_dashboard.html').read(); old=\"var x=(0.38+wr*.57)*W,y=(0.78-Math.min(t,300)/300*.62)*H,jit=((idx*7)%11-5)*.038;return {x:x,y:Math.max(.1*H,Math.min(.9*H,y+jit*H))};\"; new=\"var xBase=.12+(mb*.9);var x=(xBase+wr*.52)*W;var jitX=((idx*13)%17-8)*.025;var yBase=.75;var y=(yBase-Math.min(t,500)/500*.52)*H;var jitY=((idx*7)%11-5)*.04;x=Math.max(.08*W,Math.min(.88*W,x+jitX*W));y=Math.max(.15*H,Math.min(.82*H,y+jitY*H));return {x:x,y:y};\"; print('found' if old in c else 'NOT FOUND'); open('/root/arena_dashboard.html','w').write(c.replace(old,new))"
pm2 restart dashboard && git add -A && git commit -m "Battlefield: fix bot clustering, spread by market, boundary clamping" && git push
echo "set +H" >> /root/.bashrc
pm2 logs dashboard --lines 10 --nostream | grep -v "DeprecationWarning\|datetime"
grep -n "connecting\|Connecting\|connect" /root/dashboard_v4.py | head -10
grep -n "connecting\|Connecting\|fetchData\|fetch(" /root/dashboard_v4.py | head -10
grep -n "connect\|fetch\|websocket\|polling" /root/arena_dashboard.html | head -10
python3 -c "c=open('/root/arena_dashboard.html').read(); old='.tb{max-width:90px;font-size:7px}.sc{min-width:140px}'; new='.tb{max-width:75px;font-size:6px}.sc{min-width:130px}.bpfp{transform:scale(0.75)}.btag{display:none}'; print('found' if old in c else 'NOT FOUND'); open('/root/arena_dashboard.html','w').write(c.replace(old,new))"
grep -n "connecting\|Connecting" /root/dashboard_v4.py | head -10
python3 -c "import http.client; c=http.client.HTTPConnection('167.172.244.100',8080); c.request('GET','/'); r=c.getresponse(); print(r.status,r.reason)"
sed -n '1,50p' /root/dashboard_v4.py
h = kalshi.kalshi_auth.create_auth_headers("GET", url) headers=h, params={"limit":10}, timeout=6)
sed -n '30,36p' /root/dashboard_v4.py
grep -n "connecting\|Connecting\|fetch\|status" /root/dashboard_v4.py | grep -i "connect\|fetch" | head -15
wc -l /root/dashboard_v4.py
sed -n '100,136p' /root/dashboard_v4.py
wc -l /root/dashboard_v4.html
sed -n '88,130p' /root/dashboard_v4.html
sed -n '10,20p' /root/dashboard_v4.html
python3 -c "import urllib.request; r=urllib.request.urlopen('http://167.172.244.100:8080/api/data',timeout=5); print(r.read()[:200].decode())"
sed -n '85,98p' /root/dashboard_v4.html
python3 -c "c=open('/root/dashboard_v4.html').read(); old='.header{padding:10px 12px;}'; new='.header{padding:8px 10px;flex-wrap:wrap;gap:6px;height:auto;}.header-right{gap:6px;flex-wrap:wrap;}.bible-btn{font-size:8px;padding:4px 7px;}.utc-time{font-size:9px;}.logo-text{font-size:12px;}'; print('found' if old in c else 'NOT FOUND'); open('/root/dashboard_v4.html','w').write(c.replace(old,new))"
sed -n '130,160p' /root/dashboard_v4.html
python3 -c "c=open('/root/dashboard_v4.html').read(); old='</div>\`;  div>\`;}'; new='</div>\`;}'; print('found' if old in c else 'NOT FOUND'); open('/root/dashboard_v4.html','w').write(c.replace(old,new))"
python3 -c "c=open('/root/dashboard_v4.html').read(); idx=c.find('div>\`;}'); print(repr(c[idx-20:idx+20]))"
python3 -c "c=open('/root/dashboard_v4.html').read(); idx=c.find('wr-fill'); print(repr(c[idx:idx+100]))"
python3 -c "c=open('/root/dashboard_v4.html').read(); idx=c.find('wr-bar'); start=c.rfind('wr-bar',0,c.rfind('wr-bar')); print(repr(c[start:start+200]))"
python3 -c "c=open('/root/dashboard_v4.html').read(); lines=c.split('\n'); [print(i+1,repr(lines[i])) for i in range(155,165)]"
python3 -c "c=open('/root/dashboard_v4.html').read(); idx=c.find('ft=d.features'); print(repr(c[idx:idx+200]))"
python3 -c "c=open('/root/dashboard_v4.html').read(); idx=c.find('const bal='); print(repr(c[idx:idx+300]))"
python3 -c "c=open('/root/dashboard_v4.html').read(); old='const bal=d.balance,s=d.stats,pr=d.procs,tr=d.trades,wh=d.whales,pos=d.positions,ft=d.features,ins=d.insights,hw=d.hourly;'; new='const bal=d.balance,s=d.stats,pr=d.procs,tr=d.trades,wh=d.whales,pos=d.positions,ft=d.features||{},ins=d.insights||[],hw=d.hourly||{};'; print('found' if old in c​​​​​​​​​​​​​​​​
python3 -c "c=open('/root/dashboard_v4.html').read(); [print(i+1,repr(l)) for i,l in enumerate(c.split('\n')) if 'ft.' in l or 'ins.' in l or 'hw.' in l or ' ft ' in l or ' ins ' in l]"
python3 -c "c=open('/root/dashboard_v4.html').read(); c=c.replace('ft=d.features,ins=d.insights,hw=d.hourly','ft=d.features||[],ins=d.insights||[],hw=d.hourly||{}'); open('/root/dashboard_v4.html','w').write(c); print('done')"
pm2 restart dashboard && git add -A && git commit -m "Fix Safari crash: undefined features/insights/hourly fields, mobile header" && git push
source kalshi_env/bin/activate
grep -i "sol\|cash\|CASH\|profit_lock\|breakeven" /root/performance_log.json | tail -30
tail -50 /root/sol_trade_log.csv
pm2 logs openclaw-sol --lines 50 --nostream | grep -v "DeprecationWarning\|datetime\|signal="
sed -n '620,844p' /root/openclaw.py | grep -n "cash\|CASH\|Cash\|profit_lock\|ProfitLock\|breakeven\|sell\|place_order\|adverse" | head -30
grep -n "CASHOUT\|cashout\|cash_out\|CashOut" /root/openclaw.py | head -20
sed -n '725,775p' /root/openclaw.py
sell_side = "no" if direction=="UP" else "yes". contracts = pos.get("contracts", max(1,int(pos.get("bet",2)/0.50)))
sed -i 's/sell_side = "no" if direction=="UP" else "yes". contracts/sell_side = "no" if direction=="UP" else "yes"\n                                contracts/' /root/openclaw.py
sed -n '746,752p' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol
pm2 logs openclaw-btc --lines 20 --nostream | grep -v "DeprecationWarning\|datetime\|signal="
sed -n '650,730p' /root/openclaw.py | grep -n "\. " | head -10
grep -n "sell_side.*\. " /root/openclaw.py
grep -n "contracts" /root/openclaw.py | head -20
sed -n '670,678p' /root/openclaw.py
sed -n '701,709p' /root/openclaw.py
grep -n "entry_yes" /root/openclaw.py | head -15
grep -n "CASHOUT_MINUTES\|CASHOUT_ADVERSE\|CASHOUT" /root/openclaw.py | head -5
sed -i 's/CASHOUT_MINUTES=3/CASHOUT_MINUTES=2/' /root/openclaw.py
sed -n '740,745p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='                    if status in (\"open\",\"active\"):\n                        adverse=((entry_yes-cur_yes) if direction==\"UP\" else (cur_yes-(1-entry_yes)))\n                        if adverse>CASHOUT_ADVERSE:'; new='                    if status in (\"open\",\"active\"):\n                        adverse=((entry_yes-cur_yes) if direction==\"UP\" else (cur_yes-(1-entry_yes)))\n                        hard_floor=(direction==\"UP\" and cur_yes<0.10) or (direction==\"DOWN\" and cur_yes>0.90)\n                        if adverse>CASHOUT_ADVERSE or hard_floor:'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
source kalshi_env/bin/activate
python3 /tmp/status_all.py
pm2 logs openclaw-btc --lines 50 --nostream | grep -E "CashOut|ProfitLock|BreakEven|WIN|LOSS|Positions"
pm2 logs openclaw-btc --lines 30 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" 
grep -n "between\|No signal\|DIRECTIONAL" /root/openclaw.py | head -10
sed -n '920,930p' /root/openclaw.py
sed -n '418,442p' /root/openclaw.py
sed -n '490,530p' /root/openclaw.py 
sed -n '530,570p' /root/openclaw.py
sed -i 's/if window_minute==0 or window_minute>4 or window_minute>=13:/if window_minute==0 or window_minute>=13:/' /root/openclaw.py
sed -n '558,566p' /root/openclaw.py
python3 -m py_compile /root/openclaw.py && echo "OK"
sed -n '520,526p' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
pm2 logs openclaw-btc --lines 15 --nostream | grep -v "DeprecationWarning\|datetime\|signal="
grep -n "\. " /root/openclaw.py | grep -v "#\|print\|url\|http\|fmt\|pct\|str\|int\|float\|round\|json\|csv\|os\." | head -20 
grep -n "except.*pass\|except:$" /root/openclaw.py | head -20
grep -n "if.*and.*and.*and" /root/openclaw.py | head -10
grep -n "consecutive_signal\|last_signal_direction\|COOLDOWN" /root/openclaw.py | head -15
sed -n '458,492p' /root/openclaw.py
sed -n '385,415p' /root/openclaw.py
sed -n '530,545p' /root/openclaw.py
grep -n "RISK_SCORE" /root/openclaw.py | head -10
sed -n '542,555p' /root/openclaw.py
grep "Regime:" /root/.pm2/logs/openclaw-btc-out.log | tail -20 | awk -F'Regime: ' '{print $2}' | awk '{print $1}' | sort | uniq -c
sed -n '216,230p' /root/openclaw.py
sed -n '228,240p' /root/openclaw.py
sed -i 's/REGIME,RISK_SCORE="CHOP",0.35/REGIME,RISK_SCORE="CHOP",0.60/' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
python3 -c "bal=301.94; max_bet=bal*0.07; scale=0.57; risk=0.60; bet=max_bet*scale*risk; print('Typical bet: $'+str(round(bet,2))); print('Peak bet: $'+str(round(max_bet,2))); print('Min after floor: $2.00')"
sed -n '271,310p' /root/openclaw.py
grep -n "double_down\|DOUBLE\|dd_bet" /root/openclaw.py | head -10
grep -n "SESSION_START_BAL" /root/openclaw.py | head -10
sed -n '940,962p' /root/openclaw.py
grep -n "DAILY_LOSS_LIMIT" /root/openclaw.py
sed -n '780,845p' /root/openclaw.py
python3 -c "
 c=open('/root/openclaw.py').read()
 old='            contracts=max(1,int(bet/0.50))\n            realized=round(contracts*1.0-bet,2) if won else -bet'
 new='            entry_p=pos.get(\"entry_yes\",0.5) if direction==\"UP\" else (1-pos.get(\"entry_yes\",0.5))\n            contracts=max(1,int(bet/entry_p))\n            realized=round(contracts*1.0-bet,2) if won else -bet'
 print('found' if old in c else 'NOT FOUND')
 open('/root/openclaw.py','w').write(c.replace(old,new))
 " && python3 -m py_compile /root/openclaw.py && echo "OK"
python3 -c "c=open('/root/openclaw.py').read(); old='            contracts=max(1,int(bet/0.50))\n            realized=round(contracts*1.0-bet,2) if won else -bet'; new='            entry_p=pos.get(\"entry_yes\",0.5) if direction==\"UP\" else (1-pos.get(\"entry_yes\",0.5))\n            contracts=max(1,int(bet/entry_p))\n            realized=round(contracts*1.0-bet,2) if won else -bet'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
sed -n '108,132p' /root/openclaw.py
sed -n '93,108p' /root/openclaw
sed -i 's/return max(2.00,min(20.00,round(CURRENT_BALANCE\*pct\*tod_scale,2)))/return max(2.00,round(CURRENT_BALANCE*pct*tod_scale,2))/' /root/openclaw.py
grep "PEAK_BET_PCT\|MAX_BET_PCT" /root/openclaw.py | head -5
grep "_CONFIGS" /root/openclaw.py | head -5
grep -A 5 "_CONFIGS = {" /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save 
sed -n '605,625p' /root/openclaw.py
sed -n '635,675p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='                            contracts = pos.get(\"contracts\", max(1,int(pos.get(\"bet\",2)/0.50)))\n                            sell_p = min(99,max(1,round((1-cur_yes)*100))) if direction==\"UP\" else min(99,max(1,round(cur_yes*100)))\n                            sell_order = kalshi.create_order(\n                                ticker=ticker, action=\"sell\", side=sell_side,\n                                type=\"limit\", count=contracts,\n                                yes_price=max(1,sell_p-5) if sell_side==\"yes\" else None,\n                                no_price=max(1,sell_p-5) if sell_side==\"no\" else None,\n                                time_in_force=\"ioc\"\n                            )\n                            if sell_order and hasattr(sell_order,\"order\") and sell_order.order:\n                                o=sell_order.order\n                                print(f\"[ProfitLock] Sell order: {o.status}\")'; new='                            entry_p2=pos.get(\"entry_yes\",0.5) if direction==\"UP\" else (1-pos.get(\"entry_yes\",0.5))\n                            contracts = pos.get(\"contracts\", max(1,int(pos.get(\"bet\",2)/entry_p2)))\n                            sell_p = min(99,max(1,round((1-cur_yes)*100))) if direction==\"UP\" else min(99,max(1,round(cur_yes*100)))\n                            sell_order = kalshi.create_order(\n                                ticker=ticker, action=\"sell\", side=sell_side,\n                                type=\"limit\", count=contracts,\n                                yes_price=max(1,sell_p-5) if sell_side==\"yes\" else None,\n                                no_price=max(1,sell_p-5) if sell_side==\"no\" else None,\n                                time_in_force=\"ioc\"\n                            )\n                            if sell_order and hasattr(sell_order,\"order\") and sell_order.order:\n                                o=sell_order.order\n                                print(f\"[ProfitLock] Sell order: {o.status}\")'; print('PL found' if old in c else 'PL NOT FOUND'); c2=c.replace(old,new); open('/root/openclaw.py','w').write(c2)" && python3 -m py_compile /root/openclaw.py && echo "OK"
sed -n '670,675p' /root/openclaw.py
sed -i 's/                            contracts = pos.get("contracts", max(1,int(pos.get("bet",2)\/0.50)))/                            entry_p2=pos.get("entry_yes",0.5) if direction=="UP" else (1-pos.get("entry_yes",0.5))\n                            contracts = pos.get("contracts", max(1,int(pos.get("bet",2)\/entry_p2)))/' /root/openclaw.py
sed -i '752s/                            contracts/                                contracts/' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
grep -n "entry_p2\|contracts = pos" /root/openclaw.py
cat /root/.bashrc | grep "set +H"
source kalshi_env/bin/activate
python3 /tmp/status_all.py
sed -n '312,330p' /root/openclaw.py
sed -n '281,300p' /root/openclaw.py
sed -i 's/if len(recent) >= 2:/if len(recent) >= 1:/' /root/openclaw.py
sed -i 's/_t.time()-_os.path.getmtime(f) < 90/_t.time()-_os.path.getmtime(f) < 120/' /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
git add -A && git commit -m "Tighten correlation guard: only 1 bot fires per 120sec window - fix insufficient balance errors" && git push
pm2 logs openclaw-btc --lines 50 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | grep -E "BET|LOSS|WIN|CashOut|HardFloor|ProfitLock|Settled|81|82|106"
grep "12:0[0-9]\|LOSS\|WIN\|cashout\|CashOut" /root/performance_log.json | grep "2026-04-11" | tail -20
pm2 logs openclaw-sol --lines 3 --nostream | grep "Positions\|Session"
grep "81\|82\|83" /root/performance_log.json | grep "2026-04-11" | grep "PLACED\|WIN\|LOSS"
grep "2026-04-11 12" /root/trade_log.csv
grep "81\|82" /root/trade_log.csv | tail -10
sed -i 's/bet=max(2.00,round(bet,2))/bet=max(2.00,min(40.00,round(bet,2)))/' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
grep -n "log_trade.*PLACED\|PLACED.*log_trade" /root/openclaw.py | head -5
sed -n '395,410p' /root/openclaw.py
sed -n '353,365p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='        print(f\"[Order] {ticker} | {side} | count={contract_count} | \${bet:.2f}\")\n        yes_p=min(99,max(1,round((mkt_yes or 0.5)*100))) if side==\"yes\" else None'; new='        log_trade(direction,bet,\"ATTEMPTING\",notes=f\"{strategy_tag}|{ticker}\")\n        print(f\"[Order] {ticker} | {side} | count={contract_count} | \${bet:.2f}\")\n        yes_p=min(99,max(1,round((mkt_yes or 0.5)*100))) if side==\"yes\" else None'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
date -u
pm2 logs openclaw-eth --lines 5 --nostream | grep "Positions\|Session\|Settled\|WIN\|LOSS"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
source kalshi_env/bin/activate
python3 /tmp/status_all.py
sed -n '628,645p' /root/openclaw.py
grep -n "placed_at\|age_placed\|age_min" /root/openclaw.py | head -15
grep -n "hard_floor\|cur_yes<0.10\|cur_yes>0.90" /root/openclaw.py
sed -n '730,748p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='        if age_placed>=CASHOUT_MINUTES:'; new='        try:\n            _iurl=f\"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}\"\n            _ihr=kalshi.kalshi_auth.create_auth_headers(\"GET\",_iurl)\n            _imr=requests.get(_iurl,headers=_ihr,timeout=4)\n            if _imr.status_code==200:\n                _iya=_imr.json().get(\"market\",{}).get(\"yes_ask_dollars\")\n                if _iya is not None:\n                    _icy=float(_iya)\n                    _ifloor=(direction==\"UP\" and _icy<0.06) or (direction==\"DOWN\" and _icy>0.94)\n                    if _ifloor and age_placed>=0.5:\n                        print(f\"[HardFloor] {direction} on {ticker} YES={_icy:.2f}\")\n                        try:\n                            _ss=\"no\" if direction==\"UP\" else \"yes\"\n                            _ep=pos.get(\"entry_yes\",0.5) if direction==\"UP\" else (1-pos.get(\"entry_yes\",0.5))\n                            _nc=pos.get(\"contracts\",max(1,int(pos.get(\"bet\",2)/_ep)))\n                            _so=kalshi.create_order(ticker=ticker,action=\"sell\",side=_ss,type=\"market\",count=_nc,time_in_force=\"ioc\")\n                            send_telegram(f\"HardFloor: {direction} {ticker} YES={_icy:.2f}\")\n                            to_remove.append(pos);continue\n                        except Exception as _he: print(f\"[HardFloor] fail: {str(_he)}\")\n        except Exception: pass\n        if age_placed>=CASHOUT_MINUTES:'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
grep -n "remaining_count\|filled\|resting\|status.*executed\|executed" /root/openclaw.py | head -20
sed -n '340,395p' /root/openclaw.py
sed -i 's/return False\.  if any/return False\n    if any/' /root/openclaw.py
sed -i 's/contract_count=max(1,int(bet\/0.50))/contract_count=max(1,int(bet\/(mkt_yes or mkt_no or 0.50)))/' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
sed -n '395,415p' /root/openclaw.py
grep -n "False\.\|True\.\|None\." /root/openclaw.py | grep -v "#\|print\|url\|http\|\.2f\|\.0f\|\.1f\|\.2%\|split\|replace\|format\|join\|strip\|lower\|upper\|get\|append\|extend\|update\|write\|read\|close\|open\|json\|csv\|os\." | head -20
grep -n "0\.50\|0\.5)" /root/openclaw.py | grep -v "#\|print\|yes_price\|no_price\|0\.50\*\|entry\|cur_yes\|win_prob\|trend\|gap\|scale\|RISK\|TOD\|EXTREME\|CASHOUT\|ADVERSE" | head -15
grep -n "action.*sell\|sell.*action" /root/openclaw.py | head -10
sed -n '674,680p' /root/openclaw.py
sed -i '677s/                                type="limit", count=contracts,/                                type="market", count=contracts,/' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
sed -n '675,685p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='                                type=\"market\", count=contracts,\n                                yes_price=max(1,sell_p-5) if sell_side==\"yes\" else None,\n                                no_price=max(1,sell_p-5) if sell_side==\"no\" else None,\n                                time_in_force=\"ioc\"'; new='                                type=\"market\", count=contracts,\n                                time_in_force=\"ioc\"'; print(str(c.count(old))+' found'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
sed -n '773,782p' /root/openclaw.py
sed -n '769,776p' /root/openclaw.py
sed -i '772,774d' /root/openclaw.py
sed -i '771a\                                    type="market", count=contracts,' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
pm2 logs openclaw-btc --lines 15 --nostream | grep -v "DeprecationWarning\|datetime\|signal="
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':100},timeout=8); pos=[p for p in r.json().get('market_positions',[]) if float(p.get('market_exposure_dollars',0))>0]; print(str(len(pos))+' open positions'); [print(p.get('ticker'),p.get('market_exposure_dollars'),p.get('position')) for p in pos]"
sed -n '885,915p' /root/openclaw.py
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https​​​​​​​​​​​​​​​​
python3 -c "c=open('/root/openclaw.py').read(); old='            direction=\"UNKNOWN\"\n            try:\n                murl=f\"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}\"\n                mhdr=kalshi.kalshi_auth.create_auth_headers(\"GET\",murl)\n                mr=requests.get(murl,headers=mhdr,timeout=5)\n                if mr.status_code==200:\n                    last=float(mr.json().get(\"market\",{}).get(\"last_price_dollars\",0.5))\n                    direction=\"UP\" if last>=0.5 else \"DOWN\"\n            except Exception:\n                pass'; new='            pos_count=p.get(\"position\",0)\n            direction=\"UP\" if pos_count>0 else \"DOWN\" if pos_count<0 else \"UNKNOWN\"'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
grep -n "DAILY_LOSS_LIMIT\|Circuit breaker\|Daily loss" /root/openclaw.py
grep -n "to_remove\|OPEN_POSITIONS" /root/openclaw.py | head -20
ruff check /root/openclaw.py --select E,F --ignore E501,E401,E402,E701,E702 2>/dev/null | head -20
sed -i '769d' /root/openclaw.py
sed -i '704d' /root/openclaw.py
sed -i '674d' /root/openclaw.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
grep -n "send_telegram.*LOSS\|send_telegram.*loss\|send_telegram.*CashOut\|send_telegram.*cashout" /root/openclaw.py | head -10
f"{"✅" if won else "❌"}..."
sed -n '852,856p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='send_telegram(f\"{\"✅\" if won else \"❌\"} {BOT_NAME.split()[1]} {outcome}: {direction} \${bet:.2f} | pnl=\${realized:+.2f}\\\\n{session_wins}W/{session_losses}L ({wr:.0f}%) | Bal=\${CURRENT_BALANCE:.2f}\")'; print('found' if old in c else 'NOT FOUND')"
grep -n "✅.*if won" /root/openclaw.py
sed -i '854s/.*/            icon="✅" if won else "❌"\n            send_telegram(icon+" "+BOT_NAME.split()[1]+" "+outcome+": "+direction+" $"+str(round(bet,2))+" | pnl=$"+str(round(realized,2))+"\\n"+str(session_wins)+"W\/"+str(session_losses)+"L ("+str(round(wr,0))+"%) | Bal=$"+str(round(CURRENT_BALANCE,2)))/' /root/openclaw.py
grep -n "HardFloor.*send_telegram\|send_telegram.*HardFloor" /root/openclaw.py
pm2 logs openclaw-btc --lines 5 --nostream | grep -v "DeprecationWarning\|datetime\|signal="
date -u
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
date -u && pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session" && pm2 logs openclaw-eth --lines 3 --nostream | grep "Positions\|Session"
date -u && pm2 logs openclaw-btc --lines 5 --nostream | grep "Positions\|Session\|WIN\|LOSS\|Settled" && pm2 logs openclaw-eth --lines 5 --nostream | grep "Positions\|Session\|WIN\|LOSS\|Settled"
pm2 logs openclaw-btc --lines 5 --nostream | grep "Positions\|Session\|WIN\|LOSS\|Settled"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
grep -n "def evaluate\|wr\|score\|promote\|leaderboard" /root/arena.py | head -20
grep -n "def evaluate\|def auto_promote\|leaderboard\|wr\|score\|wins\|losses\|trades" /root/arena.py | head -25
wc -l /root/arena.py
sed -n '956,990p' /root/arena.py
python3 -c "c=open('/root/arena.py').read(); old='def auto_promote(pool):'; new='def risk_score(v):\n    t=v.get(\"trades\",0)\n    if t==0: return 0\n    wr=v.get(\"wins\",0)/t\n    import math\n    confidence=math.log(t+1)/math.log(100)\n    return round(wr*confidence,4)\n\ndef auto_promote(pool):'; print('found' if old in c else 'NOT FOUND'); open('/root/arena.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/arena.py && echo "OK"
python3 -c "c=open('/root/arena.py').read(); old='leader=max(candidates,key=lambda v:v.get(\"wins\",0)/v.get(\"trades\",1))'; new='leader=max(candidates,key=lambda v:risk_score(v))'; print('found' if old in c else 'NOT FOUND'); open('/root/arena.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/arena.py && echo "OK"
python3 -c "c=open('/root/arena.py').read(); old='\"leaderboard\":[{\"id\":v[\"id\"],\"market\":v[\"market\"],\"wr\":v[\"wins\"]/v[\"trades\"] if v[\"trades\"]>0 else 0,\"trades\":v[\"trades\"],\"pnl\":v[\"pnl\"],\"gen\":v[\"generation\"]} for v in pool]'; new='\"leaderboard\":[{\"id\":v[\"id\"],\"market\":v[\"market\"],\"wr\":v[\"wins\"]/v[\"trades\"] if v[\"trades\"]>0 else 0,\"trades\":v[\"trades\"],\"pnl\":v[\"pnl\"],\"gen\":v[\"generation\"],\"risk_score\":risk_score(v),\"wins\":v[\"wins\"],\"losses\":v[\"losses\"],\"entry_threshold\":v[\"entry_threshold\"],\"max_bet_pct\":v[\"max_bet_pct\"],\"chop_allowed\":v.get(\"chop_allowed\",False)} for v in pool]'; print('found' if old in c else 'NOT FOUND'); open('/root/arena.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/arena.py && echo "OK"
python3 -c "import json,math; pool=json.load(open('/root/genome.json')); [print(v['id'],v['market'],'trades='+str(v['trades']),'wr='+str(round(v['wins']/v['trades'],3) if v['trades']>0 else 0),'risk='+str(round((v['wins']/v['trades'] if v['trades']>0 else 0)*math.log(v['trades']+1)/math.log(100),4))) for v in sorted(pool,key=lambda x:-(x['wins']/x['trades'] if x['trades']>0 else 0)*math.log(x['trades']+1)/math.log(100))]"
pm2 restart arena
python3 -c "c=open('/root/arena.py').read(); old='def auto_promote(pool):'; new='import subprocess\ndef auto_promote(pool):'; print('found' if old in c else 'NOT FOUND'); open('/root/arena.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/arena.py && echo "OK"
pm2 logs arena --lines 8 --nostream
source kalshi_env/bin/activate
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session\|Balance"
python3 /tmp/status_all.py
pm2 stop openclaw-btc openclaw-eth openclaw-sol && pm2 save
tail -30 /root/performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0)) for l in sys.stdin if l.strip()]"
tail -30 /root/eth_performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0)) for l in sys.stdin if l.strip()]"
tail -30 /root/sol_performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0)) for l in sys.stdin if l.strip()]"
git log --oneline | head -10
git log --oneline | head -20
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':100},timeout=8); pos=[p for p in r.json().get('market_positions',[]) if float(p.get('market_exposure_dollars',0))>0]; print(str(len(pos))+' open positions'); [print(p.get('ticker'),p.get('market_exposure_dollars'),p.get('position')) for p in pos]"
git show 66820b3:openclaw.py > /root/openclaw_stable.py
diff /root/openclaw_stable.py /root/openclaw.py | head -80
grep "18:0[5-9]\|18:1[0-9]" /root/performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0),json.loads(l).get('notes','')) for l in sys.stdin if l.strip()]"
grep "18:0[5-9]\|18:1[0-9]" /root/eth_performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0),json.loads(l).get('notes','')) for l in sys.stdin if l.strip()]"
grep "18:0[5-9]\|18:1[0-9]" /root/sol_performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0),json.loads(l).get('notes','')) for l in sys.stdin if l.strip()]"
sed -i 's/bet=max(2.00,min(40.00,round(bet,2)))/bet=max(2.00,min(25.00,round(bet,2)))/' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='    # CORRELATION GUARD — prevent all 3 bots firing simultaneously\n    try:\n        import glob as _gl\n        import time as _t\n        import os as _os\n        lock_path = f\'/tmp/openclaw_firing_{MARKET_SERIES}.lock\'\n        locks = _gl.glob(\'/tmp/openclaw_firing_*.lock\')\n        recent = [f for f in locks if _t.time()-_os.path.getmtime(f) < 120]\n        if len(recent) >= 1:\n            print(f\"[CorrGuard] {len(recent)} bots already fired — skipping to avoid correlated loss\")\n            return False\n        open(lock_path, \'w\').write(str(_t.time()))\n    except Exception as _e:\n        print(f\"[CorrGuard] {_e}\")'; new='    # CORRELATION GUARD — atomic file lock prevents simultaneous firing\n    try:\n        import glob as _gl\n        import time as _t\n        import os as _os\n        lock_path = f\'/tmp/openclaw_firing_{MARKET_SERIES}.lock\'\n        master_lock = \'/tmp/openclaw_master.lock\'\n        # Atomic check-and-set using exclusive file creation\n        try:\n            fd = _os.open(master_lock, _os.O_CREAT|_os.O_EXCL|_os.O_WRONLY)\n            _os.write(fd, str(_t.time()).encode())\n            _os.close(fd)\n        except FileExistsError:\n            age = _t.time()-_os.path.getmtime(master_lock)\n            if age < 120:\n                print(f\"[CorrGuard] Master lock held ({age:.0f}s) — skipping\")\n                return False\n            _os.remove(master_lock)\n        open(lock_path, \'w\').write(str(_t.time()))\n    except Exception as _e:\n        print(f\"[CorrGuard] {_e}\")'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
rm -f /tmp/openclaw_*.lock /tmp/openclaw_master.lock
source kalshi_env/bin/activate
grep -n "bet" /root/arena.py | grep -v "#\|print\|pnl\|profit\|max_bet\|min_bet" | head -20
grep -n "DRY_RUN" /root/arena.py | head -5
pm2 stop arena && pm2 save
sed -i 's/DRY_RUN=False/DRY_RUN=True/' /root/arena.py
git add -A && git commit -m "CRITICAL: Set arena DRY_RUN=True - was placing real orders with 12 uncapped variants" && git push
python3 /tmp/status_all.py
ls -la /tmp/openclaw_master.lock 2>/dev/null || echo "no lock file"
pm2 stop openclaw-btc openclaw-eth openclaw-sol && pm2 save
sed -n '955,975p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='    load_existing_positions()\n    cancel_resting_orders()\n    print(\"[Startup] Resting orders cleared\")'; new='    # Staggered startup: ETH waits 45s, SOL waits 90s to prevent simultaneous firing\n    _startup_delay={\"btc\":0,\"eth\":45,\"sol\":90}.get(_args.market,0)\n    if _startup_delay>0:\n        print(f\"[Startup] Staggered delay {_startup_delay}s for {_args.market.upper()}\")\n        import time as _st; _st.sleep(_startup_delay)\n    load_existing_positions()\n    cancel_resting_orders()\n    print(\"[Startup] Resting orders cleared\")'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
pm2 logs openclaw-btc --lines 5 --nostream | grep "CorrGuard\|Balance\|fired"
python3 /tmp/status_all.py
grep "min(25" /root/openclaw.py
sed -n '615,625p' /root/openclaw.py
sed -n '100,110p' /root/openclaw.py
sed -i 's/return max(2.00,round(CURRENT_BALANCE\*pct\*tod_scale,2))/return max(2.00,min(22.00,round(CURRENT_BALANCE*pct*tod_scale,2)))/' /root/openclaw.py
sed -i 's/return max(2.00,min(22.00,round(CURRENT_BALANCE\*pct\*tod_scale,2)))/reserved=sum(p.get("bet",0) for p in OPEN_POSITIONS)\n    avail=max(0,CURRENT_BALANCE-reserved)\n    return max(2.00,min(22.00,round(avail*pct*tod_scale,2)))/' /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
pm2 restart openclaw-btc openclaw-eth openclaw-sol && pm2 save
date -u
pm2 stop openclaw-btc openclaw-eth openclaw-sol && pm2 save
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/balance'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); d=r.json(); print('Cash:',d.get('balance',0)/100); print('Portfolio:',d.get('portfolio_value',0)/100); print('Total:',(d.get('balance',0)+d.get('portfolio_value',0))/100)"
pm2 logs openclaw-btc --lines 30 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | tail -20
grep "22:37\|22:39\|22:40\|22:42" /root/performance_log.json | tail -10
grep "111845" /root/performance_log.json | tail -10
grep -n "retry\|while.*order\|attempt" /root/openclaw.py | head -10
python3 -c "c=open('/root/openclaw.py').read(); old='        if not filled:\n            print(f\"[Order] Not filled: {order}\")\n            # Cancel the resting order immediately to free funds'; new='        if not filled:\n            print(f\"[Order] Not filled: {order}\")\n            open(\"/tmp/openclaw_order_failed\",\"w\").write(str(__import__(\"time\").time()))\n            # Cancel the resting order immediately to free funds'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
python3 -c "c=open('/root/openclaw.py').read(); old='    if not ticker:\n        print(\"[Order] No ticker — skipping\")\n        return False'; new='    try:\n        import os as _oi,time as _ti\n        _ff=\"/tmp/openclaw_order_failed\"\n        if _oi.path.exists(_ff) and _ti.time()-float(open(_ff).read())<60:\n            print(\"[Order] Global cooldown after failed order — skipping\")\n            return False\n    except Exception: pass\n    if not ticker:\n        print(\"[Order] No ticker — skipping\")\n        return False'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
pm2 logs openclaw-btc --lines 10 --nostream | grep "cooldown\|Global\|failed\|ATTEMPTING\|Balance"
ls -la /tmp/openclaw_order_failed 2>/dev/null && cat /tmp/openclaw_order_failed || echo "no file"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/balance'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); d=r.json(); print('Cash:',d.get('balance',0)/100); print('Portfolio:',d.get('portfolio_value',0)/100); print('Total:',(d.get('balance',0)+d.get('portfolio_value',0))/100)"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':100},timeout=8); pos=[p for p in r.json().get('market_positions',[]) if float(p.get('market_exposure_dollars',0))>0]; print(str(len(pos))+' open'); [print(p.get('ticker'),p.get('market_exposure_dollars')) for p in pos]"
pm2 stop openclaw-btc openclaw-eth openclaw-sol && pm2 save
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXBTC15M-26APR111915-15'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); m=r.json().get('market',{}); print('status:',m.get('status')); print('close:',m.get('close_time')); print('result:',m.get('result'))"
date -u 
python3 /tmp/status_all.py
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
grep -n "o.status\|o.filled\|filled_count\|filled_yes\|filled_no\|amount_filled" /root/openclaw.py | head -15 
sed -n '375,395p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='                print(f\"[Order] status={status} remaining={remaining} filled={filled}\")'; new='                filled_count=getattr(o,\"filled_count\",None) or getattr(o,\"yes_count\",None) or getattr(o,\"no_count\",None)\n                print(f\"[Order] status={status} remaining={remaining} filled={filled} filled_count={filled_count}\")'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK" 
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
date -u
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
pm2 stop openclaw-btc openclaw-eth openclaw-sol && pm2 save
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
python3 -c "c=open('/root/openclaw.py').read(); old='    if any(p.get(\"ticker\")==ticker and p.get(\"direction\")==direction for p in OPEN_POSITIONS):'; new='    if any(p.get(\"ticker\")==ticker for p in OPEN_POSITIONS):'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
grep -n "double_down\|DoubleDown" /root/openclaw.py | head -8
grep -n "create_order" /root/openclaw.py | head -15
grep -n "TOD_SCHEDULE\|PEAK_HOURS" /root/openclaw.py | head -10
sed -n '78,90p' /root/openclaw.py
sed -n '965,995p' /root/openclaw.py
sed -n '995,1010p' /root/openclaw.py 
grep -n "def simulate_trade" /root/openclaw.py
placed+=place_order("UP",leg_bet,"arb_yes",...)
grep -n "ARB_THRESHOLD\|try_arb" /root/openclaw.py | head -10
sed -n '927,965p' /root/openclaw.py
grep -n "CYCLE_SLEEP\|MIN_EDGE\|EXTREME" /root/openclaw.py | head -10
exit
source kalshi_env/bin/activate
grep -n "CYCLE_SLEEP\|MIN_EDGE\|EXTREME" /root/openclaw.py | head -10
grep -n "def get_btc_prices\|def get_coinbase" /root/openclaw.py
sed -n '140,155p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='            bal=(d.get(\"balance\",0)+d.get(\"portfolio_value\",0))/100'; new='            bal=d.get(\"balance\",0)/100  # Cash only, not portfolio_value'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
cat /tmp/status_all.
sed -i 's/bal = (d.get("balance",0) + d.get("portfolio_value",0)) \/ 100/bal = d.get("balance",0) \/ 100/' /tmp/status_all.py
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':100},timeout=8); pos=[p for p in r.json().get('market_positions',[]) if float(p.get('market_exposure_dollars',0))>0]; print(str(len(pos))+' open positions'); [print(p.get('ticker'),p.get('market_exposure_dollars')) for p in pos]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXBTC15M-26APR112200-00'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); m=r.json().get('market',{}); print('status:',m.get('status')); print('close:',m.get('close_time')); print('result:',m.get('result')); print('open:',m.get('open_time'))"
python3 /tmp/status_all.py
date -u
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
tail -5 /root/performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0),json.loads(l).get('notes','')) for l in sys.stdin if l.strip()]" 
pm2 logs openclaw-btc --lines 20 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | tail -15
pm2 stop openclaw-btc openclaw-eth openclaw-sol && pm2 save
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/orders'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'limit':10,'status':'all'},timeout=8); orders=r.json().get('orders',[]); [print(o.get('created_time','')[:16],o.get('ticker',''),o.get('side',''),o.get('action',''),o.get('filled_cost',''),o.get('status','')) for o in orders]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/fills'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'limit':20},timeout=8); print(r.status_code); fills=r.json().get('fills',[]); [print(f.get('created_time','')[:16],f.get('ticker',''),f.get('side',''),f.get('action',''),f.get('count',''),f.get('yes_price','')) for f in fills[:10]]"
exit
source kalshi_env/bin/activate
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/fills'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'limit':20},timeout=8); print(r.status_code); fills=r.json().get('fills',[]); [print(f.get('created_time','')[:16],f.get('ticker',''),f.get('side',''),f.get('action',''),f.get('count',''),f.get('yes_price','')) for f in fills[:10]]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/fills'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'limit':30},timeout=8); fills=r.json().get('fills',[]); btc=[f for f in fills if 'BTC' in f.get('ticker','') and '112215' in f.get('ticker','')]; [print(f.get('created_time','')[:19],f.get('count',''),f.get('yes_price',''),f.get('no_price',''),f.get('side','')) for f in btc]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/fills'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'limit':5},timeout=8); import json; fills=r.json().get('fills',[]); print(json.dumps(fills[0],indent=2)) if fills else print('no fills')"
grep -n "contract_count=max" /root/openclaw.py
sed -n '357,362p' /root/openclaw.py
sed -i 's/contract_count=max(1,int(bet\/(mkt_yes or mkt_no or 0.50)))/contract_count=max(1,min(30,int(bet\/(mkt_yes or mkt_no or 0.50))))/' /root/openclaw.py
pm2 logs openclaw-btc --lines 50 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | grep "02:0\|CashOut\|HardFloor\|Positions\|PLACED\|WIN\|LOSS\|Settled" | head -20
sell_side = "no" if direction=="UP" else "yes"
python3 -c "c=open('/root/openclaw.py').read(); old='                    if status in (\"open\",\"active\"):\n                        adverse=((entry_yes-cur_yes) if direction==\"UP\" else (cur_yes-(1-entry_yes)))\n                        hard_floor=(direction==\"UP\" and cur_yes<0.10) or (direction==\"DOWN\" and cur_yes>0.90)\n                        if adverse>CASHOUT_ADVERSE or hard_floor:'; new='                    if status in (\"open\",\"active\") and direction in (\"UP\",\"DOWN\"):\n                        adverse=((entry_yes-cur_yes) if direction==\"UP\" else (cur_yes-(1-entry_yes)))\n                        hard_floor=(direction==\"UP\" and cur_yes<0.10) or (direction==\"DOWN\" and cur_yes>0.90)\n                        if adverse>CASHOUT_ADVERSE or hard_floor:'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':10},timeout=8); import json; pos=r.json().get('market_positions',[]); print(json.dumps(pos[0],indent=2)) if pos else print('no positions')"
python3 -c "c=open('/root/openclaw.py').read(); old='                    _ifloor=(direction==\"UP\" and _icy<0.06) or (direction==\"DOWN\" and _icy>0.94)\n                    if _ifloor and age_placed>=0.5:'; new='                    _ifloor=((direction==\"UP\" and _icy<0.06) or (direction==\"DOWN\" and _icy>0.94)) and direction in (\"UP\",\"DOWN\")\n                    if _ifloor and age_placed>=0.5:'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXBTC15M-26APR112215-15/candlesticks'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'period_interval':1},timeout=8); print(r.status_code); print(str(r.json())[:500])"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/series/KXBTC15M/markets'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); print(r.status_code); print(str(r.json())[:300])"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXBTC15M-26APR112215-15/trades'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); print(r.status_code); print(str(r.json())[:500])"
cat /root/mentions_scanner.py | head -50
ls /root/*scanner* /root/*whale* 2>/dev/null
head -60 /root/whale_scanner.py
nano /root/price_historian.py
python3 -m py_compile /root/price_historian.py && echo "OK"
pm2 start /root/price_historian.py --name price-historian --interpreter python3
sleep 15 && head -3 /root/price_history.jsonl
grep -n "CYCLE_SLEEP\|check_open_positions\|def simulate_trade" /root/openclaw.py | head -10
sed -n '995,1010p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='            elapsed=time.time()-cycle_start\n            time.sleep(max(0,CYCLE_SLEEP-elapsed))'; new='            elapsed=time.time()-cycle_start\n            remaining=max(0,CYCLE_SLEEP-elapsed)\n            # Fast cashout check every 15sec while waiting for next cycle\n            slept=0\n            while slept<remaining:\n                chunk=min(15,remaining-slept)\n                time.sleep(chunk)\n                slept+=chunk\n                if OPEN_POSITIONS: check_open_positions()'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
sed -n '378,395p' /root/openclaw.py
sed -n '408,425p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='        msg=f\"✅ {BOT_NAME.split()[1]} {strategy_tag.upper()}: {direction} \${bet:.2f} on {ticker}\"'; new='        actual_cost=round(contract_count*(mkt_yes if direction==\"UP\" else (1-(mkt_yes or 0.5))),2) if mkt_yes else bet\n        msg=f\"✅ {BOT_NAME.split()[1]} {strategy_tag.upper()}: {direction} {contract_count}c @ \${(mkt_yes if direction==\"UP\" else (1-(mkt_yes or 0.5))):.2f} = \${actual_cost:.2f} on {ticker}\"'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
sed -n '418,425p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='        OPEN_POSITIONS.append({\"direction\":direction,\"bet\":bet,\"ticker\":ticker,\n            \"strategy\":strategy_tag,\"time\":time.time(),\"placed_at\":time.time(),\n            \"entry_time\":now_utc.isoformat(),\"entry_yes\":entry_yes,\n            \"min_yes\":entry_yes,\"max_yes\":entry_yes,\n            \"signal_type\":\"EXTREME\" if is_extreme else \"STANDARD\",\n            \"entry_minute\":now_utc.minute%15,\"contracts\":contract_count})\n        log_trade(direction,bet,\"PLACED\",notes=f\"{strategy_tag}|{ticker}\")'; new='        OPEN_POSITIONS.append({\"direction\":direction,\"bet\":actual_cost,\"ticker\":ticker,\n            \"strategy\":strategy_tag,\"time\":time.time(),\"placed_at\":time.time(),\n            \"entry_time\":now_utc.isoformat(),\"entry_yes\":entry_yes,\n            \"min_yes\":entry_yes,\"max_yes\":entry_yes,\n            \"signal_type\":\"EXTREME\" if is_extreme else \"STANDARD\",\n            \"entry_minute\":now_utc.minute%15,\"contracts\":contract_count})\n        log_trade(direction,actual_cost,\"PLACED\",notes=f\"{strategy_tag}|{ticker}\")'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
grep -n "hourly\|send_hourly\|_last_summary" /root/openclaw.py | head -10
sed -n '891,910p' /root/openclaw.py
sed -n '960,968p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='    check_open_positions()\n    send_hourly_summary()'; new='    check_open_positions()\n    send_hourly_summary()\n    for _pp in OPEN_POSITIONS:\n        try:\n            _purl=f\"https://api.elections.kalshi.com/trade-api/v2/markets/{_pp.get(chr(116)+chr(105)+chr(99)+chr(107)+chr(101)+chr(114))}\"\n            _phr=kalshi.kalshi_auth.create_auth_headers(\"GET\",_purl)\n            _pr=requests.get(_purl,headers=_phr,timeout=3)\n            if _pr.status_code==200:\n                _pm=_pr.json().get(\"market\",{})\n                _pya=_pm.get(\"yes_ask_dollars\")\n                if _pya:\n                    with open(PERF_LOG,\"a\") as _pf: _pf.write(__import__(\"json\").dumps({\"ts\":__import__(\"datetime\").datetime.utcnow().isoformat(),\"type\":\"position_snapshot\",\"ticker\":_pp.get(\"ticker\"),\"direction\":_pp.get(\"direction\"),\"entry_yes\":_pp.get(\"entry_yes\"),\"cur_yes\":float(_pya),\"bet\":_pp.get(\"bet\"),\"contracts\":_pp.get(\"contracts\")})+\"\\n\")\n        except: pass'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
python3 -c "c=open('/root/openclaw.py').read(); old='    for _pp in OPEN_POSITIONS:\n        try:\n            _purl=f\"https://api.elections.kalshi.com/trade-api/v2/markets/{_pp.get(chr(116)+chr(105)+chr(99)+chr(107)+chr(101)+chr(114))}\"\n            _phr=kalshi.kalshi_auth.create_auth_headers(\"GET\",_purl)\n            _pr=requests.get(_purl,headers=_phr,timeout=3)\n            if _pr.status_code==200:\n                _pm=_pr.json().get(\"market\",{})\n                _pya=_pm.get(\"yes_ask_dollars\")\n                if _pya:\n                    with open(PERF_LOG,\"a\") as _pf: _pf.write(__import__(\"json\").dumps({\"ts\":__import__(\"datetime\").datetime.utcnow().isoformat(),\"type\":\"position_snapshot\",\"ticker\":_pp.get(\"ticker\"),\"direction\":_pp.get(\"direction\"),\"entry_yes\":_pp.get(\"entry_yes\"),\"cur_yes\":float(_pya),\"bet\":_pp.get(\"bet\"),\"contracts\":_pp.get(\"contracts\")})+\"\\n\")\n        except: pass'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,''))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
python3 /tmp/status_all.py
pm2 logs openclaw-btc --lines 5 --nostream | grep -v "DeprecationWarning\|datetime\|signal="
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':100},timeout=8); pos=[p for p in r.json().get('market_positions',[]) if float(p.get('market_exposure_dollars',0))>0]; print(str(len(pos))+' open positions'); [print(p.get('ticker'),p.get('market_exposure_dollars')) for p in pos]"
ls -la /tmp/openclaw_master.lock 2>/dev/null || echo "no master lock"
source kalshi_env/bin/activate
python3 /tmp/status_all.py
source kalshi_env/bin/activate
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/balance'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); d=r.json(); print('Cash:',d.get('balance',0)/100); print('Portfolio:',d.get('portfolio_value',0)/100)"
tail -20 /root/performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0)) for l in sys.stdin if l.strip()]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/balance'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); d=r.json(); print('Cash:',d.get('balance',0)/100); print('Portfolio:',d.get('portfolio_value',0)/100)"
source kalshi_env/bin/activate
grep "09:00\|08:5[0-9]" /root/eth_performance_log.json | grep "2026-04-12" | tail -5
exit
source kalshi_env/bin/activate
grep "09:00\|08:5[0-9]" /root/eth_performance_log.json | grep "2026-04-12" | tail -5
source kalshi_env/bin/activate
python3 /tmp/status_all.py
grep "LOSS\|loss" /root/performance_log.json | grep "2026-04-12" | tail -5
grep -n "actual_cost" /root/openclaw.py | head -5
grep -n "min(30\|contract_count" /root/openclaw.py | head -5
sed -i 's/contract_count=max(1,min(30,int(bet\/(mkt_yes or mkt_no or 0.50))))/entry_price=(mkt_yes if side=="yes" else (mkt_no if mkt_no else (1-(mkt_yes or 0.5))))\n    contract_count=max(1,min(25,int(bet\/max(0.01,entry_price))))/' /root/openclaw.py
ls -la /tmp/openclaw_master.lock 2>/dev/null && date -u
grep -n "Master lock held\|CorrGuard" /root/openclaw.py | head -5
grep "12:37" /root/performance_log.json | tail -3
sed -n '315,340p' /root/openclaw.py
sed -n '408,416p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='        except FileExistsError:\n            age = _t.time()-_os.path.getmtime(master_lock)\n            if age < 120:\n                print(f\"[CorrGuard] Master lock held ({age:.0f}s) — skipping\")\n                return False\n            _os.remove(master_lock)'; new='        except FileExistsError:\n            age = _t.time()-_os.path.getmtime(master_lock)\n            if age < 180:\n                print(f\"[CorrGuard] Master lock held ({age:.0f}s) — skipping\")\n                return False\n            _os.remove(master_lock)\n            fd=_os.open(master_lock,_os.O_CREAT|_os.O_EXCL|_os.O_WRONLY)\n            _os.write(fd,str(_t.time()).encode())\n            _os.close(fd)'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_master.lock /tmp/openclaw_*.lock /tmp/openclaw_order_failed
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/balance'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); d=r.json(); print('Full response:',d)" 
grep "09:00\|08:5[0-9]" /root/eth_performance_log.json | grep "2026-04-12" | tail -5
grep -n "master_lock\|openclaw_firing" /root/openclaw.py | head -10
grep -n "lock_path = f'/tmp/openclaw_firing" /root/openclaw.py
sed -i '319s/.*/        window_lock = f'"'"'\/tmp\/openclaw_window_{live_ticker}.lock'"'"'/' /root/openclaw.py
sed -n '326,332p' /root/openclaw.py
sed -i '328a\        except Exception as _e2: print(f"[CorrGuard] lock error: {str(_e2)}")' /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
ruff check /root/openclaw.py --select E,F,W --ignore E501,E401,E402,E701,E702 2>/dev/null
grep -n "None\|0\.50\|0\.5)" /root/openclaw.py | grep -v "#\|print\|url\|http\|entry\|cur_yes\|win_prob\|trend\|gap\|scale\|RISK\|TOD\|EXTREME\|CASHOUT\|ADVERSE\|0\.50\*\|entry_p\|mkt_yes\|mkt_no\|yes_p\|no_p\|sell_p\|entry_price\|_ep\|0\.506\|0\.503" | head -20
grep -n "except.*pass\|except:$\|except Exception:$" /root/openclaw.py | head -20
sed -i '316d' /root/openclaw.py
sed -n '349,355p' /root/openclaw.py
sed -n '529,535p' /root/openclaw.py
rm -f /tmp/openclaw_order_failed /tmp/openclaw_master.lock /tmp/openclaw_*.lock
echo "price_history.jsonl" >> /root/.gitignore
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXBTC15M-26APR130115-15/orderbook'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); print(r.status_code); print(str(r.json())[:400])"
python3 -c "import requests,tempfile,datetime; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'status':'open','series_ticker':'KXBTC15M','limit':1},timeout=8); markets=r.json().get('markets',[]); ticker=markets[0].get('ticker') if markets else None; print('ticker:',ticker); url2=f'https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}/orderbook'; hdrs2=k​​​​​​​​​​​​​​​​
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,params={'status':'open','series_ticker':'KXBTC15M','limit':1},timeout=8); t=r.json().get('markets',[])[0].get('ticker'); print(t); open('/tmp/btcticker','​​​​​​​​​​​​​​​​
nano /tmp/checkob.py
python3 /tmp/checkob.py
nano /tmp/testliquidity.py
python3 /tmp/testliquidity.py
sed -n '195,210p' /root/openclaw.py
nano /tmp/obliquidity.py
grep -n "def get_trend_validator" /root/openclaw.py
sed -i '207r /tmp/obliquidity.py' /root/openclaw.py
sed -n '375,385p' /root/openclaw.py
sed -i '380a\    liquid,ob_price=get_orderbook_liquidity(ticker,side,contract_count)\n    if not liquid:\n        print(f"[Order] Insufficient liquidity for {contract_count} {side} contracts on {ticker} — skipping")\n        return False' /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_window_*.lock
pm2 logs openclaw-btc --lines 15 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | tail -10
python3 /tmp/status_all.py
nano /tmp/hourly_wr.py
python3 /tmp/hourly_wr.py
sed -n '82,86p' /root/openclaw.py
sed -i 's/TOD_SCHEDULE={0:0.40,1:0.25,2:1.00,3:1.00,4:0.40,5:0.00,6:1.00,7:1.00,8:1.00,9:1.00,10:1.00,11:1.00,12:0.50,13:0.50,14:1.00,15:1.00,16:1.00,17:0.75,18:0.75,19:1.00,20:0.75,21:1.00,22:0.25,23:0.75}/TOD_SCHEDULE={0:0.50,1:0.30,2:0.75,3:1.25,4:0.20,5:0.00,6:1.25,7:1.25,8:1.00,9:1.25,10:1.00,11:1.25,12:0.75,13:0.40,14:1.25,15:1.50,16:1.00,17:0.85,18:0.85,19:1.25,20:0.80,21:1.25,22:0.40,23:0.50}/' /root/openclaw.py
sed -i 's/PEAK_HOURS={3,6,7,8,9,10,11,14,15,16,19,21}/PEAK_HOURS={3,6,7,8,9,11,14,15,16,19,21}/' /root/openclaw.py
sed -i 's/TOD_SCHEDULE={0:0.00,1:0.00,2:0.00,3:0.00,4:0.00,5:0.00,6:1.00,7:1.00,8:1.00,9:1.00,10:1.00,11:1.00,12:0.50,13:0.50,14:1.00,15:1.00,16:1.00,17:0.75,18:0.75,19:1.00,20:0.75,21:1.00,22:0.00,23:0.00}/TOD_SCHEDULE={0:0.00,1:0.00,2:0.00,3:0.00,4:0.00,5:0.00,6:1.25,7:1.25,8:1.00,9:1.25,10:1.00,11:1.25,12:0.75,13:0.40,14:1.25,15:1.50,16:1.00,17:0.85,18:0.85,19:1.25,20:0.80,21:1.25,22:0.00,23:0.00}/' /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_window_*.lock
date -u && python3 -c "import datetime; h=datetime.datetime.utcnow().hour; btc={0:0.50,1:0.30,2:0.75,3:1.25,4:0.20,5:0.00,6:1.25,7:1.25,8:1.00,9:1.25,10:1.00,11:1.25,12:0.75,13:0.40,14:1.25,15:1.50,16:1.00,17:0.85,18:0.85,19:1.25,20:0.80,21:1.25,22:0.40,23:0.50}; print(f'Hour {h:02d} UTC: BTC scale={btc.get(h,1.0)}x')"
pm2 logs openclaw-btc --lines 10 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | grep -E "Liquidity|CorrGuard|Order|Balance"
nano /tmp/reconcile_v2.py
python3 /tmp/reconcile_v2.py
nano /tmp/reconcile_v2.py
python3 /tmp/reconcile_v2.py
nano /tmp/reconcile_v2.py
python3 /tmp/reconcile_v2.py
nano /tmp/reconcile_v3.py
python3 /tmp/reconcile_v3.py
grep "120700\|120900\|120345" /root/eth_performance_log.json | grep "2026-04-12" | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0)) for l in sys.stdin if l.strip()]"
grep "10:5[0-9]" /root/performance_log.json | grep "2026-04-12" | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0),json.loads(l).get('notes','')[-20:]) for l in sys.stdin if l.strip()]"
pm2 logs openclaw-btc --lines 20 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | grep -E "CorrGuard|Order|PLACED|WIN|Liquidity" | head -10
grep -n "type.*market\|time_in_force\|ioc" /root/openclaw.py | grep "create_order\|action.*buy" | head -5
sed -n '396,400p' /root/openclaw.py
sed -n '387,398p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='        order=kalshi.create_order(ticker=ticker,action=\"buy\",side=side,type=\"market\",\n            count=contract_count,yes_price=yes_p,no_price=no_p,time_in_force=\"ioc\")'; new='        order=kalshi.create_order(ticker=ticker,action=\"buy\",side=side,type=\"market\",\n            count=contract_count,time_in_force=\"ioc\")'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
python3 -c "c=open('/root/openclaw.py').read(); old='        yes_p=min(99,max(1,round((mkt_yes or 0.5)*100))) if side==\"yes\" else None\n        no_p=min(99,max(1,round((mkt_no or 0.5)*100))) if side==\"no\" else None\n        order=kalshi.create_order(ticker=ticker,action=\"buy\",side=side,type=\"market\",\n            count=contract_count,time_in_force=\"ioc\")'; new='        order=kalshi.create_order(ticker=ticker,action=\"buy\",side=side,type=\"market\",\n            count=contract_count,time_in_force=\"ioc\")'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
sed -n '385,400p' /root/openclaw.py
ruff check /root/openclaw.py --select F841,F401 2>/dev/null
sed -i '218d' /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
python3 /tmp/prove_gap.py 2>/dev/null | head -40
python3 /tmp/prove_gap.py
nano /tmp/prove_gap.py
python3 /tmp/prove_gap.py
python3 -c "import csv; placed=[(r[0],r[2],r[5]) for f in ['/root/trade_log.csv','/root/eth_trade_log.csv','/root/sol_trade_log.csv'] for r in csv.reader(open(f)) if len(r)>=6 and '2026-04-12' in r[0] and 'PLACED' in r[3]]; total=sum(float(p[1]) for p in placed); print(f'Logged PLACED: {len(placed)} trades, \${total:.2f} total')"
nano /tmp/fills_by_ticker.py
python3 /tmp/fills_by_ticker.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_window_*.lock
sed -n '398,430p' /root/openclaw.py
sed -n '428,445p' /root/openclaw.py
sed -n '430p' /root/openclaw.py
pm2 logs openclaw-btc --lines 30 --nostream | grep "Order\|filled\|status=" | head -10
python3 -c "from kalshi_python.models import Order; print([a for a in dir(Order()) if not a.startswith('_')])"
date -u 
pm2 logs openclaw-btc --lines 10 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | tail -8
git tag -a "v4.1-stable" -m "Stable: orderbook liquidity, window lock, TOD schedule, market orders fixed" && git push origin v4.1-stable
python3 -c "c=open('/root/openclaw.py').read(); old='        order=kalshi.create_order(ticker=ticker,action=\"buy\",side=side,type=\"market\",\n            count=contract_count,time_in_force=\"ioc\")'; new='        yes_p=min(99,max(1,round((mkt_yes or 0.5)*100)+5)) if side==\"yes\" else None\n        no_p=min(99,max(1,round((mkt_no or 0.5)*100)+5)) if side==\"no\" else None\n        order=kalshi.create_order(ticker=ticker,action=\"buy\",side=side,type=\"market\",\n            count=contract_count,yes_price=yes_p,no_price=no_p,time_in_force=\"ioc\")'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
cpm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':10},timeout=8); import json; pos=r.json().get('market_positions',[]); [print(json.dumps({k:v for k,v in p.items() if k in ['ticker','position','market_exposure_dollars','yes_count','no_count','total_cost_cents']})) for p in pos[:3]] if pos else print('no positions')"
sed -n '920,935p' /root/openclaw.py
sed -n '935,950p' /root/openclaw.py
python3 -c "c=open('/root/openclaw.py').read(); old='            pos_count=p.get(\"position\",0)\n            direction=\"UP\" if pos_count>0 else \"DOWN\" if pos_count<0 else \"UNKNOWN\"'; new='            pos_count=p.get(\"position\",0)\n            yes_c=float(p.get(\"yes_count\",0) or 0)\n            no_c=float(p.get(\"no_count\",0) or 0)\n            if pos_count and pos_count!=0:\n                direction=\"UP\" if pos_count>0 else \"DOWN\"\n            elif yes_c>0:\n                direction=\"UP\"\n            elif no_c>0:\n                direction=\"DOWN\"\n            else:\n                direction=\"UNKNOWN\"'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
date -u
sed -n '383,392p' /root/openclaw.py
sed -i '384,385d' /root/openclaw.py
pm2 logs openclaw-eth --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_window_*.lock
nano /root/reconcile_daily.py
python3 /root/reconcile_daily.py
pm2 start /root/reconcile_daily.py --name reconcile --interpreter python3 --cron "0 23 * * *" --no-autorestart
wc -l /root/openclaw.py
sed -n '667,720p' /root/openclaw.py
sed -n '720,830p' /root/openclaw.py
nano /tmp/evaluate_exit.py
grep -n "def simulate_trade\|def check_open" /root/openclaw.py
git add /tmp/evaluate_exit.py 2>/dev/null || true
python3 /tmp/status_all.py
pm2 logs openclaw-btc --lines 10 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | grep "PLACED\|Restored\|Positions\|WIN\|LOSS" | tail -5
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':10},timeout=8); pos=[p for p in r.json().get('market_positions',[]) if float(p.get('market_exposure_dollars',0))>0]; [print(p.get('ticker'),p.get('market_exposure_dollars'),p.get('yes_count'),p.get('no_count')) for p in pos] if pos else print('no positions')"
ls -la /tmp/openclaw_window_*26APR122245* 2>/dev/null || echo "no window locks found"
grep -n "window_lock = f" /root/openclaw.py
sed -i "s|window_lock = f'/tmp/openclaw_window_{live_ticker}.lock'|window_lock = f'/tmp/openclaw_window_{live_ticker.split(\"-\",1)[-1]}.lock'|" /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXBTC15M-26APR122245-45'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); m=r.json().get('market',{}); print('status:',m.get('status')); print('close:',m.get('close_time')); print('result:',m.get('result'))"
sleep 90 && pm2 logs openclaw-btc --lines 5 --nostream | grep "WIN\|LOSS\|Settled\|Positions"
python3 /tmp/status_all.py
rm -f /tmp/openclaw_window_*.lock
pm2 logs openclaw-btc --lines 3 --nostream | grep -v "DeprecationWarning\|datetime\|signal="
cat /root/genome.json | python3 -c "import sys,json; g=json.load(sys.stdin); variants=g.get('variants',[]); [print(f\"v{v.get('id','?'):03d} WR={v.get('win_rate',0):.0%} T={v.get('trades',0)} PnL={v.get('pnl',0):.0f}\") for v in sorted(variants,key=lambda x:-x.get('win_rate',0))[:5]]"
pm2 logs openclaw-btc --lines 1 --nostream | grep "Balance"
python3 -c "import json; g=json.load(open('/root/genome.json')); print(type(g)); print(str(g)[:300])"
python3 -c "import json; g=json.load(open('/root/genome.json')); [print(f\"{v.get('id')} WR={v.get('wins',0)/(v.get('trades',1)):.0%} T={v.get('trades',0)} PnL={v.get('pnl',0):.0f} status={v.get('status')}\") for v in sorted(g,key=lambda x:-x.get('wins',0)/max(x.get('trades',1),1))[:8]]"
pm2 logs arena --lines 10 --nostream | grep -v "DeprecationWarning\|datetime" | tail -8
grep -n "genome\|json.dump\|write" /root/arena.py | head -15 
sed -n '946,1000p' /root/arena.py
grep -n "wins.*+\|losses.*+\|pool.*save\|save_json.*pool" /root/arena.py | head -15
python3 -c "import json; g=json.load(open('/root/genome.json')); total_trades=sum(v.get('trades',0) for v in g); print(f'Total trades in genome: {total_trades}'); print(f'Variants: {len(g)}'); [print(f\"{v.get('id')} T={v.get('trades',0)} WR={v.get('wins',0)/max(v.get('trades',1),1):.0%}\") for v in g]" 
python3 -c "import json; g=json.load(open('/root/genome.json')); v4=[v for v in g if v.get('id')=='v004'][0]; v7=[v for v in g if v.get('id')=='v007'][0]; print('v004:',{k:v for k,v in v4.items() if k not in ['wins','losses','trades','pnl','generation','mutations','status']}); print('v007:',{k:v for k,v in v7.items() if k not in ['wins','losses','trades','pnl','generation','mutations','status']
grep -n "auto_promote\|AutoPromote" /root/arena.py | head -5
pm2 logs arena --lines 20 --nostream | grep -v "DeprecationWarning\|datetime" | grep "AutoPromote\|promote\|restart" | head -5
grep -n "subprocess.run.*pm2\|pm2.*restart" /root/arena.py
sed -i '987s/.*/        #subprocess.run(["pm2","restart","openclaw-btc","openclaw-eth","openclaw-sol"]) # DISABLED - manual promotion only/' /root/arena.py
pm2 restart arena && pm2 save
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/balance'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); d=r.json(); print('Cash:',d.get('balance',0)/100,'Portfolio:',d.get('portfolio_value',0)/100)"
pm2 logs openclaw-btc --lines 20 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | grep -E "CorrGuard|PLACED|WIN|LOSS|Order" | head -10
grep -n "window_lock" /root/openclaw.py | head -3
ls /tmp/openclaw_window_*.lock 2>/dev/null 
sed -i 's/print(f"\[CorrGuard\] Window {live_ticker} already traded/print(f"[CorrGuard] Window {live_ticker.split(\"-\",1)[-1]} already traded/' /root/openclaw.py
python3 /tmp/status_all.py
grep -n "DRY_RUN" /root/openclaw.py | head -5
grep -n "_args\|argparse\|add_argument" /root/openclaw.py | head -8 
python3 -c "c=open('/root/openclaw.py').read(); old='_parser.add_argument(\"--market\", choices=[\"btc\",\"eth\",\"sol\"], default=\"btc\")'; new='_parser.add_argument(\"--market\", choices=[\"btc\",\"eth\",\"sol\"], default=\"btc\")\n_parser.add_argument(\"--dry-run\", action=\"store_true\", default=False)'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
python3 -c "c=open('/root/openclaw.py').read(); old='DRY_RUN=False'; new='DRY_RUN=_args.dry_run'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
python3 /root/openclaw.py --market btc --dry-run
timeout 30 python3 /root/openclaw.py --market btc --dry-run 2>/dev/null | grep -v "DeprecationWarning\|datetime\|signal=" | head -15
rm -f /tmp/openclaw_window_*.lock
nano /tmp/per_market_analysis.py
python3 /tmp/per_market_analysis.py
grep -n "MAX_BET_PCT\|PEAK_BET_PCT" /root/openclaw.py | head -10
sed -i 's/"eth": ("KXETH15M","OpenClaw ETH Bot v4.0","\/root\/eth_trade_log.csv","\/root\/STOP_ETH",0.09/"eth": ("KXETH15M","OpenClaw ETH Bot v4.0","\/root\/eth_trade_log.csv","\/root\/STOP_ETH",0.11/' /root/openclaw.py
sed -i 's/18:0.85,19:1.25,20:0.80,21:1.25,22:0.00,23:0.00}/18:0.00,19:1.25,20:0.80,21:1.25,22:0.00,23:0.00}/' /root/openclaw.py
sed -i 's/PEAK_BET_PCT=0.10/PEAK_BET_PCT=0.12/' /root/openclaw.py
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':10},timeout=8); pos=[p for p in r.json().get('market_positions',[]) if float(p.get('market_exposure_dollars',0))>0]; [print(p.get('ticker'),p.get('market_exposure_dollars')) for p in pos] if pos else print('no positions')"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXSOL15M-26APR122345-45'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); m=r.json().get('market',{}); print('status:',m.get('status')); print('close:',m.get('close_time')); print('result:',m.get('result'))"
date -u
rm -f /tmp/openclaw_window_*.lock
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/portfolio/balance'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); d=r.json(); print('Cash:',d.get('balance',0)/100,'Portfolio:',d.get('portfolio_value',0)/100)"
awk 'NR>=667 && NR<=954' /root/openclaw.py | wc -l
grep -n "def check_open_positions\|def load_existing_positions\|def simulate_trade" /root/openclaw.py
cat /tmp/evaluate_exit.py | head -20
sed -i 's/DRY_RUN=_args.dry_run/DRY_RUN=_args.dry_run\nUSE_ERV=False  # Set True to use unified ERV cashout (test first with --dry-run)/' /root/openclaw.py
sed -i '667r /tmp/evaluate_exit.py' /root/openclaw.py
grep -n "def check_open_positions\|def evaluate_exit\|USE_ERV" /root/openclaw.py | head -8
sed -n '732,742p' /root/openclaw.py
sed -i '736a\    if USE_ERV:\n        for pos in list(OPEN_POSITIONS):\n            evaluate_exit(pos,kalshi,send_telegram,to_remove)\n        for pos in to_remove:\n            if pos in OPEN_POSITIONS: OPEN_POSITIONS.remove(pos)\n        return' /root/openclaw.py
timeout 65 python3 /root/openclaw.py --market btc --dry-run 2>/dev/null | grep -v "DeprecationWarning\|signal=" | head -20
timeout 65 python3 /root/openclaw.py --market btc --dry-run 2>/dev/null | head -20
timeout 65 python3 /root/openclaw.py --market btc --dry-run 2>&1 | grep -v "DeprecationWarning\|datetime" | head -20
timeout 65 python3 /root/openclaw.py --market btc --dry-run > /tmp/dryrun_test.log 2>&1
python3 -c "import sys; sys.argv=['openclaw.py','--market','btc','--dry-run']; exec(open('/root/openclaw.py').read())" 2>&1 | head -20
python3 /root/openclaw.py --market btc --dry-run &
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_window_*.lock
date -u
grep -n "DAILY_LOSS\|daily_loss\|circuit" /root/openclaw.py | head -5
sed -n '300,315p' /root/openclaw.py
pm2 logs openclaw-btc --lines 10 --nostream | grep -v "DeprecationWarning\|datetime\|signal=" | grep -E "Signal|Confidence|CorrGuard|PLACED|WIN" | head -8
nano /tmp/health.py
python3 /tmp/health.py
cp /tmp/health.py /root/health.py
python3 /root/health.py 2>/dev/null
grep -n "CASHOUT_MINUTES\|CASHOUT_ADVERSE" /root/openclaw.py | head -5
grep -n "create_order" /tmp/evaluate_exit.py
grep -n "action=\"sell\"" /root/openclaw.py | head -5
python3 -c "c=open('/root/openclaw.py').read(); old='USE_ERV=False  # Set True to use unified ERV cashout (test first with --dry-run)'; new='USE_ERV=(MARKET_SERIES==\"KXETH15M\")  # ERV enabled for ETH only, testing phase'; print('found' if old in c else 'NOT FOUND'); open('/root/openclaw.py','w').write(c.replace(old,new))" && python3 -m py_compile /root/openclaw.py && echo "OK"
sed -n '58,68p' /root/openclaw.py
timeout 65 python3 /root/openclaw.py --market eth --dry-run > /tmp/dryrun_eth.log 2>&1 &
timeout 15 python3 /root/openclaw.py --market eth --dry-run 2>&1 | grep -v "DeprecationWarning\|signal=" | head -15
python3 /root/openclaw.py --market eth --dry-run > /tmp/eth_test.log 2>&1 &
python3 -u /root/openclaw.py --market eth --dry-run > /tmp/eth_test.log 2>&1 &
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
rm -f /tmp/openclaw_window_*.lock
grep -n "BOT_TOKEN\|CHAT_ID\|send_telegram" /root/openclaw.py | head -8
nano /root/telegram_commander.py
pm2 start /root/telegram_commander.py --name telegram-commander --interpreter python3
pm2 logs telegram-commander --lines 10 --nostream
sleep 10 && pm2 logs telegram-commander --lines 5 --nostream
python3 /root/health.py 2>/dev/null
pm2 logs bond-scanner --lines 5 --nostream | grep -v "DeprecationWarning\|datetime"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); hdrs=k.kalshi_auth.create_auth_headers('GET','https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'); r=requests.get('https://api.elections.kalshi.com/trade-api/v2/portfolio/positions',headers=hdrs,params={'limit':100},timeout=8); pos=r.json().get('market_positions',[]); [print(p.get('ticker'),p.get('market_exposure_dollars')) for p in pos if float(p.get('market_exposure_dollars',0))>0]"
python3 -c "import requests,tempfile; raw=open('/root/real_bot_pre_v4_backup.py').read(); key=raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]; sec=raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]; tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w'); tf.write(sec); tf.close(); from kalshi_python import KalshiClient; from kalshi_python.configuration import Configuration; cfg=Configuration(); cfg.host='https://api.elections.kalshi.com/trade-api/v2'; k=KalshiClient(cfg); k.set_kalshi_auth(key,tf.name); url='https://api.elections.kalshi.com/trade-api/v2/markets/KXBTCD-26APR1301-T71199.99'; hdrs=k.kalshi_auth.create_auth_headers('GET',url); r=requests.get(url,headers=hdrs,timeout=8); m=r.json().get('market',{}); print('title:',m.get('title')); print('status:',m.get('status')); print('close:',m.get('close_time'))"
sed -i "s/p.get('ticker','')[-15:]/p.get('ticker','')[-20:]/g" /root/telegram_commander.py
tail -5 /root/performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0)) for l in sys.stdin if l.strip()]"
date -u
ls -la /tmp/openclaw_window_*.lock 2>/dev/null
rm -f /tmp/openclaw_window_*.lock
git add -A && git commit -m "Fix Telegram status ticker display length, restart commander" && git push
grep -n "'" /root/bond_scanner.py | grep "u201\|curly\|\u201c\|\u201d" | head -5
grep -n "def cmd_pause\|def cmd_resume\|def handle" /root/telegram_commander.py
sed -n '82,95p' /root/telegram_commander.py
sed -i "s/    elif t=='\/help': cmd_help()/    elif t=='\/restart': cmd_restart()\n    elif t=='\/locks': cmd_locks()\n    elif t=='\/help': cmd_help()/" /root/telegram_commander.py
sed -i "82i def cmd_restart():\n    import subprocess\n    subprocess.Popen(['pm2','restart','openclaw-btc','openclaw-eth','openclaw-sol'])\n    send('🔄 Restarting all bots...')\n\ndef cmd_locks():\n    import os\n    locks=[f for f in os.listdir('/tmp') if f.startswith('openclaw_window_')]\n    if locks:\n        msg='🔒 Active locks:\\n'+'\\n'.join(l.replace('openclaw_window_','').replace('.lock','') for l in locks)\n    else:\n        msg='✅ No active window locks'\n    send(msg)\n" /root/telegram_commander.py
nano /root/telegram_commander.py
python3 -m py_compile /root/telegram_commander.py && echo "OK"
sed -i "s|def cmd_help():|def cmd_help():|" /root/telegram_commander.py
sed -n '79,82p' /root/telegram_commander.py
sed -i 's|send("🤖 OpenClaw Commands:\\n\/status — full system status\\n\/balance — quick balance check\\n\/pause — pause all bots\\n\/resume — resume all bots\\n\/help — this message")|send("🤖 OpenClaw Commands:\n/status — full system status\n/balance — quick balance check\n/pause — pause all bots\n/resume — resume all bots\n/restart — restart all bots\n/locks — show active window locks\n/help — this message")|' /root/telegram_commander.py
nano /root/telegram_commander.py
python3 -m py_compile /root/telegram_commander.py && echo "OK"
pm2 restart telegram-commander && pm2 save
grep -rn "datetime.utcnow()" /root/openclaw.py /root/reconcile_daily.py /root/health.py /root/price_historian.py | wc -l
sed -i 's/datetime\.datetime\.utcnow()/datetime.datetime.now(datetime.timezone.utc)/g' /root/openclaw.py /root/reconcile_daily.py /root/health.py /root/price_historian.py
pm2 restart openclaw-btc openclaw-eth openclaw-sol price-historian && pm2 save
rm -f /tmp/openclaw_window_*.lock
grep -n "SESSION_START_BAL" /root/openclaw.py | head -8
sed -n '1070,1082p' /root/openclaw.py
grep -n "SESSION_START_BAL=live_start" /root/openclaw.py
nano /tmp/fix_session.py
python3 /tmp/fix_session.py && python3 -m py_compile /root/openclaw.py && echo "OK"
pm2 logs openclaw-btc --lines 3 --nostream | grep "Positions\|Session"
cat /tmp/openclaw_day_start.json
pm2 logs openclaw-btc --lines 10 --nostream | grep -v "DeprecationWarning\|signal=" | head -8
pm2 logs openclaw-btc --lines 10 --nostream 2>/dev/null | grep "Day start\|Live balance\|Startup\|Balance:"  | head -5
pm2 logs openclaw-btc --lines 20 --nostream | grep -v "DeprecationWarning\|signal=" | grep -E "Signal|Confidence|Score|Timing|TOD" | head -10
date -u && python3 -c "import datetime; h=datetime.datetime.now(datetime.timezone.utc).hour; btc={0:0.50,1:0.30,2:0.75,3:1.25,4:0.20,5:0.00,6:1.25,7:1.25,8:1.00,9:1.25,10:1.00,11:1.25,12:0.75,13:0.40,14:1.25,15:1.50,16:1.00,17:0.85,18:0.85,19:1.25,20:0.80,21:1.25,22:0.40,23:0.50}; print(f'Hour {h:02d} UTC | BTC scale={btc.get(h,1.0)}x | MaxBet approx \${361*0.07*btc.get(h,1.0):.2f}')"
python3 /root/health.py 2>/dev/null
rm -f /tmp/openclaw_window_*.lock
grep "2026-04-13" /root/performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0),json.loads(l).get('balance',0),json.loads(l).get('notes','')[-20:]) for l in sys.stdin if l.strip() if json.loads(l).get('action') in ('LOSS','WIN','PLACED')]" | head -20
grep "122045" /root/performance_log.json | python3 -c "import sys,json; [print(json.loads(l)['timestamp'],json.loads(l)['action'],json.loads(l).get('bet',0)) for l in sys.stdin if l.strip()]"
pm2 logs openclaw-btc --lines 50 --nostream | grep "Startup\|KeyboardInterrupt\|Started" | head -5
grep -n "double_down\|DoubleDown\|Already have" /root/openclaw.py | head -8
grep -n "OPEN_POSITIONS.append\|to_remove.append" /root/openclaw.py | head -5
sed -n '373,380p' /root/openclaw.py
sed -n '448,460p' /root/openclaw.py
sed -n '395,445p' /root/openclaw.py
exit
