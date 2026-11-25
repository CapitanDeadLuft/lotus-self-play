import re, pathlib, json

root = pathlib.Path(r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts")
call = re.compile(r"\b(Entity|EntityClass|EC|NPC|Hero|Heroes|Player|Players|Ability|Item|Items|Engine|GameRules|World|GridNav|Fow|FogOfWar|Modifier|Modifiers|Buff|Couriers|NetChannel|Input|Render|Camera|Particles|Projectiles|LaneGroupsManager|Minimap|Communication|GameUI|Cvar|Sound|Effects|UI|Humanizer)\.([A-Z]\w*)\(")

used = {}
for p in list(root.rglob("*.lua")):
    try:
        txt = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    for m in call.finditer(txt):
        used.setdefault(m.group(1), set()).add(m.group(2))

src = pathlib.Path(r"D:\hake\lotus\src")
defs = {}
deffn = re.compile(r"function\s+(?:M\.)?([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*\(")
for name in ("api.lua","enums.lua","globals.lua","loader.lua","orders.lua","entity.lua","nav.lua","mathx.lua","menu.lua"):
    p = src/name
    if not p.exists(): continue
    txt = p.read_text(encoding="utf-8", errors="ignore")
    for m in deffn.finditer(txt):
        defs.setdefault(m.group(1), set()).add(m.group(2))
    # also table fields assigned as functions: X.Y = function(
    for m in re.finditer(r"\b([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*=\s*function\s*\(", txt):
        defs.setdefault(m.group(1), set()).add(m.group(2))

report = {}
total_missing = 0
for ns, fns in sorted(used.items()):
    have = defs.get(ns, set())
    missing = sorted(f for f in fns if f not in have)
    if missing:
        report[ns] = missing
        total_missing += len(missing)
for ns, missing in report.items():
    print(ns, len(missing), "->", ", ".join(missing[:18]) + (" ..." if len(missing) > 18 else ""))
print("TOTAL missing:", total_missing)
pathlib.Path(r"D:\hake\lotus\MISSING_API.txt").write_text(json.dumps(report, indent=2), encoding="utf-8")
