import json, re, sys
p = r"D:\hake\lotus\dumper\dota2_dump\offsets.json"
d = json.load(open(p, encoding="utf-8"))
print("top keys:", list(d.keys()))
sch = d.get("schema", {})
print("schema modules:", sorted(set(k.split("::")[0] for k in sch))[:10])
print("classes:", len(sch))

wanted_fields = ["PhysicalArmor","MagicalResistance","MagicalArmor","SpellAmp","ChannelStart",
 "AutoCast","BaseAttackTime","BaseAttackSpeed","CastRange","Strength","Agility","Intelligence",
 "Level","AbilityLevel","Build","GameEnd","GameStart","Lobby","AttackRange","HullRadius"]
for f in wanted_fields:
    hits = []
    for cls, fields in sch.items():
        for name, off in fields.items():
            if f.lower() in name.lower():
                hits.append((cls, name, off))
    if hits:
        print(f"\n=== {f} ===")
        for cls, name, off in hits[:8]:
            print(f"  {cls}.{name} = {off} (0x{off:X})")

print("\n=== classes matching Building/Hero/GameRules/Ability/NPC ===")
for cls in sorted(sch):
    if re.search(r"Building|Hero|GameRules|GameEntity|UnitAbility|BaseAbility", cls):
        print(" ", cls, "fields=", len(sch[cls]))
