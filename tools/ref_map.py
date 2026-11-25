import json, re, os
ref = json.load(open(r"D:\hake\lotus\reference_treant.jsonl", encoding='utf-8'))
runs=[]; cur=[]
for e in ref:
    if cur and e['clock'] < cur[-1]['clock'] - 1:
        runs.append(cur); cur=[]
    cur.append(e)
if cur: runs.append(cur)

logs = [r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log",
        r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.log"]
# parse all score lines
pat = re.compile(r"\[SelfPlay score\] clock=([-\d.]+) hero=(npc_dota_hero_\w+) role=(\d+) lane=(\d+) lastHits=(\d+) denies=(\d+) networth=(\d+) gold=(\d+) xp=(\d+) heroDamage=(\d+) laneGold=(\d+) jungleGold=(\d+)")
recs=[]  # (logidx, session, line, fields)
for li,f in enumerate(logs):
    ses=None
    for line in open(f, encoding='utf-8', errors='replace'):
        if line.startswith("====="):
            ses=line.strip()
            continue
        m=pat.search(line)
        if m:
            g=m.groups()
            recs.append((li, ses, line.rstrip(), g))
print("parsed score lines:", len(recs))
idx={}
for r in recs:
    g=r[3]
    key=(float(g[0]), g[1], int(g[2]), int(g[3]), int(g[4]), int(g[5]), int(g[6]), int(g[7]), int(g[8]), int(g[9]), int(g[10]), int(g[11]))
    idx[key]=r
found=[]
for ri,run in enumerate(runs):
    e=run[0]
    key=(e['clock'], 'npc_dota_hero_treant', e['role'], e['lane'], e['lh'], e['dn'], e['nw'], e['gold'], e['xp'], e['hd'], e['laneGold'], e['jungle'])
    r=idx.get(key)
    if r:
        found.append((ri, r[0], r[1], r[2][:100]))
    else:
        found.append((ri, None, None, "NOT FOUND"))
for x in found: print(x)
