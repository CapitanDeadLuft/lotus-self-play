-- mathx.lua — Vector / Vec2 / Color / Angle classes (Umbrella API compatible).
local M = {}
local sqrt, floor, abs, min, max = math.sqrt, math.floor, math.abs, math.min, math.max
local sin, cos, atan2, pi = math.sin, math.cos, math.atan2, math.pi

-- Vector ------------------------------------------------------------------
local Vector = {}
Vector.__index = Vector
-- perf instrumentation (temporary): Vector allocations dominate GC if hot
local vcount, vtime = 0, 0
local clock = os.clock
local function vnew(x, y, z)
  vcount = vcount + 1
  local t0 = clock()
  local v = setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vector)
  vtime = vtime + (clock() - t0)
  return v
end
function _G.__mathxStats()
  local c, t = vcount, vtime
  vcount, vtime = 0, 0
  return c, t
end
function Vector.__add(a, b) return vnew(a.x + b.x, a.y + b.y, a.z + b.z) end
function Vector.__sub(a, b) return vnew(a.x - b.x, a.y - b.y, a.z - b.z) end
function Vector.__mul(a, b)
  if type(a) == "number" then return vnew(a * b.x, a * b.y, a * b.z) end
  if type(b) == "number" then return vnew(a.x * b, a.y * b, a.z * b) end
  return vnew(a.x * b.x, a.y * b.y, a.z * b.z)
end
function Vector.__div(a, b)
  if type(b) == "number" then return vnew(a.x / b, a.y / b, a.z / b) end
  return vnew(a.x / b.x, a.y / b.y, a.z / b.z)
end
function Vector.__unm(a) return vnew(-a.x, -a.y, -a.z) end
function Vector.__eq(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
function Vector.__tostring(a) return string.format("Vector(%.2f, %.2f, %.2f)", a.x, a.y, a.z) end
function Vector:Length() return sqrt(self.x * self.x + self.y * self.y + self.z * self.z) end
function Vector:Length2D() return sqrt(self.x * self.x + self.y * self.y) end
function Vector:LengthSqr() return self.x * self.x + self.y * self.y + self.z * self.z end
function Vector:Length2DSqr() return self.x * self.x + self.y * self.y end
function Vector:Normalize()
  local l = self:Length(); if l == 0 then return vnew(0, 0, 0) end
  return vnew(self.x / l, self.y / l, self.z / l)
end
function Vector:Dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function Vector:Cross(b) return vnew(self.y * b.z - self.z * b.y, self.z * b.x - self.x * b.z, self.x * b.y - self.y * b.x) end
function Vector:Dist(b) return (self - b):Length() end
function Vector:Dist2D(b) return (self - b):Length2D() end
function Vector:ToScreen()
  -- via Render.WorldToScreen (set by render module)
  if M.WorldToScreen then return M.WorldToScreen(self) end
  return vnew(0, 0, 0), false
end
function Vector:Unpack() return self.x, self.y, self.z end
M.Vector = vnew

-- Vec2 --------------------------------------------------------------------
local Vec2 = {}
Vec2.__index = Vec2
local function v2new(x, y) return setmetatable({ x = x or 0, y = y or 0 }, Vec2) end
function Vec2.__add(a, b) return v2new(a.x + b.x, a.y + b.y) end
function Vec2.__sub(a, b) return v2new(a.x - b.x, a.y - b.y) end
function Vec2.__mul(a, b)
  if type(a) == "number" then return v2new(a * b.x, a * b.y) end
  if type(b) == "number" then return v2new(a.x * b, a.y * b) end
  return v2new(a.x * b.x, a.y * b.y)
end
function Vec2.__div(a, b)
  if type(b) == "number" then return v2new(a.x / b, a.y / b) end
  return v2new(a.x / b.x, a.y / b.y)
end
function Vec2.__unm(a) return v2new(-a.x, -a.y) end
function Vec2.__eq(a, b) return a.x == b.x and a.y == b.y end
function Vec2.__tostring(a) return string.format("Vec2(%.2f, %.2f)", a.x, a.y) end
function Vec2:Length() return sqrt(self.x * self.x + self.y * self.y) end
function Vec2:Dist(b) return (self - b):Length() end
function Vec2:Normalize() local l = self:Length(); if l == 0 then return v2new(0, 0) end; return v2new(self.x / l, self.y / l) end
M.Vec2 = v2new

-- Color -------------------------------------------------------------------
local Color = {}
Color.__index = Color
local function cnew(r, g, b, a) return setmetatable({ r = r or 255, g = g or 255, b = b or 255, a = a or 255 }, Color) end
function Color.__eq(a, b) return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a end
function Color.__tostring(c) return string.format("Color(%d, %d, %d, %d)", c.r, c.g, c.b, c.a) end
function Color:Unpack() return self.r, self.g, self.b, self.a end
M.Color = cnew

-- Angle -------------------------------------------------------------------
local Angle = {}
Angle.__index = Angle
local function anew(p, y, r) return setmetatable({ pitch = p or 0, yaw = y or 0, roll = r or 0 }, Angle) end
function Angle.__add(a, b) return anew(a.pitch + b.pitch, a.yaw + b.yaw, a.roll + b.roll) end
function Angle.__sub(a, b) return anew(a.pitch - b.pitch, a.yaw - b.yaw, a.roll - b.roll) end
function Angle:GetForward()
  local pitch = math.rad(self.pitch or 0)
  local yaw = math.rad(self.yaw or 0)
  local cp = cos(pitch)
  return vnew(cp * cos(yaw), cp * sin(yaw), -sin(pitch))
end
function Angle:GetYaw() return self.yaw or 0 end
function Angle:GetPitch() return self.pitch or 0 end
function Angle:Normalize()
  local function n(x) x = x % 360; if x > 180 then x = x - 360 end; return x end
  return anew(n(self.pitch), n(self.yaw), n(self.roll))
end
M.Angle = anew

return M
