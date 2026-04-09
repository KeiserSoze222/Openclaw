import requests,time,datetime,json,os,tempfile
raw=open("/root/real_bot_pre_v4_backup.py").read()
KALSHI_KEY=raw.split("KALSHI_API_KEY = '")[1].split("'")[0]
KALSHI_SEC=raw.split("KALSHI_SECRET  = '''")[1].split("'''")[0]
BOT_TOKEN=raw.split("BOT_TOKEN = '")[1].split("'")[0]
CHAT_ID=raw.split("CHAT_ID   = '")[1].split("'")[0]
tf=tempfile.NamedTemporaryFile(delete=False,suffix=".pem",mode="w")
tf.write(KALSHI_SEC)
tf.close()
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
cfg=Configuration()
cfg.host="https://api.elections.kalshi.com/trade-api/v2"
k=KalshiClient(cfg)
k.set_kalshi_auth(KALSHI_KEY,tf.name)
SCAN_INTERVAL=60
alerted=set()
BASE_RATES={"inflation":0.95,"recession":0.45,"rate":0.92,"employment":0.88,"gdp":0.72,"tariff":0.65,"uncertainty":0.55,"data":0.98,"balance":0.60,"mandate":0.75}
def hdrs(m,u): return k.kalshi_auth.create_auth_headers(m,u)
def tg(msg):
 try: requests.get("https://api.telegram.org/bot"+BOT_TOKEN+"/sendMessage",params={"chat_id":CHAT_ID,"text":msg},timeout=5)
 except: pass
def get_mentions_markets():
 url="https://api.elections.kalshi.com/trade-api/v2/markets"
 r=requests.get(url,headers=hdrs("GET",url),params={"status":"open","limit":200},timeout=10)
 if r.status_code!=200: return []
 markets=[]
 for m in r.json().get("markets",[]):
  tk=m.get("ticker","")
  title=m.get("title","").lower()
  series=m.get("series_ticker","")
  if any(x in series.upper() for x in ["FOMC","POWELL","FED","EARNINGS","MENTION","SPEECH","PRESS"]):
   markets.append(m)
  elif any(x in title for x in ["mentioned","mention","says","said","word","times"]):
   markets.append(m)
 return markets
def analyze(m):
 title=m.get("title","").lower()
 ticker=m.get("ticker","")
 yes_ask=m.get("yes_ask_dollars") or 0.5
 yp=float(yes_ask)
 word_found=None
 for word,base in BASE_RATES.items():
  if word in title:
   word_found=word
   base_rate=base
   break
 if not word_found: return None
 edge=base_rate-yp
 if abs(edge)<0.08: return None
 side="yes" if edge>0 else "no"
 price=yp if side=="yes" else 1-yp
 return {"ticker":ticker,"title":m.get("title","")[:60],"word":word_found,"base_rate":base_rate,"market_price":yp,"edge":edge,"side":side,"price":price}
print("Mentions scanner started - watching for FOMC/earnings markets")
tg("Mentions scanner started - watching for FOMC/earnings/speech markets")
while True:
 if os.path.exists("/root/STOP_MENTIONS"): break
 try:
  markets=get_mentions_markets()
  if markets:
   print("["+datetime.datetime.now().strftime("%H:%M")+"] Found "+str(len(markets))+" mentions markets")
   for m in markets:
    tk=m.get("ticker","")
    analysis=analyze(m)
    if analysis and tk not in alerted:
     alerted.add(tk)
     msg="MENTIONS EDGE: "+analysis["ticker"]+"
Word: "+analysis["word"]+" | Base rate: "+str(round(analysis["base_rate"]*100))+"%
Market price: "+str(round(analysis["market_price"]*100))+"% | Edge: "+str(round(analysis["edge"]*100,1))+"%
Trade: "+analysis["side"].upper()+" @ "+str(round(analysis["price"]*100))+"c
"+analysis["title"]
     print(msg)
     tg(msg)
  else:
   print("["+datetime.datetime.now().strftime("%H:%M")+"] No mentions markets open yet")
 except Exception as e: print("[Mentions] "+str(e))
 time.sleep(SCAN_INTERVAL)
