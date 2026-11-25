import re
f=r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_host.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
print("lines", len(lines))
n=0
for l in lines:
    if "dragon_knight" in l:
        print(l.rstrip()[:300]); n+=1
        if n>=20: break
print("=== first lines of host log ===")
for l in lines[:20]: print(l.rstrip()[:250])
