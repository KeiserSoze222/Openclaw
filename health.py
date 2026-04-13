import requests,tempfile,json,os,datetime,csv
from collections import defaultdict

raw=open('/root/real_bot_pre_v4_backup.py').read()
key=raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
sec=raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w')
tf.write(sec);tf.close()
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
cfg=Configuration()
cfg.host="https://api.elections.kalshi.com/trade-api/v2"
k=KalshiClient(cfg)
k.set_kalshi_auth(key,tf.name)

# Balance
url="https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
hdrs=k.kalshi_auth.create_auth_headers("GET",url)
d=requests.get(url,headers=hdrs,timeout=8).json()
cash=d.get('balance',0)/100
portfolio=d.get('portfolio_value',0)/100

# Open positions
url2="https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
hdrs2=k.kalshi_auth.create_auth_headers("GET",url2)
pos=requests.get(url2,headers=hdrs2,params={"limit":100},timeout=8).json().get('market_positions',[])
open_pos=[p for p in pos if float(p.get('market_exposure_dollars',0))>0]

# Trade stats
today=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
w=defaultdict(int); l=defaultdict(int); pnl=defaultdict(float)
for f,m in [('/root/trade_log.csv','BTC'),('/root/eth_trade_log.csv','ETH'),('/root/sol_trade_log.csv','SOL')]:
    for r in csv.reader(open(f)):
        if len(r)>=4:
            if 'WIN' in r[3]: w[m]+=1; w['ALL']+=1
            elif 'LOSS' in r[3]: l[m]+=1; l['ALL']+=1

# Lock files
locks=[f for f in os.listdir('/tmp') if f.startswith('openclaw_window_')]

# PM2 status
import subprocess
pm2=subprocess.check_output(['pm2','jlist'],timeout=5).decode()
procs=json.loads(pm2)
running={p['name']:p['pm2_env']['status'] for p in procs}

print(f"\n{'='*50}")
print(f"OpenClaw Health Check — {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}")
print(f"{'='*50}")
print(f"💰 Cash: ${cash:.2f} | Portfolio: ${portfolio:.2f} | Total: ${cash+portfolio:.2f}")
print(f"📊 ALL: {w['ALL']}W/{l['ALL']}L ({w['ALL']/(w['ALL']+l['ALL'])*100:.0f}%)" if (w['ALL']+l['ALL'])>0 else "No trades")
print(f"   BTC: {w['BTC']}W/{l['BTC']}L | ETH: {w['ETH']}W/{l['ETH']}L | SOL: {w['SOL']}W/{l['SOL']}L")
print(f"📈 Open positions: {len(open_pos)}")
for p in open_pos: print(f"   {p.get('ticker','')} ${float(p.get('market_exposure_dollars',0)):.2f}")
print(f"🔒 Active window locks: {len(locks)}")
for lk in locks[:3]: print(f"   {lk.replace('openclaw_window_','').replace('.lock','')}")
print(f"⚙️  Processes:")
for name in ['openclaw-btc','openclaw-eth','openclaw-sol','arena','price-historian','whale-scanner']:
    status=running.get(name,'unknown')
    icon='✅' if status=='online' else '❌'
    print(f"   {icon} {name}: {status}")
print(f"{'='*50}\n")
