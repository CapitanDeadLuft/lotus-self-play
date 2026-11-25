import re, os
f = r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
ses=[]
cur=None
with open(f, 'r', encoding='utf-8', errors='replace') as fh:
    for line in fh:
        if line.startswith("====="):
            cur=line.strip(); ses.append([cur,0,0,0,[]])
        elif cur:
            s=ses[-1]
            s[1]+=1
            if "hero=npc_dota_hero_treant role=4 lane=1" in line: s[2]+=1
            if "[SelfPlay] role=4 lane=1 " in line: s[3]+=1
            if "npc_dota_hero_" in line and len(s[4])<6:
                m=re.search(r"hero=(npc_dota_hero_\w+)", line)
                if m and m.group(1) not in s[4]: s[4].append(m.group(1))
print("sessions:", len(ses))
for idx,s in enumerate(ses):
    if s[2] or s[3]:
        print(idx, s[0], "lines",s[1], "scoreTR41",s[2], "roleTR41",s[3], "heroes",s[4])
