import requests, tempfile, csv
from kalshi_python import KalshiClient
from kalshi_python.configuration import Configuration
kid = '2d0a8c45-b76a-4459-a0e1-9a5e4d63fd8b'
pem = '''-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEArkD0NUpJf2F1v6hW9tlKzQ1wPGJ0ypTgBVLMk73dPINtXjAU
TVcunm2GtdG5p9QReCmUaihBYOVCom9m9D93tH6n/8gm4AjciW+GvtEolsJiExmQ
145maRyZjS2aLzuQY0LKjEVxtIdbwRuWnQ4X4VuL6k/lHI/N5Nzz1WLDRHaEwwSO
0Evcu9Nl5NBeJKaUjpUKaBLwmK3T7VrizkpnWYo9hZwEU9RZpSW4KjYG9+lSeYeN
OZ/L5DUwhabSdqXIipFaXwtElt0wLa5TicqK2Dc8dy2fdyz5pX/fcmSvMffsuPEg
kjvtMnhDjWL3aCzwDsTGJe7oR5r/Wxe0x4daIQIDAQABAoIBAA2FmzqKnTfceqRF
jk0+Tc1DsbK94ScNqAsOgpmKx9Q36EP0byuuDD9D0iRINgpaYB12/Ir2vLwMJ/OU
hksfcbNfI+8RVRLyUErJ8/Ol8p356SpnEK2DFPQrJ/wKNRP21By5Xh/5QGDF8DTR
maQH9L2kIPz5xJZ6AkkBBfR7fLOfOtJXXxGRua/4AnzBf/zDRV0so/2tJaMOxNeU
Nop9xKGqvISVXPMk3M7j2LlDGTkZcNvcNfbuPwzkUbQFoAJ/Cko0Esx0nT7DQTuh
SzGbqGI/rnLu0NsMDFOABCK4yJuQCZSh4WP6x5WDOwdaz+loWotEdPfHVms0eGjb
U5p8a1ECgYEA2z8VIC2LnlyLEzwmM86K8vfy2XgqoL1LgZbctuepk9ymAvfS3Xa5
Mvges+aeHSc/6H0apJHCTdQBozQo/vekyKofPQQrIFCCNGla6sAxjqNv6cskT6pg
0WqpBNjY+5eRGGGDCcB4LRbgGlmt5455F+bmQ7ijMbeVJStZ0er2RHMCgYEAy3cE
004aPtnH22EQdJopic5tnqNqqX0ruEPqT+MwjkA8T7CbC52CFcZTG3HAn2KWyn1H
FVvngCkUflxbrNSL0BfwwWQBmfoOyrFkbCUcIG8q6s2t3i74zvkFGlTB8IPboxjg
b672WisT4pktTnXHIuq/nDAwnwmTOKzLjhTS1hsCgYEAkT8cZsHlohcbB7YsdNvb
T5WV7B5g1zYwxHxGYmHdBRkDXioCJzeU/8BCztn0W8n527KtqOLrf5X5M77Ffgxf
vZR+t3SAgZr0d3ZoheanriB2bsNmneR42aO4r35dWWgS9rz7C8XXl7903eAVhrbr
YDtWxvyWGMTPaN1sVtY7KiMCgYEAl4Gz7SjucDi5Esnvd/RH1B8MD6H+TeEwShEA
jKZPRM3eWzTV70tFT7OTtQ76cXT3dibdZLE/7HYqlYFunn7S8YyyMT+n1aGXnCWF
8uWbUSeWnKu1uYneqjhSLW5J0DBPv95JWcC+HxyOvSB01UTsmTqWndZgjjySDRTW
qqEk8lsCgYBWXgZTI0C1ukU0/jHu9OMULsPsoioZgj1pLP7Zvc6TzIWQVSCn0a6j
/DL0JzwIlrU4B+YEuHPMnbRzuYtx2bDlW7Ycky51Wfp7jw2SVUj/Lr1rxNe9y9a+
7VTiKzf+09eR4dAW/8VcpNTErYmLqHRQQcWgo7/WSpmp8V0xy0AaRQ==
-----END RSA PRIVATE KEY-----'''
tf = tempfile.NamedTemporaryFile(delete=False, suffix='.pem', mode='w')
tf.write(pem); tf.close()
config = Configuration()
config.host = "https://api.elections.kalshi.com/trade-api/v2"
client = KalshiClient(config)
client.set_kalshi_auth(kid, tf.name)
url = "https://api.elections.kalshi.com/trade-api/v2/portfolio/balance"
headers = client.kalshi_auth.create_auth_headers("GET", url)
resp = requests.get(url, headers=headers, timeout=8)
d = resp.json()
bal = d.get("balance",0) / 100
def stats(csvfile):
    w,l,pnl=0,0,0.0
    try:
        with open(csvfile) as f:
            for row in csv.reader(f):
                if len(row)<5: continue
                action=row[3]
                if "WIN" in action:
                    w+=1
                    try: pnl+=float(row[4].replace("%",""))*float(row[2])/100
                    except: pass
                elif "LOSS" in action:
                    l+=1
                    try: pnl-=float(row[2])
                    except: pass
    except FileNotFoundError: pass
    wr=w/(w+l)*100 if (w+l)>0 else 0
    return w,l,wr,pnl
bw,bl,bwr,bpnl=stats("/root/trade_log.csv")
ew,el,ewr,epnl=stats("/root/eth_trade_log.csv")
sw,sl,swr,spnl=stats("/root/sol_trade_log.csv")
tw,tl=bw+ew+sw,bl+el+sl
twr=tw/(tw+tl)*100 if (tw+tl)>0 else 0
tpnl=bpnl+epnl+spnl
print(f"💰 Total Balance: ${bal:.2f} | True PnL: ${bal-977.64:+.2f} | Since Mar25: ${bal-262.18:+.2f}")
print(f"ALL: {tw}W/{tl}L ({twr:.0f}%) | PnL: ${tpnl:+.2f}")
print(f"BTC: {bw}W/{bl}L ({bwr:.0f}%) | PnL: ${bpnl:+.2f}")
print(f"ETH: {ew}W/{el}L ({ewr:.0f}%) | PnL: ${epnl:+.2f}")
print(f"SOL: {sw}W/{sl}L ({swr:.0f}%) | PnL: ${spnl:+.2f}")