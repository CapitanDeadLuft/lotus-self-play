import json
d = json.load(open(r"D:\hake\lotus\dumper\dota2_dump\offsets.json", encoding="utf-8"))
sch = d["schema"]
for cls in ("client.dll::C_DOTAPlayerController",):
    print("==", cls)
    for name, off in sorted(sch[cls].items(), key=lambda kv: kv[1]):
        if any(k in name.lower() for k in ("order","seq","issuer","selected")):
            print(f"   {name} = {off} (0x{off:X})")
# also any class with order sequence
for cls, fields in sch.items():
    for n, o in fields.items():
        if "ordersequence" in n.lower() or n.lower().endswith("_sequence"):
            print(cls, n, o)
