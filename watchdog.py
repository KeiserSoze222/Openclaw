#!/usr/bin/env python3
"""
OpenClaw Watchdog
Checks every 5 minutes if bots are running and restarts if crashed.
Run: nohup python3 -u /root/watchdog.py > /root/watchdog.log 2>&1 &
"""
import subprocess
import time
import datetime
import requests

# Load telegram config from real_bot
raw       = open('/root/real_bot.py').read()
BOT_TOKEN = '8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
CHAT_ID   = '8257178399'

BOTS = [
    {
        "name":    "BTC",
        "script":  "/root/real_bot.py",
        "log":     "/root/bot.log",
        "stop":    "/root/STOP",
    },
    {
        "name":    "ETH",
        "script":  "/root/eth_bot.py",
        "log":     "/root/eth_bot.log",
        "stop":    "/root/STOP_ETH",
    },
    {
        "name":    "SOL",
        "script":  "/root/sol_bot.py",
        "log":     "/root/sol_bot.log",
        "stop":    "/root/STOP_SOL",
    },
    {
        "name":    "BOND",
        "script":  "/root/bond_scanner.py",
        "log":     "/root/bond_scanner.log",
        "stop":    "/root/STOP_BOND",
    },
]

def send_telegram(msg):
    try:
        requests.get(
            f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            params={"chat_id": CHAT_ID, "text": msg},
            timeout=5
        )
    except Exception:
        pass

def is_running(script):
    result = subprocess.run(
        ["pgrep", "-f", script],
        capture_output=True
    )
    return result.returncode == 0

def restart_bot(bot):
    import os, signal, time
    # Kill any existing instances first
    try:
        result = subprocess.run(
            ["pgrep", "-f", bot["script"]],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            pids = result.stdout.strip().split()
            for pid in pids:
                try:
                    os.kill(int(pid), signal.SIGTERM)
                    print(f"[Watchdog] Killed existing PID {pid}")
                except Exception:
                    pass
            time.sleep(3)  # wait for clean exit
    except Exception as e:
        print(f"[Watchdog] Kill failed: {e}")
    # Now start fresh
    log  = open(bot["log"], "a")
    proc = subprocess.Popen(
        ["python3", "-u", bot["script"]],
        stdout=log,
        stderr=log,
        start_new_session=True
    )
    return proc.pid

if __name__ == "__main__":
    print(f"[{datetime.datetime.now().strftime('%H:%M')}] Watchdog started")
    send_telegram("🐕 Watchdog started — monitoring BTC, ETH, SOL, BOND bots")

    # Auto-start any bots not already running on watchdog launch
    import os
    for bot in BOTS:
        if not os.path.exists(bot["stop"]) and not is_running(bot["script"]):
            pid = restart_bot(bot)
            print(f"[Watchdog] Auto-started {bot['name']} (PID {pid})")
            time.sleep(5)

    while True:
        import os
        for bot in BOTS:
            # Skip if stop file exists
            if os.path.exists(bot["stop"]):
                continue

            if not is_running(bot["script"]):
                now = datetime.datetime.now().strftime('%H:%M')
                print(f"[{now}] {bot['name']} bot is DOWN — restarting")
                pid = restart_bot(bot)
                msg = f"⚠️ {bot['name']} bot crashed and was restarted (PID {pid})"
                print(msg)
                send_telegram(msg)
                time.sleep(10)  # wait for restart
            else:
                print(f"[{datetime.datetime.now().strftime('%H:%M')}] "
                      f"{bot['name']} ✅")

        time.sleep(300)  # check every 5 minutes
