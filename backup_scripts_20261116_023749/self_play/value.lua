local value = {}
local winModel = require("self_play.win_model")

value.xpTable = {0, 240, 640, 1160, 1760, 2440, 3200, 4000, 4900, 5900, 7000, 8200, 9500, 10900, 12400, 14000, 15700,
	17500, 19400, 21400, 23600, 26000, 28600, 31400, 34400, 38400, 43400, 49400, 56400, 63900}
value.campGold = {[0] = 70, [1] = 95, [2] = 130, [3] = 220}

local function minutes(ctx)
	return math.max(0, ctx.clock or 0) / 60
end

function value.scale(ctx)
	local state = ctx.winModel
	local worth = state and state.allyItems and state.enemyItems and (state.allyItems + state.enemyItems) / 2 or 0
	if worth <= 0 then worth = 3000 + minutes(ctx) * 2200 end
	return math.max(8000, worth)
end

function value.perLogit(ctx)
	return value.scale(ctx) / winModel.weights.gold
end

function value.xpNeeded(level)
	local current, next = value.xpTable[level], value.xpTable[level + 1]
	if not current or not next then return 7500 end
	return next - current
end

function value.xpRate(ctx)
	local level = NPC.GetCurrentLevel(ctx.hero)
	if level >= 30 then return 0 end
	local derived = winModel.weights.level / (5 * value.xpNeeded(level)) * value.perLogit(ctx)
	return math.max(0.15, math.min(1.1, math.max(derived, 0.9 - level * 0.03)))
end

function value.networth(ctx)
	local ok, info = pcall(Player.GetTeamPlayer, ctx.player)
	return ok and info and info.networth or 0
end

function value.income(ctx)
	local cached = ctx.valueIncome
	if cached and ctx.now - cached.time < 1 then return cached.amount end
	local span = math.max(1, minutes(ctx))
	local floorGpm = ctx.role <= 3 and 280 + minutes(ctx) * 10 or 180 + minutes(ctx) * 4
	local gpm = minutes(ctx) > 2 and math.max(floorGpm * 0.6, value.networth(ctx) / span) or floorGpm
	local xp = Hero.GetCurrentXP and Hero.GetCurrentXP(ctx.hero) or 0
	local xpm = minutes(ctx) > 2 and xp / span or 300
	local amount = math.min(30, (gpm + xpm * value.xpRate(ctx)) / 60)
	ctx.valueIncome = {time = ctx.now, amount = amount}
	return amount
end

function value.time(ctx, seconds)
	return math.max(0, seconds) * value.income(ctx)
end

function value.respawn(level)
	return math.min(100, 4 + level * 2.6)
end

function value.bounty(level)
	return 110 + level * 8
end

function value.deathCost(ctx)
	local level = NPC.GetCurrentLevel(ctx.hero)
	local goldLoss = 50 + value.networth(ctx) / 40
	local respawn = value.respawn(level)
	local alive = winModel.weights.alive * 0.25 * (0.3 + 0.7 * math.min(1, minutes(ctx) / 30)) * math.min(1, respawn / 40)
	return goldLoss + value.bounty(level) + respawn * value.income(ctx) * 1.3
		+ (winModel.weights.kills + alive) * value.perLogit(ctx)
end

function value.kill(ctx, enemy)
	local level = NPC.GetCurrentLevel(enemy)
	local respawn = value.respawn(level)
	local alive = winModel.weights.alive * 0.25 * (0.3 + 0.7 * math.min(1, minutes(ctx) / 30)) * math.min(1, respawn / 40)
	return value.bounty(level) + (100 + level * 12) * value.xpRate(ctx) + respawn * value.income(ctx)
		+ (winModel.weights.kills + alive) * value.perLogit(ctx)
end

function value.building(ctx, unit)
	return winModel.building(unit) * winModel.weights.buildings * value.perLogit(ctx)
end

function value.wisdom(ctx)
	return (280 + 30 * math.floor(math.max(0, ctx.clock) / 420)) * value.xpRate(ctx)
end

function value.camp(ctx, campType)
	local gold = value.campGold[campType or 1] or 95
	return gold * (1 + minutes(ctx) / 40) * (1 + 0.6 * value.xpRate(ctx))
end

function value.rate(ctx, worth, seconds, risk)
	return (worth - (risk or 0) * value.deathCost(ctx)) / math.max(1, seconds)
end

function value.summary(ctx)
	return string.format("perLogit=%.0f xp=%.2fg income=%.1fg/s death=%.0fg wisdom=%.0fg camp=%.0fg",
		value.perLogit(ctx), value.xpRate(ctx), value.income(ctx), value.deathCost(ctx), value.wisdom(ctx), value.camp(ctx, 1))
end

return value
