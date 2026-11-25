local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[aigame] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
L("inGame=%s state=%s", tostring(Engine.IsInGame()), tostring(GameRules.GetGameState()))
local cmds = { "dota_start_ai_game 1", "dota_start_ai_game", "dota_bot_create_game 1", "dota_create_local_lobby" }
for _, c in ipairs(cmds) do
  local ok, err = pcall(Engine.ExecuteCommand, c)
  L("cmd %s -> ok=%s err=%s", c, tostring(ok), tostring(err))
end
L("done")
