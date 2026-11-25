import re
f=r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_probe.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
print("lines", len(lines))
for l in lines[:40]: print(l.rstrip()[:300])
print("=== ledger line sample ===")
n=0
for l in lines:
    if "[ledger]" in l:
        print(l.rstrip()[:400]); n+=1
        if n>=8: break
