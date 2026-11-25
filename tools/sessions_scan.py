import os, re
cands = [
 r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log",
 r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.log",
 r"D:\hake\lotus\self_play.log",
 r"D:\hake\lotus\r11_stages_A1_20261117_191645.log",
 r"D:\hake\lotus\host.log",
]
for f in cands:
    if not os.path.exists(f): print("MISSING", f); continue
    heads=[]
    with open(f, 'r', encoding='utf-8', errors='replace') as fh:
        for i, line in enumerate(fh):
            if line.startswith("====="):
                heads.append((i+1, line.strip()))
    print(f, "size", os.path.getsize(f), "sessions:", len(heads))
    for h in heads[:20]: print("   ", h)
