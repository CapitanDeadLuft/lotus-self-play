import re, collections
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
start=next(i for i,l in enumerate(lines) if l.strip()=="===== Self Play session 2026-11-16 03:12:52 =====")
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
names=["axe","silencer","zuus","skeleton_king","sniper","grimstroke"]
for nm in names:
    print("\n=====", nm)
    n=0
    for i in range(start,end):
        if "npc_dota_hero_"+nm in lines[i]:
            print(i, lines[i].rstrip()[:230]); n+=1
            if n>=8: break
