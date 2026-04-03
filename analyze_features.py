#!/usr/bin/env python3
"""
Feature Attribution Analyzer
Run weekly: python3 /root/analyze_features.py
Shows which bot features are contributing to wins vs losses.
"""
import json
from collections import defaultdict

entries = []
try:
    with open('/root/feature_log.json') as f:
        for line in f:
            try:
                entries.append(json.loads(line.strip()))
            except:
                pass
except FileNotFoundError:
    print("No feature_log.json yet — run the bot first")
    exit()

settled = [e for e in entries if e['action'] in ('WIN', 'LOSS')]
print(f"\n{'='*50}")
print(f"FEATURE ATTRIBUTION REPORT")
print(f"Total settled trades: {len(settled)}")
print(f"{'='*50}\n")

def analyze_feature(name, key_func):
    groups = defaultdict(lambda: {'wins': 0, 'losses': 0, 'pnl': 0})
    for e in settled:
        k = key_func(e)
        if e['action'] == 'WIN':
            groups[k]['wins'] += 1
            groups[k]['pnl'] += e.get('profit_pct', 0) * e['bet'] / 100
        else:
            groups[k]['losses'] += 1
            groups[k]['pnl'] -= e['bet']
    print(f"── {name} ──")
    for k, v in sorted(groups.items()):
        total = v['wins'] + v['losses']
        wr = v['wins']/total*100 if total else 0
        verdict = "✅ KEEP" if wr >= 70 else "⚠️ REVIEW" if wr >= 55 else "❌ REMOVE"
        print(f"  {k}: {v['wins']}W/{v['losses']}L ({wr:.0f}%) "
              f"PnL=${v['pnl']:+.2f} {verdict}")
    print()

analyze_feature("Signal Type",
    lambda e: e.get('features', {}).get('signal_type', 'UNKNOWN'))
analyze_feature("Entry Minute",
    lambda e: f"min_{e.get('features', {}).get('entry_minute', -1)}")
analyze_feature("Market",
    lambda e: e.get('features', {}).get('market', 'UNKNOWN'))
analyze_feature("Binance Confirmed",
    lambda e: str(e.get('features', {}).get('binance_confirmed', False)))
analyze_feature("Edge Range",
    lambda e: f"{int(e.get('features', {}).get('edge', 0) * 10) * 10}%+")
