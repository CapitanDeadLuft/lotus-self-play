import re
f = r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
target="===== Self Play session 2026-11-18 03:53:32 ====="
lines=open(f, encoding='utf-8', errors='replace').readlines()
start=[i for i,l in enumerate(lines) if l.strip()==target][0]
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
print("=== [SelfPlay ally] (all) ===")
for l in lines[start:end]:
    if "[SelfPlay ally]" in l: print(l.rstrip()[:260])
print("\n=== first 15 hero=pangolier lines ===")
c=0
for l in lines[start:end]:
    if "hero=npc_dota_hero_pangolier" in l:
        print(l.rstrip()[:260]); c+=1
        if c>=15: break
print("\n=== [SelfPlay group]/[help]/[supply] samples ===")
for pat in ["[SelfPlay group]","[SelfPlay help]","[SelfPlay supply]"]:
    c=0
    for l in lines[start:end]:
        if pat in l:
            print(l.rstrip()[:260]); c+=1
            if c>=4: break
