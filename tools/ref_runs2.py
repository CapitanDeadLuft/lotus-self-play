import json, re, os
ref = json.load(open(r"D:\hake\lotus\reference_treant.jsonl", encoding='utf-8'))
pat = re.compile(r"\[(-?\d+):(\d+)\] \[SelfPlay score\] clock=([-\d.]+) hero=(npc_dota_hero_\w+) role=(\d+) lane=(\d+) lastHits=(\d+) denies=(\d+) networth=(\d+) gold=(\d+) xp=(\d+) heroDamage=(\d+) laneGold=(\d+) jungleGold=(\d+)")
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
raw=[]; session=None; session_start=0
for i,line in enumerate(lines):
    if line.startswith("====="):
        session=line.strip(); session_start=i; continue
    m=pat.search(line)
    if m:
        g=m.groups()
        if g[3]=='npc_dota_hero_treant' and int(g[4])==4 and float(g[2])>=0:
            raw.append(dict(fileline=i, sess=session, ts=g[0]+':'+g[1], clock=float(g[2]), role=int(g[4]), lane=int(g[5]), lh=int(g[6]), dn=int(g[7]), nw=int(g[8]), gold=int(g[9]), xp=int(g[10]), hd=int(g[11]), laneGold=int(g[12]), jungle=int(g[13])))
def key(e): return (e['clock'],e['role'],e['lane'],e['lh'],e['dn'],e['nw'],e['gold'],e['xp'],e['hd'],e['laneGold'],e['jungle'])
rawkeys=[key(e) for e in raw]; refkeys=[key(e) for e in ref]
j=0; mapped=[]
for i,k in enumerate(rawkeys):
    if j<len(refkeys) and k==refkeys[j]:
        mapped.append(raw[i]); j+=1
print("mapped", len(mapped))
# group by match: session change or clock decrease
runs=[]; cur=[]
for e in mapped:
    if cur and (e['sess']!=cur[-1]['sess'] or e['clock'] < cur[-1]['clock']-1):
        runs.append(cur); cur=[]
    cur.append(e)
if cur: runs.append(cur)
print("ref runs (matches):", len(runs))
for ri,r in enumerate(runs):
    e5 = [x for x in r if x['clock']<=300]
    lh5 = max((x['lh'] for x in e5), default=None)
    print(ri, "n=%d"%len(r), r[0]['sess'], "start_line=%d"%r[0]['fileline'], "clock %.1f..%.1f"%(r[0]['clock'],r[-1]['clock']), "lanes", sorted(set(x['lane'] for x in r)), "LH<=300:", lh5, "LHmax", max(x['lh'] for x in r))
    # lane switch info
    seq=[]
    for x in r:
        if not seq or seq[-1][1]!=x['lane']: seq.append((x['clock'], x['lane'], x['lh']))
    print("    lane seq (clock,lane,curLH):", seq[:8])
