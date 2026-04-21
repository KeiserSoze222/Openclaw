#!/usr/bin/env python3
import requests,time,json,subprocess,datetime,csv,os,tempfile
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
    send("🤖 OpenClaw Commands:\n/status — full system status\n/balance — quick balance check\n/positions — list open positions\n/health — bot process health (pm2)\n/pause — pause all bots\n/resume — resume all bots\n/restart — restart all bots\n/locks — show active window locks\n/clearlocks — clear all window locks\n/help — this message")

def cmd_restart():
    import subprocess
    subprocess.Popen(['pm2','restart','openclaw-btc','openclaw-eth','openclaw-sol'])
    send('🔄 Restarting all bots...')

def cmd_locks():
    import os
    locks=[f for f in os.listdir('/tmp') if f.startswith('openclaw_window_')]
    if locks:
        msg='🔒 Active locks:\n'+'\n'.join(l.replace('openclaw_window_','').replace('.lock','') for l in locks)
    else:
        msg='✅ No active window locks'
    send(msg)

def cmd_clearlocks():
    import os,glob
    locks=glob.glob("/tmp/openclaw_window_*.lock")
    for l in locks: os.remove(l)
    send(f"🔓 Cleared {len(locks)} window locks")

def cmd_positions():
    try:
        pos=get_positions()
        if not pos:
            send("📭 No open positions")
            return
        msg=f"📈 Open Positions ({len(pos)})\n"
        for p in pos:
            ticker=p.get('ticker','')
            exp=float(p.get('market_exposure_dollars',0))
            yes_c=float(p.get('yes_count',0) or 0)
            no_c=float(p.get('no_count',0) or 0)
            side="YES" if yes_c>0 else "NO"
            contracts=int(yes_c if yes_c>0 else no_c)
            mkt_series="BTC" if "BTC" in ticker else ("ETH" if "ETH" in ticker else "SOL")
            msg+=f"  {mkt_series} {side} {contracts}c ${exp:.2f} | {ticker[-12:]}\n"
        send(msg.strip())
    except Exception as e:
        send(f"⚠️ Positions error: {e}")

def cmd_health():
    try:
        result=subprocess.run(['pm2','jlist'],capture_output=True,text=True,timeout=8)
        procs=json.loads(result.stdout) if result.stdout else []
        lines=["🏥 Bot Health:"]
        for p in procs:
            name=p.get('name','')
            if 'openclaw' not in name: continue
            status=p.get('pm2_env',{}).get('status','?')
            restarts=p.get('pm2_env',{}).get('restart_time',0)
            mem=p.get('monit',{}).get('memory',0)//1024//1024
            icon="✅" if status=="online" else "❌"
            lines.append(f"{icon} {name}: {status} | restarts={restarts} | mem={mem}MB")
        if len(lines)==1:
            lines.append("No openclaw processes found in pm2")
        send('\n'.join(lines))
    except Exception as e:
        send(f"⚠️ Health check error: {e}")

def handle(text):
    t=text.strip().lower()
    if t=='/status': cmd_status()
    elif t=='/balance': cmd_balance()
    elif t=='/pause': cmd_pause()
    elif t=='/resume': cmd_resume()
    elif t=='/restart': cmd_restart()
    elif t=='/locks': cmd_locks()
    elif t=="/clearlocks": cmd_clearlocks()
    elif t=='/positions': cmd_positions()
    elif t=='/health': cmd_health()
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

