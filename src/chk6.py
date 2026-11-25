from luaparser import ast
p = r"D:\hake\lotus\src\orders.lua"
ast.parse(open(p, encoding="utf-8").read()); print("orders.lua OK")
