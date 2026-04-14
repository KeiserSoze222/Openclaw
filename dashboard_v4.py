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

VERSION_BALANCE = 977.64

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


def get_hourly():
    hw={}
    for path in ["/root/trade_log.csv","/root/eth_trade_log.csv","/root/sol_trade_log.csv"]:
        for row in parse_csv(path):
            if len(row)>=4 and ("WIN" in row[3] or "LOSS" in row[3]):
                try:
                    h=int(row[0].split(" ")[1].split(":")[0])
                    if h not in hw: hw[h]={"w":0,"l":0}
                    if "WIN" in row[3]: hw[h]["w"]+=1
                    else: hw[h]["l"]+=1
                except: pass
    return {str(h):{"w":v["w"],"l":v["l"],"wr":round(v["w"]/(v["w"]+v["l"])*100,1) if (v["w"]+v["l"])>0 else 0} for h,v in hw.items()}

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path.split("?")[0] == "/api/data":
            try:
                data = {"balance":get_balance(),"version_balance":VERSION_BALANCE,"stats":get_stats(),"procs":get_processes(),"trades":get_recent_trades(20),"whales":get_whales(6),"positions":get_positions(),"hourly":get_hourly(),"features":[],"insights":[]}
                self.send_response(200)
                self.send_header('Content-Type','application/json')
                self.send_header('Access-Control-Allow-Origin','*')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
            except Exception as e:
                self.send_response(500); self.end_headers()
                self.wfile.write(str(e).encode())
        elif self.path.split("?")[0] == "/arena_state":
            try:
                d=json.load(open('/root/arena_state.json'))
                self.send_response(200)
                self.send_header('Content-Type','application/json')
                self.send_header('Access-Control-Allow-Origin','*')
                self.end_headers()
                self.wfile.write(json.dumps(d).encode())
            except: self.send_response(500); self.end_headers()
        elif self.path.split("?")[0] == "/arena":
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.end_headers()
            self.wfile.write(open('/root/arena_dashboard.html','rb').read())
        elif self.path.startswith('/arena_signal/'):
            mkt=self.path.split('/')[-1]
            try:
                d=json.load(open(f'/root/arena_signal_{mkt}.json'))
                self.send_response(200)
                self.send_header('Content-Type','application/json')
                self.send_header('Access-Control-Allow-Origin','*')
                self.end_headers()
                self.wfile.write(json.dumps(d).encode())
            except: self.send_response(500); self.end_headers()
        elif self.path.split("?")[0] == "/bible":
            try:
                content=open('/root/OPENCLAW_GUIDE.md').read()
                self.send_response(200)
                self.send_header('Content-Type','text/html')
                self.end_headers()
                html=f"""<!DOCTYPE html><html><head><title>OpenClaw Bible</title>
                <style>body{{background:#050810;color:#e0e8ff;font-family:monospace;padding:20px;max-width:900px;margin:0 auto;}}
                h1,h2,h3{{color:#00d4ff;}} pre{{background:#0d1526;padding:15px;border-radius:8px;overflow-x:auto;}}</style></head>
                <body><pre>{content}</pre></body></html>"""
                self.wfile.write(html.encode())
            except: self.send_response(404); self.end_headers()
        elif self.path.split("?")[0] == "/api/intelligence":
            try:
                import csv,datetime
                signals=[]
                for f,m in [('/root/trade_log.csv','BTC'),('/root/eth_trade_log.csv','ETH'),('/root/sol_trade_log.csv','SOL')]:
                    rows=list(csv.reader(open(f)))
                    wins=[r for r in rows if len(r)>=5 and 'WIN' in r[3]]
                    losses=[r for r in rows if len(r)>=3 and 'LOSS' in r[3]]
                    if wins:
                        avg_profit=sum(float(r[4].replace('%',''))*float(r[2])/100 for r in wins if len(r)>=5)/len(wins)
                        signals.append(f"{m}: {len(wins)}W/{len(losses)}L avg profit ${avg_profit:.2f}")
                balance=get_balance()
                insights=[
                    f"ETH is best performer at 93% WR — consider increasing bet size",
                    f"Peak hours: 06,07,09,11,14,15,19,21 UTC",
                    f"Current balance ${balance:.2f} — deposit to $600 for $125/day target",
                    f"Whale follower active — watching for $3000+ BTC/ETH/SOL bets",
                ]
                self.send_response(200)
                self.send_header('Content-Type','application/json')
                self.send_header('Access-Control-Allow-Origin','*')
                self.end_headers()
                self.wfile.write(json.dumps({"signals":signals,"insights":insights}).encode())
            except Exception as e: self.send_response(500); self.end_headers(); self.wfile.write(str(e).encode())
        else:
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.end_headers()
            html = open('/root/dashboard_v4.html').read()
            self.wfile.write(html.encode())

if __name__ == '__main__':
    print("Dashboard v4.0 running at http://0.0.0.0:8080")
    http.server.HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
