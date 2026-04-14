#!/usr/bin/env python3
"""OpenClaw Whale Follower v1 — mirror large bets on our markets"""
import requests,time,datetime,csv,os,tempfile,threading
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration

raw=open('/root/real_bot_pre_v4_backup.py').read()
BOT_TOKEN=raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID=raw.split("CHAT_ID   = '")[1].split("'")[0]
key=raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
sec=raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
tf=tempfile.NamedTemporaryFile(delete=False,suffix='.pem',mode='w')
tf.write(sec);tf.close()
cfg=Configuration();cfg.host="https://api.elections.kalshi.com/trade-api/v2"
kalshi=KalshiClient(cfg);kalshi.set_kalshi_auth(key,tf.name)

TRADES_URL="https://api.elections.kalshi.com/trade-api/v2/markets/trades"
MIN_WHALE_SIZE=3000
FOLLOW_BET=10.00
MAX_FOLLOW_BET=20.00
OUR_MARKETS=("KXBTC15M","KXETH15M","KXSOL15M")
LOG_CSV="/root/whale_follow_log.csv"
STOP_FILE="/root/STOP_WHALE"
seen_ids=set()
followed_windows=set()

def send_telegram(msg):
    try: requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",json={"chat_id":CHAT_ID,"text":str(msg)},timeout=8)
    except: pass

def get_balance():
    try:
        url="https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
        h=kalshi.kalshi_auth.create_auth_headers("GET",url)
        d=requests.get(url,headers=h,timeout=5).json()
        return (d.get("balance",0)+d.get("portfolio_value",0))/100
    except: return 0

def place_follow(ticker,side,whale_size):
    try:
        balance=get_balance()
        if balance<50:
            print(f"[Follow] Balance ${balance:.2f} too low — skipping")
            return
        bet=min(MAX_FOLLOW_BET,max(FOLLOW_BET,round(whale_size/200,2)))
        bet=min(bet,balance*0.05)
        url=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
        h=kalshi.kalshi_auth.create_auth_headers("GET",url)
        mkt=requests.get(url,headers=h,timeout=5).json().get("market",{})
        status=mkt.get("status","")
        if status!="active":
            print(f"[Follow] Market {ticker} not active ({status}) — skipping")
            return
        yes_p=float(mkt.get("yes_ask_dollars") or 0.5)
        no_p=float(mkt.get("no_ask_dollars") or 0.5)
        entry_p=yes_p if side=="YES" else no_p
        if entry_p>0.92:
            print(f"[Follow] Entry {entry_p:.2f} too high — skipping")
            return
        count=max(1,int(bet/entry_p))
        yes_price=min(99,max(1,round(yes_p*100)+5)) if side=="YES" else None
        no_price=min(99,max(1,round(no_p*100)+5)) if side=="NO" else None
        order=kalshi.create_order(ticker=ticker,action="buy",
            side=side.lower(),type="market",count=count,
            yes_price=yes_price,no_price=no_price,time_in_force="ioc")
        cost=round(count*entry_p,2)
        msg=f"🐋 WHALE FOLLOW: {side} {count}c @ ${entry_p:.2f} = ${cost:.2f}\n{ticker}\nWhale size: ${whale_size:,.0f}"
        print(msg)
        send_telegram(msg)
        with open(LOG_CSV,"a",newline="") as f:
            csv.writer(f).writerow([datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),ticker,side,f"{cost:.2f}",f"{whale_size:.0f}"])
    except Exception as e:
        print(f"[Follow] Error: {e}")

def scan():
    min_ts=int(time.time())-60
    while True:
        if os.path.exists(STOP_FILE): break
        try:
            h={"accept":"application/json"}
            r=requests.get(TRADES_URL,params={"limit":100,"min_ts":min_ts},headers=h,timeout=10)
            trades=r.json().get("trades",[]) if r.status_code==200 else []
            for t in trades:
                tid=t.get("trade_id","")
                if not tid or tid in seen_ids: continue
                seen_ids.add(tid)
                ticker=t.get("ticker","")
                if not any(m in ticker for m in OUR_MARKETS): continue
                side=t.get("taker_side","").upper()
                count=float(t.get("count_fp") or 0)
                yes_p=float(t.get("yes_price_dollars") or 0.5)
                size=round(count*yes_p if side=="YES" else count*(1-yes_p),2)
                if size<MIN_WHALE_SIZE: continue
                window=ticker.split("-",1)[-1] if "-" in ticker else ticker
                if window in followed_windows:
                    print(f"[Follow] Already followed {window} — skipping")
                    continue
                followed_windows.add(window)
                print(f"[Follow] Whale ${size:,.0f} {side} on {ticker} — following!")
                threading.Thread(target=place_follow,args=(ticker,side,size),daemon=True).start()
            min_ts=int(time.time())-5
        except Exception as e:
            print(f"[Follow] Scan error: {e}")
        time.sleep(15)

if __name__=="__main__":
    print("🐋 Whale Follower v1 starting...")
    print(f"Min whale: ${MIN_WHALE_SIZE:,} | Follow bet: ${FOLLOW_BET}-${MAX_FOLLOW_BET}")
    scan()
