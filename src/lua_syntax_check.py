from luaparser import ast
import sys
for p in [r"D:\hake\lotus\src\menu.lua", r"D:\hake\lotus\src\orders.lua", r"D:\hake\lotus\src\api.lua"]:
    try:
        src = open(p, encoding="utf-8", errors="ignore").read()
        ast.parse(src)
        print("OK   ", p, len(src), "bytes")
    except Exception as e:
        print("FAIL ", p, type(e).__name__, str(e)[:300])
