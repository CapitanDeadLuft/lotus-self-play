-- recon.lua — locate dota2.exe and print bases of the modules our reader needs.
io.stdout:setvbuf("no")
local proc = require("proc")

print("step: find dota2")
local pid = proc.find("dota2.exe")
if not pid then print("dota2.exe not running"); os.exit(1) end
print("dota2.exe pid=" .. pid)

print("step: modules snapshot")
local mods = proc.modules(pid)
print("modules total: " .. #mods)
local want = { "client.dll", "engine2.dll", "schemasystem.dll", "tier0.dll", "vstdlib.dll", "steam_api64.dll" }
for _, w in ipairs(want) do
  local m = nil
  for _, x in ipairs(mods) do if x.name == w then m = x break end end
  if m then
    print(string.format("  %-18s base=0x%X size=0x%X", w, tonumber(m.base), m.size))
  else
    print(string.format("  %-18s NOT LOADED", w))
  end
end