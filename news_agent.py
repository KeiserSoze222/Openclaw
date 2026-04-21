"""
OpenClaw News Feed Agent
========================
Monitors RSS feeds and scores content for trading bot relevance.
Sends daily digest + instant alerts via Telegram.
Run alongside the trading bot: nohup python3 -u news_agent.py > news_agent.log 2>&1 &
"""

import feedparser
import requests
import time
import json
import datetime
import hashlib
import os

# ── CONFIG ────────────────────────────────────────────────────────────────────
BOT_TOKEN = '8716034840:AAHBhhlM0nFOQCIAhVOzYW8iXamumTAZypU'
CHAT_ID   = '8257178399'
SEEN_FILE = '/root/news_seen.json'
LOG_FILE  = '/root/news_log.json'

INSTANT_ALERT_THRESHOLD = 8   # score above this → immediate Telegram alert
DAILY_DIGEST_HOUR       = 8   # send daily digest at 8am UTC
CHECK_INTERVAL_MINUTES  = 30  # check feeds every 30 minutes

# ── SOURCES ───────────────────────────────────────────────────────────────────
FEEDS = [
    # Crypto news — keep fast/breaking sources only.
    # Reddit feeds (r/kalshi, r/polymarket, r/algotrading, etc.) were removed:
    # NEWS_AGENT_VALUE.md analysis showed 72% of corpus was community discussion
    # with no actionable signal for 15-minute crypto contracts.
    {"url": "https://www.theblock.co/rss.xml",                "source": "TheBlock"},
    {"url": "https://cointelegraph.com/rss",                  "source": "CoinTelegraph"},
    {"url": "https://decrypt.co/feed",                        "source": "Decrypt"},
]

# ── SCORING ───────────────────────────────────────────────────────────────────
HIGH_VALUE   = ["kalshi", "polymarket", "prediction market", "arbitrage",
                "btc bot", "trading bot", "binary market", "market making bot",
                "prediction market bot", "automated trading"]
MEDIUM_VALUE = ["bitcoin trading", "crypto bot", "algo trading", "win rate",
                "market signal", "trading strategy", "order book", "edge",
                "quantitative", "backtesting"]
LOW_VALUE    = ["ai agent", "automation", "python bot", "trading algorithm",
                "machine learning trading", "neural network trading"]
NEGATIVE     = ["sports betting", "nfl", "nba", "mlb", "election",
                "political", "weather bet", "oscar", "emmy"]

def score_item(title, summary):
    text  = (title + " " + summary).lower()
    score = 0
    matched = []
    for kw in HIGH_VALUE:
        if kw in text:
            score += 3
            matched.append(f"+3:{kw}")
    for kw in MEDIUM_VALUE:
        if kw in text:
            score += 2
            matched.append(f"+2:{kw}")
    for kw in LOW_VALUE:
        if kw in text:
            score += 1
            matched.append(f"+1:{kw}")
    for kw in NEGATIVE:
        if kw in text:
            score -= 2
            matched.append(f"-2:{kw}")
    return score, matched

def get_item_id(title, link):
    return hashlib.md5(f"{title}{link}".encode()).hexdigest()[:12]

def load_seen():
    if os.path.exists(SEEN_FILE):
        with open(SEEN_FILE) as f:
            return set(json.load(f))
    return set()

def save_seen(seen):
    with open(SEEN_FILE, 'w') as f:
        json.dump(list(seen)[-2000:], f)  # keep last 2000

def send_telegram(message):
    try:
        requests.get(
            f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            params={"chat_id": CHAT_ID, "text": message},
            timeout=5
        )
    except Exception:
        pass

def log_item(item):
    with open(LOG_FILE, 'a') as f:
        f.write(json.dumps(item) + '\n')

def fetch_all_feeds():
    seen    = load_seen()
    new_items = []

    for feed_config in FEEDS:
        try:
            feed = feedparser.parse(
                feed_config["url"],
                request_headers={"User-Agent": "OpenClaw-NewsAgent/1.0"}
            )
            for entry in feed.entries[:20]:  # check latest 20 per feed
                title   = getattr(entry, 'title',   '') or ''
                summary = getattr(entry, 'summary', '') or ''
                link    = getattr(entry, 'link',    '') or ''
                item_id = get_item_id(title, link)

                if item_id in seen:
                    continue

                seen.add(item_id)
                score, matched = score_item(title, summary)

                if score <= 0:
                    continue

                item = {
                    "id":        item_id,
                    "source":    feed_config["source"],
                    "title":     title[:200],
                    "link":      link,
                    "score":     score,
                    "matched":   matched,
                    "timestamp": datetime.datetime.utcnow().isoformat(),
                    "summary":   summary[:300],
                }
                new_items.append(item)
                log_item(item)

                # Instant alert for high-scoring items
                if score >= INSTANT_ALERT_THRESHOLD:
                    msg = (
                        f"🔥 HIGH-VALUE ITEM (score={score})\n"
                        f"Source: {feed_config['source']}\n"
                        f"Title: {title[:150]}\n"
                        f"Keywords: {', '.join(matched[:5])}\n"
                        f"Link: {link}"
                    )
                    send_telegram(msg)
                    print(f"[Alert] Score={score} | {feed_config['source']} | {title[:60]}")

        except Exception as e:
            print(f"[Feed] Error fetching {feed_config['source']}: {e}")

    save_seen(seen)
    return new_items

def send_daily_digest():
    if not os.path.exists(LOG_FILE):
        return

    # Read items from last 24 hours
    cutoff = datetime.datetime.utcnow() - datetime.timedelta(hours=24)
    items  = []
    with open(LOG_FILE) as f:
        for line in f:
            try:
                item = json.loads(line.strip())
                ts   = datetime.datetime.fromisoformat(item["timestamp"])
                if ts > cutoff:
                    items.append(item)
            except Exception:
                pass

    if not items:
        send_telegram("📰 Daily digest: No relevant items found in last 24h")
        return

    # Sort by score descending
    items.sort(key=lambda x: x["score"], reverse=True)
    top   = items[:8]

    lines = [f"📰 Daily Digest — {datetime.datetime.utcnow().strftime('%Y-%m-%d')}",
             f"Found {len(items)} relevant items. Top {len(top)}:\n"]
    for i, item in enumerate(top, 1):
        lines.append(
            f"{i}. [{item['score']}⭐] {item['source']}\n"
            f"   {item['title'][:100]}\n"
            f"   {item['link']}\n"
        )
    send_telegram('\n'.join(lines))
    print(f"[Digest] Sent {len(top)} items")

# ── MAIN LOOP ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print(f"OpenClaw News Agent starting — checking every {CHECK_INTERVAL_MINUTES}min")
    send_telegram("📡 News Agent started — monitoring TheBlock, CoinTelegraph, Decrypt")

    last_digest_day = None

    while True:
        now = datetime.datetime.utcnow()

        # Daily digest
        if now.hour == DAILY_DIGEST_HOUR and now.date() != last_digest_day:
            send_digest = True
            last_digest_day = now.date()
            send_daily_digest()

        # Fetch feeds
        print(f"[{now.strftime('%H:%M')}] Checking feeds...")
        new_items = fetch_all_feeds()
        print(f"[{now.strftime('%H:%M')}] Found {len(new_items)} new relevant items")

        time.sleep(CHECK_INTERVAL_MINUTES * 60)
