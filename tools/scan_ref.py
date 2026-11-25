import glob, os, re
pats = ["assignRoles", "reference_treant", "hero=npc_dota_hero_treant role=4 lane=1"]
files = []
for root in [r"D:\hake\lotus", r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif"]:
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            files.append(os.path.join(dirpath, fn))
small = [f for f in files if os.path.getsize(f) < 80*1024*1024 and not f.lower().endswith(('.png','.dmp','.dll','.zip','.bin','.exe'))]
hits = {}
for f in small:
    try:
        with open(f, 'rb') as fh:
            data = fh.read()
    except Exception:
        continue
    for pat in ["assignRoles", "reference_treant"]:
        if pat.encode() in data:
            hits.setdefault(pat, []).append((f, os.path.getsize(f), data.count(pat.encode())))
print("scanned", len(small))
for pat, lst in hits.items():
    print("\nPATTERN", pat)
    for f, sz, c in lst:
        print(" ", f, sz, "count", c)
