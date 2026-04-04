#!/usr/bin/env python3
"""OpenClaw Pre-Break Health Check — run before stepping away"""
import subprocess, requests, tempfile, csv, datetime, os
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"
ok = lambda s: print(f"{GREEN}✅ {s}{RESET}")
warn = lambda s: print(f"{YELLOW}⚠️  {s}{RESET}")
fail = lambda s: print(f"{RED}❌ {s}{RESET}")

print("\n" + "="*50)
print("  OPENCLAW HEALTH CHECK")
print("  " + datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"))
print("="*50 + "\n")

issues = 0

# 1. Process check
result = subprocess.run(["pgrep", "-f", "openclaw.py"], capture_output=True)
count = len(result.stdout.decode().strip().split('\n')) if result.returncode==0 else 0
if count >= 3:
    ok(f"Bots running: {count} processes")
else:
    fail(f"Only {count} bot processes running — expected 3+")
    issues += 1

result2 = subprocess.run(["pgrep", "-f", "watchdog.py"], capture_output=True)
if result2.returncode == 0:
    ok("Watchdog running")
else:
    fail("Watchdog NOT running")
    issues += 1

# 2. Error check
for name, logf in [("BTC","/root/bot.log"),("ETH","/root/eth_bot.log"),("SOL","/root/sol_bot.log")]:
    try:
        lines = open(logf).readlines()[-200:]
        today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        errors = [l for l in lines if "entry_yes" in l or "Traceback" in l]
        recent_errors = [l for l in errors if today in l]
        if recent_errors:
            fail(f"{name} has {len(recent_errors)} recent errors: {recent_errors[-1][:60]}")
            issues += 1
        else:
            ok(f"{name} log clean — no errors")
    except: warn(f"Could not read {name} log")

# 3. Resting order check
for name, logf in [("BTC","/root/bot.log"),("ETH","/root/eth_bot.log"),("SOL","/root/sol_bot.log")]:
    try:
        lines = open(logf).readlines()[-100:]
        today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        resting = [l for l in lines if "resting" in l and today in l and "Cancelled" not in l]
        if resting:
            warn(f"{name} has {len(resting)} recent resting orders")
        else:
            ok(f"{name} no resting orders")
    except: pass

# 4. Balance check
try:
    raw = open('/root/real_bot_pre_v4_backup.py').read()
    key = raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
    sec = raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
    tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
    tf.write(sec); tf.close()
    config = Configuration()
    config.host = "https://api.elections.kalshi.com/trade-api/v2"
    kalshi = KalshiClient(config)
    kalshi.set_kalshi_auth(key, tf.name)
    url = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
    h = kalshi.kalshi_auth.create_auth_headers("GET", url)
    r = requests.get(url, headers=h, timeout=6)
    d = r.json()
    bal = (d.get("balance",0) + d.get("portfolio_value",0)) / 100
    if bal >= 155:
        ok(f"Balance: ${bal:.2f}")
    elif bal >= 140:
        warn(f"Balance low: ${bal:.2f}")
    else:
        fail(f"Balance critical: ${bal:.2f}")
        issues += 1
except Exception as e:
    warn(f"Could not check balance: {e}")

# 5. Open positions check
try:
    url2 = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
    h2 = kalshi.kalshi_auth.create_auth_headers("GET", url2)
    r2 = requests.get(url2, headers=h2, params={"limit":20}, timeout=6)
    positions = r2.json().get("market_positions", [])
    if positions:
        warn(f"{len(positions)} open positions — bots are active")
        for p in positions:
            print(f"   {p.get('ticker')} exposure={p.get('market_exposure_dollars',0)}")
    else:
        ok("No stuck open positions")
except: pass

# 6. Watchdog log check
try:
    wlog = open('/root/watchdog.log').readlines()[-20:]
    crashes = [l for l in wlog if "crashed" in l]
    if crashes:
        warn(f"{len(crashes)} recent crashes: {crashes[-1].strip()}")
        issues += 1
    else:
        ok("No recent crashes in watchdog")
except: pass

# 7. Halt loop detection
try:
    wlog = open('/root/watchdog.log').readlines()[-50:]
    recent_restarts = sum(1 for l in wlog if 'crashed and was restarted' in l)
    halts = sum(1 for l in wlog if 'HALTED' in l or 'below floor' in l)
    if recent_restarts >= 3:
        fail(f"HALT LOOP: {recent_restarts} restarts, {halts} halts detected") 
        fail("FIX: Lower MIN_BALANCE in openclaw.py or add funds")
        issues += 1
    elif recent_restarts >= 1:
        warn(f"{recent_restarts} recent restart(s) — monitor closely")
    else:
        ok("No halt loop detected")
except Exception as he:
    warn(f"Could not check halt loop: {he}")

# Summary
print("\n" + "="*50)
if issues == 0:
    print(f"{GREEN}  ✅ ALL CLEAR — safe to step away{RESET}")
else:
    print(f"{RED}  ❌ {issues} ISSUE(S) FOUND — fix before leaving{RESET}")
print("="*50 + "\n")
