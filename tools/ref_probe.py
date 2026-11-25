import json, collections
p = r"D:\hake\lotus\reference_treant.jsonl"
raw = open(p, encoding="utf-8").read()
print("bytes:", len(raw), "lines:", raw.count("\n")+1)
# try json array
try:
    data = json.loads(raw)
    print("array/json parsed len:", len(data))
except Exception as e:
    print("json.loads failed:", e)
    lines=[l for l in raw.splitlines() if l.strip()]
    print("nonempty lines:", len(lines))
    data=[json.loads(l) for l in lines]
kinds = collections.Counter(d.get("kind") for d in data)
print("kinds:", kinds)
for k in kinds:
    ex = next(d for d in data if d.get("kind")==k)
    print("\nKIND", k, "example keys:", list(ex.keys()))
    s = json.dumps(ex, ensure_ascii=False)
    print(s[:1200])
