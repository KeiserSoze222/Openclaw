#!/usr/bin/env python3
import requests,tempfile,csv,json,datetime
from collections import defaultdict

raw=open('/root/real_bot_pre_v4_backup.py').read()
BOT_TOKEN=raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID=raw.split("CHAT_ID   = '")[1].split("'")[0]
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

def send(msg):
    try: requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",json={"chat_id":CHAT_ID,"text":msg},timeout=8)
    except: pass

yesterday=(datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=1)).strftime('%Y-%m-%d')
today=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')

# Get Kalshi balance
url="https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
hdrs=k.kalshi_auth.create_auth_headers("GET",url)
d=requests.get(url,headers=hdrs,timeout=8).json()
balance=d.get('balance',0)/100
portfolio=d.get('portfolio_value',0)/100

# Get yesterday's fills
url2="https://api.elections.kalshi.com/trade-api/v2/portfolio/fills"
all_fills=[]
cursor=None
while True:
    hdrs2=k.kalshi_auth.create_auth_headers("GET",url2)
    params={"limit":100}
    if cursor: params["cursor"]=cursor
    r=requests.get(url2,headers=hdrs2,params=params,timeout=10)
    d2=r.json()
    fills=d2.get("fills",[])
    all_fills.extend(fills)
    cursor=d2.get("cursor")
    if not cursor or not fills: break

yesterday_fills=[f for f in all_fills if yesterday in f.get("created_time","") and f.get("action")=="buy"]
kalshi_total=sum(float(f.get("count_fp",0))*float(f.get("no_price_dollars",0) if f.get("side")=="no" else f.get("yes_price_dollars",0)) for f in yesterday_fills)

# Get logged stats for yesterday
w=defaultdict(int); l=defaultdict(int); pnl=defaultdict(float)
for f,m in [('/root/trade_log.csv','BTC'),('/root/eth_trade_log.csv','ETH'),('/root/sol_trade_log.csv','SOL')]:
    for row in csv.reader(open(f)):
        if len(row)>=5 and yesterday in row[0]:
            if 'WIN' in row[3]:
                w[m]+=1; w['ALL']+=1
                try: pnl[m]+=float(row[4].replace('%',''))*float(row[2])/100; pnl['ALL']+=float(row[4].replace('%',''))*float(row[2])/100
                except: pass
            elif 'LOSS' in row[3]:
                l[m]+=1; l['ALL']+=1
                try: pnl[m]-=float(row[2]); pnl['ALL']-=float(row[2])
                except: pass

total=w['ALL']+l['ALL']
wr=w['ALL']/total*100 if total else 0

# Gap calculation
logged_total=sum(float(r[2]) for f in ['/root/trade_log.csv','/root/eth_trade_log.csv','/root/sol_trade_log.csv'] for r in csv.reader(open(f)) if len(r)>=4 and yesterday in r[0] and 'PLACED' in r[3])
gap=kalshi_total-logged_total
gap_pct=gap/kalshi_total*100 if kalshi_total>0 else 0

msg=f"🌅 OpenClaw Morning Report — {today}\n"
msg+=f"💰 Balance: ${balance:.2f} | Open: ${portfolio:.2f}\n"
msg+=f"📊 Yesterday: {w['ALL']}W/{l['ALL']}L ({wr:.0f}%) | Net: ${pnl['ALL']:+.2f}\n"
msg+=f"  BTC: {w['BTC']}W/{l['BTC']}L | ETH: {w['ETH']}W/{l['ETH']}L | SOL: {w['SOL']}W/{l['SOL']}L\n"
msg+=f"🔍 Reconcile: Kalshi=${kalshi_total:.2f} | Logged=${logged_total:.2f} | Gap={gap_pct:.1f}%\n"
msg+=f"📈 All-time WR: {wr:.0f}% | {w['ALL']}W/{l['ALL']}L yesterday"

print(msg)
send(msg)
with open('/root/reconcile_log.jsonl','a') as rf:
    rf.write(json.dumps({"date":today,"balance":balance,"yesterday_wr":round(wr,1),"yesterday_pnl":round(pnl['ALL'],2),"gap_pct":round(gap_pct,1)})+'\n')
