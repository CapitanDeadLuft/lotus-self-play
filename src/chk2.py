from luaparser import ast
for p in [r"D:\hake\lotus\src\entity.lua"]:
    try:
        ast.parse(open(p, encoding="utf-8").read()); print("OK", p)
    except Exception as e:
        print("FAIL", p, type(e).__name__, str(e)[:200])
