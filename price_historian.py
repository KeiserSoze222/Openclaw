#!/usr/bin/env python3
import requests,time,datetime,json,os
TRADES_URL="https://api.elections.kalshi.com/trade-api/v2/markets/trades"
MARKETS_URL="https://api.elections.kalshi.com/trade-api/v2/markets"
OUR_MARKETS=("KXBTC15M","KXETH15M","KXSOL15M")
SCAN_INTERVAL=10
LOG_FILE="/root/price_history.jsonl"
STOP_FILE="/root/STOP_PRICE_HIST"
seen_ids=set()
def get_market_price(ticker):
    try:
        r=requests.get(f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}",timeout=4)
        if r.status_code==200:
            m=r.json().get("market",{})
            return {"yes_ask":m.get("yes_ask_dollars"),"yes_bid":m.get("yes_bid_dollars"),"no_ask":m.get("no_ask_dollars"),"no_bid":m.get("no_bid_dollars"),"last":m.get("last_price_dollars"),"volume":m.get("volume")}
    except: return {}
    return {}
def get_active_tickers():
    tickers=[]
    try:
        for series in OUR_MARKETS:
            r=requests.get(MARKETS_URL,params={"status":"open","series_ticker":series,"limit":5},timeout=8)
            if r.status_code==200:
                for m in r.json().get("markets",[]):
                    tk=m.get("ticker","")
                    if tk: tickers.append(tk)
    except: pass
    return tickers
def fetch_trades(min_ts):
    try:
        r=requests.get(TRADES_URL,params={"limit":200,"min_ts":min_ts},timeout=10)
        if r.status_code==200: return r.json().get("trades",[])
    except: pass
    return []
def log_entry(entry):
    with open(LOG_FILE,"a") as f: f.write(json.dumps(entry)+"\n")
def scan(min_ts):
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    wm=datetime.datetime.now(datetime.timezone.utc).minute%15
    for ticker in get_active_tickers():
        if not any(m in ticker for m in OUR_MARKETS): continue
        p=get_market_price(ticker)
        if p and p.get("yes_ask"):
            log_entry({"ts":now,"ticker":ticker,"type":"snapshot","yes_ask":p.get("yes_ask"),"yes_bid":p.get("yes_bid"),"no_ask":p.get("no_ask"),"no_bid":p.get("no_bid"),"last":p.get("last"),"volume":p.get("volume"),"window_minute":wm})
    new_ts=min_ts
    for t in fetch_trades(min_ts):
        tid=t.get("trade_id","")
        if not tid or tid in seen_ids: continue
        seen_ids.add(tid)
        ticker=t.get("ticker","")
        if not any(m in ticker for m in OUR_MARKETS): continue
        ts_val=t.get("ts") or 0
        if isinstance(ts_val,(int,float)) and ts_val>new_ts: new_ts=ts_val
        log_entry({"ts":now,"trade_ts":str(ts_val),"ticker":ticker,"type":"trade","side":t.get("taker_side",""),"count":t.get("count_fp"),"yes_price":t.get("yes_price_dollars"),"no_price":t.get("no_price_dollars"),"trade_id":tid})
    return new_ts
if __name__=="__main__":
    print("[PriceHistorian] Starting")
    min_ts=int(time.time())-300
    cycle=0
    while True:
        if os.path.exists(STOP_FILE): break
        try:
            min_ts=scan(min_ts)
            cycle+=1
            if cycle%60==0:
                size=os.path.getsize(LOG_FILE)/1024/1024 if os.path.exists(LOG_FILE) else 0
                print(f"[PH] Cycle {cycle} | Log: {size:.1f}MB")
        except Exception as e: print(f"[PH] Error: {e}")
        time.sleep(SCAN_INTERVAL)

