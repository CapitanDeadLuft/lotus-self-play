import re
f=r"D:\hake\lotus\patches\last_hit.lua.probe2"
lines=open(f, encoding='utf-8', errors='replace').readlines()
for i,l in enumerate(lines):
    if re.search(r"p\.(calls|seen|chk|gate|denyNo|far|imm|evPos|ev0|act|cands|chosen)\s*=\s*p\.", l) or "probe2Load" in l or "probe2Flush" in l or "[ledger]" in l:
        print(i+1, l.rstrip()[:220])
