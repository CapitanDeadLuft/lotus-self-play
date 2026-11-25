import glob, os
files = [r"D:\hake\lotus\self_play.log"] + glob.glob(r"D:\hake\lotus\archive\*\*.log")
for f in files:
    if not os.path.exists(f): continue
    sz=os.path.getsize(f)
    try:
        data=open(f, encoding='utf-8', errors='replace').read()
    except Exception as e:
        print("ERR", f, e); continue
    print("====", f, sz, "bytes")
    print("  [SelfPlay ally] count:", data.count("[SelfPlay ally]"))
    print("  [SelfPlay lane] count:", data.count("[SelfPlay lane]"))
    for name in ["dragon_knight","axe","treant","pangolier"]:
        print("  ", name, data.count("npc_dota_hero_"+name))
