import glob, re, os
for f in [r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_host.log", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v2_host.log", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_host.log", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match2_crash_host.log"]:
    data=open(f, encoding='utf-8', errors='replace').read()
    print("\n==", os.path.basename(f))
    for l in data.splitlines():
        if "anchor" in l or "horn" in l.lower() or "observed state transition" in l:
            print("  ", l[:260])
