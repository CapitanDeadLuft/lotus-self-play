import re, os, collections
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\build_brain_builds.txt"
print("size", os.path.getsize(f))
lines=open(f, encoding='utf-8', errors='replace').readlines()
print("lines", len(lines))
for l in lines[:25]: print(l.rstrip()[:250])
print("...")
for l in lines[-10:]: print(l.rstrip()[:250])
cnt=collections.Counter()
for l in lines:
    m=re.search(r"npc_dota_hero_(\w+)", l)
    if m: cnt[m.group(1)]+=1
print("hero counts:", cnt.most_common(30))
