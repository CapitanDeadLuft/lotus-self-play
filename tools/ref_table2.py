import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
ref = ["2026-11-16 03:12:52","2026-11-16 03:58:57","2026-11-16 04:23:34","2026-11-16 05:02:02","2026-11-16 05:44:19","2026-11-16 23:51:36","2026-11-17 00:19:13","2026-11-17 00:44:53","2026-11-17 01:04:57","2026-11-17 01:36:32","2026-11-17 02:00:54","2026-11-17 02:32:23","2026-11-17 03:10:42","2026-11-17 03:38:53","2026-11-17 04:15:11"]
def csec(l):
    m=re.match(r"\[(-?\d+):(\d+)\]", l)
    return int(m.group(1))*60+int(m.group(2)) if m else None
print("%-22s %-28s %6s %6s %6s %7s %6s" % ("session","switch(es)","LH@5m","lane@5m","acts","cand>0","lastHitLines"))
for h in ref:
    key="===== Self Play session "+h+" ====="
    a=next(i for i,l in enumerate(lines) if l.strip()==key)
    b=next(i for i in range(a+1,len(lines)) if lines[i].startswith("====="))
    sw=[]; acts=0; candpos=0; lhl=0; s5=None
    for i in range(a,b):
        l=lines[i]; c=csec(l)
        if c is None: continue
        ml=re.search(r"\[SelfPlay lane\] (\w+) -> (\w+): (.*)$", l.rstrip())
        if ml: sw.append("%s->%s@%ds" % (ml.group(1),ml.group(2),c))
        if 0<=c<=300:
            if "[SelfPlay actions]" in l:
                acts+=1
                m=re.search(r"candidates=(\d+)", l)
                if m and int(m.group(1))>0: candpos+=1
            if "[SelfPlay last hit]" in l: lhl+=1
        if 240<=c<=330:
            m=re.search(r"\[SelfPlay score\] clock=([-\d.]+) hero=npc_dota_hero_treant role=\d+ lane=(\d+) lastHits=(\d+)", l)
            if m: s5=(int(m.group(2)), int(m.group(3)))
    print("%-22s %-28s %6s %6s %6d %6d %6d" % (h, ";".join(sw)[:28] or "none", s5[1] if s5 else "?", s5[0] if s5 else "?", acts, candpos, lhl))
