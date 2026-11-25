import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\Self Play.lua"
data=open(f, encoding='utf-8', errors='replace').read()
# find scan() where ctx.allies built
for m in re.finditer(r"ctx\.allies", data):
    s=max(0,m.start()-200); e=min(len(data), m.end()+200)
    print("...", data[s:e].replace("\n"," | ")[:500], "\n")
