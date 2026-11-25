import re, glob, os
for f in sorted(glob.glob(r"D:\hake\lotus\archive\20261122_animtarget_safefix\*_host.log")):
    data=open(f, encoding='utf-8', errors='replace').read()
    clocks=[l for l in data.splitlines() if "[clock]" in l]
    print("\n==", os.path.basename(f), "clock lines:", len(clocks))
    for l in clocks[:6]: print("  ", l[:220])
