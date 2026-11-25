package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local menu = require("menu")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
for _, w in ipairs(menu.widgets) do
  if w.name and w.name:find("Enable Self Play") then
    f:write(os.date("%H:%M:%S ") .. "TOGGLE Enable=" .. tostring(w.value) .. "\n")
  end
end
f:close()
