 import requests
 BOT_TOKEN = '8716034840:AAFhyZgriXRbPBfhajMVLG300TMBELh68TE'
 CHAT_ID = '8257178399'
 r = requests.get(f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage?chat_id={CHAT_ID}&text=✅ Cloud bot is ONLINE and ready!')
 print('Test alert sent!' if r.status_code == 200 else 'Failed:', r.text)
 EOF

python3 test_telegram.py
python3 test_telegram.py
cat > test_telegram.py << 'EOF'
 import requests
 BOT_TOKEN = '8716034840:AAFhyZgriXRbPBfhajMVLG300TMBELh68TE'
 CHAT_ID = '8257178399'
 print("Script started - sending test message...")
 r = requests.get(f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage?chat_id={CHAT_ID}&text=✅ Cloud bot is ONLINE and ready!')
 print("Status code:", r.status_code)
 print("Response:", r.text)
 if r.status_code == 200:
     print("✅ SUCCESS - Test alert sent!")
 else:
     print("❌ FAILED - Check response above")
 EOF
python3 test_telegram.py
root@OpenClaw-bot:~#
root@OpenClaw-bot:~#curl -s "https://api.telegram.org/bot8716034840:AAFhyZgriXRbPBfhajMVLG300TMBELh68TE/sendMessage?chat_id=8257178399&text=✅ Cloud bot is ONLINE and ready from curl test!"
cat > curl_test.sh << 'EOF'
 curl -s "https://api.telegram.org/bot8716034840:AAFhyZgriXRbPBfhajMVLG300TMBELh68TE/sendMessage?chat_id=8257178399&text=✅ Cloud bot is ONLINE and ready from curl test!"
 EOF
bash curl_test.sh
