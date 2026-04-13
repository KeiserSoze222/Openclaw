#!/usr/bin/env python3
import requests,tempfile,csv,json,datetime,os
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
today=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
url="https://api.elections.kalshi.com/trade-api/v2/portfolio/fills"
all_fills=[]
cursor=None
while True:
    hdrs=k.kalshi_auth.create_auth_headers("GET",url)
    params={"limit":100}
    if cursor: params["cursor"]=cursor
    r=requests.get(url,headers=hdrs,params=params,timeout=10)
    d=r.json()
    fills=d.get("fills",[])
    all_fills.extend(fills)
    cursor=d.get("cursor")
    if not cursor or not fills: break
today_fills=[f for f in all_fills if today in f.get("created_time","") and f.get("action")=="buy"]
kalshi_total=sum(float(f.get("count_fp",0))*float(f.get("no_price_dollars",0) if f.get("side")=="no" else f.get("yes_price_dollars",0)) for f in today_fills)
placed=[]
for f,m in [('/root/trade_log.csv','BTC'),('/root/eth_trade_log.csv','ETH'),('/root/sol_trade_log.csv','SOL')]:
    for r in csv.reader(open(f)):
        if len(r)>=6 and today in r[0] and 'PLACED' in r[3]:
            placed.append(float(r[2]))
log_total=sum(placed)
gap=kalshi_total-log_total
report={
    "date":today,
    "kalshi_fills":len(today_fills),
    "kalshi_total":round(kalshi_total,2),
    "logged_placed":len(placed),
    "logged_total":round(log_total,2),
    "gap":round(gap,2),
    "gap_pct":round(gap/kalshi_total*100,1) if kalshi_total>0 else 0
}
print(json.dumps(report,indent=2))
log_file='/root/reconcile_log.jsonl'
with open(log_file,'a') as lf: lf.write(json.dumps(report)+'\n')
print(f"\nSaved to {log_file}")

