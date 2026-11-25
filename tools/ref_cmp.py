import json, re
ref = json.load(open(r"D:\hake\lotus\reference_treant.jsonl", encoding='utf-8'))
pat = re.compile(r"\[SelfPlay score\] clock=([-\d.]+) hero=(npc_dota_hero_\w+) role=(\d+) lane=(\d+) lastHits=(\d+) denies=(\d+) networth=(\d+) gold=(\d+) xp=(\d+) heroDamage=(\d+) laneGold=(\d+) jungleGold=(\d+)")
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
raw=[]
for line in open(f, encoding='utf-8', errors='replace'):
    m=pat.search(line)
    if m:
        g=m.groups()
        if g[1]=='npc_dota_hero_treant' and int(g[2])==4 and float(g[0])>=0:
            raw.append(dict(kind='score', clock=float(g[0]), role=int(g[2]), lane=int(g[3]), lh=int(g[4]), dn=int(g[5]), nw=int(g[6]), gold=int(g[7]), xp=int(g[8]), hd=int(g[9]), laneGold=int(g[10]), jungle=int(g[11])))
print("raw filtered:", len(raw), "ref:", len(ref))
def key(e): return (e['clock'],e['role'],e['lane'],e['lh'],e['dn'],e['nw'],e['gold'],e['xp'],e['hd'],e['laneGold'],e['jungle'])
rawkeys=[key(e) for e in raw]; refkeys=[key(e) for e in ref]
print("equal list:", rawkeys==refkeys)
# find first mismatch
for i,(a,b) in enumerate(zip(rawkeys,refkeys)):
    if a!=b:
        print("first mismatch at",i); print("raw",a); print("ref",b); break
# check ref is subsequence
j=0
for i,k in enumerate(rawkeys):
    if j<len(refkeys) and k==refkeys[j]: j+=1
print("subsequence progress:", j, "/", len(refkeys))
