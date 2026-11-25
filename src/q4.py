import json
d = json.load(open(r"D:\hake\lotus\dumper\dota2_dump\offsets.json", encoding="utf-8"))
sch = d["schema"]
print("=== C_DOTA_UnitInventory ===")
for k, v in sorted(sch.get("client.dll::C_DOTA_UnitInventory", {}).items(), key=lambda x: x[1]):
    print(f"  {k} = {v} (0x{v:X})")
print("=== inventory-ish classes ===")
for cls in sch:
    if "Inventory" in cls or "PlayerResource" in cls or "TeamPlayer" in cls or "DataTeamPlayer" in cls:
        print(" ", cls, len(sch[cls]))
print("=== fields with lasthit/deny/networth/gold/xp ===")
for cls, fields in sch.items():
    for k, v in fields.items():
        lk = k.lower()
        if any(t in lk for t in ("lasthit", "last_hit", "denies", "deny", "networth", "net_worth", "hero_damage", "creep_kill", "neutral_kill", "gold_lost")):
            print(f"  {cls}.{k} = {v}")
