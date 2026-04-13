#!/usr/bin/env python3
import requests,time,json,subprocess,datetime,csv,os,tempfile
from collections import defaultdict

raw=open('/root/real_bot_pre_v4_backup.py').read()
BOT_TOKEN=raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID=raw.split("CHAT_ID   = '")[1].split("'")[0]
KALSHI_KEY=raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
KALSHI_SEC=raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w')
tf.write(KALSHI_SEC);tf.close()
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
cfg=Configuration()
cfg.host="https://api.elections.kalshi.com/trade-api/v2"
k=KalshiClient(cfg)
k.set_kalshi_auth(KALSHI_KEY,tf.name)

BASE=f"https://api.telegram.org/bot{BOT_TOKEN}"
last_update_id=0

def send(msg):
    try: requests.post(f"{BASE}/sendMessage",json={"chat_id":CHAT_ID,"text":msg},timeout=8)
    except: pass

def get_balance():
    url="https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
    hdrs=k.kalshi_auth.create_auth_headers("GET",url)
    d=requests.get(url,headers=hdrs,timeout=8).json()
    return d.get('balance',0)/100,d.get('portfolio_value',0)/100

def get_positions():
    url="https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
    hdrs=k.kalshi_auth.create_auth_headers("GET",url)
    pos=requests.get(url,headers=hdrs,params={"limit":100},timeout=8).json().get('market_positions',[])
    return [p for p in pos if float(p.get('market_exposure_dollars',0))>0]

def get_stats():
    w=defaultdict(int); l=defaultdict(int)
    for f,m in [('/root/trade_log.csv','BTC'),('/root/eth_trade_log.csv','ETH'),('/root/sol_trade_log.csv','SOL')]:
        for r in csv.reader(open(f)):
            if len(r)>=4:
                if 'WIN' in r[3]: w[m]+=1; w['ALL']+=1
                elif 'LOSS' in r[3]: l[m]+=1; l['ALL']+=1
    return w,l

def cmd_status():
    cash,port=get_balance()
    pos=get_positions()
    w,l=get_stats()
    total=w['ALL']+l['ALL']
    wr=w['ALL']/total*100 if total else 0
    now=datetime.datetime.utcnow().strftime('%H:%M UTC')
    msg=f"🤖 OpenClaw Status — {now}\n"
    msg+=f"💰 Cash: ${cash:.2f} | Open: ${port:.2f}\n"
    msg+=f"📊 {w['ALL']}W/{l['ALL']}L ({wr:.0f}%)\n"
    msg+=f"  BTC: {w['BTC']}W/{l['BTC']}L | ETH: {w['ETH']}W/{l['ETH']}L | SOL: {w['SOL']}W/{l['SOL']}L\n"
    msg+=f"📈 Open positions: {len(pos)}\n"
    for p in pos: msg+=f"  {p.get('ticker','')[-15:]} ${float(p.get('market_exposure_dollars',0)):.2f}\n"
    locks=[f for f in os.listdir('/tmp') if f.startswith('openclaw_window_')]
    msg+=f"🔒 Window locks: {len(locks)}"
    send(msg)

def cmd_pause():
    for m in ['btc','eth','sol']:
        open(f'/root/STOP_{m.upper()}' if m!='btc' else '/root/STOP','w').write('paused')
    send("⏸ All bots paused — STOP files created")

def cmd_resume():
    for f in ['/root/STOP','/root/STOP_ETH','/root/STOP_SOL']:
        try: os.remove(f)
        except: pass
    send("▶️ All bots resumed — STOP files removed")

def cmd_balance():
    cash,port=get_balance()
    send(f"💰 Cash: ${cash:.2f}\n📈 Portfolio: ${port:.2f}\n💎 Total: ${cash+port:.2f}")

def cmd_help():
    send("🤖 OpenClaw Commands:\n/status — full system status\n/balance — quick balance check\n/pause — pause all bots\n/resume — resume all bots\n/help — this message")

def handle(text):
    t=text.strip().lower()
    if t=='/status': cmd_status()
    elif t=='/balance': cmd_balance()
    elif t=='/pause': cmd_pause()
    elif t=='/resume': cmd_resume()
    elif t=='/help': cmd_help()
    else: send(f"Unknown command: {text}\nTry /help")

print("[TelegramCommander] Starting...")
send("🤖 OpenClaw Commander online! Type /help for commands.")
while True:
    try:
        r=requests.get(f"{BASE}/getUpdates",params={"offset":last_update_id+1,"timeout":30},timeout=35)
        for upd in r.json().get("result",[]):
            last_update_id=upd["update_id"]
            msg=upd.get("message",{})
            if str(msg.get("chat",{}).get("id",""))!=CHAT_ID: continue
            text=msg.get("text","")
            if text: handle(text)
    except Exception as e:
        print(f"[Commander] Error: {e}")
        time.sleep(5)

