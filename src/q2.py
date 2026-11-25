import json
d = json.load(open(r"D:\hake\lotus\dumper\dota2_dump\offsets.json", encoding="utf-8"))
sch = d.get("schema", {})
hits = []
for cls, fields in sch.items():
    for name, off in fields.items():
        if "designer" in name.lower() or "EntityIdentity" in cls:
            hits.append((cls, name, off))
for h in hits[:20]:
    print(h)
print("--- classes ---")
for c in sorted(sch):
    print(c, len(sch[c]))
# also dump non-schema top-level keys
for k, v in d.items():
    if k not in ("schema",):
        print(k, type(v).__name__, list(v)[:20] if isinstance(v, dict) else v)
