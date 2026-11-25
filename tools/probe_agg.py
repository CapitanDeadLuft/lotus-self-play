import re, glob, os
# aggregate probe ledger in first 5 min using known gs
cases = [
 ("match1_v1", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_probe.log", 190.567),
 ("match1_v2", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v2_probe.log", 190.567),
 ("match2_crash", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match2_crash_probe.log", 190.567),
 ("match3_final", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_probe.log", 143.067),
]
keys=["calls","seen","chk","gate","denyNo","far","imm","evPos","ev0","act","cands","chosen","ua","dpt"]
for name, f, gs in cases:
    if not os.path.exists(f): print("missing", f); continue
    totals={k:0 for k in keys}; n=0
    for l in open(f, encoding='utf-8', errors='replace'):
        m=re.search(r"\[ledger\] clock=([-\d.]+)", l)
        if not m: continue
        clk=float(m.group(1))
        if not (gs+2 <= clk <= gs+305): continue
        n+=1
        for k in keys:
            mm=re.search(r"\b%s=(\d+)" % k, l)
            if mm: totals[k]+=int(mm.group(1))
    print("\n==", name, "ledger seconds:", n, "gs", gs)
    print("  ", {k:totals[k] for k in keys})
