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

VERSION_BALANCE = 159.02

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

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path == '/api/data':
            try:
                data = {"balance":get_balance(),"version_balance":VERSION_BALANCE,"stats":get_stats(),"procs":get_processes(),"trades":get_recent_trades(8),"whales":get_whales(6),"positions":get_positions()}
                self.send_response(200)
                self.send_header('Content-Type','application/json')
                self.send_header('Access-Control-Allow-Origin','*')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
            except Exception as e:
                self.send_response(500); self.end_headers()
                self.wfile.write(str(e).encode())
        else:
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.end_headers()
            html = open('/root/dashboard_v4.html').read()
            self.wfile.write(html.encode())

if __name__ == '__main__':
    print("Dashboard v4.0 running at http://0.0.0.0:8080")
    http.server.HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
