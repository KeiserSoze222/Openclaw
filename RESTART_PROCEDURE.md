# OpenClaw Restart Procedure

## ALWAYS follow this order:

### To restart bots after code changes:
1. Stop watchdog: `pkill -f watchdog.py`
2. Stop all bots: `pkill -f real_bot.py && pkill -f eth_bot.py && pkill -f sol_bot.py`
3. Wait: `sleep 5`
4. Verify stopped: `ps aux | grep -E "real_bot|eth_bot|sol_bot|watchdog" | grep -v grep`
5. Make your code changes
6. Compile check: `python3 -m py_compile /root/real_bot.py && python3 -m py_compile /root/eth_bot.py && python3 -m py_compile /root/sol_bot.py`
7. Start watchdog ONLY: `nohup python3 -u /root/watchdog.py > /root/watchdog.log 2>&1 &`
8. Watchdog auto-starts all bots immediately on launch
9. OR manually start bots AND watchdog together but never start bots if watchdog already running

## NEVER:
- Start bots manually if watchdog is already running
- This creates duplicate processes that double-bet

## Emergency stop:
touch /root/STOP && touch /root/STOP_ETH && touch /root/STOP_SOL
pkill -f real_bot.py && pkill -f eth_bot.py && pkill -f sol_bot.py
