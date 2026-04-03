#!/usr/bin/env python3
"""OpenClaw Dashboard v3.1 — Full Featured"""
import http.server, json, os, csv, datetime, requests, tempfile, subprocess
from collections import defaultdict

BOT_TOKEN  = '8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
KALSHI_KEY = '2d0a8c45-b76a-4459-a0e1-9a5e4d63fd8b'
KALSHI_SEC = '''-----BEGIN RSA PRIVATE KEY-----
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

tf = tempfile.NamedTemporaryFile(delete=False, suffix=".pem", mode="w")
tf.write(KALSHI_SEC); tf.close()

from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
config      = Configuration()
config.host = "https://api.elections.kalshi.com/trade-api/v2"
kalshi      = KalshiClient(config)
kalshi.set_kalshi_auth(KALSHI_KEY, tf.name)

CUTOFF = '2026-03-25'

# Deposit history for true P&L calculation
DEPOSITS = [
    ("2026-03-06", 515.46),  # Lost mostly to count=1000 bug
    ("2026-03-25", 135.63),  # Clean start deposit
    ("2026-03-30", 126.55),  # Most recent deposit
]
TOTAL_DEPOSITED = sum(d[1] for d in DEPOSITS)  # $777.64
CLEAN_START_DEPOSITED = sum(d[1] for d in DEPOSITS if d[0] >= '2026-03-25')  # $262.18

def get_balance():
    try:
        url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp    = requests.get(url, headers=headers, timeout=5)
        if resp.status_code == 200:
            d = resp.json()
            return (d.get('balance',0)+d.get('portfolio_value',0))/100
    except: pass
    return 0

def parse_csv(csv_file):
    wins=losses=0; pnl=0.0; recent=[]
    hourly=defaultdict(lambda:{'w':0,'l':0})
    equity=[]; streak=0; streak_dir=None
    trades_by_hour=defaultdict(int)
    try:
        for row in csv.reader(open(csv_file)):
            if len(row)<5 or row[0]<CUTOFF: continue
            action=row[3]
            if action not in ('WIN','LOSS'): continue
            bet=float(row[2])
            try: h=int(row[0][11:13])
            except: h=0
            trades_by_hour[h]+=1
            if action=='WIN':
                wins+=1
                try: p=bet*float(row[4].replace('%',''))/100; pnl+=p
                except: p=0
                hourly[h]['w']+=1
                recent.append(('WIN',row))
                if streak_dir=='WIN': streak+=1
                else: streak=1; streak_dir='WIN'
            else:
                losses+=1
                pnl-=bet
                hourly[h]['l']+=1
                recent.append(('LOSS',row))
                if streak_dir=='LOSS': streak+=1
                else: streak=1; streak_dir='LOSS'
    except: pass
    return wins,losses,pnl,recent[-8:],hourly,streak,streak_dir,trades_by_hour

def get_equity_points():
    points=[]; bal=143.90
    for f in ['/root/trade_log.csv','/root/eth_trade_log.csv','/root/sol_trade_log.csv']:
        try:
            for row in csv.reader(open(f)):
                if len(row)<5 or row[0]<CUTOFF: continue
                if row[3]=='WIN':
                    try: bal+=float(row[2])*float(row[4].replace('%',''))/100
                    except: pass
                elif row[3]=='LOSS':
                    try: bal-=float(row[2])
                    except: pass
                points.append((row[0][:16], round(bal,2)))
        except: pass
    points.sort(key=lambda x:x[0])
    return points[-80:] if len(points)>80 else points

def build_equity_svg(points, width=380, height=70):
    if len(points)<2: return '<div class="empty-msg">Accumulating equity data...</div>', 0, 0
    vals=[p[1] for p in points]
    mn=min(vals); mx=max(vals); rng=mx-mn if mx!=mn else 1
    def px(i): return round(10+i/(len(vals)-1)*(width-20),1)
    def py(v): return round(height-5-(v-mn)/rng*(height-15),1)
    path_pts=" L ".join(f"{px(i)},{py(v)}" for i,v in enumerate(vals))
    area=f"M {px(0)},{height+2} L {path_pts} L {px(len(vals)-1)},{height+2} Z"
    col='#00e676' if vals[-1]>=vals[0] else '#ff5252'
    chg=vals[-1]-vals[0]; chg_pct=chg/vals[0]*100 if vals[0] else 0
    svg=f'''<svg viewBox="0 0 {width} {height+5}" style="width:100%;height:{height}px">
      <defs><linearGradient id="eg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{col}" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="{col}" stop-opacity="0"/></linearGradient></defs>
      <path d="{area}" fill="url(#eg)"/>
      <polyline points="{" ".join(f"{px(i)},{py(v)}" for i,v in enumerate(vals))}" fill="none" stroke="{col}" stroke-width="1.5"/>
      <circle cx="{px(len(vals)-1)}" cy="{py(vals[-1])}" r="3" fill="{col}"/>
    </svg>'''
    return svg, chg, chg_pct

def build_frequency_svg(trades_by_hour_combined, utc_hour, width=380, height=50):
    mx=max(trades_by_hour_combined.values()) if trades_by_hour_combined else 1
    bars=""
    for h in range(24):
        cnt=trades_by_hour_combined.get(h,0)
        bar_h=max(2,int(cnt/mx*height)) if mx>0 else 2
        col='#58a6ff' if h==utc_hour else '#30363d'
        if cnt>0: col='#00e676' if h==utc_hour else '#21a1f1'
        bars+=f'<rect x="{h*(width//24)}" y="{height-bar_h}" width="{width//24-1}" height="{bar_h}" fill="{col}" rx="1"/>'
        if h%6==0:
            bars+=f'<text x="{h*(width//24)}" y="{height+10}" font-size="7" fill="#555">{h:02d}</text>'
    return f'<svg viewBox="0 0 {width} {height+12}" style="width:100%;height:{height+12}px">{bars}</svg>'

def build_feature_table():
    try:
        entries=[]
        with open('/root/feature_log.json') as f:
            for line in f:
                try: entries.append(json.loads(line.strip()))
                except: pass
        settled=[e for e in entries if e.get('action') in ('WIN','LOSS')]
        total=len(settled)
        if total<5:
            pct=total/30*100
            return (f'<div class="empty-msg">{total}/30 trades logged</div>'
                    f'<div style="background:var(--bg3);border-radius:4px;height:4px;margin-top:6px">'
                    f'<div style="background:var(--green);height:100%;width:{pct:.0f}%;border-radius:4px"></div></div>'
                    f'<div style="font-size:10px;color:var(--muted);margin-top:4px">{30-total} more trades needed</div>')
        def make_row(name,w,l):
            t=w+l; wr=w/t*100 if t else 0
            col='#00e676' if wr>=75 else '#ffab00' if wr>=55 else '#ff5252'
            conf=min(100,t/30*100)
            verdict='✅' if wr>=70 and t>=10 else '⚠️' if t<10 else '❌'
            return (f'<div style="padding:5px 0;border-bottom:1px solid var(--border);font-size:11px">'
                    f'<div style="display:flex;justify-content:space-between">'
                    f'<span>{name}</span><span style="color:{col};font-weight:700">{wr:.0f}% {verdict}</span></div>'
                    f'<div style="font-size:10px;color:var(--muted)">{w}W/{l}L • Confidence: {conf:.0f}%</div>'
                    f'<div style="background:var(--bg3);border-radius:2px;height:3px;margin-top:2px">'
                    f'<div style="background:{col};height:100%;width:{wr:.0f}%;border-radius:2px"></div></div></div>')
        from collections import defaultdict as dd
        signals=dd(lambda:{"w":0,"l":0})
        minutes=dd(lambda:{"w":0,"l":0})
        coinbase=dd(lambda:{"w":0,"l":0})
        edges=dd(lambda:{"w":0,"l":0})
        for e in settled:
            feat=e.get("features",{}); outcome="w" if e["action"]=="WIN" else "l"
            signals[feat.get("signal_type","UNKNOWN")][outcome]+=1
            m=feat.get("entry_minute",-1)
            minutes[f"Min {m}" if m>=0 else "Unknown"][outcome]+=1
            bc=feat.get("binance_confirmed",None)
            if bc is not None: coinbase["Confirmed" if bc else "Not confirmed"][outcome]+=1
            edge=feat.get("edge",0)
            if edge:
                er="Edge >=45%" if edge>=0.45 else "Edge 35-45%" if edge>=0.35 else "Edge <35%"
                edges[er][outcome]+=1
        html=f'<div style="font-size:10px;color:var(--muted);margin-bottom:6px">{total} trades analyzed</div>'
        html+='<div style="font-size:10px;font-weight:700;color:var(--muted);margin:8px 0 2px">SIGNAL TYPE</div>'
        for k,v in sorted(signals.items()): html+=make_row(k,v["w"],v["l"])
        html+='<div style="font-size:10px;font-weight:700;color:var(--muted);margin:8px 0 2px">ENTRY MINUTE</div>'
        for k,v in sorted(minutes.items()): html+=make_row(k,v["w"],v["l"])
        if coinbase:
            html+='<div style="font-size:10px;font-weight:700;color:var(--muted);margin:8px 0 2px">COINBASE SIGNAL</div>'
            for k,v in sorted(coinbase.items()): html+=make_row(k,v["w"],v["l"])
        if edges:
            html+='<div style="font-size:10px;font-weight:700;color:var(--muted);margin:8px 0 2px">EDGE STRENGTH</div>'
            for k,v in sorted(edges.items()): html+=make_row(k,v["w"],v["l"])
        return html
    except FileNotFoundError:
        return '<div class="empty-msg">Feature log not created yet</div>'
    except Exception as e:
        return f'<div class="empty-msg">Error: {e}</div>'

def build_ai_insight(total_w,total_l,total_wr,total_pnl,balance,bc,bd,ex,bot_data,utc_hour):
    insights=[]
    total_t=total_w+total_l
    if total_t<5: return "🔄 Warming up — insights appear after 5+ trades."
    if total_wr>=85: insights.append(f"🟢 Excellent — {total_wr:.0f}% WR over {total_t} trades. Above baseline.")
    elif total_wr>=70: insights.append(f"🟡 Strong — {total_wr:.0f}% WR. Near historical average of 77%.")
    else: insights.append(f"🔴 Below baseline — {total_wr:.0f}% WR. Strategy may need review.")
    if bc>0 and bd==0: insights.append(f"✅ Coinbase confirmed all {bc} signals — strong consensus.")
    elif bd>0:
        dr=bd/(bc+bd)*100 if bc+bd>0 else 0
        insights.append(f"⚠️ Coinbase disagreed on {dr:.0f}% of signals — market is choppy.")
    if ex>0: insights.append(f"⚡ {ex} extreme signal(s) fired — highest EV trades.")
    if 0<=utc_hour<6: insights.append("🌙 Overnight — ETH/SOL paused, BTC at reduced size.")
    elif 13<=utc_hour<=17: insights.append("🏆 Peak NYC hours — optimal trading conditions.")
    best=max(bot_data.items(),key=lambda x:x[1]['w']/(x[1]['w']+x[1]['l']) if x[1]['w']+x[1]['l']>0 else 0)
    bname,bd2=best; bt=bd2['w']+bd2['l']
    if bt>=3: insights.append(f"🏅 Best bot: {bname} at {bd2['w']/bt*100:.0f}% WR ({bd2['w']}W/{bd2['l']}L).")
    if total_t>=30: insights.append(f"📊 {total_t} trades — statistically significant. Run analyze_features.py for full report.")
    else: insights.append(f"📊 {30-total_t} more trades needed for full feature confidence.")
    return "<br>".join(insights)

def get_open_positions():
    try:
        url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp    = requests.get(url, headers=headers, params={"limit":20}, timeout=5)
        if resp.status_code == 200:
            return resp.json().get("market_positions", [])
    except: pass
    return []

def get_news():
    items=[]; seen=set()
    try:
        for line in open('/root/news_log.json'):
            try:
                d=json.loads(line.strip())
                t=d.get('title','')
                if d.get('score',0)>=5 and t not in seen:
                    items.append(d); seen.add(t)
            except: pass
        items.sort(key=lambda x:x.get('score',0),reverse=True)
    except: pass
    return items[:5]

def generate_html():
    balance  = get_balance()
    positions= get_open_positions()
    news     = get_news()
    now      = datetime.datetime.now(datetime.timezone.utc)
    utc_hour = now.hour
    now_str  = now.strftime('%Y-%m-%d %H:%M UTC')

    bots=[('BTC','🔶','/root/trade_log.csv','/root/bot.log'),
          ('ETH','💎','/root/eth_trade_log.csv','/root/eth_bot.log'),
          ('SOL','🌟','/root/sol_trade_log.csv','/root/sol_bot.log')]

    bot_data={}; all_hourly=defaultdict(lambda:{'w':0,'l':0})
    all_trades_by_hour=defaultdict(int)
    total_w=total_l=0; total_pnl=0.0; total_bc=total_bd=total_ex=total_co=0
    all_recent=[]

    for name,icon,csvf,logf in bots:
        w,l,pnl,recent,hourly,streak,streak_dir,tbh=parse_csv(csvf)
        # Get live signals from log
        bc=bd=ex=co=0
        try:
            for line in open(logf):
                if 'Confirms' in line and 'Binance' in line: bc+=1
                if 'Disagrees' in line and 'Binance' in line: bd+=1
                if 'EXTREME' in line and 'firing' in line: ex+=1
                if '[CashOut]' in line: co+=1
        except: pass
        bot_data[name]={'icon':icon,'w':w,'l':l,'pnl':pnl,'recent':recent,
                        'hourly':hourly,'bc':bc,'bd':bd,'ex':ex,'co':co,
                        'streak':streak,'streak_dir':streak_dir}
        total_w+=w; total_l+=l; total_pnl+=pnl
        total_bc+=bc; total_bd+=bd; total_ex+=ex; total_co+=co
        for h,v in hourly.items():
            all_hourly[h]['w']+=v['w']; all_hourly[h]['l']+=v['l']
        for h,c in tbh.items(): all_trades_by_hour[h]+=c
        all_recent+=[(name,o,r) for o,r in recent]

    total_t=total_w+total_l
    total_wr=total_w/total_t*100 if total_t else 0
    wr_col='#00e676' if total_wr>=75 else '#ffab00' if total_wr>=55 else '#ff5252'

    # Equity curve
    eq_points=get_equity_points()
    eq_svg,eq_chg,eq_chg_pct=build_equity_svg(eq_points)
    eq_col='#00e676' if eq_chg>=0 else '#ff5252'

    # Trade frequency
    freq_svg=build_frequency_svg(all_trades_by_hour,utc_hour)

    # Bot cards with streak
    cards=''
    for name,icon,_,_ in bots:
        d=bot_data[name]
        t=d['w']+d['l']; wr=d['w']/t*100 if t else 0
        col='#00e676' if wr>=75 else '#ffab00' if wr>=55 else '#ff5252'
        glow=f'box-shadow:0 0 15px {col}44;border-color:{col}44' if wr>=75 else ''
        streak=d['streak']; sdir=d['streak_dir']
        streak_icon='🔥' if sdir=='WIN' and streak>=3 else '❄️' if sdir=='LOSS' and streak>=2 else ''
        streak_col='#00e676' if sdir=='WIN' else '#ff5252' if sdir=='LOSS' else '#555'
        # EV calculation: at current avg entry ~0.75, EV = 0.75*wr - (1-wr)
        ev=wr/100*0.33-(1-wr/100) if wr>0 else 0
        ev_col='#00e676' if ev>0 else '#ff5252'
        cards+=f'''<div class="card" style="{glow}">
          <div class="card-header"><span>{icon}</span><span class="card-name">{name}</span><span style="color:{streak_col};font-size:11px">{streak_icon}{streak}{sdir[0] if sdir else ""}</span></div>
          <div class="card-wr" style="color:{col}">{wr:.0f}%</div>
          <div class="card-wl">{d["w"]}W / {d["l"]}L</div>
          <div class="card-pnl" style="color:{'#00e676' if d['pnl']>=0 else '#ff5252'}">${d["pnl"]:+.2f}</div>
          <div style="font-size:10px;color:{ev_col};margin:2px 0">EV: {ev:+.2f} per $1</div>
          <div class="card-icons">
            <span title="Coinbase Confirms">🛰️{d["bc"]}</span>
            <span title="Disagrees">⚠️{d["bd"]}</span>
            <span title="Extreme">⚡{d["ex"]}</span>
            <span title="CashOut">💸{d["co"]}</span>
          </div>
        </div>'''

    # Hourly WR chart
    chart=''
    for h in range(24):
        v=all_hourly.get(h,{'w':0,'l':0}); t=v['w']+v['l']
        wr2=v['w']/t*100 if t>0 else -1
        active='active-bar' if h==utc_hour else ''
        if wr2<0:
            chart+=f'<div class="hbar empty {active}"><div class="hbar-fill" style="height:3px;background:#21262d"></div><span>{h}</span></div>'
        else:
            col='#00e676' if wr2>=75 else '#ffab00' if wr2>=55 else '#ff5252'
            ht=max(3,int(wr2*0.8))
            tip=f"{h:02d}:00 {wr2:.0f}% ({v['w']}W/{v['l']}L)"
            chart+=f'<div class="hbar {active}" title="{tip}"><div class="hbar-fill" style="height:{ht}px;background:{col}"></div><span>{h}</span></div>'

    # Recent trades
    all_recent.sort(key=lambda x:x[2][0] if x[2] else '',reverse=True)
    trades=''
    for bot,outcome,row in all_recent[:12]:
        col='#00e676' if outcome=='WIN' else '#ff5252'
        icon2='✅' if outcome=='WIN' else '❌'
        detail=f"{outcome}: {row[1]} ${row[2]} | {row[5][:35] if len(row)>5 else ''}" if row else ''
        trades+=f'<div class="trade"><span style="color:{col}">{icon2}</span><span class="t-bot">{bot}</span><span class="t-detail">{detail}</span></div>'

    # Positions
    pos_html=''
    for p in positions[:6]:
        ticker=p.get('ticker','')[-16:]
        exp=float(p.get('market_exposure_dollars',0))
        pos_html+=f'<div class="pos">📍 <span class="pos-t">{ticker}</span><span class="pos-v">${exp:.2f}</span></div>'
    if not pos_html: pos_html='<div class="empty-msg">No open positions</div>'

    # News
    news_html=''
    for item in get_news():
        sc=item.get('score',0); ti=item.get('title','')[:55]
        src=item.get('source',''); lk=item.get('link','#')
        news_html+=f'<div class="news-item"><span class="ns">⭐{sc}</span><a href="{lk}" target="_blank" class="nl">{ti}</a><span class="nsrc">{src}</span></div>'

    # Feature table and AI insight
    feature_table=build_feature_table()
    ai_insight=build_ai_insight(total_w,total_l,total_wr,total_pnl,balance,total_bc,total_bd,total_ex,bot_data,utc_hour)

    # System status
    procs=[('Real Bot','real_bot'),('Eth Bot','eth_bot'),('Sol Bot','sol_bot'),
           ('Bond','bond_scanner'),('Watchdog','watchdog'),('Dashboard','dashboard'),('News','news_agent')]
    sys_html=''.join(f'<span class="proc {"ok" if subprocess.run(["pgrep","-f",p],capture_output=True).returncode==0 else "down"}">{lb} {"✅" if subprocess.run(["pgrep","-f",p],capture_output=True).returncode==0 else "❌"}</span>' for lb,p in procs)

    # TOD status
    tod_labels={0:'40%',1:'25%',2:'100%',3:'100%',4:'40%',5:'25%',6:'100%',7:'100%',8:'100%',9:'100%',10:'100%',11:'100%',12:'50%',13:'50%',14:'100%',15:'100%',16:'100%',17:'75%',18:'75%',19:'100%',20:'75%',21:'100%',22:'25%',23:'75%'}
    tod_size=tod_labels.get(utc_hour,'100%')
    tod_col='#00e676' if tod_size=='100%' else '#ffab00' if tod_size in ('75%','50%') else '#ff5252'

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="20">
<title>OpenClaw</title>
<style>
:root{{--bg:#0d1117;--bg2:#161b22;--bg3:#21262d;--green:#00e676;--yellow:#ffab00;--red:#ff5252;--blue:#58a6ff;--text:#c9d1d9;--muted:#8b949e;--border:#30363d}}
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;padding:12px;max-width:480px;margin:0 auto}}
.logo{{display:flex;align-items:center;gap:8px;margin-bottom:2px}}
.logo h1{{color:var(--green);font-size:1.3em;font-weight:700}}
.pulse{{animation:pulse 2s infinite;color:var(--green);font-size:10px}}
@keyframes pulse{{0%,100%{{opacity:1}}50%{{opacity:0.4}}}}
.subtitle{{font-size:11px;color:var(--muted);margin-bottom:12px}}
.balance{{font-size:3em;font-weight:800;color:var(--green);letter-spacing:-1px;line-height:1}}
.bal-sub{{font-size:11px;color:var(--muted);margin-bottom:14px;margin-top:3px}}
.stats{{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-bottom:14px}}
.stat{{background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:10px}}
.stat-v{{font-size:1.25em;font-weight:700}}
.stat-l{{font-size:10px;color:var(--muted);margin-top:2px}}
.cards{{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:12px}}
.card{{background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:11px;transition:all 0.3s}}
.card-header{{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px}}
.card-name{{font-size:11px;font-weight:600;color:var(--muted)}}
.card-wr{{font-size:1.8em;font-weight:800;line-height:1}}
.card-wl{{font-size:11px;color:var(--muted);margin:2px 0}}
.card-pnl{{font-size:13px;font-weight:600;margin-bottom:4px}}
.card-icons{{display:flex;justify-content:space-between;font-size:10px;color:var(--muted);margin-top:4px}}
.section{{background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:13px;margin-bottom:10px}}
.st{{font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:1.5px;margin-bottom:10px}}
.hourly{{display:flex;align-items:flex-end;gap:2px;height:80px}}
.hbar{{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:2px}}
.hbar-fill{{width:100%;border-radius:2px 2px 0 0;min-height:2px}}
.hbar span{{font-size:7px;color:var(--muted)}}
.active-bar .hbar-fill{{opacity:1!important;filter:brightness(1.3)}}
.hbar:not(.active-bar){{opacity:0.65}}
.trade{{display:flex;gap:7px;padding:6px 0;border-bottom:1px solid var(--border);font-size:11px;align-items:flex-start}}
.trade:last-child{{border-bottom:none}}
.t-bot{{font-weight:700;min-width:28px;color:var(--muted)}}
.t-detail{{color:var(--text);flex:1;line-height:1.4}}
.pos{{display:flex;justify-content:space-between;padding:5px 0;border-bottom:1px solid var(--border);font-size:12px}}
.pos:last-child{{border-bottom:none}}
.pos-t{{color:var(--muted)}}
.pos-v{{color:var(--yellow);font-weight:600}}
.news-item{{display:flex;gap:7px;padding:5px 0;border-bottom:1px solid var(--border);font-size:11px;align-items:flex-start}}
.news-item:last-child{{border-bottom:none}}
.ns{{color:var(--yellow);font-weight:700;flex-shrink:0}}
.nl{{color:var(--blue);text-decoration:none;flex:1;line-height:1.4}}
.nl:hover{{text-decoration:underline}}
.nsrc{{color:var(--muted);font-size:10px;flex-shrink:0;min-width:65px;text-align:right}}
.legend{{display:grid;grid-template-columns:1fr 1fr;gap:5px;font-size:11px}}
.li{{display:flex;gap:6px;align-items:center;color:var(--muted)}}
.proc-grid{{display:flex;flex-wrap:wrap;gap:5px}}
.proc{{padding:4px 9px;border-radius:5px;font-size:11px;font-weight:600}}
.proc.ok{{background:#1a2f1a;color:var(--green);border:1px solid #2d4a2d}}
.proc.down{{background:#2f1a1a;color:var(--red);border:1px solid #4a2d2d}}
.empty-msg{{color:var(--muted);font-size:12px;text-align:center;padding:8px 0}}
.eq-meta{{display:flex;justify-content:space-between;font-size:11px;color:var(--muted);margin-top:5px}}
.tod-badge{{display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:700;margin-top:4px}}
.footer{{text-align:center;font-size:10px;color:var(--muted);margin-top:12px;padding-bottom:20px}}
</style>
</head>
<body>

<div class="logo"><span>🦅</span><h1>OpenClaw</h1><span class="pulse">● LIVE</span></div>
<div class="subtitle">Kalshi 15-min Prediction Market System • {now_str}</div>

<div class="balance">${balance:.2f}</div>
<div class="bal-sub">Total Portfolio Value — TOD: <span style="color:{tod_col}">{tod_size} bet size</span> at {utc_hour:02d}:00 UTC</div>
<div style="display:flex;gap:12px;margin-top:6px;font-size:11px;flex-wrap:wrap">
  <span style="color:var(--muted)">Deposited: <span style="color:var(--text)">${TOTAL_DEPOSITED:.2f}</span></span>
  <span style="color:var(--muted)">True P\<div class="bal-sub">Total Portfolio Value — TOD: <span style="color:{tod_col}">{tod_size} bet size</span> at {utc_hour:02d}:00 UTC</div>P&amp;L: <span style="color:{"var(--green)" if balance>=TOTAL_DEPOSITED else "var(--red)"}">${balance-TOTAL_DEPOSITED:+.2f}</span></span>
  <span style="color:var(--muted)">Since Mar 25: <span style="color:{"var(--green)" if balance>=CLEAN_START_DEPOSITED else "var(--red)"}">${balance-CLEAN_START_DEPOSITED:+.2f}</span></span>
</div>

<div class="stats">
  <div class="stat"><div class="stat-v" style="color:{wr_col}">{total_wr:.0f}%</div><div class="stat-l">Win Rate</div></div>
  <div class="stat"><div class="stat-v">{total_w}W/{total_l}L</div><div class="stat-l">All Trades</div></div>
  <div class="stat"><div class="stat-v" style="color:{'#00e676' if total_pnl>=0 else '#ff5252'}">${total_pnl:+.2f}</div><div class="stat-l">Total PnL</div></div>
  <div class="stat"><div class="stat-v">⚡{total_ex}</div><div class="stat-l">Extreme</div></div>
  <div class="stat"><div class="stat-v">🛰️{total_bc}</div><div class="stat-l">Confirmed</div></div>
  <div class="stat"><div class="stat-v">💸{total_co}</div><div class="stat-l">Cash Outs</div></div>
</div>

<div class="cards">{cards}</div>

<div class="section">
  <div class="st">📈 Equity Curve ({len(eq_points)} trades)</div>
  {eq_svg}
  <div class="eq-meta">
    <span>Start: $143.90</span>
    <span style="color:{eq_col}">{eq_chg:+.2f} ({eq_chg_pct:+.1f}%)</span>
  </div>
</div>

<div class="section">
  <div class="st">📊 Trade Frequency by Hour</div>
  {freq_svg}
</div>

<div class="section">
  <div class="st">🕐 Win Rate by Hour (UTC {utc_hour:02d}:00)</div>
  <div class="hourly">{chart}</div>
</div>

<div class="section">
  <div class="st">📍 Open Positions ({len(positions)})</div>
  {pos_html}
</div>

<div class="section">
  <div class="st">🔄 Recent Trades</div>
  {trades if trades else '<div class="empty-msg">No trades yet</div>'}
</div>

<div class="section">
  <div class="st">🧬 Feature Attribution</div>
  {feature_table}
</div>

<div class="section">
  <div class="st">🤖 Bot Intelligence</div>
  <div style="font-size:12px;line-height:1.8;color:var(--text)">{ai_insight}</div>
</div>

<div class="section">
  <div class="st">📖 Icon Legend</div>
  <div class="legend">
    <div class="li"><span>🛰️</span><span>Coinbase confirms direction</span></div>
    <div class="li"><span>⚠️</span><span>Coinbase disagrees (bet -60%)</span></div>
    <div class="li"><span>⚡</span><span>Extreme signal (YES&lt;20% or &gt;80%)</span></div>
    <div class="li"><span>💸</span><span>Cash out triggered early</span></div>
    <div class="li"><span>🔥W</span><span>Active winning streak</span></div>
    <div class="li"><span>❄️L</span><span>Active losing streak</span></div>
  </div>
</div>

<div class="section">
  <div class="st">📰 Top News</div>
  {news_html if news_html else '<div class="empty-msg">No news items</div>'}
</div>

<div class="section">
  <div class="st">⚙️ System Status</div>
  <div class="proc-grid">{sys_html}</div>
</div>

<div class="footer">Auto-refresh 20s • OpenClaw v3.1 • <a href="/docs" style="color:var(--blue)">📖 Guide</a></div>
</body>
</html>'''

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            html=generate_html().encode()
            self.send_response(200)
            self.send_header('Content-Type','text/html; charset=utf-8')
            self.send_header('Content-Length',len(html))
            self.end_headers()
            self.wfile.write(html)
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f"Error: {e}".encode())
    def do_GET(self):
        if self.path == '/docs':
            try:
                import markdown2
                md = open('/root/OPENCLAW_GUIDE.md').read()
                html_body = markdown2.markdown(md, extras=["tables", "fenced-code-blocks"])
            except ImportError:
                md = open('/root/OPENCLAW_GUIDE.md').read()
                html_body = '<pre style="white-space:pre-wrap;font-family:monospace;color:#c9d1d9">' + md + '</pre>'
            html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OpenClaw Guide</title>
<style>
body{{background:#0d1117;color:#c9d1d9;font-family:-apple-system,sans-serif;padding:20px;max-width:800px;margin:0 auto;line-height:1.7}}
h1{{color:#00e676}}h2{{color:#58a6ff;border-bottom:1px solid #30363d;padding-bottom:6px}}
h3{{color:#ffab00}}code{{background:#161b22;padding:2px 6px;border-radius:4px;font-family:monospace}}
pre{{background:#161b22;padding:15px;border-radius:8px;overflow-x:auto}}
table{{border-collapse:collapse;width:100%}}
td,th{{border:1px solid #30363d;padding:8px;text-align:left}}
th{{background:#161b22;color:#00e676}}
a{{color:#58a6ff}}
.back{{display:inline-block;margin-bottom:20px;color:#00e676;text-decoration:none;font-size:14px}}
</style></head><body>
<a href="/" class="back">← Back to Dashboard</a>
{html_body}
</body></html>"""
            html = html.encode()
            self.send_response(200)
            self.send_header('Content-Type','text/html; charset=utf-8')
            self.send_header('Content-Length',len(html))
            self.end_headers()
            self.wfile.write(html)
            return
        try:
            html=generate_html().encode()
            self.send_response(200)
            self.send_header('Content-Type','text/html; charset=utf-8')
            self.send_header('Content-Length',len(html))
            self.end_headers()
            self.wfile.write(html)
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f"Error: {e}".encode())
    def log_message(self,*args): pass

if __name__=="__main__":
    server=http.server.HTTPServer(('0.0.0.0',8080),Handler)
    print("Dashboard v3.1 running at http://0.0.0.0:8080")
    server.serve_forever()
