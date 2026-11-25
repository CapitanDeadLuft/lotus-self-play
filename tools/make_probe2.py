#!/usr/bin/env python3
# Generate the [probe2] ledger-coverage build of last_hit.lua from the clean
# backup. Every replacement must match exactly once (fails loudly otherwise).
import hashlib, sys

SRC = r'D:\hake\lotus\backup_scripts_20261116_023749\last_hit.lua.bak_20261122b'
OUT_PATCH = r'D:\hake\lotus\patches\last_hit.lua.probe2'
OUT_LIVE = r'C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\self_play\last_hit.lua'
CLEAN_MD5 = 'F52C068C1CE6B3EB5589673A6FBD1F10'

def h(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest().upper()

src = open(SRC, encoding='utf-8').read()
assert h(SRC) == CLEAN_MD5, 'clean backup hash changed: ' + h(SRC)

def rep(old, new):
    global src
    n = src.count(old)
    assert n == 1, 'pattern count %d for %r' % (n, old[:60])
    src = src.replace(old, new)

# ---------------------------------------------------------------- helpers
HELPERS = '''
-- [probe2] TEMP ledger/coverage probe (remove before acceptance, AI-13).
local function probe2Load(ctx)
	if not ctx.role or ctx.role < 4 then return nil end
	local p = ctx.__probe2
	if not p then
		p = {calls = 0, seen = 0, chk = 0, gate = 0, denyNo = 0, far = 0, imm = 0,
			evPos = 0, ev0 = 0, act = 0, ev0act = 0, ev0actDp = 0,
			ev0actTgtMe = 0, ev0actTgtOther = 0, ev0actTgtNil = 0,
			ev0actCyc = 0, ev0actEvSrc = 0, ev0actDpSrc = 0,
			animEv = 0, animRej = 0, animNoTgt = 0, animFar = 0, animIns = 0, animS1 = nil,
			anim = 0, cyc = 0, pred = 0, noDelay = 0, min0 = 0, hpHiEv0 = 0,
			flag = 0, nowin = 0, noroute = 0, unsafe = 0, cands = 0, chosen = 0,
			s1 = nil, s2 = nil, s3 = nil, at = -1}
		ctx.__probe2 = p
	end
	return p
end

local function probe2Sources(events)
	local a, c, pr = 0, 0, 0
	for _, e in ipairs(events) do
		if e.predicted then pr = pr + 1
		elseif e.release then a = a + 1
		else c = c + 1 end
	end
	return a, c, pr
end

local function probe2EventCount(hits)
	local n = 0
	for _ in pairs(hits.events) do n = n + 1 end
	return n
end

local function probe2Dp()
	local ok, dp = pcall(function() return LIB_DAMAGE_PREDICTION end)
	if not (ok and type(dp) == "table") then return 0, 0 end
	local ua, tg = 0, 0
	if type(dp.unit_attack) == "table" then for _ in pairs(dp.unit_attack) do ua = ua + 1 end end
	if type(dp.targets) == "table" then
		for _, pr in pairs(dp.targets) do
			if type(pr) == "table" and pr.attacks and #pr.attacks > 0 then tg = tg + 1 end
		end
	end
	return ua, tg
end

local function probe2Log(ctx, p, cands, chosen)
	p.cands, p.chosen = p.cands + cands, p.chosen + (chosen and 1 or 0)
	if ctx.now < (p.at or -1) + 1.0 then return end
	p.at = ctx.now
	local ua, tg = probe2Dp()
	local df = io.open("D:\\\\hake\\\\lotus\\\\probe.log", "a")
	if df then
		df:write(string.format("%s [ledger] clock=%.0f calls=%d seen=%d chk=%d gate=%d denyNo=%d far=%d imm=%d evPos=%d ev0=%d act=%d ev0act=%d ev0actDp=%d ev0actTgtMe=%d ev0actTgtOther=%d ev0actTgtNil=%d ev0actCyc=%d ev0actEvSrc=%d ev0actDpSrc=%d animEv=%d animRej=%d animNoTgt=%d animFar=%d animIns=%d anim=%d cyc=%d pred=%d noDelay=%d min0=%d hpHiEv0=%d flag=%d nowin=%d noroute=%d unsafe=%d cands=%d chosen=%d ua=%d dpt=%d\\n",
			os.date("%H:%M:%S"), ctx.now or -1, p.calls, p.seen, p.chk, p.gate, p.denyNo, p.far, p.imm,
			p.evPos, p.ev0, p.act, p.ev0act, p.ev0actDp, p.ev0actTgtMe, p.ev0actTgtOther, p.ev0actTgtNil,
			p.ev0actCyc, p.ev0actEvSrc, p.ev0actDpSrc,
			p.animEv, p.animRej, p.animNoTgt, p.animFar, p.animIns,
			p.anim, p.cyc, p.pred, p.noDelay, p.min0,
			p.hpHiEv0, p.flag, p.nowin, p.noroute, p.unsafe, p.cands, p.chosen, ua, tg))
		if p.animS1 then df:write("  a1 " .. p.animS1 .. "\\n") end
		if p.s1 then df:write("  s1 " .. p.s1 .. "\\n") end
		if p.s2 then df:write("  s2 " .. p.s2 .. "\\n") end
		if p.s3 then df:write("  s3 " .. p.s3 .. "\\n") end
		df:flush(); df:close()
	end
	p.calls, p.seen, p.chk, p.gate, p.denyNo, p.far, p.imm = 0, 0, 0, 0, 0, 0, 0
	p.evPos, p.ev0, p.act, p.ev0act, p.ev0actDp = 0, 0, 0, 0, 0
	p.ev0actTgtMe, p.ev0actTgtOther, p.ev0actTgtNil = 0, 0, 0
	p.ev0actCyc, p.ev0actEvSrc, p.ev0actDpSrc = 0, 0, 0
	p.anim, p.cyc, p.pred, p.noDelay, p.min0, p.hpHiEv0 = 0, 0, 0, 0, 0, 0
	p.animEv, p.animRej, p.animNoTgt, p.animFar, p.animIns = 0, 0, 0, 0, 0
	p.animS1 = nil
	p.flag, p.nowin, p.noroute, p.unsafe = 0, 0, 0, 0
	p.cands, p.chosen, p.s1, p.s2, p.s3 = 0, 0, nil, nil, nil
end
'''

rep('''local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end
''', '''local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end
''' + HELPERS)

# ---------------------------------------------------------------- plan entry
rep('''function lastHit.plan(ctx)
	if NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return false end
	local attackReady = ctx.attackNext
''', '''function lastHit.plan(ctx)
	if NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return false end
	local __p2 = probe2Load(ctx)
	if __p2 then __p2.calls = __p2.calls + 1 end
	local attackReady = ctx.attackNext
''')

# ---------------------------------------------------------------- loop gate
rep('''	for _, creep in ipairs(ctx.creeps) do
		if live(creep) and NPC.IsVisible(creep) and not ctx.hits.blocked[Entity.GetIndex(creep)] then
			local allied = Entity.IsSameTeam(ctx.hero, creep)
			local denyable = allied and laneRules.denyable(ctx.clock, Entity.GetHealth(creep), Entity.GetMaxHealth(creep),
				NPC.GetModifierProperty(creep, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT))
			if (denyable or not allied and laneRules.canLastHit(ctx, creep))
				and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
				and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < math.max(cfg.searchRange, range + 500) then
				local health = Entity.GetHealth(creep)
''', '''	for _, creep in ipairs(ctx.creeps) do
		if live(creep) and NPC.IsVisible(creep) and not ctx.hits.blocked[Entity.GetIndex(creep)] then
			if __p2 then __p2.seen = __p2.seen + 1 end
			local allied = Entity.IsSameTeam(ctx.hero, creep)
			local denyable = allied and laneRules.denyable(ctx.clock, Entity.GetHealth(creep), Entity.GetMaxHealth(creep),
				NPC.GetModifierProperty(creep, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT))
			local __gateOk = denyable or not allied and laneRules.canLastHit(ctx, creep)
			local __stateOk = not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
				and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			local __rangeOk = ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < math.max(cfg.searchRange, range + 500)
			if __gateOk and __stateOk and __rangeOk then
				local health = Entity.GetHealth(creep)
''')

# closing of the gate if + loop: add the failure counters.
# The body ends with "candidates[#candidates + 1] = candidate\n\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\tend"
# We must be careful: patch the end of the gate if by matching the unique sequence
# around the end of the loop. Match on the loop tail after 'if map then GridNav.ReleaseNpcMap(map) end'.
rep('''	if map then GridNav.ReleaseNpcMap(map) end
	ctx.hits.candidateCount = #candidates
	local best = timeline.choose(candidates, ctx.now, NPC.GetSecondsPerAttack(ctx.hero, false), speed)
	if not best then ctx.hits.focus = nil; return false end
''', '''	if map then GridNav.ReleaseNpcMap(map) end
	ctx.hits.candidateCount = #candidates
	local best = timeline.choose(candidates, ctx.now, NPC.GetSecondsPerAttack(ctx.hero, false), speed)
	if __p2 then probe2Log(ctx, __p2, #candidates, best ~= nil) end
	if not best then ctx.hits.focus = nil; return false end
''')

# gate failure counters: attach an else-branch to the gate-if (3 tabs level).
rep('''				end
			end
		end
	end
	if map then GridNav.ReleaseNpcMap(map) end
''', '''				end
			elseif __p2 then
				if not __gateOk then
					if allied then __p2.denyNo = __p2.denyNo + 1 else __p2.gate = __p2.gate + 1 end
				elseif not __stateOk then __p2.imm = __p2.imm + 1
				else __p2.far = __p2.far + 1 end
			end
		end
	end
	if map then GridNav.ReleaseNpcMap(map) end
''')

# ---------------------------------------------------------------- per-creep ledger accounting
rep('''				local events = ledger(ctx, creep)
				local delay, windup = lastHit.timing(ctx, creep)
				if delay and minimum > 0 and (health < minimum * 2 or #events > 0) then
''', '''				local events = ledger(ctx, creep)
				local delay, windup = lastHit.timing(ctx, creep)
				if __p2 then
					__p2.chk = __p2.chk + 1
					local ev = #events
					local a, c, pr = probe2Sources(events)
					__p2.anim, __p2.cyc, __p2.pred = __p2.anim + a, __p2.cyc + c, __p2.pred + pr
					local ls = ctx.hits.lastSource and ctx.hits.lastSource[Entity.GetIndex(creep)]
					local hurtAge = ls and (ctx.now - (ls.time or -99)) or 99
					local active = hurtAge >= 0 and hurtAge < 1.6
					if ev > 0 then __p2.evPos = __p2.evPos + 1 end
					if active then __p2.act = __p2.act + 1 end
					if not delay then __p2.noDelay = __p2.noDelay + 1 end
					if minimum <= 0 then __p2.min0 = __p2.min0 + 1 end
					local flag = delay and minimum > 0 and (health < minimum * 2 or ev > 0)
					if flag then __p2.flag = __p2.flag + 1
					elseif ev == 0 and health >= minimum * 2 then __p2.hpHiEv0 = __p2.hpHiEv0 + 1 end
					if ev == 0 then
						__p2.ev0 = __p2.ev0 + 1
						if active then
							__p2.ev0act = __p2.ev0act + 1
							local src = ls and ls.source or nil
							local dpn = 0
							if prediction.available() then
								local dpl = prediction.attacks(ctx, creep)
								for _, atk in ipairs(dpl or {}) do
									if atk.impact and atk.impact > ctx.now then dpn = dpn + 1 end
								end
							end
							if dpn > 0 then __p2.ev0actDp = __p2.ev0actDp + 1 end
							-- cause split: was the hurt source's swing seen at all, and to which target?
							local tgtState = "noSrc"
							local cycSrc, evSrc, dpSrc = 0, 0, 0
							if src and live(src) then
								if ctx.hits.cycles[Entity.GetIndex(src)] then cycSrc = 1 end
								for _, e in pairs(ctx.hits.events) do if e.source == src then evSrc = evSrc + 1 end end
								local tgt = attackTarget(ctx, src)
								if tgt == creep then tgtState = "me"
								elseif tgt then tgtState = "other:" .. tostring(NPC.GetUnitName(tgt)) else tgtState = "nil" end
								local okdp, dpt = pcall(function() return LIB_DAMAGE_PREDICTION end)
								if okdp and type(dpt) == "table" and type(dpt.unit_attack) == "table" then
									for _, ent in pairs(dpt.unit_attack) do
										if ent.source == src then dpSrc = dpSrc + 1 end
									end
								end
							end
							if tgtState == "me" then __p2.ev0actTgtMe = __p2.ev0actTgtMe + 1
							elseif tgtState == "nil" or tgtState == "noSrc" then __p2.ev0actTgtNil = __p2.ev0actTgtNil + 1
							else __p2.ev0actTgtOther = __p2.ev0actTgtOther + 1 end
							if cycSrc > 0 then __p2.ev0actCyc = __p2.ev0actCyc + 1 end
							if evSrc > 0 then __p2.ev0actEvSrc = __p2.ev0actEvSrc + 1 end
							if dpSrc > 0 then __p2.ev0actDpSrc = __p2.ev0actDpSrc + 1 end
							if not __p2.s2 then
								local srcName = "none"
								if src then srcName = NPC.GetUnitName(src) or "?" end
								__p2.s2 = string.format("ev0active hp=%d min=%d max=%d hurtAge=%.2f src=%s allied=%s tgt=%s cycSrc=%d evSrc=%d dpSrc=%d dpFuture=%d animEv=%d",
									health, minimum, maximum, hurtAge, srcName, tostring(src and Entity.IsSameTeam(ctx.hero, src) or false),
									tgtState, cycSrc, evSrc, dpSrc, dpn, probe2EventCount(ctx.hits))
							end
						end
					elseif not __p2.s1 then
						__p2.s1 = string.format("evpos hp=%d min=%d ev=%d a=%d c=%d pr=%d active=%s",
							health, minimum, ev, a, c, pr, tostring(active))
					end
				end
				if delay and minimum > 0 and (health < minimum * 2 or #events > 0) then
''')

# ---------------------------------------------------------------- route failure counter
rep('''							impact, wait = window(ctx, candidate, earliest)
						else impact = nil end
''', '''							impact, wait = window(ctx, candidate, earliest)
						else impact = nil; if __p2 then __p2.noroute = __p2.noroute + 1 end end
''')

# ---------------------------------------------------------------- accept/reject counters + nowin sample
rep('''						candidates[#candidates + 1] = candidate
					end
''', '''						candidates[#candidates + 1] = candidate
					elseif __p2 then
						if impact then
							__p2.unsafe = __p2.unsafe + 1
						else
							__p2.nowin = __p2.nowin + 1
							if not __p2.s3 then
								local evn = #candidate.events
								if evn > 0 then
									local lastEvent = candidate.events[evn]
									local low, high, coll = timeline.predict(candidate.health, candidate.regen,
										candidate.barrier, ctx.now, lastEvent.impact, candidate.events)
									__p2.s3 = string.format("nowin hp=%d dmg=%d ev=%d low=%.0f high=%.0f collision=%s lastKind=%s",
										candidate.health, candidate.damage, evn, low, high, tostring(coll),
										lastEvent.predicted and "pred" or (lastEvent.release and "anim" or "cyc"))
								else
									__p2.s3 = string.format("nowin hp=%d dmg=%d ev=0", candidate.health, candidate.damage)
								end
							end
						end
					end
''')

# ---------------------------------------------------------------- impact-time coverage in lastHit.hurt
rep('''	local now, matched, closest = GameRules.GetGameTime(), nil, 0.35
	for key, event in pairs(ctx.hits.events) do
		local difference = math.abs(event.impact - now)
		if event.source == data.source and event.target == data.target and difference < closest then matched, closest = key, difference end
	end
	if not matched then return end
''', '''	local now, matched, closest = GameRules.GetGameTime(), nil, 0.35
	for key, event in pairs(ctx.hits.events) do
		local difference = math.abs(event.impact - now)
		if event.source == data.source and event.target == data.target and difference < closest then matched, closest = key, difference end
	end
	-- [probe3] impact-time ledger coverage for lane-creep hurt events
	if ctx.role >= 4 then
		local pp = probe2Load(ctx)
		if pp then
			pp.hurtN = (pp.hurtN or 0) + 1
			if data.source == ctx.hero then
				pp.hurtHero = (pp.hurtHero or 0) + 1
			elseif matched then
				pp.hurtMatch = (pp.hurtMatch or 0) + 1
			else
				local srcEv, srcEvTgt, cycSrc = 0, 0, 0
				for _, e in pairs(ctx.hits.events) do
					if e.source == data.source then
						srcEv = srcEv + 1
						if e.target == data.target then srcEvTgt = srcEvTgt + 1 end
					end
				end
				if ctx.hits.cycles[Entity.GetIndex(data.source)] then cycSrc = 1 end
				pp.hurtNo = (pp.hurtNo or 0) + 1
				if srcEv > 0 then pp.hurtMisattr = (pp.hurtMisattr or 0) + 1
				else pp.hurtNoDetect = (pp.hurtNoDetect or 0) + 1 end
				if cycSrc > 0 then pp.hurtCyc = (pp.hurtCyc or 0) + 1 end
				if not pp.hurtS1 then
					local srcName = "none"
					if data.source then srcName = NPC.GetUnitName(data.source) or "?" end
					pp.hurtS1 = string.format("hurtNoMatch src=%s srcEv=%d srcEvTgt=%d cyc=%d dmg=%d",
						srcName, srcEv, srcEvTgt, cycSrc, data.damage)
				end
			end
			if ctx.now >= (pp.hurtAt or -1) + 1.0 then
				pp.hurtAt = ctx.now or 0
				local df = io.open("D:\\\\hake\\\\lotus\\\\probe.log", "a")
				if df then
					df:write(string.format("%s [hurtcov] clock=%.0f total=%d hero=%d match=%d no=%d misattr=%d nodetect=%d cyc=%d\\n",
						os.date("%H:%M:%S"), ctx.now or -1, pp.hurtN or 0, pp.hurtHero or 0, pp.hurtMatch or 0,
						pp.hurtNo or 0, pp.hurtMisattr or 0, pp.hurtNoDetect or 0, pp.hurtCyc or 0))
					if pp.hurtS1 then df:write("  h1 " .. pp.hurtS1 .. "\\n") end
					df:flush(); df:close()
				end
				pp.hurtN, pp.hurtHero, pp.hurtMatch, pp.hurtNo = 0, 0, 0, 0
				pp.hurtMisattr, pp.hurtNoDetect, pp.hurtCyc, pp.hurtS1 = 0, 0, 0, nil
			end
		end
	end
	if not matched then return end
''')

# ---------------------------------------------------------------- swing-target resolution in lastHit.animation
rep('''function lastHit.animation(ctx, data)
	if not live(data.unit) or not NPC.IsAttacking(data.unit) then return end
	local target = attackTarget(ctx, data.unit)
	if not live(target) or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > 2500 then return end
''', '''function lastHit.animation(ctx, data)
	local __p3 = probe2Load(ctx)
	if __p3 then __p3.animEv = __p3.animEv + 1 end
	if not live(data.unit) or not NPC.IsAttacking(data.unit) then
		if __p3 then __p3.animRej = __p3.animRej + 1 end
		return
	end
	local target = attackTarget(ctx, data.unit)
	if not live(target) then
		if __p3 then
			__p3.animNoTgt = __p3.animNoTgt + 1
			if not __p3.animS1 then
				local okr, rot = pcall(Entity.GetRotation, data.unit)
				__p3.animS1 = string.format("noTgt unit=%s att=%s yaw=%s",
					tostring(NPC.GetUnitName(data.unit)), tostring(NPC.IsAttacking(data.unit)),
					tostring(okr and rot and rot.yaw))
			end
		end
		return
	end
	if ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > 2500 then
		if __p3 then __p3.animFar = __p3.animFar + 1 end
		return
	end
	if __p3 then __p3.animIns = __p3.animIns + 1 end
''')

open(OUT_PATCH, 'w', encoding='utf-8', newline='\n').write(src)
print('wrote patch', OUT_PATCH, len(src), 'md5', hashlib.md5(src.encode()).hexdigest().upper())
if '--live' in sys.argv:
    open(OUT_LIVE, 'w', encoding='utf-8', newline='\n').write(src)
    print('wrote live', OUT_LIVE)