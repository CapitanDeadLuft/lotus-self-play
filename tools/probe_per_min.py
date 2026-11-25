import re, json
out={}
for name,f,gs in [("match1",r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_probe.log",190.567),("match3",r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_probe.log",143.067)]:
    keys=["calls","seen","chk","gate","denyNo","cands","chosen"]
    mins=[]
    for m in range(5):
        tot={k:0 for k in keys}
        for l in open(f, encoding='utf-8', errors='replace'):
            mm=re.search(r"\[ledger\] clock=([-\d.]+)", l)
            if not mm: continue
            c=float(mm.group(1))
            if gs+m*60 <= c < gs+(m+1)*60:
                for k in keys:
                    x=re.search(r"\b%s=(\d+)" % k, l)
                    if x: tot[k]+=int(x.group(1))
        mins.append(tot)
    out[name]=mins
    print(name)
    for m,t in enumerate(mins): print(" min",m,t)
json.dump(out, open(r"D:\hake\lotus\tools\probe_minutes.json","w"), indent=1)
