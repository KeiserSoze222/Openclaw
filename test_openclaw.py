#!/usr/bin/env python3
"""OpenClaw regression test suite - run after every change"""
import sys,os,json,subprocess
errors=[]
warnings=[]

def check(name,condition,msg):
    if not condition:
        errors.append(f"❌ {name}: {msg}")
    else:
        print(f"✅ {name}")

def warn(name,condition,msg):
    if not condition:
        warnings.append(f"⚠️  {name}: {msg}")
    else:
        print(f"✅ {name}")

print("=== OpenClaw Test Suite ===\n")

# 1. Syntax check
r=subprocess.run(["python3","-m","py_compile","/root/openclaw.py"],capture_output=True)
check("Syntax check",r.returncode==0,"openclaw.py has syntax errors")

# 2. Critical config values
import importlib.util
try:
    src=open('/root/openclaw.py').read()
    check("MIN_BALANCE defined","MIN_BALANCE" in src,"MIN_BALANCE not found")
    check("DRY_RUN via args","dry_run" in src,"DRY_RUN arg missing")
    check("USE_ERV=False","USE_ERV=False" in src or "USE_ERV = False" in src,"USE_ERV may be True")
    check("Entry price cap","entry_price>0.92" in src,"Entry price cap missing")
    check("Cashout price range","0.001<float(ya)<0.999" in src,"Cashout price range too narrow - will miss near-zero prices!")
    check("Min profit filter","expected_profit<2.00" in src,"Min profit filter missing")
    check("Kraken BTC-only","get_kraken_btc() if MARKET_SERIES" in src,"Kraken not limited to BTC")
    check("Trend filter BULL","REGIME==\"BULL\" and current_direction==\"DOWN\"" in src,"BULL trend filter missing")
    check("Trend filter BEAR","REGIME==\"BEAR\" and current_direction==\"UP\"" in src,"BEAR trend filter missing")
    check("Cashout params","CASHOUT_ADVERSE=0.20" in src and "CASHOUT_MINUTES=2" in src,"Cashout params wrong")
    check("Window lock on fail","openclaw_window_" in src,"Window lock missing")
    check("Max bet 30","min(30.00" in src,"Max bet not set to 30")
    check("PEAK_BET_PCT 0.14","PEAK_BET_PCT=0.14" in src,"PEAK_BET_PCT not 0.14")
except Exception as e:
    errors.append(f"❌ Config check failed: {e}")

# 3. Arena check
try:
    src2=open('/root/arena.py').read()
    check("Arena DRY_RUN","DRY_RUN=True" in src2 or "DRY_RUN = True" in src2,"Arena DRY_RUN not True!")
except Exception as e:
    errors.append(f"❌ Arena check failed: {e}")

# 4. Key files exist
for f in ['/root/openclaw.py','/root/arena.py','/root/dashboard_v4.py','/root/bond_scanner.py','/root/health.py','/root/morning_report.py','/root/whale_scanner.py']:
    check(f"File exists: {f.split('/')[-1]}",os.path.exists(f),f"Missing: {f}")

# 5. Performance logs exist
for f in ['/root/trade_log.csv','/root/eth_trade_log.csv','/root/sol_trade_log.csv']:
    check(f"Log exists: {f.split('/')[-1]}",os.path.exists(f),f"Missing: {f}")

# 6. PM2 processes
r=subprocess.run(["pm2","jlist"],capture_output=True,text=True)
if r.returncode==0:
    procs=json.loads(r.stdout)
    online=[p['name'] for p in procs if p.get('pm2_env',{}).get('status')=='online']
    for name in ['openclaw-btc','openclaw-eth','openclaw-sol','arena','price-historian','whale-scanner']:
        check(f"PM2: {name}",name in online,f"{name} not online!")

print(f"\n=== Results ===")
if errors:
    print(f"\nFAILED ({len(errors)} errors):")
    for e in errors: print(e)
else:
    print("All critical checks passed!")
if warnings:
    print(f"\nWarnings ({len(warnings)}):")
    for w in warnings: print(w)
print(f"\nTotal: {len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors else 0)

