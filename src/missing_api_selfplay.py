import re, pathlib, json

root = pathlib.Path(r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts")
targets = [root / "Self Play.lua"] + list((root / "self_play").rglob("*.lua"))
call = re.compile(r"\b(Entity|EntityClass|EC|NPC|NPCs|Entities|Hero|Heroes|Player|Players|Ability|Item|Items|Engine|GameRules|World|GridNav|Fow|FogOfWar|Modifier|Modifiers|Buff|Buffs|Couriers|Courier|NetChannel|Input|Render|Camera|Particles|Projectiles|LaneGroupsManager|Minimap|Communication|GameUI|Cvar|Sound|Effects|UI|Humanizer|Tower|Tree|Rune|Runes|TempTrees|Bottle|PowerTreads|GC|HTTP|Panorama|Log|Config|Menu|Vector|Vec2|Color|Angle)\.([A-Z]\w*)\(")

used = {}
for p in targets:
    try:
        txt = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    for m in call.finditer(txt):
        used.setdefault(m.group(1), set()).add(m.group(2))

src = pathlib.Path(r"D:\hake\lotus\src")
defs = {}
deffn = re.compile(r"function\s+(?:M\.)?([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*\(")
assign = re.compile(r"\b([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*=\s*function\s*\(")
for name in ("api.lua","enums.lua","globals.lua","loader.lua","orders.lua","entity.lua","nav.lua","mathx.lua","menu.lua","render.lua","overlay.lua","xhelpers.lua"):
    p = src/name
    if not p.exists(): continue
    txt = p.read_text(encoding="utf-8", errors="ignore")
    for m in list(deffn.finditer(txt)) + list(assign.finditer(txt)):
        defs.setdefault(m.group(1), set()).add(m.group(2))

report = {}
total = 0
for ns, fns in sorted(used.items()):
    have = defs.get(ns, set())
    missing = sorted(f for f in fns if f not in have)
    if missing:
        report[ns] = missing
        total += len(missing)
for ns, missing in report.items():
    print(ns, len(missing), "->", ", ".join(missing))
print("TOTAL missing (Self Play only):", total)
pathlib.Path(r"D:\hake\lotus\MISSING_API_SELFPLAY.txt").write_text(json.dumps(report, indent=2), encoding="utf-8")
