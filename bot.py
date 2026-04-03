import os
import time
import random
import numpy as np
from pycoingecko import CoinGeckoAPI
from termcolor import colored
import datetime
import requests
 
START_TIME = datetime.datetime.now()
cg = CoinGeckoAPI()
 
# === YOUR TELEGRAM SETTINGS (already filled in) ===
BOT_TOKEN = "8716034840:AAFhyZgriXRbPBfhajMVLG300TMBELh68TE"
CHAT_ID = "8257178399"
 
def send_telegram(message):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    params = {"chat_id": CHAT_ID, "text": message, "parse_mode": "Markdown"}
    try:
        requests.get(url, params=params, timeout=10)
    except:
        pass
 
# === YOUR EXISTING BOT LOGIC (same as before) ===
INITIAL_BALANCE = 500.0
CURRENT_BALANCE = INITIAL_BALANCE
TRADE_LOG = []
VOLATILITY_HISTORY = []
trade_counter = 0
VOLATILITY_WINDOW = 30
TRADE_INTERVAL = 90   # 15-minute markets
 
def get_btc_prices(minutes=30):
    try:
        data = cg.get_coin_market_chart_by_id(id='bitcoin', vs_currency='usd', days=1, interval='minute')
        prices = [candle[1] for candle in data['prices'][-minutes:]]
        return np.array(prices)
    except:
        return np.array([random.uniform(60000, 72000) for _ in range(minutes)])
 
def compute_volatility(prices):
    if len(prices) < 2: return 0
    returns = np.diff(np.log(prices))
    return np.std(returns)
 
def bayesian_prob_update(prices):
    returns = np.diff(np.log(prices))
    momentum = np.mean(returns[-5:]) if len(returns) >= 5 else 0
    prior = 0.5
    likelihood_up = 1 / (1 + np.exp(-momentum * 100))
    posterior = (likelihood_up * prior) / (likelihood_up * prior + (1 - likelihood_up) * (1 - prior))
    # Simple RSI adjustment
    if len(returns) >= 14:
        gains = np.maximum(returns[-14:], 0).mean()
        losses = np.abs(np.minimum(returns[-14:], 0)).mean()
        rs = gains / losses if losses != 0 else 1
        rsi = 100 - (100 / (1 + rs))
        if rsi < 30: posterior = min(1.0, posterior + 0.1)
        elif rsi > 70: posterior = max(0.0, posterior - 0.1)
    return posterior
 
def kelly_size(prob):
    edge = prob - 0.5
    return max(0.01, min(0.5, 2 * edge))  # fractional Kelly
 
def simulate_trade():
    global trade_counter, CURRENT_BALANCE
    prices = get_btc_prices(VOLATILITY_WINDOW)
    vol = compute_volatility(prices)
    avg_vol = np.mean(VOLATILITY_HISTORY[-10:] or [vol])
    if abs(vol - avg_vol) <= 0.95 * avg_vol and avg_vol > 0:
        return  # skip low vol
    
    prob_up = bayesian_prob_update(prices)
    trade_counter += 1
 
    if prob_up >= 0.52 or prob_up <= 0.48 or (trade_counter % 5 == 0):
        direction = "UP" if prob_up > 0.5 else "DOWN"
        bet = max(20, int(0.05 * CURRENT_BALANCE))  # 5% of balance, min $20
        message = f"""🚨 OPENCLAW ALERT
PLACE ${bet} on **{direction}**
Avg price: TBD (check link)
https://polymarket.com/crypto
Balance: ${CURRENT_BALANCE:.2f}"""
        send_telegram(message)
        TRADE_LOG.append(f"LIVE {direction} ${bet}")
 
try:
    while True:
        simulate_trade()
        time.sleep(TRADE_INTERVAL)
except KeyboardInterrupt:
    print("Bot stopped.")
