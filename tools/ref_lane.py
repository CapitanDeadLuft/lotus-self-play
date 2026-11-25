import re, glob, os
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
start=next(i for i,l in enumerate(lines) if l.strip()=="===== Self Play session 2026-11-16 03:12:52 =====")
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
print("=== [SelfPlay lane] in ref session 0 ===")
for i in range(start,end):
    if "[SelfPlay lane]" in lines[i]: print(i, lines[i].rstrip()[:400])
print("=== laneStatus? Other references to switch ===")
for i in range(start,end):
    if "switch " in lines[i] and "lane" in lines[i].lower(): print(i, lines[i].rstrip()[:300])
print("=== hero names in session 0 ===")
import collections
cnt=collections.Counter()
for i in range(start,end):
    for m in re.finditer(r"npc_dota_hero_(\w+)", lines[i]): cnt[m.group(1)]+=1
print(cnt)
