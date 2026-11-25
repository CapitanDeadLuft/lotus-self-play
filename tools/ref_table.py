import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
# reference sessions list from mapping
ref_sessions = ["2026-11-16 03:12:52","2026-11-16 03:58:57","2026-11-16 04:23:34","2026-11-16 05:02:02","2026-11-16 05:44:19","2026-11-16 23:51:36","2026-11-17 00:19:13","2026-11-17 00:44:53","2026-11-17 01:04:57","2026-11-17 01:36:32","2026-11-17 02:00:54","2026-11-17 02:32:23","2026-11-17 03:10:42","2026-11-17 03:38:53","2026-11-17 04:15:11"]
# build session ranges
idx={}
cur=None
for i,l in enumerate(lines):
    if l.startswith("====="):
        cur=l.strip(); idx[cur]=[i,i]
    elif cur: idx[cur][1]=i
for h in ref_sessions:
    key="===== Self Play session "+h+" ====="
    if key not in idx: print("MISSING", key); continue
    a,b=idx[key]
    scores=[]
    switches=[]
    for i in range(a,b+1):
        l=lines[i]
        m=re.match(r"\[(-?\d+):(\d+)\]", l)
        c=int(m.group(1))*60+int(m.group(2)) if m else None
        ms=re.search(r"\[SelfPlay score\] clock=([-\d.]+) hero=npc_dota_hero_treant role=(\d+) lane=(\d+) lastHits=(\d+)", l)
        if ms: scores.append((float(ms.group(1)), int(ms.group(3)), int(ms.group(4)), c))
        ml=re.search(r"\[SelfPlay lane\] (\w+) -> (\w+): (.*)$", l.rstrip())
        if ml: switches.append((c, ml.group(1), ml.group(2), ml.group(3)))
    s300=min(scores, key=lambda x: abs(x[0]-312.3)) if scores else None
    print(h, "| switches:", [(t,f_,t_,r[:45]) for t,f_,t_,r in switches], "| @~5min lane", s300[1] if s300 else None, "LH", s300[2] if s300 else None)
