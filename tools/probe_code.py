import re
f=r"D:\hake\lotus\patches\last_hit.lua.probe2"
data=open(f, encoding='utf-8', errors='replace').read()
# find probe counters
for key in ["ledger","gate","denyNo","cands","chosen","calls","seen","chk"]:
    print("\n###", key, "occurrences:", data.count(key))
for m in re.finditer(r"gate", data):
    a=max(0,m.start()-250); b=min(len(data), m.end()+250)
    print("...", data[a:b].replace("\n"," | ")[:600], "\n")
    break
