from luaparser import ast
p = r"D:\hake\lotus\src\probe_identity.lua"
try:
    ast.parse(open(p, encoding="utf-8").read()); print("probe syntax OK")
except Exception as e:
    print("FAIL", type(e).__name__, str(e)[:300])
