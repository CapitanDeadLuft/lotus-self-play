import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
start=next(i for i,l in enumerate(lines) if l.strip()=="===== Self Play session 2026-11-16 03:12:52 =====")
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
def csec(l):
    m=re.match(r"\[(-?\d+):(\d+)\]", l)
    return int(m.group(1))*60+int(m.group(2)) if m else None
print("=== S1 last hit lines 0-330 ===")
for i in range(start,end):
    l=lines[i]; c=csec(l)
    if c is not None and 0<=c<=330 and "[SelfPlay last hit]" in l: print(i, l.rstrip()[:340])
print("\n=== S1 action ticks with candidates>0 0-330 ===")
for i in range(start,end):
    l=lines[i]; c=csec(l)
    if c is not None and 0<=c<=330 and "[SelfPlay actions]" in l:
        m=re.search(r"candidates=(\d+)", l)
        if m and int(m.group(1))>0: print(i, l.rstrip()[:340])
print("\n=== S1 score lines 0-330 ===")
for i in range(start,end):
    l=lines[i]; c=csec(l)
    if c is not None and 0<=c<=330 and "[SelfPlay score]" in l: print(i, l.rstrip()[:300])
