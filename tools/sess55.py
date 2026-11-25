import re
f = r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
# session 55 starts at line 2 of? use header index
target="===== Self Play session 2026-11-18 03:53:32 ====="
lines=open(f, encoding='utf-8', errors='replace').readlines()
start=[i for i,l in enumerate(lines) if l.strip()==target][0]
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
print("session lines:", end-start)
print("--- first 40 lines ---")
for l in lines[start:start+40]: print(l.rstrip()[:240])
print("--- unique prefixes sample ---")
import collections
cnt=collections.Counter()
for l in lines[start:end]:
    m=re.match(r"\[[^\]]*\]\s*(\[SelfPlay[^\]]*\]|\[[\w ]+\])", l)
    if m: cnt[m.group(1)]+=1
for k,v in cnt.most_common(25): print(v,k)
print("--- hero= lines ---")
heroes=collections.Counter()
for l in lines[start:end]:
    for m in re.finditer(r"hero=(npc_dota_hero_\w+)", l): heroes[m.group(1)]+=1
print(heroes)
print("--- lines with 'planner' or 'assign' ---")
for l in lines[start:end]:
    if "planner" in l.lower() or "assign" in l.lower(): print(l.rstrip()[:300])
