from luaparser import ast
p = r"D:\hake\lotus\src\diag_ctx_scan.lua"
try:
    ast.parse(open(p, encoding="utf-8").read()); print("diag syntax OK", len(open(p,encoding='utf-8').read()), "bytes")
except Exception as e:
    print("FAIL", type(e).__name__, e)
