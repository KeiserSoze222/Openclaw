#!/usr/bin/env python3
"""OpenClaw BTC Bot v4.0 — Clean Rebuild"""
import os
import time
import csv
import datetime
import requests
import tempfile
import json
import numpy as np
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration

KALSHI_API_KEY='2d0a8c45-b76a-4459-a0e1-9a5e4d63fd8b'
KALSHI_SECRET='''-----BEGIN RSA PRIVATE KEY-----
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
BOT_TOKEN='8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
CHAT_ID='8257178399'
_tf=tempfile.NamedTemporaryFile(delete=False,suffix=".pem",mode="w")
_tf.write(KALSHI_SECRET);_tf.close()
_config=Configuration()
_config.host="https://api.elections.kalshi.com/trade-api/v2"
kalshi=KalshiClient(_config)
kalshi.set_kalshi_auth(KALSHI_API_KEY,_tf.name)
import argparse as _ap
_parser = _ap.ArgumentParser()
_parser.add_argument("--market", choices=["btc","eth","sol"], default="btc")
_parser.add_argument("--dry-run", action="store_true", default=False)
_args = _parser.parse_args()
_CONFIGS = {
    "btc": ("KXBTC15M","OpenClaw BTC Bot v4.0","/root/trade_log.csv","/root/STOP",0.07,"/root/performance_log.json"),
    "eth": ("KXETH15M","OpenClaw ETH Bot v4.0","/root/eth_trade_log.csv","/root/STOP_ETH",0.09,"/root/eth_performance_log.json"),
    "sol": ("KXSOL15M","OpenClaw SOL Bot v4.0","/root/sol_trade_log.csv","/root/STOP_SOL",0.05,"/root/sol_performance_log.json"),
}
MARKET_SERIES,BOT_NAME,LOG_CSV,STOP_FILE,MAX_BET_PCT,PERF_LOG = _CONFIGS[_args.market]
assert MARKET_SERIES in ("KXBTC15M","KXETH15M","KXSOL15M"),f"Invalid market: {MARKET_SERIES}"
FEAT_LOG="/root/feature_log.json"
DRY_RUN=_args.dry_run
PEAK_BET_PCT=0.10
MIN_BALANCE=100.00
DAILY_LOSS_LIMIT=0.12
CYCLE_SLEEP=60
COOLDOWN_CYCLES=2
ARB_THRESHOLD=0.50
DIRECTIONAL_HIGH=0.68
DIRECTIONAL_LOW=0.32
EXTREME_HIGH=0.80
EXTREME_LOW=0.20
STRONG_MIN1_EDGE=0.30
MIN_EDGE=0.20
CASHOUT_MINUTES=2
CASHOUT_ADVERSE=0.20
INITIAL_BALANCE=295.66
SESSION_START_BAL=295.66
CURRENT_BALANCE=INITIAL_BALANCE
# TOD schedule — adjusted per market liquidity
if MARKET_SERIES == "KXBTC15M":
    TOD_SCHEDULE={0:0.50,1:0.30,2:0.75,3:1.25,4:0.20,5:0.00,6:1.25,7:1.25,8:1.00,9:1.25,10:1.00,11:1.25,12:0.75,13:0.40,14:1.25,15:1.50,16:1.00,17:0.85,18:0.85,19:1.25,20:0.80,21:1.25,22:0.40,23:0.50}
else:
    # ETH/SOL: reduce hours 1-5 UTC (thin liquidity causes resting orders)
    TOD_SCHEDULE={0:0.00,1:0.00,2:0.00,3:0.00,4:0.00,5:0.00,6:1.25,7:1.25,8:1.00,9:1.25,10:1.00,11:1.25,12:0.75,13:0.40,14:1.25,15:1.50,16:1.00,17:0.85,18:0.85,19:1.25,20:0.80,21:1.25,22:0.00,23:0.00}
PEAK_HOURS={3,6,7,8,9,11,14,15,16,19,21}
OPEN_POSITIONS=[]
COOLDOWN_REMAINING=0
REGIME="CHOP"
RISK_SCORE=0.60
last_signal_direction=None
consecutive_signal_count=0
session_wins=0
session_losses=0
session_pnl=0.0
live_ticker=None

_last_summary_hour=-1

def get_max_bet(is_extreme=False):
    hour=datetime.datetime.now(datetime.timezone.utc).hour
    tod_scale=TOD_SCHEDULE.get(hour,1.0)
    if tod_scale==0.0:
        return max(2.00,round(CURRENT_BALANCE*0.03,2)) if is_extreme else 0.0
    pct=PEAK_BET_PCT if hour in PEAK_HOURS else MAX_BET_PCT
    reserved=sum(p.get("bet",0) for p in OPEN_POSITIONS)
    avail=max(0,CURRENT_BALANCE-reserved)
    return max(2.00,min(22.00,round(avail*pct*tod_scale,2)))

def send_telegram(msg):
    try:
        requests.get(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            params={"chat_id":CHAT_ID,"text":str(msg)},timeout=5)
    except Exception:
        pass

def log_trade(direction,bet,action,profit_pct=0,notes="",features=None):
    ts=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(LOG_CSV,"a",newline="") as f:
            csv.writer(f).writerow([ts,direction,f"{bet:.2f}",action,f"{profit_pct:.2f}%",notes])
    except Exception:
        pass
    entry={"timestamp":ts,"direction":direction,"bet":bet,"action":action,
           "profit_pct":profit_pct,"notes":notes,"balance":CURRENT_BALANCE,
           "session_wins":session_wins,"session_losses":session_losses,
           "session_pnl":session_pnl,"regime":REGIME,"market":MARKET_SERIES}
    try:
        with open(PERF_LOG,"a") as f:
            f.write(json.dumps(entry)+"\n")
    except Exception:
        pass
    if features is not None:
        try:
            with open(FEAT_LOG,"a") as f:
                f.write(json.dumps({**entry,"features":features})+"\n")
        except Exception:
            pass

def get_live_balance():
    try:
        url="https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
        headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
        resp=requests.get(url,headers=headers,timeout=8)
        if resp.status_code==200:
            d=resp.json()
            bal=d.get("balance",0)/100  # Cash only, not portfolio_value
            if bal>0:
                return round(bal,2)
    except Exception as e:
        print(f"[Balance] Failed: {e}")
    return CURRENT_BALANCE

def get_coinbase_price(market_series):
    symbols={"KXBTC15M":"BTC-USD","KXETH15M":"ETH-USD","KXSOL15M":"SOL-USD"}
    symbol=symbols.get(market_series)
    if not symbol:
        return None
    try:
        resp=requests.get(f"https://api.coinbase.com/v2/prices/{symbol}/spot",timeout=3)
        if resp.status_code==200:
            return float(resp.json()["data"]["amount"])
    except Exception:
        pass
    return None

def get_btc_prices(minutes=60):
    try:
        resp=requests.get("https://api.kraken.com/0/public/OHLC",
            params={"pair":"XBTUSD","interval":1},timeout=8)
        if resp.status_code==200:
            candles=resp.json().get("result",{}).get("XXBTZUSD",[])
            closes=[float(c[4]) for c in candles[-minutes:]]
            if closes:
                return np.array(closes)
    except Exception as e:
        print(f"[Prices] Kraken failed: {e}")
    return np.array([83000]*minutes)

def get_kraken_btc():
    try:
        resp=requests.get("https://api.kraken.com/0/public/Ticker",
            params={"pair":"XBTUSD"},timeout=3)
        if resp.status_code==200:
            result=resp.json().get("result",{})
            if result:
                return float(list(result.values())[0]["c"][0])
    except Exception:
        pass
    return None

def get_market_prices(ticker):
    try:
        url=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
        headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
        resp=requests.get(url,headers=headers,timeout=5)
        if resp.status_code==200:
            m=resp.json().get("market",{})
            ya=m.get("yes_ask_dollars")
            na=m.get("no_ask_dollars")
            st=m.get("floor_strike",0)
            if ya is not None and na is not None:
                return float(ya),float(na),float(st or 0)
    except Exception as e:
        print(f"[Prices] {e}")
    return None,None,None

def get_orderbook_liquidity(ticker,side,contracts_needed):
    try:
        url=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}/orderbook"
        headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
        r=requests.get(url,headers=headers,timeout=4)
        if r.status_code!=200: return True,0
        ob=r.json().get("orderbook_fp",{})
        book=ob.get(f"{side}_dollars",[])
        if not book: return True,0
        best_price=float(book[0][0])
        total_qty=sum(float(x[1]) for x in book[:3])
        if total_qty<contracts_needed:
            print(f"[Liquidity] Thin {side} book: only {total_qty:.0f} contracts available, need {contracts_needed}")
            return False,best_price
        return True,best_price
    except Exception as e:
        print(f"[Liquidity] {e}")
        return True,0

def get_trend_validator():
    try:
        url="https://api.elections.kalshi.com/trade-api/v2/markets"
        headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
        resp=requests.get(url,headers=headers,
            params={"series_ticker":"KXBTC1H","status":"open","limit":5},timeout=5)
        if resp.status_code==200:
            markets=resp.json().get("markets",[])
            if markets:
                ya=markets[0].get("yes_ask_dollars")
                if ya is not None:
                    print(f"[Trend] 1H BTC: YES={float(ya):.2f}")
                    return float(ya)
    except Exception as e:
        print(f"[Trend] Failed: {e}")
    return None

def update_regime(prices):
    global REGIME,RISK_SCORE
    if len(prices)<20:
        return
    ma20=np.mean(prices[-20:])
    ma60=np.mean(prices[-60:]) if len(prices)>=60 else ma20
    current=prices[-1]
    if current>ma20*1.005 and ma20>ma60:
        REGIME,RISK_SCORE="BULL",0.75
    elif current<ma20*0.995 and ma20<ma60:
        REGIME,RISK_SCORE="BEAR",0.45
    else:
        REGIME,RISK_SCORE="CHOP",0.60

def update_live_ticker():
    global live_ticker
    def build_ticker(dt):
        floored=(dt.minute//15)*15
        hhmm=f"{dt.hour:02d}{floored:02d}"
        suffix=f"{floored:02d}"
        return (f"{MARKET_SERIES}-"
                f"{dt.strftime('%y').upper()}"
                f"{dt.strftime('%b').upper()}"
                f"{dt.strftime('%d')}"
                f"{hhmm}-{suffix}")
    for status in ("open","closed"):
        try:
            url="https://api.elections.kalshi.com/trade-api/v2/markets"
            headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
            resp=requests.get(url,headers=headers,
                params={"status":status,"series_ticker":MARKET_SERIES,"limit":5},timeout=8)
            if resp.status_code==200:
                markets=resp.json().get("markets",[])
                hits=[m for m in markets if (m.get("ticker") or "").upper().startswith(MARKET_SERIES)]
                if hits:
                    open_hits=[m for m in hits if (m.get("status") or "").lower() in ("open","active")]
                    pick=(open_hits or hits)[0]["ticker"]
                    live_ticker=pick
                    return live_ticker,(open_hits or hits)[0]
        except Exception as e:
            print(f"[Ticker] {status} error: {e}")
    now_utc=datetime.datetime.now(datetime.timezone.utc)
    t1=build_ticker(now_utc)
    live_ticker=t1
    return live_ticker,None


def write_arena_signal(market, yes_prob, regime, confidence, window_age, ticker, news_score=0, bond_score=0, whale_score=0):
    signal={"yes_prob":yes_prob,"regime":regime,"confidence":confidence,"window_age":window_age,"ticker":ticker,"news_score":news_score,"bond_score":bond_score,"whale_score":whale_score,"ts":datetime.datetime.utcnow().isoformat()}
    path=f"/root/arena_signal_{market}.json"
    try:
        open(path,"w").write(__import__("json").dumps(signal))
    except Exception as e:
        print(f"[ArenaSignal] write error: {e}")

def safety_check():
    global CURRENT_BALANCE
    CURRENT_BALANCE=get_live_balance()
    if CURRENT_BALANCE<MIN_BALANCE:
        return False,f"Balance ${CURRENT_BALANCE:.2f} below floor ${MIN_BALANCE:.2f}"
    if SESSION_START_BAL>0:
        loss_pct=(SESSION_START_BAL-CURRENT_BALANCE)/SESSION_START_BAL
        if loss_pct>=DAILY_LOSS_LIMIT:
            return False,f"Daily loss {loss_pct*100:.1f}% exceeds limit {DAILY_LOSS_LIMIT*100:.0f}%"
    total=session_wins+session_losses
    if total>=10:
        wr=session_wins/total
        if wr<0.45:
            return False,f"Circuit breaker: {wr*100:.0f}% WR over {total} trades"
    return True,"OK"

def cancel_resting_orders():
    try:
        url="https://api.elections.kalshi.com/trade-api/v2/portfolio/orders"
        headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
        resp=requests.get(url,headers=headers,params={"status":"resting","limit":50},timeout=8)
        if resp.status_code==200:
            orders=resp.json().get("orders",[])
            for order in orders:
                oid=order.get("order_id") or order.get("id")
                if not oid:
                    continue
                del_url=f"https://api.elections.kalshi.com/trade-api/v2/portfolio/orders/{oid}"
                del_hdr=kalshi.kalshi_auth.create_auth_headers("DELETE",del_url)
                requests.delete(del_url,headers=del_hdr,timeout=5)
    except Exception as e:
        print(f"[Orders] Cancel failed: {e}")

def place_order(direction,bet,strategy_tag="directional",mkt_yes=None,mkt_no=None):
    # CORRELATION GUARD — atomic file lock prevents simultaneous firing
    try:
        import time as _t
        import os as _os
        window_lock = f'/tmp/openclaw_window_{live_ticker.split("-",1)[-1]}.lock'
        try:
            if _os.path.exists(window_lock):
                age = _t.time()-_os.path.getmtime(window_lock)
                if age < 840:
                    print(f"[CorrGuard] Window {live_ticker.split("-",1)[-1]} already traded ({age:.0f}s ago) -- skipping")
                    return False
            fd = _os.open(window_lock, _os.O_CREAT|_os.O_EXCL|_os.O_WRONLY)
            _os.write(fd, str(_t.time()).encode())
            _os.close(fd)
        except Exception as _e2: print(f"[CorrGuard] lock error: {str(_e2)}")
    except Exception as _e:
        print(f"[CorrGuard] {_e}")
    global COOLDOWN_REMAINING
    ok,reason=safety_check()
    if not ok:
        print(f"[Safety] {reason}")
        send_telegram(f"🛑 HALTED: {reason}")
        raise SystemExit(reason)
    is_extreme=(mkt_yes is not None and (mkt_yes<EXTREME_LOW or mkt_yes>EXTREME_HIGH))
    max_bet=get_max_bet(is_extreme=is_extreme)
    if max_bet==0.0:
        print("[TOD] Skipping — bad hour for this bot")
        return False
    bet=min(round(bet,2),max_bet)
    bet=max(2.00,bet)
    ticker=live_ticker
    try:
        import os as _oi,time as _ti
        _ff="/tmp/openclaw_order_failed"
        if _oi.path.exists(_ff) and _ti.time()-float(open(_ff).read())<60:
            print("[Order] Global cooldown after failed order — skipping")
            return False
    except Exception: pass
    if not ticker:
        print("[Order] No ticker — skipping")
        return False
    if any(p.get("ticker")==ticker for p in OPEN_POSITIONS):
        print(f"[Order] Already have {direction} on {ticker} — skipping")
        return False
    side="yes" if direction=="UP" else "no"
    entry_price=(mkt_yes if side=="yes" else (mkt_no if mkt_no else (1-(mkt_yes or 0.5))))
    contract_count=max(1,min(25,int(bet/max(0.01,entry_price))))
    liquid,ob_price=get_orderbook_liquidity(ticker,side,contract_count)
    if not liquid:
        print(f"[Order] Insufficient liquidity for {contract_count} {side} contracts on {ticker} — skipping")
        return False
    if DRY_RUN:
        print(f"[DRY RUN] {direction} ${bet:.2f} on {ticker} ({strategy_tag})")
        log_trade(direction,bet,f"DRY_{strategy_tag.upper()}",notes=ticker)
        return True
    try:
        log_trade(direction,bet,"ATTEMPTING",notes=f"{strategy_tag}|{ticker}")
        print(f"[Order] {ticker} | {side} | count={contract_count} | ${bet:.2f}")
        yes_p=min(99,max(1,round((mkt_yes or 0.5)*100)+5)) if side=="yes" else None
        no_p=min(99,max(1,round((mkt_no or 0.5)*100)+5)) if side=="no" else None
        order=kalshi.create_order(ticker=ticker,action="buy",side=side,type="market",
            count=contract_count,yes_price=yes_p,no_price=no_p,time_in_force="ioc")
        try:
            if hasattr(order, "order") and order.order is not None:
                o = order.order
                status = str(o.status) if o.status else ""
                remaining = o.remaining_count if o.remaining_count is not None else -1
                filled = status in ("filled","executed") or (remaining == 0 and o.order_id is not None)
                filled_count=getattr(o,"filled_count",None) or getattr(o,"yes_count",None) or getattr(o,"no_count",None)
                print(f"[Order] status={status} remaining={remaining} filled={filled} filled_count={filled_count}")
            elif isinstance(order, dict):
                status = (order or {}).get("order",{}).get("status","")
                filled = status in ("filled","executed")
                print(f"[Order] dict status={status} filled={filled}")
            else:
                print(f"[Order] Unknown response: {type(order)} — treating as not filled")
                filled = False
        except Exception as ex:
            print(f"[Order] Fill check error: {ex}")
            filled = False
        if not filled:
            print(f"[Order] Not filled: {order}")
            open("/tmp/openclaw_order_failed","w").write(str(__import__("time").time()))
            # Cancel the resting order immediately to free funds
            try:
                if hasattr(order,"order") and order.order and order.order.order_id:
                    oid = order.order.order_id
                    curl = f"https://api.elections.kalshi.com/trade-api/v2/portfolio/orders/{oid}"
                    ch = kalshi.kalshi_auth.create_auth_headers("DELETE", curl)
                    requests.delete(curl, headers=ch, timeout=5)
                    print(f"[Order] Cancelled resting order {oid}")
                else:
                    cancel_resting_orders()
            except Exception as ce:
                print(f"[Order] Cancel failed: {ce}")
            COOLDOWN_REMAINING=COOLDOWN_CYCLES
            return False
        actual_cost=round(contract_count*(mkt_yes if direction=="UP" else (1-(mkt_yes or 0.5))),2) if mkt_yes else bet
        msg=f"✅ {BOT_NAME.split()[1]} {strategy_tag.upper()}: {direction} {contract_count}c @ ${(mkt_yes if direction=="UP" else (1-(mkt_yes or 0.5))):.2f} = ${actual_cost:.2f} on {ticker}"
        print(msg)
        send_telegram(msg)
        entry_yes=mkt_yes if mkt_yes is not None else (yes_price if yes_price else 0.5)
        now_utc=datetime.datetime.now(datetime.timezone.utc)
        OPEN_POSITIONS.append({"direction":direction,"bet":actual_cost,"ticker":ticker,
            "strategy":strategy_tag,"time":time.time(),"placed_at":time.time(),
            "entry_time":now_utc.isoformat(),"entry_yes":entry_yes,
            "min_yes":entry_yes,"max_yes":entry_yes,
            "signal_type":"EXTREME" if is_extreme else "STANDARD",
            "entry_minute":now_utc.minute%15,"contracts":contract_count})
        log_trade(direction,actual_cost,"PLACED",notes=f"{strategy_tag}|{ticker}")
        COOLDOWN_REMAINING=0
        return True
    except Exception as e:
        err=str(e)
        print(f"[Order] Failed: {err}")
        send_telegram(f"⚠️ Order failed: {direction} ${bet:.2f} — {err}")
        COOLDOWN_REMAINING=COOLDOWN_CYCLES
        return False

def try_arb(yes_price,no_price,ticker):
    price_sum=yes_price+no_price
    if price_sum>=ARB_THRESHOLD:
        return False
    spread=1.0-price_sum
    print(f"[ARB] YES={yes_price:.2f}+NO={no_price:.2f}={price_sum:.2f} spread={spread:.3f}")
    send_telegram(f"🎯 ARB: {ticker}\nYES={yes_price:.2f}+NO={no_price:.2f}={price_sum:.2f}")
    leg_bet=min(get_max_bet()/2,CURRENT_BALANCE*0.15)
    placed=0
    placed+=place_order("UP",leg_bet,"arb_yes",mkt_yes=yes_price,mkt_no=no_price)
    placed+=place_order("DOWN",leg_bet,"arb_no",mkt_yes=yes_price,mkt_no=no_price)
    return placed>0

def try_directional(yes_price,no_price):
    global last_signal_direction,consecutive_signal_count
    now_utc=datetime.datetime.now(datetime.timezone.utc)
    window_minute=now_utc.minute%15
    if yes_price>DIRECTIONAL_HIGH:
        current_direction="UP"
        edge=yes_price-0.5
    elif yes_price<DIRECTIONAL_LOW:
        current_direction="DOWN"
        edge=0.5-yes_price
    else:
        last_signal_direction=None
        consecutive_signal_count=0
        return False
    if edge<MIN_EDGE:
        print(f"[Signal] Edge {edge:.2f} below minimum {MIN_EDGE} — skipping")
        return False
    # CONFIDENCE SCORER (1-10) — high score = larger bet, earlier entry
    def score_confidence():
        score = 0
        reasons = []
        # Edge strength (0-3 points)
        if edge >= 0.45: score += 3; reasons.append("extreme_edge")
        elif edge >= 0.30: score += 2; reasons.append("strong_edge")
        elif edge >= 0.20: score += 1; reasons.append("moderate_edge")
        # Coinbase confirmation (0-2 points)
        try:
            spot = get_coinbase_price(MARKET_SERIES)
            if spot:
                _,_,strike = get_market_prices(live_ticker)
                if strike > 0:
                    gap = spot - strike
                    cb_agrees = (current_direction=="UP" and gap>0) or (current_direction=="DOWN" and gap<0)
                    gap_pct = abs(gap)/strike*100
                    if cb_agrees and gap_pct > 0.5: score += 2; reasons.append("coinbase_strong")
                    elif cb_agrees: score += 1; reasons.append("coinbase_weak")
        except Exception: pass
        # Cross-market correlation (0-2 points)
        try:
            btc = get_coinbase_price("KXBTC15M")
            eth = get_coinbase_price("KXETH15M")
            sol = get_coinbase_price("KXSOL15M")
            if btc and eth and sol:
                import time as _t; _t.sleep(0.5)
                btc2 = get_coinbase_price("KXBTC15M")
                eth2 = get_coinbase_price("KXETH15M")
                sol2 = get_coinbase_price("KXSOL15M")
                if btc2 and eth2 and sol2:
                    moves = [btc2>btc, eth2>eth, sol2>sol]
                    agree = sum(1 for m in moves if m) if current_direction=="UP" else sum(1 for m in moves if not m)
                    if agree >= 3: score += 2; reasons.append("all3_agree")
                    elif agree >= 2: score += 1; reasons.append("2of3_agree")
        except Exception: pass
        # Timing bonus (0-1 point)
        hour = datetime.datetime.now(datetime.timezone.utc).hour
        if hour in PEAK_HOURS: score += 1; reasons.append("peak_hour")
        # Trend validator (0-2 points)
        try:
            trend = get_trend_validator()
            if trend:
                agrees = (current_direction=="UP" and trend>0.55) or (current_direction=="DOWN" and trend<0.45)
                if agrees: score += 2; reasons.append("trend_agrees")
        except Exception: pass
        return min(score, 10), reasons

    confidence, conf_reasons = score_confidence()
    print(f"[Confidence] Score={confidence}/10 | {','.join(conf_reasons)}")
    write_arena_signal(market=_args.market,yes_prob=yes_price,regime=REGIME,confidence=confidence,window_age=window_minute,ticker=live_ticker)

    # HIGH CONFIDENCE: score 8+ in minute 0-1 = fire immediately with larger bet
    if confidence >= 8 and window_minute <= 1:
        print(f"[HighConf] Score {confidence}/10 — firing early with boosted bet")
        consecutive_signal_count = 2  # bypass confirmation requirement

    is_extreme=yes_price>EXTREME_HIGH or yes_price<EXTREME_LOW
    if is_extreme and window_minute==1:
        print(f"[Signal] EXTREME {current_direction} | yes={yes_price:.2f} | edge={edge:.2f} | firing immediately")
        consecutive_signal_count=2
    elif window_minute==1 and edge>=STRONG_MIN1_EDGE:
        spot=get_coinbase_price(MARKET_SERIES)
        confirmed=False
        if spot is not None:
            try:
                _,_,strike=get_market_prices(live_ticker)
                if strike>0:
                    spot_gap=spot-strike
                    confirmed=((current_direction=="UP" and spot_gap>0) or (current_direction=="DOWN" and spot_gap<0))
            except Exception:
                pass
        if confirmed:
            print(f"[Signal] STRONG_MIN1 {current_direction} | yes={yes_price:.2f} | edge={edge:.2f} | confirmed | firing early")
            consecutive_signal_count=2
        else:
            if window_minute==0 or window_minute>4:
                return False
            if current_direction==last_signal_direction:
                consecutive_signal_count+=1
            else:
                last_signal_direction=current_direction
                consecutive_signal_count=1
            if consecutive_signal_count<2:
                print(f"[Signal] {current_direction} candidate | yes={yes_price:.2f} | waiting (1/2)")
                return False
    else:
        if window_minute==0 or window_minute>=13:
            print(f"[Timing] Window {window_minute} min old — skipping")
            return False
        if current_direction==last_signal_direction:
            consecutive_signal_count+=1
        else:
            last_signal_direction=current_direction
            consecutive_signal_count=1
        if consecutive_signal_count<2:
            print(f"[Signal] {current_direction} candidate | yes={yes_price:.2f} | waiting (1/2)")
            return False
    scale=min(1.0,edge/0.35)
    bet=round(get_max_bet(is_extreme=is_extreme)*scale*RISK_SCORE,2)
    bet=max(2.00,min(bet,get_max_bet(is_extreme=is_extreme)))
    # Boost bet based on confidence score
    if confidence>=9:
        bet=min(round(bet*2.0,2),get_max_bet(is_extreme=is_extreme)*2.0,CURRENT_BALANCE*0.15)
        print(f"[HighConf] Score {confidence} — bet doubled to ${bet:.2f}")
    elif confidence>=8:
        bet=min(round(bet*1.50,2),get_max_bet(is_extreme=is_extreme)*1.5,CURRENT_BALANCE*0.12)
        print(f"[HighConf] Score {confidence} — bet boosted 50% to ${bet:.2f}")
    elif confidence>=7:
        bet=min(round(bet*1.25,2),get_max_bet(is_extreme=is_extreme)*1.25)
        print(f"[Conf] Score {confidence} — bet boosted 25% to ${bet:.2f}")
    bet=max(2.00,min(25.00,round(bet,2)))
    spot_price=get_coinbase_price(MARKET_SERIES)
    cb_confirmed=False
    if spot_price is not None:
        try:
            _,_,strike=get_market_prices(live_ticker)
            if strike>0:
                spot_gap=spot_price-strike
                gap_pct=abs(spot_gap)/strike*100
                cb_confirmed=((current_direction=="UP" and spot_gap>0) or (current_direction=="DOWN" and spot_gap<0))
                if cb_confirmed:
                    if gap_pct>0.3:
                        bet=min(round(bet*1.30,2),get_max_bet(is_extreme=is_extreme))
                    print(f"[Coinbase] Confirms {current_direction} | ${spot_price:.0f} gap={spot_gap:+.0f} ({gap_pct:.2f}%)")
                else:
                    bet=round(bet*0.40,2)
                    bet=max(2.00,bet)
                    print(f"[Coinbase] Disagrees | ${spot_price:.0f} — bet reduced to ${bet:.2f}")
        except Exception as e:
            print(f"[Coinbase] Strike fetch failed: {e}")
    kraken_price=get_kraken_btc()
    if kraken_price and spot_price:
        diff_pct=abs(kraken_price-spot_price)/spot_price*100
        if diff_pct>0.5:
            bet=round(bet*0.90,2)
            print(f"[Kraken] Divergence {diff_pct:.2f}% — bet trimmed")
    trend_yes=get_trend_validator()
    if trend_yes is not None:
        trend_agrees=((current_direction=="UP" and trend_yes>0.55) or (current_direction=="DOWN" and trend_yes<0.45))
        if trend_agrees:
            bet=min(round(bet*1.10,2),get_max_bet(is_extreme=is_extreme))
            print(f"[Trend] 1H agrees {current_direction} — bet boosted")
        elif ((current_direction=="UP" and trend_yes<0.40) or (current_direction=="DOWN" and trend_yes>0.60)):
            bet=round(bet*0.85,2)
            print("[Trend] 1H disagrees — bet trimmed")
    if get_max_bet(is_extreme=is_extreme)>0:
        try:
            btc1=get_coinbase_price("KXBTC15M")
            eth1=get_coinbase_price("KXETH15M")
            sol1=get_coinbase_price("KXSOL15M")
            if btc1 and eth1 and sol1:
                time.sleep(1)
                btc2=get_coinbase_price("KXBTC15M")
                eth2=get_coinbase_price("KXETH15M")
                sol2=get_coinbase_price("KXSOL15M")
                if btc2 and eth2 and sol2:
                    moves=[btc2>btc1,eth2>eth1,sol2>sol1]
                    agree=(sum(1 for m in moves if m) if current_direction=="UP" else sum(1 for m in moves if not m))
                    if agree>=3:
                        bet=min(round(bet*1.20,2),get_max_bet(is_extreme=is_extreme))
                        print("[Correlation] All 3 agree — bet boosted")
                    elif agree==1:
                        bet=round(bet*0.90,2)
                        print("[Correlation] Markets diverging — bet trimmed")
                    else:
                        print(f"[Correlation] 2/3 agree {current_direction}")
        except Exception:
            pass
    print(f"[Signal] CONFIRMED {current_direction} | yes={yes_price:.2f} | edge={edge:.2f} | bet=${bet:.2f}")
    existing=[p for p in OPEN_POSITIONS if p.get("ticker")==live_ticker
              and p.get("direction")==current_direction and p.get("strategy")!="restored"]
    if existing and edge>0.40:
        dd_bet=round(min(existing[0].get("bet",0)*0.50,get_max_bet(is_extreme=is_extreme)*0.50),2)
        dd_bet=max(2.00,dd_bet)
        print(f"[DoubleDown] edge={edge:.2f} — adding ${dd_bet:.2f}")
        result=place_order(current_direction,dd_bet,"double_down",mkt_yes=yes_price,mkt_no=no_price)
        if result:
            consecutive_signal_count=0
        return result
    result=place_order(current_direction,bet,"directional",mkt_yes=yes_price,mkt_no=no_price)
    if result:
        consecutive_signal_count=0
    return result

def check_open_positions():
    global CURRENT_BALANCE,session_wins,session_losses,session_pnl
    if not OPEN_POSITIONS:
        return
    to_remove=[]
    for pos in list(OPEN_POSITIONS):
        ticker=pos.get("ticker")
        direction=pos.get("direction")
        bet=pos.get("bet",0)
        strategy=pos.get("strategy","unknown")
        placed_at=pos.get("placed_at",0)
        age_min=(time.time()-pos.get("time",time.time()))/60
        if not ticker:
            to_remove.append(pos)
            continue
        try:
            murl=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
            mheader=kalshi.kalshi_auth.create_auth_headers("GET",murl)
            mr=requests.get(murl,headers=mheader,timeout=4)
            if mr.status_code==200:
                cur_yes=float(mr.json().get("market",{}).get("yes_ask_dollars",0.5))
                pos["min_yes"]=min(pos.get("min_yes",cur_yes),cur_yes)
                pos["max_yes"]=max(pos.get("max_yes",cur_yes),cur_yes)
        except Exception:
            pass
        age_placed=(time.time()-placed_at)/60 if placed_at>0 else 999
        # PROFIT LOCK — exit if winning and reversal detected
        if age_placed>=1.5:
            try:
                murl=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
                mheader=kalshi.kalshi_auth.create_auth_headers("GET",murl)
                mr=requests.get(murl,headers=mheader,timeout=4)
                if mr.status_code==200:
                    mkt=mr.json().get("market",{})
                    ya=mkt.get("yes_ask_dollars") or mkt.get("yes_bid_dollars")
                    entry_yes=pos.get("entry_yes",0.5)
                    cur_yes=float(ya) if ya and 0.02<float(ya)<0.98 else entry_yes
                    win_prob=(1-cur_yes) if direction=="DOWN" else cur_yes
                    reversal=((cur_yes-entry_yes)>0.08) if direction=="DOWN" else ((entry_yes-cur_yes)>0.08)
                    if win_prob>0.70 and reversal:
                        print(f"[ProfitLock] {direction} on {ticker} win={win_prob:.2f} reversing — locking profit")
                        try:
                            sell_side = "no" if direction=="UP" else "yes"
                            entry_p2=pos.get("entry_yes",0.5) if direction=="UP" else (1-pos.get("entry_yes",0.5))
                            contracts = pos.get("contracts", max(1,int(pos.get("bet",2)/entry_p2)))
                            sell_order = kalshi.create_order(
                                ticker=ticker, action="sell", side=sell_side,
                                type="market", count=contracts,
                                time_in_force="ioc"
                            )
                            if sell_order and hasattr(sell_order,"order") and sell_order.order:
                                o = sell_order.order
                                label = "ProfitLock"
                                print(f"[ProfitLock] Sell order: {o.status}")
                                if o.status == "resting" and o.order_id:
                                    try:
                                        del_url = f"https://api.elections.kalshi.com/trade-api/v2/portfolio/orders/{o.order_id}"
                                        del_h = kalshi.kalshi_auth.create_auth_headers("DELETE", del_url)
                                        requests.delete(del_url, headers=del_h, timeout=5)
                                        print(f"[{label}] Cancelled resting sell {o.order_id}")
                                    except Exception as de:
                                        print(f"[{label}] Cancel failed: {de}")
                        except Exception as se:
                            print(f"[ProfitLock] Sell failed: {se}")
                        send_telegram(f"🔒 ProfitLock: {direction} {ticker}\nwin={win_prob:.2f} | securing profit")
                        to_remove.append(pos)
                        continue
                    entry_win_prob=(1-entry_yes) if direction=="DOWN" else entry_yes
                    if win_prob<0.45 and age_placed>=2.5 and entry_win_prob>0.60:
                        print(f"[BreakEven] {direction} on {ticker} crossed 50% — exiting")
                        try:
                            sell_side = "no" if direction=="UP" else "yes"
                            entry_p2=pos.get("entry_yes",0.5) if direction=="UP" else (1-pos.get("entry_yes",0.5))
                            contracts = pos.get("contracts", max(1,int(pos.get("bet",2)/entry_p2)))
                            sell_order = kalshi.create_order(
                                ticker=ticker, action="sell", side=sell_side,
                                type="market", count=contracts,
                                time_in_force="ioc"
                            )
                            if sell_order and hasattr(sell_order,"order") and sell_order.order:
                                o = sell_order.order
                                print(f"[BreakEven] Sell order: {o.status}")
                                if o.status == "resting" and o.order_id:
                                    try:
                                        del_url = f"https://api.elections.kalshi.com/trade-api/v2/portfolio/orders/{o.order_id}"
                                        del_h = kalshi.kalshi_auth.create_auth_headers("DELETE", del_url)
                                        requests.delete(del_url, headers=del_h, timeout=5)
                                        print(f"[BreakEven] Cancelled resting sell {o.order_id}")
                                    except Exception as de:
                                        print(f"[BreakEven] Cancel failed: {de}")
                        except Exception as se:
                            print(f"[BreakEven] Sell failed: {se}")
                        send_telegram(f"⚖️ BreakEven: {direction} {ticker}\n{entry_win_prob:.0%}→{win_prob:.0%}")
                        to_remove.append(pos)
                        continue
            except Exception as pe:
                print(f"[ProfitLock] Error: {pe}")
        try:
            _iurl=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
            _ihr=kalshi.kalshi_auth.create_auth_headers("GET",_iurl)
            _imr=requests.get(_iurl,headers=_ihr,timeout=4)
            if _imr.status_code==200:
                _iya=_imr.json().get("market",{}).get("yes_ask_dollars")
                if _iya is not None:
                    _icy=float(_iya)
                    _ifloor=((direction=="UP" and _icy<0.06) or (direction=="DOWN" and _icy>0.94)) and direction in ("UP","DOWN")
                    if _ifloor and age_placed>=0.5:
                        print(f"[HardFloor] {direction} on {ticker} YES={_icy:.2f}")
                        try:
                            _ss="no" if direction=="UP" else "yes"
                            _ep=pos.get("entry_yes",0.5) if direction=="UP" else (1-pos.get("entry_yes",0.5))
                            _nc=pos.get("contracts",max(1,int(pos.get("bet",2)/_ep)))
                            _so=kalshi.create_order(ticker=ticker,action="sell",side=_ss,type="market",count=_nc,time_in_force="ioc")
                            send_telegram(f"HardFloor: {direction} {ticker} YES={_icy:.2f}")
                            to_remove.append(pos);continue
                        except Exception as _he: print(f"[HardFloor] fail: {str(_he)}")
        except Exception: pass
        if age_placed>=CASHOUT_MINUTES:
            try:
                murl=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
                mheader=kalshi.kalshi_auth.create_auth_headers("GET",murl)
                mr=requests.get(murl,headers=mheader,timeout=4)
                if mr.status_code==200:
                    mkt=mr.json().get("market",{})
                    status=mkt.get("status","")
                    ya=mkt.get("yes_ask_dollars") or mkt.get("yes_bid_dollars")
                    entry_yes=pos.get("entry_yes",0.5)
                    cur_yes=float(ya) if ya and 0.02<float(ya)<0.98 else entry_yes
                    if status in ("open","active") and direction in ("UP","DOWN"):
                        adverse=((entry_yes-cur_yes) if direction=="UP" else (cur_yes-(1-entry_yes)))
                        hard_floor=(direction=="UP" and cur_yes<0.10) or (direction=="DOWN" and cur_yes>0.90)
                        if adverse>CASHOUT_ADVERSE or hard_floor:
                            print(f"[CashOut] {direction} on {ticker} moved {adverse:.2f} against — exiting early")
                            # SELL the position on Kalshi to recover remaining value
                            try:
                                sell_side = "no" if direction=="UP" else "yes"
                                entry_p2=pos.get("entry_yes",0.5) if direction=="UP" else (1-pos.get("entry_yes",0.5))
                                contracts = pos.get("contracts", max(1,int(pos.get("bet",2)/entry_p2)))
                                sell_order = kalshi.create_order(
                                    ticker=ticker, action="sell", side=sell_side,
                                    type="market", count=contracts,
                                    time_in_force="ioc"
                                )
                                if sell_order and hasattr(sell_order,"order") and sell_order.order:
                                    o=sell_order.order
                                    print(f"[CashOut] Sell order: {o.status}")
                                    if o.status=="resting" and o.order_id:
                                        try:
                                            du=f"https://api.elections.kalshi.com/trade-api/v2/portfolio/orders/{o.order_id}"
                                            dh=kalshi.kalshi_auth.create_auth_headers("DELETE",du)
                                            requests.delete(du,headers=dh,timeout=5)
                                            print(f"[CashOut] Cancelled resting sell {o.order_id}")
                                        except Exception as de:
                                            print(f"[CashOut] Cancel failed: {de}")
                            except Exception as se:
                                print(f"[CashOut] Sell failed: {se}")
                            send_telegram(f"💸 CashOut: {direction} {ticker}\nadverse={adverse:.2f} | saving capital")
                            to_remove.append(pos)
                            continue
            except Exception as ce:
                print(f"[CashOut] Error: {ce}")
        if strategy=="restored" and age_min>16:
            # Try to determine WIN/LOSS for restored position before removing
            try:
                murl=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
                mheader=kalshi.kalshi_auth.create_auth_headers("GET",murl)
                mr=requests.get(murl,headers=mheader,timeout=5)
                if mr.status_code==200:
                    mkt=mr.json().get("market",{})
                    result=mkt.get("result","")
                    if result:
                        bet=pos.get("bet",0)
                        won=(direction=="UP" and result=="yes") or (direction=="DOWN" and result=="no")
                        if won:
                            payout=round(bet/(pos.get("entry_yes",0.5) if direction=="UP" else (1-pos.get("entry_yes",0.5))),2)
                            realized=round(payout-bet,2)
                            log_trade(direction,bet,"WIN",notes=f"restored|{ticker}",profit_pct=round(realized/bet*100,1))
                            send_telegram(f"✅ {BOT_NAME.split()[1]} WIN (restored): {direction} ${bet:.2f} | pnl=${realized:+.2f}")
                            print(f"[Restored] WIN: {direction} ${bet:.2f} on {ticker}")
                        else:
                            log_trade(direction,bet,"LOSS",notes=f"restored|{ticker}")
                            send_telegram(f"❌ {BOT_NAME.split()[1]} LOSS (restored): {direction} ${bet:.2f}")
                            print(f"[Restored] LOSS: {direction} ${bet:.2f} on {ticker}")
            except Exception as re:
                print(f"[Restored] Settlement check failed: {re}")
            to_remove.append(pos)
            continue
        if age_min<=16:
            continue
        try:
            url="https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
            headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
            resp=requests.get(url,headers=headers,params={"limit":100},timeout=8)
            if resp.status_code!=200:
                continue
            open_tickers={p.get("ticker") for p in resp.json().get("market_positions",[])}
            if ticker in open_tickers:
                continue
            murl=f"https://api.elections.kalshi.com/trade-api/v2/markets/{ticker}"
            mheader=kalshi.kalshi_auth.create_auth_headers("GET",murl)
            mr=requests.get(murl,headers=mheader,timeout=5)
            if mr.status_code!=200:
                if age_min>20:
                    to_remove.append(pos)
                continue
            mkt=mr.json().get("market",{})
            result=mkt.get("result","")
            if not result:
                if age_min>20:
                    to_remove.append(pos)
                continue
            won=((result=="yes" and direction=="UP") or (result=="no" and direction=="DOWN"))
            entry_p=pos.get("entry_yes",0.5) if direction=="UP" else (1-pos.get("entry_yes",0.5))
            contracts=max(1,int(bet/entry_p))
            realized=round(contracts*1.0-bet,2) if won else -bet
            outcome="WIN" if won else "LOSS"
            session_pnl+=realized
            CURRENT_BALANCE=round(CURRENT_BALANCE+realized,2)
            if won:
                session_wins+=1
            else:
                session_losses+=1
            total=session_wins+session_losses
            wr=session_wins/total*100 if total else 0
            print(f"[Settled] {outcome}: {direction} ${bet:.2f} on {ticker} | pnl=${realized:+.2f} | {session_wins}W/{session_losses}L ({wr:.0f}%)")
            icon="✅" if won else "❌"
            send_telegram(icon+" "+BOT_NAME.split()[1]+" "+outcome+": "+direction+" $"+str(round(bet,2))+" | pnl=$"+str(round(realized,2))+"\n"+str(session_wins)+"W/"+str(session_losses)+"L ("+str(round(wr,0))+"%) | Bal=$"+str(round(CURRENT_BALANCE,2)))
            features={"signal_type":pos.get("signal_type","STANDARD"),"entry_minute":pos.get("entry_minute",0),
                "market":MARKET_SERIES,"entry_yes":pos.get("entry_yes",0.5),
                "min_yes":pos.get("min_yes",0.5),"max_yes":pos.get("max_yes",0.5),
                "adverse_move":abs(pos.get("min_yes",0.5)-pos.get("entry_yes",0.5))}
            log_trade(direction,bet,outcome,profit_pct=realized/bet*100 if bet else 0,
                notes=f"{strategy}|{ticker}",features=features)
            to_remove.append(pos)
        except Exception as e:
            print(f"[Settled] Check failed: {e}")
            if age_min>20:
                to_remove.append(pos)
    for pos in to_remove:
        if pos in OPEN_POSITIONS:
            OPEN_POSITIONS.remove(pos)

def send_hourly_summary():
    global _last_summary_hour
    hour=datetime.datetime.now(datetime.timezone.utc).hour
    if hour==_last_summary_hour:
        return
    _last_summary_hour=hour
    total=session_wins+session_losses
    wr=session_wins/total*100 if total else 0
    send_telegram(f"📊 {BOT_NAME.split()[1]} Hourly ({hour:02d}:00 UTC)\n{session_wins}W/{session_losses}L ({wr:.0f}%) | PnL: ${session_pnl:+.2f} | Bal: ${CURRENT_BALANCE:.2f}")

def load_existing_positions():
    try:
        url="https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
        headers=kalshi.kalshi_auth.create_auth_headers("GET",url)
        resp=requests.get(url,headers=headers,params={"limit":100},timeout=8)
        if resp.status_code!=200:
            return
        positions=resp.json().get("market_positions",[])
        for p in positions:
            ticker=p.get("ticker","")
            exposure=float(p.get("market_exposure_dollars",0))
            if not ticker or exposure<=0:
                continue
            if MARKET_SERIES not in ticker:
                continue
            pos_count=p.get("position",0)
            yes_c=float(p.get("yes_count",0) or 0)
            no_c=float(p.get("no_count",0) or 0)
            if pos_count and pos_count!=0:
                direction="UP" if pos_count>0 else "DOWN"
            elif yes_c>0:
                direction="UP"
            elif no_c>0:
                direction="DOWN"
            else:
                direction="UNKNOWN"
            OPEN_POSITIONS.append({"direction":direction,"bet":exposure,"ticker":ticker,
                "strategy":"restored","time":time.time()-300,"placed_at":0,
                "entry_yes":0.5,"min_yes":0.5,"max_yes":0.5,
                "signal_type":"RESTORED","entry_minute":0})
            print(f"[Startup] Restored: {ticker} ${exposure:.2f} {direction}")
        if OPEN_POSITIONS:
            print(f"[Startup] Loaded {len(OPEN_POSITIONS)} BTC position(s)")
    except Exception as e:
        print(f"[Startup] Could not load positions: {e}")

def simulate_trade():
    global COOLDOWN_REMAINING,CURRENT_BALANCE
    if os.path.exists(STOP_FILE):
        print(f"[Stop] {STOP_FILE} detected — halting")
        raise SystemExit("Stop file detected")
    if COOLDOWN_REMAINING>0:
        print(f"[Cooldown] {COOLDOWN_REMAINING} cycles remaining")
        COOLDOWN_REMAINING-=1
        check_open_positions()
        return
    ticker,_=update_live_ticker()
    if not ticker:
        print("[Ticker] No ticker — skipping")
        return
    yes_price,no_price,_=get_market_prices(ticker)
    if yes_price is None or no_price is None:
        print("[Market] Could not fetch prices")
        check_open_positions()
        return
    price_sum=yes_price+no_price
    print(f"[Ticker] {ticker}")
    print(f"[Market] YES={yes_price:.2f} | NO={no_price:.2f} | Sum={price_sum:.2f}")
    CURRENT_BALANCE=get_live_balance()
    prices=get_btc_prices(60)
    update_regime(prices)
    total=session_wins+session_losses
    wr=session_wins/total*100 if total else 0
    print(f"{'='*50}")
    print(f"Balance: ${CURRENT_BALANCE:.2f} | Regime: {REGIME} | Session: {session_wins}W/{session_losses}L ({wr:.0f}%) | PnL: ${session_pnl:+.2f}")
    if price_sum<ARB_THRESHOLD:
        print(f"[ARB] Opportunity: sum={price_sum:.2f}")
        try_arb(yes_price,no_price,ticker)
    else:
        signal_fired=try_directional(yes_price,no_price)
        if not signal_fired:
            print(f"[Cycle] No signal — YES={yes_price:.2f} is between {DIRECTIONAL_LOW:.2f} and {DIRECTIONAL_HIGH:.2f}, sum={price_sum:.2f} >= {ARB_THRESHOLD:.2f}")
    check_open_positions()
    send_hourly_summary()

    if OPEN_POSITIONS:
        print(f"[Positions] {len(OPEN_POSITIONS)} still open")

if __name__=="__main__":
    mode="DRY RUN" if DRY_RUN else "LIVE"
    print(f"\n{'='*50}")
    print(f"{BOT_NAME} — {mode}")
    live_start=get_live_balance()
    if live_start>0:
        CURRENT_BALANCE=live_start
        SESSION_START_BAL=live_start
        print(f"[Startup] Live balance synced: ${CURRENT_BALANCE:.2f}")
    else:
        CURRENT_BALANCE=INITIAL_BALANCE
        SESSION_START_BAL=INITIAL_BALANCE
        print(f"[Startup] Using initial balance: ${CURRENT_BALANCE:.2f}")
    print(f"Balance: ${CURRENT_BALANCE:.2f} | MaxBet: ${get_max_bet():.2f} | Threshold: <{DIRECTIONAL_LOW:.2f} or >{DIRECTIONAL_HIGH:.2f}")
    print(f"{'='*50}\n")
    # Staggered startup: ETH waits 45s, SOL waits 90s to prevent simultaneous firing
    _startup_delay={"btc":0,"eth":45,"sol":90}.get(_args.market,0)
    if _startup_delay>0:
        print(f"[Startup] Staggered delay {_startup_delay}s for {_args.market.upper()}")
        import time as _st; _st.sleep(_startup_delay)
    load_existing_positions()
    cancel_resting_orders()
    print("[Startup] Resting orders cleared")
    send_telegram(f"🤖 {BOT_NAME} {mode} started\nBalance=${CURRENT_BALANCE:.2f} | MaxBet=${get_max_bet():.2f}\nThreshold: <{DIRECTIONAL_LOW:.2f} or >{DIRECTIONAL_HIGH:.2f}")
    try:
        while True:
            cycle_start=time.time()
            try:
                simulate_trade()
            except SystemExit:
                raise
            except Exception as e:
                print(f"[Cycle] Unexpected error: {e}")
                send_telegram(f"⚠️ {BOT_NAME.split()[1]} cycle error: {e}")
            elapsed=time.time()-cycle_start
            remaining=max(0,CYCLE_SLEEP-elapsed)
            # Fast cashout check every 15sec while waiting for next cycle
            slept=0
            while slept<remaining:
                chunk=min(15,remaining-slept)
                time.sleep(chunk)
                slept+=chunk
                if OPEN_POSITIONS: check_open_positions()
    except SystemExit as e:
        msg=f"🛑 {BOT_NAME} halted: {e}"
        print(msg)
        send_telegram(msg)
