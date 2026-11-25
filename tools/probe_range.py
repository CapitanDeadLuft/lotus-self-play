import re
for name,f in [("match1",r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_probe.log"),("match3",r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_probe.log")]:
    clocks=[]
    for l in open(f, encoding='utf-8', errors='replace'):
        m=re.search(r"\[ledger\] clock=([-\d.]+)", l)
        if m: clocks.append(float(m.group(1)))
    print(name, "ledger lines", len(clocks), "min", min(clocks), "max", max(clocks))
    if name=="match1": gs=190.567
    else: gs=143.067
    inw=[c for c in clocks if gs+2<=c<=gs+305]
    print("  window count", len(inw), "in-game window seconds", gs+2, gs+305)
    # distribution per minute
    for m in range(0,5):
        lo=gs+m*60; hi=gs+(m+1)*60
        print("   min", m, sum(1 for c in clocks if lo<=c<hi))
