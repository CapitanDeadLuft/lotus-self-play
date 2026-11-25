from luaparser import ast
for p in [r"D:\hake\lotus\src\loader.lua", r"D:\hake\lotus\src\flags.lua"]:
    try:
        ast.parse(open(p, encoding="utf-8").read()); print("OK", p.split("\\")[-1])
    except Exception as e:
        print("FAIL", p.split("\\")[-1], str(e)[:200])
