#!/usr/bin/env python3
"""OpenClaw Live Dashboard v2.0"""
import http.server, json, os, datetime, requests, tempfile, csv
from collections import defaultdict

raw        = open('/root/real_bot.py').read()
BOT_TOKEN  = raw.split("BOT_TOKEN = '")[1].split("'")[0]
KALSHI_KEY = raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
KALSHI_SEC = raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]

tf = tempfile.NamedTemporaryFile(delete=False, suffix=".pem", mode="w")
tf.write(KALSHI_SEC); tf.close()

from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
config      = Configuration()
config.host = "https://api.elections.kalshi.com/trade-api/v2"
kalshi      = KalshiClient(config)
kalshi.set_kalshi_auth(KALSHI_KEY, tf.name)

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

def parse_log(logfile):
    wins=losses=0; pnl=0.0; recent=[]; hourly=defaultdict(lambda:{'w':0,'l':0})
    binance_confirms=binance_disagrees=extreme_signals=cashouts=0
    try:
        for line in open(logfile):
            if '[Settled] WIN:' in line:
                wins+=1
                try: pnl+=float(line.split('pnl=$')[1].split(' ')[0])
                except: pass
                recent.append(('WIN',line.strip()))
                try:
                    ts=line.split('|')[0].strip()
                    h=int(ts[-8:-6]) if len(ts)>8 else 0
                    hourly[h]['w']+=1
                except: pass
            elif '[Settled] LOSS:' in line:
                losses+=1
                try: pnl+=float(line.split('pnl=$')[1].split(' ')[0])
                except: pass
                recent.append(('LOSS',line.strip()))
                try:
                    ts=line.split('|')[0].strip()
                    h=int(ts[-8:-6]) if len(ts)>8 else 0
                    hourly[h]['l']+=1
                except: pass
            if '[Binance] ✅' in line: binance_confirms+=1
            if '[Binance] ⚠️' in line: binance_disagrees+=1
            if 'EXTREME' in line and 'firing' in line: extreme_signals+=1
            if '[CashOut]' in line: cashouts+=1
    except: pass
    return wins,losses,pnl,recent[-8:],hourly,binance_confirms,binance_disagrees,extreme_signals,cashouts

def parse_news():
    items=[]
    try:
        for line in open('/root/news_log.json'):
            try:
                d=json.loads(line.strip())
                if d.get('score',0)>=5:
                    items.append(d)
            except: pass
        items.sort(key=lambda x:x.get('score',0),reverse=True)
    except: pass
    return items[:5]

def get_open_positions():
    try:
        url     = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
        headers = kalshi.kalshi_auth.create_auth_headers("GET", url)
        resp    = requests.get(url, headers=headers, params={"limit":20}, timeout=5)
        if resp.status_code == 200:
            return resp.json().get("market_positions", [])
    except: pass
    return []

def generate_html():
    balance  = get_balance()
    try:
        import csv as _csv
        rows = list(_csv.reader(open('/root/trade_log.csv')))
        bal = 238.74  # approximate starting balance
        for row in rows[-50:]:  # last 50 trades
            if len(row) >= 5:
                try:
                    pct = float(row[4].replace('%',''))/100
                    bet = float(row[2])
                    bal += bet * pct
                except: pass
    except: pass
    positions= get_open_positions()
    news     = parse_news()
    now      = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    utc_hour = datetime.datetime.utcnow().hour

    bots = [
        ('BTC','🔶','/root/bot.log'),
        ('ETH','💎','/root/eth_bot.log'),
        ('SOL','🌟','/root/sol_bot.log'),
    ]

    bot_data = {}
    all_hourly = defaultdict(lambda:{'w':0,'l':0})
    total_w=total_l=0; total_pnl=0.0
    total_confirms=total_disagrees=total_extreme=total_cashout=0

    for name,icon,log in bots:
        w,l,pnl,recent,hourly,bc,bd,ex,co = parse_log(log)
        bot_data[name] = {'icon':icon,'w':w,'l':l,'pnl':pnl,'recent':recent,
                          'hourly':hourly,'bc':bc,'bd':bd,'ex':ex,'co':co}
        total_w+=w; total_l+=l; total_pnl+=pnl
        total_confirms+=bc; total_disagrees+=bd
        total_extreme+=ex; total_cashout+=co
        for h,v in hourly.items():
            all_hourly[h]['w']+=v['w']; all_hourly[h]['l']+=v['l']

    total_t  = total_w+total_l
    total_wr = total_w/total_t*100 if total_t else 0

    # Build bot cards
    cards_html = ""
    all_recent = []
    for name,icon,_ in bots:
        d   = bot_data[name]
        t   = d['w']+d['l']
        wr  = d['w']/t*100 if t else 0
        col = '#00e676' if wr>=75 else '#ffab00' if wr>=60 else '#ff5252'
        cards_html += f'''
        <div class="card">
            <div class="card-title">{icon} {name}</div>
            <div class="stat-big" style="color:{col}">{wr:.0f}%</div>
            <div class="stat-sub">{d['w']}W / {d['l']}L</div>
            <div class="stat-sub pnl" style="color:{'#00e676' if d['pnl']>=0 else '#ff5252'}">${d['pnl']:+.2f}</div>
            <div class="feat-row">
                <span title="Coinbase confirms">🛰️{d['bc']}</span>
                <span title="Coinbase disagrees">⚠️{d['bd']}</span>
                <span title="Extreme signals">⚡{d['ex']}</span>
                <span title="Cash outs">💸{d['co']}</span>
            </div>
        </div>'''
        all_recent += [(name, o, l) for o,l in d['recent']]

    # Hourly chart data
    hours  = list(range(24))
    wr_by_hour = []
    for h in hours:
        v  = all_hourly.get(h,{'w':0,'l':0})
        t  = v['w']+v['l']
        wr = v['w']/t*100 if t else -1
        wr_by_hour.append(wr)

    chart_bars = ""
    for h,wr in enumerate(wr_by_hour):
        if wr < 0:
            chart_bars += f'<div class="bar empty" title="{h:02d}:00 - No data"><span>{h}</span></div>'
        else:
            col    = '#00e676' if wr>=75 else '#ffab00' if wr>=60 else '#ff5252'
            active = 'active-hour' if h==utc_hour else ''
            wr_str = f"{wr:.0f}% WR ({all_hourly[h]['w']}W/{all_hourly[h]['l']}L)"
            chart_bars += f'<div class="bar {active}" style="--h:{wr:.0f}%;--c:{col}" title="{h:02d}:00 UTC - {wr_str}"><span>{h}</span></div>'

    # Recent trades
    all_recent.sort(key=lambda x:x[2],reverse=True)
    recent_html = ""
    for bot,outcome,line in all_recent[:12]:
        col  = '#00e676' if outcome=='WIN' else '#ff5252'
        icon = '✅' if outcome=='WIN' else '❌'
        short= ''
        if '[Settled]' in line:
            parts = line.split('[Settled]')[1].strip()
            short = parts[:70]
        recent_html += f'<div class="trade-row"><span style="color:{col}">{icon}</span><span class="trade-bot">{bot}</span><span class="trade-detail">{short}</span></div>'

    # Open positions
    pos_html = ""
    for p in positions[:5]:
        ticker = p.get('ticker','')[-15:]
        exp    = float(p.get('market_exposure_dollars',0))
        pos_html += f'<div class="pos-row">📍 {ticker} | ${exp:.2f}</div>'
    if not pos_html:
        pos_html = '<div style="color:#555">No open positions</div>'

    # News feed
    news_html = ""
    for item in news:
        score = item.get('score',0)
        title = item.get('title','')[:60]
        src   = item.get('source','')
        link  = item.get('link','#')
        news_html += f'<div class="news-row"><span class="news-score">⭐{score}</span><a href="{link}" target="_blank" class="news-title">{title}</a><span class="news-src">{src}</span></div>'
    if not news_html:
        news_html = '<div style="color:#555">No news items yet</div>'

    # Processes
    import subprocess
    procs = ['real_bot','eth_bot','sol_bot','bond_scanner','watchdog','dashboard','news_agent']
    proc_html = ""
    for p in procs:
        r = subprocess.run(['pgrep','-f',p],capture_output=True)
        ok = r.returncode == 0
        proc_html += f'<span class="proc {"proc-ok" if ok else "proc-down"}">{p.replace("_"," ").title()} {"✅" if ok else "❌"}</span>'

    return f'''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="20">
<title>OpenClaw Dashboard</title>
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:#0d1117;color:#c9d1d9;font-family:'Segoe UI',monospace;padding:12px}}
h1{{color:#00e676;font-size:1.4em;margin-bottom:4px}}
.subtitle{{color:#555;font-size:11px;margin-bottom:15px}}
.balance-big{{font-size:2.8em;font-weight:bold;color:#00e676;line-height:1}}
.balance-label{{color:#555;font-size:12px;margin-bottom:15px}}
.summary-row{{display:flex;gap:20px;margin-bottom:15px;flex-wrap:wrap}}
.summary-item{{background:#161b22;padding:10px 15px;border-radius:8px;min-width:100px}}
.summary-item .val{{font-size:1.4em;font-weight:bold}}
.summary-item .lbl{{font-size:10px;color:#555;margin-top:2px}}
.cards{{display:flex;gap:12px;margin-bottom:15px;flex-wrap:wrap}}
.card{{background:#161b22;border-radius:10px;padding:15px;flex:1;min-width:140px;border:1px solid #21262d}}
.card-title{{font-size:12px;color:#8b949e;margin-bottom:8px}}
.stat-big{{font-size:2em;font-weight:bold}}
.stat-sub{{font-size:12px;color:#8b949e;margin-top:2px}}
.pnl{{font-size:14px!important;margin-top:4px}}
.feat-row{{display:flex;gap:8px;margin-top:8px;font-size:11px;color:#555}}
.section{{background:#161b22;border-radius:10px;padding:15px;margin-bottom:12px;border:1px solid #21262d}}
.section-title{{font-size:12px;color:#8b949e;margin-bottom:10px;text-transform:uppercase;letter-spacing:1px}}
.chart{{display:flex;align-items:flex-end;gap:3px;height:80px;margin-top:5px}}
.bar{{display:flex;flex-direction:column;justify-content:flex-end;align-items:center;flex:1;cursor:pointer;position:relative}}
.bar::before{{content:'';display:block;width:100%;height:var(--h,0%);background:var(--c,#333);border-radius:3px 3px 0 0;transition:opacity 0.2s}}
.bar.empty::before{{height:5px;background:#21262d}}
.bar.active-hour::before{{box-shadow:0 0 8px var(--c)}}
.bar span{{font-size:8px;color:#555;margin-top:3px}}
.trade-row{{display:flex;gap:8px;padding:5px 0;border-bottom:1px solid #21262d;font-size:12px;align-items:center}}
.trade-bot{{color:#8b949e;min-width:30px;font-weight:bold}}
.trade-detail{{color:#c9d1d9;flex:1}}
.pos-row{{padding:5px 0;border-bottom:1px solid #21262d;font-size:12px;color:#8b949e}}
.news-row{{display:flex;gap:8px;padding:5px 0;border-bottom:1px solid #21262d;font-size:11px;align-items:center}}
.news-score{{color:#ffab00;min-width:30px}}
.news-title{{color:#58a6ff;text-decoration:none;flex:1}}
.news-title:hover{{text-decoration:underline}}
.news-src{{color:#555;font-size:10px;min-width:80px;text-align:right}}
.proc-row{{display:flex;gap:8px;flex-wrap:wrap;margin-top:5px}}
.proc{{padding:4px 8px;border-radius:4px;font-size:11px}}
.proc-ok{{background:#1f3a2a;color:#00e676}}
.proc-down{{background:#3a1f1f;color:#ff5252}}
.updated{{color:#555;font-size:10px;text-align:right;margin-top:10px}}
@media(max-width:500px){{.cards{{flex-direction:column}}.summary-row{{gap:10px}}}}
</style>
</head>
<body>
<h1>🦅 OpenClaw Trading System</h1>
<div class="subtitle">Live dashboard • Auto-refreshes every 20s</div>

<div class="balance-big">${balance:.2f}</div>
<div class="balance-label">Total Portfolio Value</div>

<div class="summary-row">
    <div class="summary-item">
        <div class="val" style="color:{'#00e676' if total_wr>=70 else '#ffab00'}">{total_wr:.0f}%</div>
        <div class="lbl">Combined Win Rate</div>
    </div>
    <div class="summary-item">
        <div class="val">{total_w}W/{total_l}L</div>
        <div class="lbl">Total Trades</div>
    </div>
    <div class="summary-item">
        <div class="val" style="color:{'#00e676' if total_pnl>=0 else '#ff5252'}">${total_pnl:+.2f}</div>
        <div class="lbl">Session PnL</div>
    </div>
    <div class="summary-item">
        <div class="val">⚡{total_extreme}</div>
        <div class="lbl">Extreme Signals</div>
    </div>
    <div class="summary-item">
        <div class="val">🛰️{total_confirms}</div>
        <div class="lbl">Coinbase Confirms</div>
    </div>
</div>


<div class="section">
    <div class="section-title">📈 Equity Curve (last 50 trades)</div>
        <defs><linearGradient id="eg" x1="0" y1="0" x2="0" y2="1">
        </linearGradient></defs>
    <div style="display:flex;justify-content:space-between;font-size:10px;color:#555;margin-top:4px">
    </div>
</div>
<div class="cards">{cards_html}</div>

<div class="section">
    <div class="section-title">📊 Win Rate by Hour (UTC) — Current Hour: {utc_hour:02d}:00</div>
    <div class="chart">{chart_bars}</div>
</div>

<div class="section">
    <div class="section-title">📈 Open Positions ({len(positions)})</div>
    {pos_html}
</div>

<div class="section">
    <div class="section-title">🔄 Recent Trades</div>
    {recent_html if recent_html else '<div style="color:#555">No settled trades yet</div>'}
</div>

<div class="section">
    <div class="section-title">📰 Top News (from feed)</div>
    {news_html}
</div>

<div class="section">
    <div class="section-title">⚙️ System Status</div>
    <div class="proc-row">{proc_html}</div>
</div>

<div class="updated">Last updated: {now} UTC</div>
</body>
</html>'''

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        html = generate_html().encode()
        self.send_response(200)
        self.send_header('Content-Type','text/html')
        self.send_header('Content-Length',len(html))
        self.end_headers()
        self.wfile.write(html)
    def log_message(self,*args): pass

if __name__=="__main__":
    server = http.server.HTTPServer(('0.0.0.0',8080),Handler)
    print("Dashboard v2.0 running at http://0.0.0.0:8080")
    server.serve_forever()
