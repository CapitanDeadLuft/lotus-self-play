-- protobuf.lua — stub of Umbrella protobuf lib (GC messages). Real impl needed for matchmaking.
local M = {}
function M.encodeFromJSON(msgName, jsonStr)
  return { binary = "", msg_name = msgName }
end
function M.decodeToJSONfromObject(obj)
  return "{}"
end
function M.decodeToJSON(binary, msgName)
  return "{}"
end
function M.free(binary) end
function M.load(protoContent) end
function M.register(msgName, def) end
return M