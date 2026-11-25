import json, glob
new = json.load(open(r"D:\hake\lotus\dumper\dota2_dump\offsets.json", encoding="utf-8"))
prevs = sorted(glob.glob(r"D:\hake\lotus\dumper\offsets_prev_*.json"))
prev = json.load(open(prevs[-1], encoding="utf-8"))
print("prev file:", prevs[-1].split("\\")[-1])
print("prev build:", prev.get("build"), "| new build:", new.get("build"))
print("prev engine:", prev.get("engine"))
print("new  engine:", new.get("engine"))
ns, ps = new["schema"], prev["schema"]
changed = []
for cls, fields in ns.items():
    if cls not in ps: continue
    for f, off in fields.items():
        o = ps[cls].get(f)
        if o is not None and o != off:
            changed.append((cls, f, o, off))
print("changed schema fields:", len(changed))
for c in changed[:10]: print("  ", c)
# check key fields we depend on
for cls, f in [("client.dll::C_DOTA_BaseNPC","m_flPhysicalArmorValue"),
               ("client.dll::C_DOTABaseAbility","m_flChannelStartTime"),
               ("client.dll::C_DOTA_BaseNPC_Hero","m_iPlayerID"),
               ("client.dll::C_DOTA_BaseNPC","m_iAttackRange")]:
    print(f"{cls.split('::')[-1]}.{f}: prev={ps.get(cls,{}).get(f)} new={ns.get(cls,{}).get(f)}")
