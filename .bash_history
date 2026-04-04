grep -n "OPEN_POSITIONS.append" real_bot.py | head -3
sed -n '468,482p' real_bot.py
sed -n '840,846p' real_bot.py
python3 -c "
 lines = open('/root/real_bot.py').readlines()
 # Fix line 842 - should be indented to match the if block
 lines[841] = '                            to_remove.append(pos)\n'
 open('/root/real_bot.py', 'w').writelines(lines)
 print('Fixed')
 "
nano /tmp/fix_indent.py
python3 /tmp/fix_indent.py
sed -n '492,506p' real_bot.py
sed -i 's/            "entry_time":   datetime.datetime.now().isoformat(),/            "entry_time":   datetime.datetime.now().isoformat(),\n            "entry_yes":    mkt_yes if mkt_yes else 0.5,\n            "min_yes":      mkt_yes if mkt_yes else 0.5,\n            "max_yes":      mkt_yes if mkt_yes else 0.5,/' real_bot.py
grep -n "DAILY_LOSS_LIMIT\|RISK_SCORE\|session_start" real_bot.py | head -5
nano /tmp/add_tod.py
python3 /tmp/add_tod.py
sed -i "s|open('/root/real_bot.py')|open('/root/eth_bot.py')|g" /tmp/add_tod.py
pkill -f real_bot.py
sed -i 's/MARKET_SERIES    = "KXSOL15M"/MARKET_SERIES    = "KXBTC15M"/' /root/real_bot.py
pkill -f real_bot.py
grep "MaxBet" /root/bot.log | tail -2
sed -i 's/MARKET_SERIES    = "KXBTC15M"  # ← change to KXETH15M or KXSOL15M for other markets/MARKET_SERIES    = "KXBTC15M"  # DO NOT CHANGE — use eth_bot.py or sol_bot.py for other markets/' /root/real_bot.py
cp /root/real_bot.py /root/real_bot_v3_stable.py
source kalshi_env/bin/activate
python3 /tmp/status_all.py
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/INITIAL_BALANCE    = [0-9.]*/INITIAL_BALANCE    = 238.74/' $f;      sed -i 's/SESSION_START_BAL  = [0-9.]*/SESSION_START_BAL  = 238.74/' $f;      sed -i 's/MIN_BALANCE      = [0-9.]*/MIN_BALANCE      = 205.00/' $f;  done
python3 /tmp/debug_bond.py
grep "MARKET_SERIES" /root/real_bot.py | head -1
pkill -f real_bot.py
nano /root/openclaw.py
python3 /root/analyze_features.py
ls -la /root/feature_log.json 2>/dev/null || echo "File doesn't exist"
cat /root/bot.log | tail -8
find / -name "feature_log.json" 2>/dev/null
tail -3 /root/performance_log.json | python3 -m json.tool 2>/dev/null | head -20
grep "feature_log" /root/analyze_features.py
python3 /tmp/status_all.py
grep -A 20 "def log_trade" /root/real_bot.py | head -25
sed -i 's/def log_trade(direction, bet, action, profit_pct=0, notes=""):/def log_trade(direction, bet, action, profit_pct=0, notes="", features=None):/' /root/real_bot.py
grep -n "log_path = " /root/real_bot.py | head -3
grep "log_path\|performance_log\|sol_sol\|eth_eth\|sol_eth" /root/real_bot.py | head -5
nano /tmp/fix_real_bot_logs.py
python3 /tmp/fix_real_bot_logs.py
sed -n '168,180p' real_bot.py
nano /tmp/fix_indent2.py
python3 /tmp/fix_indent2.py
pkill -f real_bot.py
ps aux | grep -E "real_bot|eth_bot|sol_bot|bond_scanner" | grep -v grep
cp /root/real_bot.py /root/real_bot_v3_stable.py
sed -i 's/log_path = "\/root\/sol_performance_log.json"/log_path = "\/root\/eth_performance_log.json"/' /root/eth_bot.py
sleep 180 && python3 /tmp/status_all.py && grep -E "Settled|WIN|LOSS|EXTREME|Binance" /root/bot.log | tail -10
cat /root/bot.log | tail -10
grep -E "PLACED|✅|Settled" /root/eth_bot.log | tail -5
grep "feature_log" /root/real_bot.py
grep "trade_log" /root/eth_bot.py | head -2
ls -la /root/*trade_log* /root/*performance* 2>/dev/null
rm -f /root/sol_eth_performance_log.json /root/sol_eth_trade_log.csv
nano /root/watchdog.py
python3 -m py_compile /root/watchdog.py && echo "OK"
nano /tmp/fix_balance_sync.py
python3 /tmp/fix_balance_sync.py
sed -i 's/    load_existing_positions()/    global CURRENT_BALANCE, SESSION_START_BAL\n    CURRENT_BALANCE = get_live_balance_startup()\n    SESSION_START_BAL = CURRENT_BALANCE\n    print(f"[Startup] Live balance: \${CURRENT_BALANCE:.2f}")\n    load_existing_positions()/' /root/real_bot.py
sed -n '954,962p' real_bot.py
nano /tmp/fix_startup.py
python3 /tmp/fix_startup.py
sed -i "s|open('/root/real_bot.py')|open('/root/eth_bot.py')|g" /tmp/fix_balance_sync.py
sed -i "s|open('/root/real_bot.py')|open('/root/eth_bot.py')|g" /tmp/fix_startup.py
pkill -f real_bot.py
cat /root/bot.log | tail -15
grep -n "get_live_balance_startup\|def get_live_balance" /root/real_bot.py | head -5
sed -i 's/OpenClaw SOL Bot v1.0/OpenClaw BTC Bot v3.0/' /root/real_bot.py
grep -n "def get_max_bet" /root/real_bot.py | head -1
sed -i 's/    live_bal = get_live_balance_startup()/    live_bal = get_live_balance()/' /root/real_bot.py
sed -i 's/    live_bal = get_live_balance_startup()/    live_bal = get_live_balance()/' /root/eth_bot.py
nohup python3 -u /root/real_bot.py > /root/bot.log 2>&1 &
grep "MARKET_SERIES" /root/real_bot.py | head -1
pkill -f real_bot.py
sed -i 's/MARKET_SERIES    = "KXBTC15M"  # DO NOT CHANGE — BTC bot only/MARKET_SERIES    = "KXBTC15M"  # DO NOT CHANGE — BTC bot only\nassert MARKET_SERIES == "KXBTC15M", f"WRONG MARKET {MARKET_SERIES} in real_bot.py — check file"/' /root/real_bot.py
cp /root/real_bot.py /root/real_bot_v3_stable.py
nano /root/dashboard.py
python3 -m py_compile /root/dashboard.py && echo "OK"
curl -s ifconfig.me
ps aux | grep -E "real_bot|eth_bot|sol_bot|bond_scanner|watchdog|dashboard" | grep -v grep
cp /root/real_bot.py /root/real_bot_v3_stable.py
python3 /tmp/status_all.py
nano /root/dashboard.py
pkill -f dashboard.py
nano /tmp/fix_dashboard.py
python3 /tmp/fix_dashboard.py
python3 /tmp/status_all.py
nano /tmp/add_equity.py
python3 /tmp/add_equity.py
grep -n "equity_svg\|equity_start\|equity_points" /root/dashboard.py | head -5
cat /root/dashboard.log | tail -10
grep -n "active = " /root/dashboard.py
sed -n '150,162p' /root/dashboard.py
sed -n '160,180p' /root/dashboard.py
nano /tmp/fix_chart.py
python3 /tmp/fix_chart.py
grep -n "equity_svg\|equity_start\|SVG\|viewBox" /root/dashboard.py | head -8
cat /root/dashboard.log | tail -15
grep -n "equity_points.append(balance)" /root/dashboard.py
nano /tmp/fix_equity_svg.py
python3 /tmp/fix_equity_svg.py
python3 /tmp/status_all.py
cat /root/dashboard.log | tail -10
grep -n "equity_svg\|SVG generation" /root/dashboard.py | head -6
nano /tmp/fix_remove_equity.py
python3 /tmp/fix_remove_equity.py
cp /root/dashboard.py /root/dashboard_v2_stable.py
pkill -f dashboard.py
python3 -m py_compile /root/dashboard.py && echo "OK"
python3 /tmp/status_all.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
ls -la /root/feature_log.json 2>/dev/null && wc -l /root/feature_log.json || echo "No feature log yet"
grep -n "features=mae\|features=feat\|feature_log" /root/real_bot.py | head -8
nano /tmp/add_dashboard_v31.py
python3 /tmp/add_dashboard_v31.py
grep -n "^def generate_html" /root/dashboard.py
nano /tmp/inject_functions.py
python3 /tmp/inject_functions.py
grep -n "def log_trade" /root/real_bot.py | head -3
cat /root/dashboard.log | tail -5
sed -n '134,175p' /root/real_bot.py
nano /tmp/fix_logtrade.py
python3 /tmp/fix_logtrade.py
grep -n "log_trade.*WIN\|log_trade.*LOSS\|log_trade.*outcome" real_bot.py | head -8
sed -n '689,697p' real_bot.py
sed -i 's/                          notes=f"{strategy}|{ticker}")/                          notes=f"{strategy}|{ticker}",\n                          features={"signal_type": pos.get("signal_type","STANDARD"), "entry_minute": pos.get("entry_minute",0), "market": MARKET_SERIES, "entry_yes": pos.get("entry_yes", 0.5), "min_yes": pos.get("min_yes", 0.5), "max_yes": pos.get("max_yes", 0.5)})/' real_bot.py
grep -n "signal_type\|entry_minute" real_bot.py | head -5
sed -n '490,508p' real_bot.py
grep -n "OPEN_POSITIONS.append" real_bot.py | head -3
grep -n "OPEN_POSITIONS.append" real_bot.py | head -1
sed -n '465,482p' real_bot.py
sed -n '434,452p' real_bot.py
sed -i 's/            "entry_time":   datetime.datetime.now().isoformat(),/            "entry_time":   datetime.datetime.now().isoformat(),\n            "entry_yes":    mkt_yes if mkt_yes else 0.5,\n            "min_yes":      mkt_yes if mkt_yes else 0.5,\n            "max_yes":      mkt_yes if mkt_yes else 0.5,\n            "signal_type":  "EXTREME" if mkt_yes and (mkt_yes > 0.80 or mkt_yes < 0.20) else "STANDARD",\n            "entry_minute": datetime.datetime.now(datetime.timezone.utc).minute % 15,/' real_bot.py
pkill -f real_bot.py
grep "MARKET_SERIES" /root/real_bot.py | head -1
cp /root/real_bot.py /root/real_bot_v3_stable.py
nano /tmp/fix_parse_log.py
python3 /tmp/fix_parse_log.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
python3 /tmp/status_all.py
grep -c "WIN\|LOSS" /root/trade_log.csv
grep -E "Settled|WIN|LOSS" /root/bot.log | tail -5
nano /tmp/fix_status_all.py
python3 /tmp/fix_status_all.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
python3 /tmp/status_all.py
python3 -c "
 import json
 entries = [json.loads(l) for l in open('/root/feature_log.json') if l.strip()]
 settled = [e for e in entries if e.get('action') in ('WIN','LOSS')]
 print(f'Feature log entries: {len(entries)} total, {len(settled)} settled')
 mins = [e.get('features',{}).get('entry_minute',-1) for e in settled]
 from collections import Counter
 print('Entry minutes:', Counter(mins))
 sigs = [e.get('features',{}).get('signal_type','?') for e in settled]
 print('Signal types:', Counter(sigs))
 wins_by_sig = {}
 for e in settled:
     s = e.get('features',{}).get('signal_type','?')
     if s not in wins_by_sig: wins_by_sig[s] = {'w':0,'l':0}
     wins_by_sig[s]['w' if e['action']=='WIN' else 'l'] += 1
 for s,v in wins_by_sig.items():
     t=v['w']+v['l']
     print(f'  {s}: {v[\"w\"]}W/{v[\"l\"]}L ({v[\"w\"]/t*100:.0f}%)')
 "
grep -n "feature_table\|ai_insight\|sys_html" /root/dashboard.py | grep -v "def \|build_\|html =" | head -10
nano /tmp/fix_fstring.py
python3 /tmp/fix_fstring.py
nano /tmp/feat_analysis.py
python3 /tmp/feat_analysis.py
grep -c "CashOut" /root/bot.log /root/eth_bot.log /root/sol_bot.log 2>/dev/null
grep -n "Mid-trade\|CashOut\|cash" /root/real_bot.py | head -8
grep "LOSS" /root/trade_log.csv | tail -10
python3 -c "
 import csv
 from collections import defaultdict
 wins_by_hour = defaultdict(lambda:{'w':0,'l':0,'wpnl':0.0,'lpnl':0.0})
 for f in ['/root/trade_log.csv','/root/eth_trade_log.csv','/root/sol_trade_log.csv']:
     for row in csv.reader(open(f)):
         if len(row)<5 or row[0]<'2026-03-25': continue
         try:
             h = int(row[0][11:13])
             bet = float(row[2])
             if row[3]=='WIN':
                 wins_by_hour[h]['w']+=1
                 wins_by_hour[h]['wpnl']+=bet*float(row[4].replace('%',''))/100
             elif row[3]=='LOSS':
                 wins_by_hour[h]['l']+=1
                 wins_by_hour[h]['lpnl']+=bet
         except: pass
 print('Hour | W | L | WR% | Net PnL')
 print('-'*45)
 for h in sorted(wins_by_hour):
     v=wins_by_hour[h]
     t=v['w']+v['l']
     wr=v['w']/t*100 if t else 0
     net=v['wpnl']-v['lpnl']
     flag='🔴' if wr<60 else '🟡' if wr<75 else '🟢'
     print(f'{h:02d}:00 | {v[\"w\"]:3d}W | {v[\"l\"]:2d}L | {wr:5.1f}% | \${net:+.2f} {flag}')
 " 2>/dev/null
nano /tmp/hourly_analysis.py
python3 /tmp/hourly_analysis.py
nano /tmp/fix_tod2.py
python3 /tmp/fix_tod2.py
nano /tmp/fix_cashout.py
python3 /tmp/fix_tod2.py
sed -i "s|open('/root/real_bot.py')|open('/root/eth_bot.py')|g" /tmp/fix_tod2.py
sed -i "s|open('/root/real_bot.py')|open('/root/eth_bot.py')|g" /tmp/fix_cashout.py
pkill -f real_bot.py
nano /tmp/hourly_by_bot.py
python3 /tmp/hourly_by_bot.py
nano /tmp/fix_smart_tod.py
cpython3 /tmp/fix_smart_tod.py
python3 /tmp/fix_smart_tod.py
grep -n "def place_order" /root/real_bot.py | head -1
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/def place_order(direction, bet, strategy_tag="directional", mkt_yes=None, mkt_no=None):/def place_order(direction, bet, strategy_tag="directional", mkt_yes=None, mkt_no=None):\n    if get_max_bet() == 0.00:\n        print(f"[TOD] Skipping trade — bad hour for this bot")\n        return False/' $f;  done
pkill -f real_bot.py
grep "TOD\|Skipping" /root/eth_bot.log | tail -5
nano /root/auto_tune_tod.py
python3 /root/auto_tune_tod.py
(crontab -l 2>/dev/null; echo "0 6 */2 * * python3 /root/auto_tune_tod.py >> /root/auto_tune.log 2>&1") | crontab -
cp /root/real_bot.py /root/real_bot_v3_stable.py
cat /root/eth_bot.log | tail -8
python3 -c "
 import json
 items = []
 for line in open('/root/news_log.json'):
     try:
         d = json.loads(line.strip())
         if d.get('score',0) >= 7:
             items.append(d)
     except: pass
 items.sort(key=lambda x: x.get('score',0), reverse=True)
 for item in items[:10]:
     print(f\"[{item['score']}] {item.get('source','')} — {item.get('title','')[:80]}\")
     print(f\"  {item.get('link','')}\")
     print()
 " 2>/dev/null
nano /tmp/show_news.py
python3 /tmp/show_news.py
python3 /tmp/status_all.py
cp /root/real_bot.py /root/real_bot_v3_stable.py
grep -n "sys_html" /root/dashboard.py | head -8
sed -n '538,548p' /root/dashboard.py
grep -n "return f'''" /root/dashboard.py
sed -n '370,380p' /root/dashboard.py
grep -n "feature_table\|ai_insight" /root/dashboard.py | grep -v "def \|build_\|#" | head -10
cat /root/dashboard.log | tail -5
nano /tmp/add_polyrouter.py
python3 /tmp/add_polyrouter.py
grep -n "Binance.*Confirms\|spot_price = get_binance" real_bot.py | head -5
sed -n '650,670p' real_bot.py
nano /tmp/add_poly_wire.py
python3 /tmp/add_poly_wire.py
sed -n '650,653p' real_bot.py | cat -A
grep -n "consecutive=2 | bet" real_bot.py | head -3
sed -n '650,653p' real_bot.py | cat -A
nano /tmp/add_kraken.py
python3 /tmp/add_kraken.py
python3 /tmp/test_prices.py
pkill -f real_bot.py
cp /root/eth_bot.py /root/eth_bot_v1_stable.py
sed -n '500,530p' /root/real_bot.py
grep -n "window_minute\|EXTREME\|consecutive_signal_count < 2\|Strong first" /root/real_bot.py | head -10
sed -n '578,605p' /root/real_bot.py
nano /tmp/fix_early_entry.py
python3 /tmp/fix_early_entry.py
sed -n '606,620p' real_bot.py
nano /tmp/fix_else.py
python3 /tmp/fix_else.py
# Item 2: Tighten threshold to 0.75/0.25
# Item 2: Tighten thresholds on all three bots
grep "MAX_BET_PCT" /root/real_bot.py | head -5
# BTC and ETH: 7% base
# Apply early entry fix to ETH and SOL
pkill -f real_bot.py
grep "assert MARKET_SERIES" /root/real_bot.py
sed -i 's/MARKET_SERIES    = "KXBTC15M"  # DO NOT CHANGE — BTC bot only/MARKET_SERIES    = "KXBTC15M"  # DO NOT CHANGE — BTC bot only\nassert MARKET_SERIES == "KXBTC15M", "WRONG MARKET in real_bot.py"/' /root/real_bot.py
cp /root/real_bot.py /root/real_bot_v3_stable.py
pkill -f dashboard.py
python3 -m py_compile /root/dashboard.py && echo "OK"
cp /root/dashboard.py /root/dashboard_v3_stable.py
grep "TOD\|Skipping" /root/eth_bot.log | tail -5
grep "Settled.*LOSS" /root/eth_bot.log | tail -5
nano /tmp/fix_feature_table.py
python3 /tmp/fix_feature_table.py
grep -n "def build_feature_table" /root/dashboard.py
sed -n '1,30p' /root/dashboard.py | grep -n "def build_feature"
grep -n "def build_feature_table\|def build_ai_insight" /root/dashboard.py
nano /tmp/fix_feat2.py
python3 /tmp/fix_feat2.py
nano /tmp/new_feature_func.py
python3 /tmp/new_feature_func.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
grep -n "spot_price = get_binance" /root/real_bot.py | head -3
grep "Settled.*LOSS" /root/sol_bot.log | tail -3
sed -n '595,650p' /root/real_bot.py
nano /tmp/add_correlation.py
python3 /tmp/add_correlation.py
grep -n "CONFIRMED.*consecutive=2\|consecutive=2.*bet=" real_bot.py | head -3
nano /tmp/add_corr2.py
python3 /tmp/add_corr2.py
pkill -f real_bot.py
cp /root/real_bot.py /root/real_bot_v3_stable.py
source kalshi_env/bin/activate
python3 /tmp/status_all.py
grep -n "Cross-market correlation\|TOD.*Skipping\|get_max_bet.*0.00" /root/real_bot.py | head -5
grep -n "bet = round(bet \* 0.80\|bet = round(bet \* 0.40" /root/real_bot.py | head -5
grep "STRONG MIN1" /root/bot.log /root/eth_bot.log /root/sol_bot.log 2>/dev/null | head -5
nano /tmp/fix_correlation.py
python3 /tmp/fix_correlation.py
sed -n '628,635p' real_bot.py
nano /tmp/fix_indent3.py
python3 /tmp/fix_indent3.py
# Apply correlation fix to ETH and SOL
pkill -f real_bot.py
nohup python3 -u /root/real_bot.py > /root/bot.log 2>&1 &
grep -c "Correlation\|STRONG MIN1\|TOD.*Skipping\|DIRECTIONAL_HIGH = 0.75" /root/real_bot.py
sed -i 's/MAX_BET_PCT        = 0.05    # 5% of balance per order/MAX_BET_PCT        = 0.07    # 7% of balance per order/' /root/real_bot.py
sed -n '628,636p' /root/real_bot.py
nano /tmp/fix_corr_guard.py
python3 /tmp/fix_corr_guard.py
grep -n "Cross-market correlation" /root/eth_bot.py
sed -n '628,634p' /root/real_bot.py
nano /tmp/add_corr_eth_sol.py
python3 /tmp/add_corr_eth_sol.py
pkill -f real_bot.py && pkill -f eth_bot.py && pkill -f sol_bot.py
grep -n "def log_trade" /root/eth_bot.py | head -2
grep -A3 "def log_trade" /root/eth_bot.py | head -6
nano /tmp/fix_logtrade_eth_sol.py
python3 /tmp/fix_logtrade_eth_sol.py
grep -n "log_trade.*outcome\|log_trade.*WIN\|log_trade.*LOSS" /root/eth_bot.py | head -5
nano /tmp/add_features_settlement.py
python3 /tmp/add_features_settlement.py
grep -n "OPEN_POSITIONS.append" /root/eth_bot.py | head -2
sed -n '461,475p' /root/eth_bot.py
for f in /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/            "entry_time":   datetime.datetime.now().isoformat(),/            "entry_time":   datetime.datetime.now().isoformat(),\n            "entry_yes":    mkt_yes if mkt_yes else 0.5,\n            "min_yes":      mkt_yes if mkt_yes else 0.5,\n            "max_yes":      mkt_yes if mkt_yes else 0.5,\n            "signal_type":  "EXTREME" if mkt_yes and (mkt_yes > 0.80 or mkt_yes < 0.20) else "STANDARD",\n            "entry_minute": datetime.datetime.now(datetime.timezone.utc).minute % 15,/' $f;  done
pkill -f eth_bot.py && pkill -f sol_bot.py
nano /root/OPENCLAW_GUIDE.md
wc -l /root/OPENCLAW_GUIDE.md
nano /tmp/add_docs.py
source kalshi_env/bin/activate
code = open('/root/dashboard.py').read()
nano /tmp/add_docs.py
python3 /tmp/add_docs.py
sed -i 's|<div class="footer">Auto-refresh 20s • OpenClaw v3.1</div>|<div class="footer">Auto-refresh 20s • OpenClaw v3.1 • <a href="/docs" style="color:var(--blue)">📖 Guide</a></div>|' /root/dashboard.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
source kalshi_env/bin/activate
python3 -c "
 import requests, tempfile
 from kalshi_python import KalshiClient
 from kalshi_python.configuration import Configuration
 
 raw = open('/root/real_bot.py').read()
 KEY = raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]
 SEC = raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]
 
 tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
 tf.write(SEC); tf.close()
 
 config = Configuration()
 config.host = 'https://api.elections.kalshi.com/trade-api/v2'
 kalshi = KalshiClient(config)
 kalshi.set_kalshi_auth(KEY, tf.name)
 
 url = 'https://api.elections.kalshi.com/trade-api/v2/portfolio/settlements'
 headers = kalshi.kalshi_auth.create_auth_headers('GET', url)
 resp = requests.get(url, headers=headers, params={'limit': 50}, timeout=8)
 print(resp.status_code)
 if resp.status_code == 200:
     data = resp.json()
     print(list(data.keys()))
     print(str(data)[:500])
 " 2>/dev/null
nano /tmp/fix_deposits.py
python3 /tmp/fix_deposits.py
grep -n "Total Portfolio Value\|bal-sub\|TOD.*badge" /root/dashboard.py | head -5
sed -i 's|<div class="bal-sub">Total Portfolio Value — TOD: <span style="color:{tod_col}">{tod_size} bet size</span> at {utc_hour:02d}:00 UTC</div>|<div class="bal-sub">Total Portfolio Value — TOD: <span style="color:{tod_col}">{tod_size} bet size</span> at {utc_hour:02d}:00 UTC</div>\n<div style="display:flex;gap:12px;margin-top:6px;font-size:11px;flex-wrap:wrap">\n  <span style="color:var(--muted)">Deposited: <span style="color:var(--text)">\${TOTAL_DEPOSITED:.2f}</span></span>\n  <span style="color:var(--muted)">True P\\&amp;L: <span style="color:{"var(--green)" if balance>=TOTAL_DEPOSITED else "var(--red)"}">\${balance-TOTAL_DEPOSITED:+.2f}</span></span>\n  <span style="color:var(--muted)">Since Mar 25: <span style="color:{"var(--green)" if balance>=CLEAN_START_DEPOSITED else "var(--red)"}">\${balance-CLEAN_START_DEPOSITED:+.2f}</span></span>\n</div>|' /root/dashboard.py
pkill -f dashboard.py
cp /root/dashboard.py /root/dashboard_v3_stable.py
grep -E "Correlation|STRONG|Settled|WIN|LOSS" /root/bot.log | tail -10
source kalshi_env/bin/activate
nohup python3 -u /root/real_bot.py > /root/bot.log 2>&1 &
cat /root/watchdog.log | tail -10
kill 495284
cat /root/eth_bot.log | tail -15
grep -E "HALT|MIN_BALANCE|SystemExit|Error|Traceback" /root/bot.log | tail -10
grep "Settled" /root/bot.log | tail -10
python3 /tmp/check_balance.py
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/INITIAL_BALANCE    = [0-9.]*/INITIAL_BALANCE    = 216.65/' $f;      sed -i 's/SESSION_START_BAL  = [0-9.]*/SESSION_START_BAL  = 216.65/' $f;      sed -i 's/MIN_BALANCE      = [0-9.]*/MIN_BALANCE      = 185.00/' $f;  done
grep -E "Error|Traceback|assert|WRONG MARKET" /root/watchdog.log | tail -10
pkill -f real_bot.py && pkill -f eth_bot.py && pkill -f sol_bot.py
cp /root/real_bot.py /root/real_bot_v3_stable.py
grep -E "assert|AssertionError|WRONG MARKET" /root/bot.log /root/eth_bot.log /root/sol_bot.log 2>/dev/null | head -10
python3 /tmp/check_balance.py
python3 -c "
 import requests, tempfile
 from kalshi_python import KalshiClient
 from kalshi_python.configuration import Configuration
 raw = open('/root/real_bot.py').read()
 KEY = raw.split(\"KALSHI_API_KEY = '\")[1].split(\"'\")[0]
 SEC = raw.split(\"KALSHI_SECRET  = '''\")[1].split(\"'''\")[0]
 tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
 tf.write(SEC); tf.close()
 config = Configuration()
 config.host = 'https://api.elections.kalshi.com/trade-api/v2'
 kalshi = KalshiClient(config)
 kalshi.set_kalshi_auth(KEY, tf.name)
 url = 'https://api.elections.kalshi.com/trade-api/v2/portfolio/positions'
 headers = kalshi.kalshi_auth.create_auth_headers('GET', url)
 resp = requests.get(url, headers=headers, params={'limit':20}, timeout=8)
 positions = resp.json().get('market_positions', [])
 print(f'Open positions: {len(positions)}')
 for p in positions:
     print(f'  {p.get(\"ticker\")} | exposure=\${float(p.get(\"market_exposure_dollars\",0)):.2f}')
 " 2>/dev/null
nano /tmp/check_positions.py
python3 /tmp/check_positions.py
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/INITIAL_BALANCE    = 216.65/INITIAL_BALANCE    = 213.85/' $f;      sed -i 's/SESSION_START_BAL  = 216.65/SESSION_START_BAL  = 213.85/' $f;  done
cat /root/sol_bot.log | tail -8
grep "2026-04-01.*LOSS" /root/trade_log.csv | tail -5
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/MAX_BET_PCT        = 0.07    # 7% of balance per order/MAX_BET_PCT        = 0.05    # 5% of balance per order/' $f;  done
pkill -f real_bot.py && pkill -f eth_bot.py && pkill -f sol_bot.py
cp /root/real_bot.py /root/real_bot_v3_stable.py
grep "Directional" /root/bot.log | head -1
cat /root/bot.log | tail -8
grep "2026-04-01 17" /root/sol_trade_log.csv | tail -5
grep "2026-04-01" /root/trade_log.csv | grep "LOSS\|WIN" | tail -10
grep "2026-04-01 17" /root/trade_log.csv | tail -5
grep "csv_path\|csv_files\|botfile" /root/sol_bot.py | head -8
grep -A 8 "csv_files = {" /root/sol_bot.py | head -10
python3 /tmp/check_positions.py
for f in /root/real_bot.py /root/eth_bot.py /root/sol_bot.py; do      sed -i 's/"eth_bot.py": "\/root\/eth_trade_log.csv",/"btc_bot.py": "\/root\/trade_log.csv",\n        "real_bot.py": "\/root\/trade_log.csv",\n        "eth_bot.py": "\/root\/eth_trade_log.csv",/' $f;  done
cat /root/bot.log | tail -5
cp /root/real_bot.py /root/real_bot_v3_stable.py
source kalshi_env/bin/activate
python3 /tmp/status_all.py
python3 /tmp/check_balance.py
touch /root/STOP_ETH
touch /root/STOP
grep "MARKET_SERIES" /root/real_bot.py | head -1
source kalshi_env/bin/activate
grep -n "def get_live_ticker\|live_ticker\|series_ticker" /root/real_bot.py | head -10
grep -n "^live_ticker\|^LIVE_TICKER" /root/real_bot.py | head -5
grep -n "def get_live_ticker" /root/real_bot.py
grep -n "def get_live_ticker" /root/real_bot.py | head -1
sed -n '188,245p' /root/real_bot.py
grep -n "def build_ticker" /root/real_bot.py
grep -n "restart_bot\|Popen\|subprocess" /root/watchdog.py | head -10
sed -n '55,75p' /root/watchdog.py
nano /tmp/fix_watchdog.py
python3 /tmp/fix_watchdog.py
rm -f /root/STOP /root/STOP_ETH /root/STOP_SOL
kill 508433
ps aux | grep -E "real_bot|eth_bot|sol_bot" | grep -v grep | wc -l
nano /root/RESTART_PROCEDURE.md
sed -n '70,95p' /root/watchdog.py
nano /tmp/fix_watchdog_autostart.py
python3 /tmp/fix_watchdog_autostart.py
sed -i 's/8. Watchdog will start all three bots automatically within 5 minutes/8. Watchdog auto-starts all bots immediately on launch/' /root/RESTART_PROCEDURE.md
cp /root/watchdog.py /root/watchdog_stable.py
python3 /tmp/status_all.py
source kalshi_env/bin/activate
python3 /tmp/check_balance.py
grep -n "DAILY_LOSS\|daily_loss\|SESSION_START_BAL\|loss_pct" /root/real_bot.py | head -10
cat /root/bot.log | tail -8
grep -n "SESSION_START_BAL\|get_live_balance\|live_bal" /root/real_bot.py | head -10
sed -i 's/DIRECTIONAL_HIGH = 0.75/DIRECTIONAL_HIGH = 0.70/' /root/real_bot.py
sed -n '958,975p' /root/real_bot.py
nano /tmp/fix_session_start.py
python3 /tmp/fix_session_start.py
pkill -f watchdog.py
grep "Live balance\|Startup" /root/bot.log | head -5
ps aux | grep -E "real_bot|eth_bot|sol_bot|watchdog" | grep -v grep
tail -5 /root/bot.log
cp /root/real_bot.py /root/real_bot_v3_stable.py
python3 /tmp/status_all.py
source kalshi_env/bin/activate
grep -n "CashOut\|Mid-trade\|cash_out\|adverse" /root/real_bot.py | head -10
grep -n "Mid-trade\|CashOut\|adverse_move\|age_min" /root/real_bot.py | head -10
grep -n "Restored position\|load_existing_positions\|OPEN_POSITIONS.append" /root/real_bot.py | head -8
sed -n '718,770p' /root/real_bot.py
nano /tmp/fix_cashout_restore.py
python3 /tmp/fix_cashout_restore.py
grep -n "MARKET_SERIES in ticker" /root/real_bot.py | head -3
sed -i 's/OpenClaw SOL Bot v1.0/OpenClaw BTC Bot v3.0/' /root/real_bot.py
pkill -f watchdog.py
sed -i 's/                if ticker and exposure > 0:/                if ticker and exposure > 0 and MARKET_SERIES in ticker:/' /root/real_bot.py
grep "Settled.*LOSS" /root/eth_bot.log /root/sol_bot.log | tail -10
grep "TOD\|Skipping\|bad hour" /root/sol_bot.log | tail -5
pkill -f watchdog.py
grep "MARKET_SERIES in ticker" /root/real_bot.py
nohup python3 -u /root/real_bot.py > /root/bot.log 2>&1 &
python3 /tmp/check_positions.py
pkill -f real_bot.py
grep "Restored\|Live balance" /root/eth_bot.log | tail -5
ps aux | grep -E "real_bot|eth_bot|sol_bot|watchdog" | grep -v grep
python3 /tmp/check_positions.py
cat /root/bot.log | tail -6
cp /root/real_bot.py /root/real_bot_v3_stable.py
sleep 120 && grep -E "CONFIRMED|EXTREME|Settled|WIN|LOSS|CashOut" /root/bot.log /root/eth_bot.log /root/sol_bot.log 2>/dev/null | tail -15
grep -n "if get_max_bet.*0.00\|TOD.*Skipping" /root/sol_bot.py | head -5
nano /tmp/fix_tod_extreme.py
python3 /tmp/fix_tod_extreme.py
pkill -f watchdog.py
sed -n '1,100p' /root/real_bot.py
sed -n '100,200p' /root/real_bot.py
grep "KALSHI_API_KEY\|BOT_TOKEN\|CHAT_ID" /root/real_bot.py | head -5
grep "KALSHI_API_KEY\|KALSHI_SECRET\|BOT_TOKEN\|CHAT_ID" /root/real_bot.py | head -6
grep -n "def \|class \|import \|^[A-Z]" /root/real_bot.py | head -60
57:BOT_TOKEN = '8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
grep -n "def " /root/real_bot.py
grep -n "def get_trend_validator\|get_btc_prices\|send_hourly\|numpy\|np\." /root/real_bot.py | head -10
grep -n "RISK_SCORE\|update_regime\|circuit_breaker\|session_start_time" /root/real_bot.py | head -10
sed -n '240,265p' /root/real_bot.py
cat > /root/openclaw_btc_v4.py << 'ENDOFFILE'
 #!/usr/bin/env python3
 """
 OpenClaw BTC Bot v4.0 — Complete Clean Rebuild
 ================================================
 Market: Kalshi KXBTC15M (15-minute Bitcoin up/down contracts)
 Strategy: Favorite-longshot bias + calibration edge
 Signals: EXTREME > STRONG_MIN1 > STANDARD
 Confirmations: Coinbase spot + Kraken cross-check + 3-market correlation
 Risk: Smart TOD scaling, daily loss limit, cash out monitor, circuit breaker
 Author: OpenClaw / Claude — April 2026
 """
 
 import os, time, csv, datetime, requests, tempfile, json, numpy as np
 from kalshi_python import KalshiClient
 from kalshi_python.configuration import Configuration
 
 # ── CREDENTIALS ───────────────────────────────────────────────────────────────
 # Read from existing bot to avoid re-entering
 _raw           = open('/root/real_bot.py').read()
 KALSHI_API_KEY = _raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
 KALSHI_SECRET  = _raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
 BOT_TOKEN      = _raw.split("BOT_TOKEN = '")[1].split("'")[0]
 CHAT_ID        = _raw.split("CHAT_ID   = '")[1].split("'")[0]
 del _raw
 
 # ── KALSHI CLIENT ─────────────────────────────────────────────────────────────
 _tf = tempfile.NamedTemporaryFile(delete=False, suffix=".pem", mode="w")
 _tf.write(KALSHI_SECRET); _tf.close()
 _config = Configuration()
 _config.host = "https://api.elections.kalshi.com/trade-api/v2"
 kalshi = KalshiClient(_config)
 kalshi.set_kalshi_auth(KALSHI_API_KEY, _tf.name)
 
 # ── BOT IDENTITY ──────────────────────────────────────────────────────────────
 BOT_NAME      = "OpenClaw BTC Bot v4.0"
 MARKET_SERIES = "KXBTC15M"  # DO NOT CHANGE — BTC bot only
 assert MARKET_SERIES == "KXBTC15M", f"WRONG MARKET: {MARKET_SERIES}"
 STOP_FILE     = "/root/STOP"
 LOG_CSV       = "/root/trade_log.csv"
 PERF_LOG      = "/root/performance_log.json"
 FEAT_LOG      = "/root/feature_log.json"
 
 # ── TRADING CONFIG ────────────────────────────────────────────────────────────
 DRY_RUN          = False
 MAX_BET_PCT      = 0.07      # 7% base — scales with TOD
 PEAK_BET_PCT     = 0.10      # 10% during peak hours
 MIN_BALANCE      = 185.00    # hard floor — halt if below
 DAILY_LOSS_LIMIT = 0.12      # 12% daily loss triggers halt
 CYCLE_SLEEP      = 60        # seconds between cycles
 COOLDOWN_CYCLES  = 2         # cycles to skip after failed order
 ARB_THRESHOLD    = 0.97      # YES+NO below this = arb opportunity
 DIRECTIONAL_HIGH = 0.70      # signal fires above this
 DIRECTIONAL_LOW  = 0.30      # signal fires below this
 EXTREME_HIGH     = 0.80      # immediate fire, no confirmation needed
 EXTREME_LOW      = 0.20      # immediate fire, no confirmation needed
 STRONG_MIN1_EDGE = 0.30      # min edge for early minute-1 entry
 MIN_EDGE         = 0.20      # skip signals with edge below this (avoid weak trades)
 CASHOUT_MINUTES  = 5         # start checking cashout after this many minutes
 CASHOUT_ADVERSE  = 0.30      # adverse move threshold to trigger cashout
 
 # ── TOD SCHEDULE ─────────────────────────────────────────────────────────────
 # Based on real historical win rate data (274 trades analyzed)
 # 0.0 = stop completely, 1.0 = full size, peak hours get PEAK_BET_PCT
 TOD_SCHEDULE = {
     0: 0.40,   # 62% WR — reduced
     1: 0.25,   # 56% WR — poor
     2: 1.00,   # 76% WR — good
     3: 1.00,   # 94% WR — PEAK
     4: 0.40,   # 56% WR — poor
     5: 0.00,   # 43% WR — STOP (net negative)
     6: 1.00,   # 93% WR — PEAK
     7: 1.00,   # 90% WR — PEAK
     8: 1.00,   # 87% WR — PEAK
     9: 1.00,   # 92% WR — PEAK
     10: 1.00,  # 81% WR — PEAK
     11: 1.00,  # 91% WR — PEAK
     12: 0.50,  # 60% WR — reduced
     13: 0.50,  # 60% WR — reduced
     14: 1.00,  # 89% WR — PEAK
     15: 1.00,  # 100% WR — PEAK
     16: 1.00,  # 88% WR — PEAK
     17: 0.75,  # 69% WR — moderate
     18: 0.75,  # 67% WR — moderate
     19: 1.00,  # 91% WR — PEAK
     20: 0.75,  # 67% WR — moderate
     21: 1.00,  # 95% WR — PEAK
     22: 0.25,  # 56% WR — poor
     23: 0.75,  # 67% WR — moderate
 }
 PEAK_HOURS = {3,6,7,8,9,10,11,14,15,16,19,21}
 
 # ── BALANCE & SESSION STATE ───────────────────────────────────────────────────
 INITIAL_BALANCE   = 200.29
 SESSION_START_BAL = 200.29
 CURRENT_BALANCE   = INITIAL_BALANCE
 
 # ── RUNTIME STATE ─────────────────────────────────────────────────────────────
 OPEN_POSITIONS           = []
 COOLDOWN_REMAINING       = 0
 REGIME                   = "CHOP"
 RISK_SCORE               = 0.4
 last_signal_direction    = None
 consecutive_signal_count = 0
 session_wins             = 0
 session_losses           = 0
 session_pnl              = 0.0
 live_ticker              = None
 session_start_time       = time.time()
 _last_summary_hour       = -1
 
 # ─────────────────────────────────────────────────────────────────────────────
 # BET SIZING — Kelly-informed with TOD scaling
 # ─────────────────────────────────────────────────────────────────────────────
 def get_max_bet(is_extreme=False):
     """
     Dynamic bet sizing based on:
     - Time of day (historical win rate per hour)
     - Peak vs normal hours
     - Extreme signal bypass during bad hours (3% floor)
     - Balance-proportional with hard caps
     """
     hour      = datetime.datetime.now(datetime.timezone.utc).hour
     tod_scale = TOD_SCHEDULE.get(hour, 1.0)
 
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
