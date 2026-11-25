import os, re
root = r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts"
for dirpath, _, files in os.walk(root):
    for fn in files:
        if not fn.endswith(".lua"): continue
        p = os.path.join(dirpath, fn)
        try: txt = open(p, encoding="utf-8", errors="ignore").read().splitlines()
        except OSError: continue
        for i, line in enumerate(txt, 1):
            if re.search(r"\bcreeps\b", line) and re.search(r"(function|\{)", line) and "=" in line:
                print(f"{os.path.relpath(p, root)}:{i}: {line.strip()[:170]}")
