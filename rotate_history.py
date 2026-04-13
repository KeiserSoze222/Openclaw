import json,datetime,os
cutoff=(datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=7)).isoformat()
infile='/root/price_history.jsonl'
tmpfile='/root/price_history_new.jsonl'
kept=0
with open(infile) as f, open(tmpfile,'w') as out:
    for line in f:
        try:
            d=json.loads(line)
            if d.get('ts','')>=cutoff:
                out.write(line)
                kept+=1
        except: pass
os.replace(tmpfile,infile)
print(f"Kept {kept} entries (last 7 days)")

