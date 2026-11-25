package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
io.stdout:setvbuf("no")
local JSON = require("assets.JSON")
local j = JSON:new()
print("test1: simple array")
print(j:encode({{ "a", true }, { "b", false }}))
print("test2: 127 entries")
local model = {}
for i = 1, 127 do model[i] = { "hero_" .. i, false } end
print(j:encode(model):sub(1, 80))
print("test3: empty")
print(j:encode({}))
print("ALL JSON OK")