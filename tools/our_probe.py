import re
f=r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_host.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
print("lines", len(lines))
# first support lines and structure
n=0
for l in lines:
    if "[support]" in l:
        print(l.rstrip()[:500]); n+=1
        if n>=12: break
print("=== other probe tags ===")
import collections
c=collections.Counter(re.findall(r"^\S+\s+\[(\w+)\]", "\n".join(lines[:5000]), re.M))
print(c.most_common(30))
