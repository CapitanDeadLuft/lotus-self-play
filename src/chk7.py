from luaparser import ast
for p in [r"D:\hake\lotus\src\orders.lua", r"D:\hake\lotus\src\bot_loop_role1.lua"]:
    ast.parse(open(p, encoding="utf-8").read()); print("OK", p.split("\\")[-1])
