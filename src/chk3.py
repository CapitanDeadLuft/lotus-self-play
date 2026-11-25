from luaparser import ast
for p in [r"D:\hake\lotus\src\diag_ctx_scan.lua", r"D:\hake\lotus\src\diag_ctx_scan2.lua"]:
    try:
        ast.parse(open(p, encoding="utf-8").read()); print("OK", p.split("\\")[-1])
    except Exception as e:
        print("FAIL", p, str(e)[:150])
