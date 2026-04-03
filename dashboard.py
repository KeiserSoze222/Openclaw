#!/usr/bin/env python3
import http.server, json, csv, os, datetime, requests, tempfile, subprocess
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration

raw = open('/root/real_bot_pre_v4_backup.py').read()
KALSHI_KEY = raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
KALSHI_SEC = raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
del raw
_tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
_tf.write(KALSHI_SEC); _tf.close()
_config = Configuration()
_config.host = "https://api.elections.kalshi.com/trade-api/v2"
kalshi = KalshiClient(_config)
kalshi.set_kalshi_auth(KALSHI_KEY, _tf.name)

VERSION_BALANCE = 159.84

def get_balance():
    try:
        url = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
        h = kalshi.kalshi_auth.create_auth_headers("GET", url)
        r = requests.get(url, headers=h, timeout=6)
        d = r.json()
        return (d.get("balance",0) + d.get("portfolio_value",0)) / 100
    except: return 0

def get_positions():
    try:
        url = "https://api.elections.kalshi.com/trade-api/v2/portfolio/positions"
        h = kalshi.kalshi_auth.create_auth_headers("GET", url)
        r = requests.get(url, headers=h, params={"limit":10}, timeout=6)
        return r.json().get("market_positions", [])
    except: return []

def parse_csv(path):
    rows = []
    try:
        with open(path) as f:
            for row in csv.reader(f):
                if len(row) >= 4: rows.append(row)
    except: pass
    return rows

def get_stats():
    stats = {}
    for market, path in [("BTC","/root/trade_log.csv"),("ETH","/root/eth_trade_log.csv"),("SOL","/root/sol_trade_log.csv")]:
        rows = parse_csv(path)
        w=l=0; pnl=0.0
        for row in rows:
            if "WIN" in row[3]:
                w+=1
                try: pnl+=float(row[4].replace("%",""))*float(row[2])/100
                except: pass
            elif "LOSS" in row[3]:
                l+=1
                try: pnl-=float(row[2])
                except: pass
        wr = w/(w+l)*100 if (w+l) else 0
        stats[market] = {"w":w,"l":l,"wr":round(wr,1),"pnl":round(pnl,2)}
    return stats

def get_recent_trades(n=8):
    trades = []
    for market, path in [("BTC","/root/trade_log.csv"),("ETH","/root/eth_trade_log.csv"),("SOL","/root/sol_trade_log.csv")]:
        for row in parse_csv(path):
            if "WIN" in row[3] or "LOSS" in row[3]:
                trades.append({"market":market,"time":row[0],"dir":row[1],"bet":row[2],"result":row[3]})
    trades.sort(key=lambda x: x["time"], reverse=True)
    return trades[:n]

def get_whales(n=6):
    whales = []
    try:
        with open("/root/whale_log.csv") as f:
            for row in csv.reader(f):
                if len(row) >= 4:
                    whales.append({"time":row[0],"ticker":row[1],"side":row[2],"size":row[3],"type":row[4] if len(row)>4 else ""})
    except: pass
    return list(reversed(whales[-n:]))

def get_processes():
    procs = {}
    for name, pattern in [("BTC","openclaw.py --market btc"),("ETH","openclaw.py --market eth"),("SOL","openclaw.py --market sol"),("WHALE","whale_scanner"),("BOND","bond_scanner"),("WATCHDOG","watchdog.py")]:
        r = subprocess.run(["pgrep","-f",pattern], capture_output=True)
        procs[name] = r.returncode == 0
    return procs


def get_features():
    import json
    from collections import defaultdict
    try:
        signals = defaultdict(lambda:{"w":0,"l":0})
        minutes = defaultdict(lambda:{"w":0,"l":0})
        with open('/root/feature_log.json') as f:
            for line in f:
                try:
                    e = json.loads(line.strip())
                    if e.get("action") not in ("WIN","LOSS"): continue
                    outcome = "w" if e["action"]=="WIN" else "l"
                    feat = e.get("features",{})
                    sig = feat.get("signal_type","UNKNOWN")
                    signals[sig][outcome] += 1
                    m = feat.get("entry_minute",0)
                    minutes[f"Min {m}"][outcome] += 1
                except: pass
        rows = []
        for k,v in sorted(signals.items()):
            total = v["w"]+v["l"]
            wr = round(v["w"]/total*100,1) if total else 0
            rows.append({"name":k,"w":v["w"],"l":v["l"],"wr":wr})
        for k,v in sorted(minutes.items()):
            total = v["w"]+v["l"]
            wr = round(v["w"]/total*100,1) if total else 0
            rows.append({"name":k,"w":v["w"],"l":v["l"],"wr":wr})
        return rows
    except: return []

def get_insights(stats):
    insights = []
    try:
        allW = sum(s["w"] for s in stats.values())
        allL = sum(s["l"] for s in stats.values())
        total = allW + allL
        wr = allW/total*100 if total else 0
        if wr >= 80: insights.append(f"🔥 Win rate {wr:.1f}% — exceptional performance")
        elif wr >= 75: insights.append(f"✅ Win rate {wr:.1f}% — strong edge confirmed")
        elif wr >= 70: insights.append(f"📊 Win rate {wr:.1f}% — above break-even")
        else: insights.append(f"⚠️ Win rate {wr:.1f}% — monitor closely")
        best = max(stats.items(), key=lambda x: x[1]["wr"])
        insights.append(f"⚡ {best[0]} is best market at {best[1]['wr']:.1f}% WR")
        if total >= 30:
            insights.append(f"📊 {total} trades — statistically significant sample")
        else:
            insights.append(f"📊 {30-total} more trades for full confidence")
        import datetime
        hour = datetime.datetime.now(datetime.timezone.utc).hour
        peak = {3,6,7,8,9,10,11,14,15,16,19,21}
        if hour in peak:
            insights.append(f"🟢 Current hour {hour}:00 UTC is PEAK — full bet size")
        elif hour == 5:
            insights.append(f"🔴 Hour 5 UTC — bots paused (stop hour)")
        else:
            insights.append(f"🟡 Hour {hour}:00 UTC — reduced bet size")
    except: pass
    return insights

def get_hourly():
    from collections import defaultdict
    hourly = defaultdict(lambda:{"w":0,"l":0})
    for path in ["/root/trade_log.csv","/root/eth_trade_log.csv","/root/sol_trade_log.csv"]:
        try:
            import csv
            with open(path) as f:
                for row in csv.reader(f):
                    if len(row)<4: continue
                    try:
                        h = int(row[0][11:13])
                        if "WIN" in row[3]: hourly[h]["w"] += 1
                        elif "LOSS" in row[3]: hourly[h]["l"] += 1
                    except: pass
        except: pass
    return {str(k):v for k,v in hourly.items()}

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path == '/api/data':
            try:
                stats = get_stats()
                data = {
                    "balance":get_balance(),
                    "version_balance":VERSION_BALANCE,
                    "stats":stats,
                    "procs":get_processes(),
                    "trades":get_recent_trades(8),
                    "whales":get_whales(6),
                    "positions":get_positions(),
                    "features":get_features(),
                    "insights":get_insights(stats),
                    "hourly":get_hourly(),
                }
                self.send_response(200)
                self.send_header('Content-Type','application/json')
                self.send_header('Access-Control-Allow-Origin','*')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
            except Exception as e:
                self.send_response(500); self.end_headers()
                self.wfile.write(str(e).encode())
        elif self.path == '/bible':
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.end_headers()
            md = open('/root/OPENCLAW_GUIDE.md').read()
            html = f'''<!DOCTYPE html><html><head><meta charset="UTF-8">
            <title>OpenClaw Bible</title>
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500&family=Orbitron:wght@700&display=swap" rel="stylesheet">
            <style>
            body{{background:#050810;color:#e0e8ff;font-family:'Inter',sans-serif;max-width:900px;margin:0 auto;padding:40px 20px;line-height:1.8;}}
            h1{{font-family:'Orbitron',monospace;color:#00d4ff;font-size:24px;margin-bottom:8px;}}
            h2{{font-family:'Orbitron',monospace;color:#00d4ff;font-size:16px;margin-top:40px;border-bottom:1px solid #1a2540;padding-bottom:8px;}}
            h3{{color:#00ff88;font-size:14px;margin-top:24px;}}
            code{{background:#0d1526;padding:2px 6px;border-radius:4px;font-size:12px;color:#ffd60a;}}
            pre{{background:#0d1526;padding:16px;border-radius:8px;overflow-x:auto;border:1px solid #1a2540;}}
            a{{color:#00d4ff;}}
            .back{{display:inline-block;margin-bottom:32px;color:#00d4ff;text-decoration:none;font-size:12px;letter-spacing:1px;border:1px solid #1a2540;padding:6px 12px;border-radius:6px;}}
            strong{{color:#ffd60a;}}
            </style></head><body>
            <a href="/" class="back">← BACK TO DASHBOARD</a>
            <div id="content"></div>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/9.1.6/marked.min.js"></script>
            <script>
            const md = {repr(md)};
            document.getElementById('content').innerHTML = marked.parse(md);
            </script>
            </body></html>'''
            self.wfile.write(html.encode())
        else:
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.end_headers()
            html = open('/root/dashboard_v4.html').read()
            self.wfile.write(html.encode())

if __name__ == '__main__':
    print("Dashboard v4.0 running at http://0.0.0.0:8080")
    http.server.HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
