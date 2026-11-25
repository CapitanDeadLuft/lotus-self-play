import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
start=next(i for i,l in enumerate(lines) if l.strip()=="===== Self Play session 2026-11-16 03:12:52 =====")
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
# Phase split at switch ~97s (1:37)
import collections
def clock_of(line):
    m=re.match(r"\[(-?\d+):(\d+)\]", line)
    if not m: return None
    return int(m.group(1))*60+int(m.group(2))
stats={'lane1':collections.Counter(),'lane3':collections.Counter()}
cand=[]; last=[]
for i in range(start,end):
    l=lines[i]
    c=clock_of(l)
    if c is None: continue
    ph='lane1' if c<97 else ('lane3' if c<=330 else None)
    if not ph: continue
    if "[SelfPlay actions]" in l:
        m=re.search(r"candidates=(\d+)", l)
        if m:
            v=int(m.group(1)); stats[ph]['actions']+=1
            if v>0: stats[ph]['cand_pos']+=1; stats[ph]['cand_sum']+=v
    if "[SelfPlay last hit]" in l:
        stats[ph]['last_hit_lines']+=1
    if "[SelfPlay] " in l and "mode=" in l:
        stats[ph]['mode_lines']+=1
print(dict((k,dict(v)) for k,v in stats.items()))
# print mode progression first 5 min
print("\n=== mode changes 0..300 ===")
prev=None
for i in range(start,end):
    l=lines[i]
    c=clock_of(l)
    if c is None or not (0<=c<=310): continue
    m=re.search(r"\[SelfPlay\] role=(\d+) lane=(\d+) mode=([^h]*?) hp=", l)
    if m and m.group(3)!=prev:
        print("[%d:%02d]" % (c//60, c%60), "lane", m.group(2), "mode", m.group(3).strip()[:60])
        prev=m.group(3)
