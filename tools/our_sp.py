import re
f=r"D:\hake\lotus\self_play.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
print("lines", len(lines))
for l in lines[:30]: print(l.rstrip()[:250])
print("=== hero name lines ===")
n=0
for l in lines:
    if "npc_dota_hero_" in l:
        print(l.rstrip()[:250]); n+=1
        if n>15: break
