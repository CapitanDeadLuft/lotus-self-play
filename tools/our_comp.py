import glob, re, os, collections
files = sorted(glob.glob(r"D:\hake\lotus\archive\20261122_animtarget_safefix\*_host.log"))
for f in files:
    data=open(f, encoding='utf-8', errors='replace').read()
    a=set(re.findall(r"A:(npc_dota_hero_\w+)", data))
    e=set(re.findall(r"E:(npc_dota_hero_\w+)", data))
    # also generic
    allh=collections.Counter(re.findall(r"(npc_dota_hero_\w+)", data))
    print("\n==", os.path.basename(f))
    print("  allies:", sorted(a))
    print("  enemies:", sorted(e))
    print("  all names:", dict(allh))
