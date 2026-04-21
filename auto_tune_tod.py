#!/usr/bin/env python3
"""
OpenClaw Auto-Tuner
Runs every 48 hours, analyzes hourly win rates, updates TOD thresholds.
Cron: 0 6 */2 * * python3 /root/auto_tune_tod.py >> /root/auto_tune.log 2>&1
"""
import csv, json, datetime, requests
from collections import defaultdict

# Telegram config — same values as openclaw.py
BOT_TOKEN = '8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
CHAT_ID   = '8257178399'

def send_telegram(msg):
    try:
        requests.get(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
                     params={"chat_id": CHAT_ID, "text": msg}, timeout=5)
    except: pass

def analyze_hourly(csv_files, min_trades=5, lookback_days=7):
    """Analyze hourly win rates from recent data."""
    cutoff = (datetime.datetime.now() - datetime.timedelta(days=lookback_days)).strftime('%Y-%m-%d')
    hourly = defaultdict(lambda:{'w':0,'l':0})
    for f in csv_files:
        try:
            for row in csv.reader(open(f)):
                if len(row)<5 or row[0]<cutoff: continue
                h = int(row[0][11:13])
                if row[3]=='WIN': hourly[h]['w']+=1
                elif row[3]=='LOSS': hourly[h]['l']+=1
        except: pass
    results = {}
    for h in range(24):
        v = hourly.get(h, {'w':0,'l':0})
        t = v['w']+v['l']
        wr = v['w']/t*100 if t>=min_trades else -1
        results[h] = {'wr': wr, 'trades': t, 'w': v['w'], 'l': v['l']}
    return results

def classify_hours(hourly):
    """Classify hours into performance tiers."""
    stop_hours   = [h for h,v in hourly.items() if 0<=v['wr']<50  and v['trades']>=5]
    bad_hours    = [h for h,v in hourly.items() if 50<=v['wr']<65 and v['trades']>=5]
    moderate     = [h for h,v in hourly.items() if 65<=v['wr']<75 and v['trades']>=5]
    good_hours   = [h for h,v in hourly.items() if 75<=v['wr']<85 and v['trades']>=5]
    peak_hours   = [h for h,v in hourly.items() if v['wr']>=85    and v['trades']>=5]
    unknown      = [h for h in range(24) if hourly[h]['wr']<0]
    return stop_hours, bad_hours, moderate, good_hours, peak_hours, unknown

if __name__ == "__main__":
    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
    print(f"\n{'='*50}")
    print(f"OpenClaw Auto-Tuner — {now}")
    print(f"{'='*50}")

    files = ['/root/trade_log.csv',
             '/root/eth_trade_log.csv',
             '/root/sol_trade_log.csv']

    hourly = analyze_hourly(files, lookback_days=7)
    stop, bad, mod, good, peak, unknown = classify_hours(hourly)

    print(f"\nHour Classification (last 7 days):")
    print(f"  🚫 STOP  (WR<50%):  {sorted(stop)}")
    print(f"  🔴 BAD   (50-65%):  {sorted(bad)}")
    print(f"  🟡 MOD   (65-75%):  {sorted(mod)}")
    print(f"  🟢 GOOD  (75-85%):  {sorted(good)}")
    print(f"  🏆 PEAK  (WR>85%):  {sorted(peak)}")
    print(f"  ❓ UNKNOWN (<5 trades): {sorted(unknown)}")

    # Generate updated TOD rules
    report = f"🤖 OpenClaw Auto-Tuner Report — {now}\n\n"
    report += f"Based on last 7 days of trading:\n"
    report += f"🚫 Stop hours: {sorted(stop)}\n"
    report += f"🔴 Bad hours: {sorted(bad)}\n"
    report += f"🏆 Peak hours: {sorted(peak)}\n\n"

    # Check for significant changes
    current_bad = [0, 1, 4, 5, 12, 13, 22]
    new_bad = sorted(set(stop + bad))
    added   = [h for h in new_bad if h not in current_bad]
    removed = [h for h in current_bad if h not in new_bad]

    if added:
        report += f"⚠️ NEW bad hours detected: {added}\n"
    if removed:
        report += f"✅ Hours improved (no longer bad): {removed}\n"
    if not added and not removed:
        report += "✅ No significant changes from last analysis\n"

    # Save results for dashboard
    results = {
        "timestamp": now,
        "stop_hours": sorted(stop),
        "bad_hours": sorted(bad),
        "moderate_hours": sorted(mod),
        "good_hours": sorted(good),
        "peak_hours": sorted(peak),
        "hourly": {str(h): v for h,v in hourly.items()}
    }
    with open('/root/tod_analysis.json', 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to /root/tod_analysis.json")
    print(report)
    send_telegram(report)
    print("Auto-tuner complete.")
