"""Sync schema-resolved fallback constants to the current dump (build 6989).

Only touches the numeric fallback argument of offOfFb()/field()/offO() calls
whose class+field exist in offsets.json schema. Runtime resolution is already
schema-first; this keeps the fallbacks honest for schema-less degradation.
"""
import json, re, pathlib

dump = json.load(open(r"D:\hake\lotus\dumper\dota2_dump\offsets.json"))
schema = {k.split("::")[-1]: v for k, v in dump["schema"].items()}
src = pathlib.Path(r"D:\hake\lotus\src")

pats = [
    re.compile(r'(offOfFb\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*)(0x[0-9A-Fa-f]+)(\s*\))'),
    re.compile(r'(field\([^,]+,\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"[^"]+"\s*,\s*)(0x[0-9A-Fa-f]+)(\s*\))'),
    re.compile(r'(offO\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*)(0x[0-9A-Fa-f]+)(\s*\))'),
]

total = 0
for name in ("api.lua", "entity.lua", "orders.lua", "globals.lua", "nav.lua", "loader.lua"):
    p = src / name
    if not p.exists():
        continue
    txt = p.read_text(encoding="utf-8")
    changed = 0
    for pat in pats:
        def repl(m):
            global changed
            cls, fld, fb = m.group(2), m.group(3), int(m.group(4), 16)
            fields = schema.get(cls)
            if fields and fld in fields and fields[fld] != fb:
                changed += 1
                return m.group(1) + hex(fields[fld]) + m.group(5)
            return m.group(0)
        txt = pat.sub(repl, txt)
    if changed:
        p.write_text(txt, encoding="utf-8")
        print(f"{name}: {changed} fallbacks updated")
        total += changed
print("total:", total)
