import re
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\Self Play.lua"
lines=open(f, encoding='utf-8', errors='replace').readlines()
for i,l in enumerate(lines):
    if "function helpers.scan" in l:
        for j in range(i, min(i+120, len(lines))):
            print(j+1, lines[j].rstrip()[:220])
        break
