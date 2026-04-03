#!/usr/bin/env python3
"""
OpenClaw Unified Bot
Usage:
  python3 openclaw.py --market BTC
  python3 openclaw.py --market ETH  
  python3 openclaw.py --market SOL
"""
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--market', choices=['BTC', 'ETH', 'SOL'], required=True)
args = parser.parse_args()

MARKET_SERIES = f"KX{args.market}15M"
STOP_FILE     = f"/root/STOP_{args.market}"
TRADE_LOG     = f"/root/{args.market.lower()}_trade_log.csv"
PERF_LOG      = f"/root/{args.market.lower()}_performance_log.json"
BOT_NAME      = f"OpenClaw {args.market} Bot v4.0"
