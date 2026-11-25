import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\self_play\catalog.lua"
data=open(f, encoding='utf-8', errors='replace').read()
for h in ["grimstroke","nyx_assassin","sand_king","batrider","beastmaster","invoker","drow_ranger","silencer","skeleton_king","earthshaker","witch_doctor"]:
    m=re.search(r'\["npc_dota_hero_%s"\] = \{([^\}]*)\}' % h, data)
    print(h, "->", m.group(1) if m else "NOT FOUND")
