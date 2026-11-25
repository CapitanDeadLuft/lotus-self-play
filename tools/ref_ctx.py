import re, collections
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
start=next(i for i,l in enumerate(lines) if l.strip()=="===== Self Play session 2026-11-16 03:12:52 =====")
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
# categorize lines containing hero names by prefix
pref=collections.Counter()
for i in range(start,end):
    if "npc_dota_hero_" in lines[i]:
        m=re.search(r"\]\s*(\[[^\]]+\])", lines[i])
        pref[m.group(1) if m else "?"]+=1
print("prefixes of hero-name lines:")
for k,v in pref.most_common(): print(v,k)
print("\n=== 'core' mentions ===")
n=0
for i in range(start,end):
    if "core" in lines[i].lower() and i>start+1300:
        print(i, lines[i].rstrip()[:260]); n+=1
        if n>=30: break
print("\n=== escort/help lines with names? ===")
n=0
for i in range(start,end):
    if ("escort" in lines[i].lower() or "[SelfPlay help]" in lines[i]) and n<25:
        print(i, lines[i].rstrip()[:260]); n+=1
