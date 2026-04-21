#!/usr/bin/env python3
import requests,tempfile,csv,json,datetime
from collections import defaultdict

BOT_TOKEN='8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
CHAT_ID='8257178399'
KALSHI_KEY='2d0a8c45-b76a-4459-a0e1-9a5e4d63fd8b'
KALSHI_SEC='''-----BEGIN RSA PRIVATE KEY-----
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
tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w')
tf.write(KALSHI_SEC);tf.close()
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
cfg=Configuration()
cfg.host="https://api.elections.kalshi.com/trade-api/v2"
k=KalshiClient(cfg)
k.set_kalshi_auth(KALSHI_KEY,tf.name)

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
cashout_wins=defaultdict(int); cashout_losses=defaultdict(int)
cashout_pnl=defaultdict(float)
for f,m in [('/root/trade_log.csv','BTC'),('/root/eth_trade_log.csv','ETH'),('/root/sol_trade_log.csv','SOL')]:
    try:
        for row in csv.reader(open(f)):
            if len(row)>=5 and yesterday in row[0]:
                action=row[3] if len(row)>3 else ''
                if 'WIN' in action and 'CASHOUT' not in action:
                    w[m]+=1; w['ALL']+=1
                    try: pnl[m]+=float(row[4].replace('%',''))*float(row[2])/100; pnl['ALL']+=float(row[4].replace('%',''))*float(row[2])/100
                    except: pass
                elif 'LOSS' in action and 'CASHOUT' not in action:
                    l[m]+=1; l['ALL']+=1
                    try: pnl[m]-=float(row[2]); pnl['ALL']-=float(row[2])
                    except: pass
                elif action=='CASHOUT_WIN':
                    cashout_wins[m]+=1; cashout_wins['ALL']+=1
                    try: cashout_pnl[m]+=float(row[4].replace('%',''))*float(row[2])/100; cashout_pnl['ALL']+=float(row[4].replace('%',''))*float(row[2])/100
                    except: pass
                elif action=='CASHOUT_LOSS':
                    cashout_losses[m]+=1; cashout_losses['ALL']+=1
                    try: cashout_pnl[m]-=float(row[2]); cashout_pnl['ALL']-=float(row[2])
                    except: pass
    except FileNotFoundError:
        pass

total=w['ALL']+l['ALL']
wr=w['ALL']/total*100 if total else 0
total_cashouts=cashout_wins['ALL']+cashout_losses['ALL']

# Gap calculation
logged_total=sum(float(r[2]) for f in ['/root/trade_log.csv','/root/eth_trade_log.csv','/root/sol_trade_log.csv'] for r in csv.reader(open(f)) if len(r)>=4 and yesterday in r[0] and 'PLACED' in r[3])
gap=kalshi_total-logged_total
gap_pct=gap/kalshi_total*100 if kalshi_total>0 else 0

msg=f"🌅 OpenClaw Morning Report — {today}\n"
msg+=f"💰 Balance: ${balance:.2f} | Open: ${portfolio:.2f}\n"
msg+=f"📊 Yesterday: {w['ALL']}W/{l['ALL']}L ({wr:.0f}%) | Net: ${pnl['ALL']:+.2f}\n"
msg+=f"  BTC: {w['BTC']}W/{l['BTC']}L | ETH: {w['ETH']}W/{l['ETH']}L | SOL: {w['SOL']}W/{l['SOL']}L\n"
if total_cashouts>0:
    co_wr=cashout_wins['ALL']/total_cashouts*100
    msg+=f"💸 Cashouts: {cashout_wins['ALL']}W/{cashout_losses['ALL']}L ({co_wr:.0f}%) | Net: ${cashout_pnl['ALL']:+.2f}\n"
msg+=f"🔍 Reconcile: Kalshi=${kalshi_total:.2f} | Logged=${logged_total:.2f} | Gap={gap_pct:.1f}%"

print(msg)
send(msg)
with open('/root/reconcile_log.jsonl','a') as rf:
    rf.write(json.dumps({"date":today,"balance":balance,"yesterday_wr":round(wr,1),"yesterday_pnl":round(pnl['ALL'],2),"gap_pct":round(gap_pct,1)})+'\n')
