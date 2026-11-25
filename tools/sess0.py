import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
# session 2026-11-16 03:12:52 range
start=next(i for i,l in enumerate(lines) if l.strip()=="===== Self Play session 2026-11-16 03:12:52 =====")
end=next((i for i in range(start+1,len(lines)) if lines[i].startswith("=====")), len(lines))
print("session range", start, end)
picks=[(i,lines[i].rstrip()) for i in range(start,end) if "Pick requested" in lines[i]]
print("picks:", len(picks))
for p in picks: print(p)
ally=[(i,lines[i].rstrip()) for i in range(start,end) if "[SelfPlay ally]" in lines[i]]
print("ally lines:", len(ally))
for p in ally[:10]: print(p)
print("...")
for p in ally[-5:]: print(p)
builds=[(i,lines[i].rstrip()) for i in range(start,end) if "[SelfPlay build]" in lines[i]]
print("builds:", len(builds))
for p in builds[:10]: print(p)
