import json, glob, os
new = json.load(open(r"D:\hake\lotus\dumper\dota2_dump\offsets.json", encoding="utf-8"))
print("NEW build:", new["build"])
print("engine:", new["engine"])
olds = sorted(glob.glob(r"D:\hake\lotus\dumper\offsets_old_*.json"))
old = json.load(open(olds[-1], encoding="utf-8"))
print("OLD build:", old["build"], "engine:", old["engine"])
for k in ("dwEntityList","dwViewMatrix","dwLocalPlayerController"):
    o = old["engine"].get(k); n = new["engine"].get(k)
    print(f"{k}: old={o} (0x{o:X})" if o else f"{k}: old=None", f"new={n} (0x{n:X})" if n else "new=None")

ns, os_ = new["schema"], old["schema"]
changed = []
for cls, fields in ns.items():
    if cls not in os_: continue
    for f, off in fields.items():
        o = os_[cls].get(f)
        if o is not None and o != off:
            changed.append((cls, f, o, off))
print("changed schema fields:", len(changed))
for c in changed[:15]: print("  ", c)
# key fields we rely on
for cls, f in [("client.dll::C_DOTA_BaseNPC","m_flPhysicalArmorValue"),
               ("client.dll::C_DOTA_BaseNPC","m_iAttackRange"),
               ("client.dll::C_DOTABaseAbility","m_flChannelStartTime"),
               ("client.dll::C_DOTABaseAbility","m_bAutoCastState"),
               ("client.dll::C_DOTA_BaseNPC_Hero","m_iPlayerID"),
               ("client.dll::C_DOTA_BaseNPC","m_flHullRadius")]:
    print(f"{cls}.{f}: old={os_.get(cls,{}).get(f)} new={ns.get(cls,{}).get(f)}")
