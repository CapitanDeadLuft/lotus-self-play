import os
for f in [r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\debug.log", r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\db.json"]:
    print("====", f, os.path.getsize(f))
    n=0
    for line in open(f, encoding='utf-8', errors='replace'):
        if "npc_dota_hero_" in line or "hero" in line.lower() and "pick" in line.lower():
            print(line.rstrip()[:240]); n+=1
            if n>=20: break
