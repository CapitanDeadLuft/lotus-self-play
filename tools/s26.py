import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
h="2026-11-17 01:04:57"
key="===== Self Play session "+h+" ====="
a=next(i for i,l in enumerate(lines) if l.strip()==key)
b=next(i for i in range(a+1,len(lines)) if lines[i].startswith("====="))
print("session", h, "lines", a, b)
for i in range(a,b):
    l=lines[i]
    if "[SelfPlay score]" in l or "[SelfPlay lane]" in l:
        print(i, l.rstrip()[:240])
