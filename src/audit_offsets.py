import json, re, pathlib

dump = json.load(open(r"D:\hake\lotus\dumper\dota2_dump\offsets.json"))
schema = {k.split("::")[-1]: v for k, v in dump["schema"].items()}

src = pathlib.Path(r"D:\hake\lotus\src")
pat_offfb = re.compile(r'offOfFb\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(0x[0-9A-Fa-f]+)\s*\)')
pat_field = re.compile(r'field\([^,]+,\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"[^"]+"\s*,\s*(0x[0-9A-Fa-f]+)\s*\)')

missing_class, missing_field, mismatch = [], [], []
for name in ("api.lua", "entity.lua", "orders.lua", "globals.lua", "nav.lua"):
    p = src / name
    if not p.exists():
        continue
    txt = p.read_text(encoding="utf-8", errors="ignore")
    for lineno, line in enumerate(txt.splitlines(), 1):
        for m in list(pat_offfb.finditer(line)) + list(pat_field.finditer(line)):
            cls, fld, fb = m.group(1), m.group(2), int(m.group(3), 16)
            fields = schema.get(cls)
            if fields is None:
                missing_class.append((name, lineno, cls, fld, fb)); continue
            if fld not in fields:
                missing_field.append((name, lineno, cls, fld, fb)); continue
            if fields[fld] != fb:
                mismatch.append((name, lineno, cls, fld, fb, fields[fld]))

print(f"classes not in dump: {len(missing_class)}")
for r in missing_class[:12]: print("  ", r)
print(f"fields not in dump: {len(missing_field)}")
for r in missing_field[:12]: print("  ", r)
print(f"fallback != schema: {len(mismatch)}")
for r in mismatch[:30]:
    print(f"   {r[0]}:{r[1]} {r[2]}.{r[3]} fallback=0x{r[4]:X} schema=0x{r[5]:X}")
