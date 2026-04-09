import requests, time, datetime, json, os, tempfile

raw = open('/root/real_bot_pre_v4_backup.py').read()
KALSHI_KEY = raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
KALSHI_SEC = raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
BOT_TOKEN  = raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID    = raw.split("CHAT_ID   = '")[1].split("'")[0]

ARB_LOG      = '/root/arb_log.json'
MIN_MINUTES  = 5
MAX_MINUTES  = 45
MAX_COST     = 10.0
MIN_NET_PCT  = 2.0
SCAN_SLEEP   = 120
placed       = set()

tf = tempfile.NamedTemporaryFile(delete=False, suffix=".pem", mode="w")
tf.write(KALSHI_SEC)
tf.close()

from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
cfg = Configuration()
cfg.host = "https://api.elections.kalshi.com/trade-api/v2"
k = KalshiClient(cfg)
k.set_kalshi_auth(KALSHI_KEY, tf.name)

def hdrs(m, u):
    return k.kalshi_auth.create_auth_headers(m, u)

def tg(msg):
try:
requests.get(
"https://api.telegram.org/bot" + BOT_TOKEN + "/sendMessage",
params={"chat_id": CHAT_ID, "text": msg}, timeout=5
)
except Exception:
pass

def get_balance():
url = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
r = requests.get(url, headers=hdrs("GET", url), timeout=5)
if r.status_code == 200:
d = r.json()
return (d.get('balance', 0) + d.get('portfolio_value', 0)) / 100
return 0

def scan_arb():
url = "https://api.elections.kalshi.com/trade-api/v2/markets"
arbs = []
cursor = ""
while True:
params = {"status": "open", "limit": 100}
if cursor:
params["cursor"] = cursor
r = requests.get(url, headers=hdrs("GET", url), params=params, timeout=10)
if r.status_code != 200:
break
data = r.json()
for m in data.get("markets", []):
ticker  = m.get("ticker", "")
yes_ask = m.get("yes_ask_dollars")
no_ask  = m.get("no_ask_dollars")
close_ts = m.get("close_time") or m.get("expiration_time")
volume  = m.get("volume", 0) or 0
if not yes_ask or not no_ask or not close_ts:
continue
if ticker in placed or volume < 1000:
continue
yp = float(yes_ask)
np = float(no_ask)
cb = yp + np
if cb >= 0.97 or cb <= 0.50:
continue
try:
cd = datetime.datetime.fromisoformat(close_ts.replace("Z", "+00:00"))
ml = (cd - datetime.datetime.now(datetime.timezone.utc)).total_seconds() / 60
except Exception:
continue
if ml < MIN_MINUTES or ml > MAX_MINUTES:
continue
gross = 1.0 - cb
net = gross * 0.93
pct = (net / cb) * 100
if pct < MIN_NET_PCT:
continue
arbs.append({
"ticker": ticker, "yp": yp, "np": np,
"cb": cb, "pct": pct, "ml": ml, "vol": volume
})
cursor = data.get("cursor", "")
if not cursor:
break
return sorted(arbs, key=lambda x: x["pct"], reverse=True)

def execute(arb):
ticker = arb["ticker"]
yp     = arb["yp"]
np     = arb["np"]
n      = max(1, int(MAX_COST / arb["cb"]))
yc     = min(99, max(1, round(yp * 100) + 1))
nc     = min(99, max(1, round(np * 100) + 1))
try:
k.create_order(ticker=ticker, action="buy", side="yes",
type="market", count=n, yes_price=yc, time_in_force="ioc")
k.create_order(ticker=ticker, action="buy", side="no",
type="market", count=n, no_price=nc, time_in_force="ioc")
placed.add(ticker)
cost   = n * arb["cb"]
profit = n * (1.0 - arb["cb"])
msg = ("ARB " + ticker +
" YES@" + str(round(yp, 3)) +
"+NO@" + str(round(np, 3)) +
"=" + str(round(arb["cb"], 3)) +
" x" + str(n) +
" cost=$" + str(round(cost, 2)) +
" profit=$" + str(round(profit, 2)) +
" (" + str(round(arb["pct"], 1)) + "%)" +
" " + str(round(arb["ml"], 0)) + "min")
print(msg)
tg(msg)
with open(ARB_LOG, "a") as f:
f.write(json.dumps({
"ts": datetime.datetime.now().isoformat(),
"ticker": ticker, "yp": yp, "np": np,
"cb": arb["cb"], "n": n,
"cost": cost, "profit": profit
}) + "\n")
return True
except Exception as e:
print("[Arb] fail: " + str(e))
return False

print("Arb scanner v1 started")
tg("Arb scanner started - hunting YES+NO < 0.97 opportunities")

while True:
if os.path.exists("/root/STOP_ARB"):
print("STOP_ARB detected - halting")
break
try:
arbs = scan_arb()
bal  = get_balance()
print("[" + datetime.datetime.now().strftime("%H:%M") + "] " +
str(len(arbs)) + " arbs found | bal=$" + str(round(bal, 2)))
if arbs:
a = arbs[0]
print("  TOP: " + a["ticker"] +
" cb=" + str(round(a["cb"], 3)) +
" net=" + str(round(a["pct"], 1)) + "%")
for arb in arbs[:2]:
execute(arb)
except Exception as e:
print("[Arb] scan err: " + str(e))
time.sleep(SCAN_SLEEP)
