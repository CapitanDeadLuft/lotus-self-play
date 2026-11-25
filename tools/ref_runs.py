import json, re, os, collections
ref = json.load(open(r"D:\hake\lotus\reference_treant.jsonl", encoding='utf-8'))
print("ref entries", len(ref), "kind set", set(x['kind'] for x in ref))
# group into runs by clock reset
runs=[]; cur=[]
for e in ref:
    if cur and e['clock'] < cur[-1]['clock'] - 1:
        runs.append(cur); cur=[]
    cur.append(e)
if cur: runs.append(cur)
print("runs:", len(runs))
for i,r in enumerate(runs):
    print(i, "n=%d"%len(r), "clock %.1f..%.1f"%(r[0]['clock'], r[-1]['clock']), "lane set", sorted(set(x['lane'] for x in r)), "role set", sorted(set(x['role'] for x in r)), "maxLH", max(x['lh'] for x in r))
