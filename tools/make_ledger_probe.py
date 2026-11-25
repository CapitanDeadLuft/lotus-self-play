#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_ledger_probe.py - deterministic generator of the read-only [ledg2] probe build.

Builds ``patches/last_hit.lua.ledger_probe`` from the pinned clean base
``backup_scripts_20261116_023749/last_hit.lua.bak_20261120_213938``
(MD5 CE33D41E8A477DE521C4CEB774B9AB79 == live scripts/self_play/last_hit.lua
at the time of the 2026-11-24 ledger/noFlag measurement).

The build instruments ``lastHit.plan`` / ``lastHit.hurt`` with counters that
explain why an enemy lane creep did or did not become a last-hit candidate,
and writes them to ``D:\\hake\\lotus\\probe_ledger.log``.  It is strictly
read-only with respect to game state: the only ctx mutation is the probe's own
``ctx.__ledg2`` table; no orders/casts/moves are issued; return values of
plan/execute/hurt are byte-for-byte the original ones.  It is NOT an
acceptance build - restore the clean CE33 file after the measurement.

--------------------------------------------------------------------------
PROBE CONTRACT v1 (marker ``[ledg2]``, log ``D:\\hake\\lotus\\probe_ledger.log``)
--------------------------------------------------------------------------
* Role gate: active only when ``ctx.role`` is set and ``ctx.role >= 4``
  (support scenario; with a core partner the gate would be active and the
  ledger variant of the question does not apply).  State lives in
  ``ctx.__ledg2``; the first active call appends ``HH:MM:SS [ledg2] begin role=N``.
* One aggregate line per log window, at most once per 1.0 match-second
  (``ctx.now``); counters are per-window sums and are reset only after the
  window was written successfully.  Wall-time prefix ``os.date("%H:%M:%S")``.
* Up to 3 sample rows per window each (same wall prefix):
    ``[ledg2 row]  clock=%.1f creep=%s hp=%d min=%d max=%d ev=%d dist=%.0f``
      - enemy creep in the maturity check that failed ``noFlag`` with dist<600;
    ``[ledg2 hurt] clock=%.1f target=%s source=%s dmg=%d srcEv=%d srcEvTgt=%d cyc=%d``
      - enemy-target hurt that did not match a ledger event (hurtENo).

Main line (field order is fixed; the analyzer ``tools/ledger_probe_report.py``
depends on these exact keys):

  clock=%.1f role=%d calls=%d seenE=%d seenA=%d gateE=%d denyNo=%d stateE=%d
  stateA=%d farE=%d farA=%d chkE=%d chkA=%d passE=%d passA=%d noFlagE=%d
  noFlagA=%d noDelayE=%d min0E=%d evPosE=%d evPosA=%d ev0E=%d evN1E=%d
  evN2E=%d evN4pE=%d srcAnimE=%d srcCycE=%d srcPredE=%d d350E=%d d600E=%d
  d900E=%d d1300E=%d noFlagCloseE=%d passCloseE=%d noFlagKillE=%d candsE=%d
  candsA=%d chosenE=%d chosenA=%d nowinE=%d unsafeE=%d norouteE=%d
  tickCall=%d tickChkE=%d tickEvE=%d tickPassE=%d tickCandsE=%d tickChosenE=%d
  hurtE=%d hurtEHero=%d hurtEMatch=%d hurtENo=%d hurtENodetect=%d
  hurtEMisattr=%d hurtAMatch=%d hurtACyc=%d

Semantics (line numbers refer to the CE33 base):
  seenE/seenA     creeps in the plan loop that pass live+visible+not blocked
                  (enemy/allied)                                  (527-528)
  gateE/denyNo    gate failed: enemy canLastHit false / allied denyable false
                                                                  (529-532)
  stateE/stateA   gate passed but ATTACK_IMMUNE or INVULNERABLE     (533-534)
  farE/farA       state passed but range guard failed               (535)
  chkE/chkA       all guards passed -> reached the maturity check   (540)
  passE/passA     maturity true (original condition)                (540)
  noFlagE/noFlagA delay and minimum>0 and #events==0 and health>=minimum*2
  noDelayE        enemy chk where delay is nil
  min0E           enemy chk where delay is set but minimum<=0
                  invariant (enemy): chkE = passE+noFlagE+noDelayE+min0E
  evPosE/A        #events>0; ev0E = #events==0 (enemy)
  evN1E/evN2E/evN4pE  enemy chk with 1 / 2-3 / >=4 events
  srcAnimE/srcCycE/srcPredE  enemy-chk event categories (release/predicted/other)
  d350E..d1300E   distance buckets over enemy chk, taken from the EXISTING
                  range check (``__dist``; nil fallback counts d1300E only)
  noFlagCloseE    noFlagE with dist<600; passCloseE = passE with dist<600
  noFlagKillE     noFlagE with health < minimum*4
  candsE/candsA   candidates appended to the plan list                 (593)
  chosenE/chosenA timeline.choose() result, split by best.allied       (601)
  nowinE          enemy candidate rejected at the final farmSafe gate because
                  impact is nil; unsafeE = the same gate with impact non-nil
  norouteE        out-of-range enemy candidate for which route() returned nil
                  (may overlap nowinE: the same candidate is re-counted at the
                  final gate; documented next to the insertion)
  tickCall        plan calls in the window; tickChkE/tickEvE/tickPassE/
                  tickCandsE/tickChosenE - plan calls where the corresponding
                  per-call enemy counter was >0
  hurtE           hurt on an enemy lane creep, hero dist<=2500 (hurt() only)
  hurtEHero       subset with source == ctx.hero
  hurtEMatch      non-hero source whose hurt matched a ledger event
  hurtENo         non-hero source with no matched event
  hurtENodetect   ... and source has zero events in ctx.hits.events
  hurtEMisattr    ... and source has events, but none for that target
  hurtAMatch      allied-target hurt that matched a ledger event
  hurtACyc        allied-target hurt whose source has an attack cycle record

Read-only invariants checked by the acceptance audit:
  1. only ``ctx.__ledg2`` is written; ctx.hits/ctx.role/ctx.mode/ctx.lastOrder
     and every other field are untouched;
  2. ``lastHit.plan``/``execute``/``hurt`` return exactly what the original
     returned (insertions only count and write the probe log);
  3. role < 4 => total no-op (no state, no log lines);
  4. no new per-creep API calls: ``__dist`` is captured from the existing range
     check; in ``lastHit.hurt`` the probe re-evaluates a few cheap read-only
     guards (``Entity.IsEntity``/``IsNPC``/``NPC.IsLaneCreep``) only for counted
     lane-creep hurts, adds one ``ctx.distance`` per counted hurt (<=2500 filter),
     one ``Entity.IsSameTeam`` for the enemy/allied split and up to 3 sampled
     ``NPC.GetUnitName`` calls per log window; no orders/casts/moves and no
     API calls are added on the per-creep plan path;
  5. all io is nil-safe and pcall-wrapped in the log writer; probe errors never
     propagate into game code (plan/execute are NOT wrapped in pcall).

Output format note: the generated build is written with LF line endings even
though the pinned base file uses CRLF (711 lines).  This is a text-only
transformation (Lua ignores line endings); the counters/anchors are computed
on the text, and the installer restores the original CRLF CE33 file byte-for-byte,
so the EOL change never touches the clean state.

All replacements below are exact-once: the build fails loudly if an anchor does
not match exactly once (this also verifies the base hash).

Usage:
  python tools\\make_ledger_probe.py                # build + write the patch
  python tools\\make_ledger_probe.py --check        # in-memory build, markers,
                                                    # line-count math, luajit
                                                    # loadfile compile; no writes
  python tools\\make_ledger_probe.py --print-stats  # extra per-block stats
  python tools\\make_ledger_probe.py --out PATH     # write somewhere else
                                                    # (tests; no other writes)

Exit code 0 = PASS, 1 = failure.  Two consecutive runs produce the same MD5.
"""

import argparse
import hashlib
import os
import re
import subprocess
import sys
import tempfile

BASE = r'D:\hake\lotus\backup_scripts_20261116_023749\last_hit.lua.bak_20261120_213938'
OUT = r'D:\hake\lotus\patches\last_hit.lua.ledger_probe'
BASE_MD5 = 'CE33D41E8A477DE521C4CEB774B9AB79'
LUAJIT = r'D:\hake\lotus\luajit\src\src\luajit.exe'

# ---------------------------------------------------------------------------
# main-line field table: (key, printf conversion, Lua expression)
# The format string and the argument list are generated from this table, so the
# number of conversions always matches the number of arguments.
# ---------------------------------------------------------------------------
MAIN_FIELDS = [
    ('clock', '%.1f', 'now'),
    ('role', '%d', 'ctx.role or -1'),
    ('calls', '%d', 'p.calls'),
    ('seenE', '%d', 'p.seenE'),
    ('seenA', '%d', 'p.seenA'),
    ('gateE', '%d', 'p.gateE'),
    ('denyNo', '%d', 'p.denyNo'),
    ('stateE', '%d', 'p.stateE'),
    ('stateA', '%d', 'p.stateA'),
    ('farE', '%d', 'p.farE'),
    ('farA', '%d', 'p.farA'),
    ('chkE', '%d', 'p.chkE'),
    ('chkA', '%d', 'p.chkA'),
    ('passE', '%d', 'p.passE'),
    ('passA', '%d', 'p.passA'),
    ('noFlagE', '%d', 'p.noFlagE'),
    ('noFlagA', '%d', 'p.noFlagA'),
    ('noDelayE', '%d', 'p.noDelayE'),
    ('min0E', '%d', 'p.min0E'),
    ('evPosE', '%d', 'p.evPosE'),
    ('evPosA', '%d', 'p.evPosA'),
    ('ev0E', '%d', 'p.ev0E'),
    ('evN1E', '%d', 'p.evN1E'),
    ('evN2E', '%d', 'p.evN2E'),
    ('evN4pE', '%d', 'p.evN4pE'),
    ('srcAnimE', '%d', 'p.srcAnimE'),
    ('srcCycE', '%d', 'p.srcCycE'),
    ('srcPredE', '%d', 'p.srcPredE'),
    ('d350E', '%d', 'p.d350E'),
    ('d600E', '%d', 'p.d600E'),
    ('d900E', '%d', 'p.d900E'),
    ('d1300E', '%d', 'p.d1300E'),
    ('noFlagCloseE', '%d', 'p.noFlagCloseE'),
    ('passCloseE', '%d', 'p.passCloseE'),
    ('noFlagKillE', '%d', 'p.noFlagKillE'),
    ('candsE', '%d', 'p.candsE'),
    ('candsA', '%d', 'p.candsA'),
    ('chosenE', '%d', 'p.chosenE'),
    ('chosenA', '%d', 'p.chosenA'),
    ('nowinE', '%d', 'p.nowinE'),
    ('unsafeE', '%d', 'p.unsafeE'),
    ('norouteE', '%d', 'p.norouteE'),
    ('tickCall', '%d', 'p.tickCall'),
    ('tickChkE', '%d', 'p.tickChkE'),
    ('tickEvE', '%d', 'p.tickEvE'),
    ('tickPassE', '%d', 'p.tickPassE'),
    ('tickCandsE', '%d', 'p.tickCandsE'),
    ('tickChosenE', '%d', 'p.tickChosenE'),
    ('hurtE', '%d', 'p.hurtE'),
    ('hurtEHero', '%d', 'p.hurtEHero'),
    ('hurtEMatch', '%d', 'p.hurtEMatch'),
    ('hurtENo', '%d', 'p.hurtENo'),
    ('hurtENodetect', '%d', 'p.hurtENodetect'),
    ('hurtEMisattr', '%d', 'p.hurtEMisattr'),
    ('hurtAMatch', '%d', 'p.hurtAMatch'),
    ('hurtACyc', '%d', 'p.hurtACyc'),
]

# counters that live in the probe state and are zeroed after a successful write
RESET_NAMES = [name for name, _fmt, expr in MAIN_FIELDS if expr.startswith('p.')]

# markers asserted by --check: substring -> expected number of occurrences
MARKERS = {
    'ledg2Load': 3,          # definition + plan start + hurt
    'ledg2Log': 2,           # definition + plan end call
    'probe_ledger.log': 2,   # helper comment + ledg2Path literal
    '__q.chkE': 3,           # init? (see build) + increment + tick merge
    '__q.noFlagE': 2,        # per-call noFlag counter (init on one line, increment)
    'hurtEMatch': 7,         # state init + increment
    '[ledg2] begin': 1,
    '[ledg2] clock=%.1f': 1,
    '[ledg2 row]': 1,
    '[ledg2 hurt]': 1,
}
EXPECTED_BASE_LINES = 711


def md5_bytes(data):
    return hashlib.md5(data).hexdigest().upper()


def md5_file(path):
    with open(path, 'rb') as fh:
        return md5_bytes(fh.read())


def block(*rows):
    """Build a Lua block: each row is (indent_level, text); tabs indent."""
    return '\n'.join(('\t' * level) + text for level, text in rows) + '\n'


def lua_table_init_lines(indent, header, names, extras):
    """Return (indent, text) lines for a multi-line Lua table initializer."""
    TAB = chr(9)
    items = ['%s = 0' % name for name in names] + list(extras)
    lines = []
    current = header + '{'
    for item in items:
        piece = item + ', '
        if len((current + piece).expandtabs(4)) > 100 and current != header + '{':
            lines.append(current.rstrip())
            current = TAB + piece
        else:
            current += piece
    current = current.rstrip().rstrip(',')
    lines.append(current + '}')
    return [(indent, text) for text in lines]


def lua_multi_assign_lines(indent, names, per_line=8):
    lines = []
    for start in range(0, len(names), per_line):
        chunk = names[start:start + per_line]
        lhs = ', '.join('p.' + name for name in chunk)
        lines.append((indent, '%s = %s' % (lhs, ', '.join(['0'] * len(chunk)))))
    return lines


# Main line format string (Lua literal body) and string.format argument list.
_lua_fmt = '%s [ledg2] ' + ' '.join('%s=%s' % (name, conv) for name, conv, _ in MAIN_FIELDS) + '\\n'
_lua_args = ', '.join([expr for _n, _c, expr in MAIN_FIELDS])
_lua_args = 'prefix, ' + _lua_args

_HELPERS = block(
    (0, ''),
    (0, '-- ledg2 read-only ledger/noFlag probe (diagnostic build; remove before acceptance).'),
    (0, '-- Log: D:\\hake\\lotus\\probe_ledger.log. Role gate ctx.role >= 4; nil-safe io;'),
    (0, '-- the only ctx mutation is the probe state ctx.__ledg2 (never ctx.hits/ctx.role/etc).'),
    (0, '-- Main line keys (fixed order; parsed by tools\\ledger_probe_report.py, contract in'),
    (0, '-- the make_ledger_probe.py docstring): clock role calls seenE seenA gateE denyNo'),
    (0, '-- stateE stateA farE farA chkE chkA passE passA noFlagE noFlagA noDelayE min0E'),
    (0, '-- evPosE evPosA ev0E evN1E evN2E evN4pE srcAnimE srcCycE srcPredE d350E d600E'),
    (0, '-- d900E d1300E noFlagCloseE passCloseE noFlagKillE candsE candsA chosenE chosenA'),
    (0, '-- nowinE unsafeE norouteE tickCall tickChkE tickEvE tickPassE tickCandsE'),
    (0, '-- tickChosenE hurtE hurtEHero hurtEMatch hurtENo hurtENodetect hurtEMisattr'),
    (0, '-- hurtAMatch hurtACyc.'),
    (0, 'local ledg2Path = "D:\\\\hake\\\\lotus\\\\probe_ledger.log"'),
    (0, 'local ledg2Fmt = "%s"' % _lua_fmt),
    (0, ''),
    (0, 'local function ledg2Load(ctx)'),
    (1, 'if not ctx.role or ctx.role < 4 then return nil end'),
    (1, 'local p = ctx.__ledg2'),
    (1, 'if not p then'),
    *lua_table_init_lines(2, 'p = ', RESET_NAMES, ['at = -1', 'rows = {}', 'hurts = {}']),
    (2, 'ctx.__ledg2 = p'),
    (2, 'local f = io.open(ledg2Path, "a")'),
    (2, 'if f then'),
    (3, 'local ok = pcall(function()'),
    (4, 'f:write(string.format("%s [ledg2] begin role=%d\\n", os.date("%H:%M:%S"), ctx.role))'),
    (4, 'f:flush()'),
    (4, 'f:close()'),
    (3, 'end)'),
    (3, 'if not ok then pcall(function() f:close() end) end'),
    (2, 'end'),
    (1, 'end'),
    (1, 'return p'),
    (0, 'end'),
    (0, ''),
    (0, 'local function ledg2Log(ctx, p)'),
    (1, 'if not p then return end'),
    (1, 'local now = ctx.now or -1'),
    (1, 'if now < (p.at or -1) + 1.0 then return end'),
    (1, 'local f = io.open(ledg2Path, "a")'),
    (1, 'if not f then return end'),
    (1, 'local prefix = os.date("%H:%M:%S")'),
    (1, 'local ok = pcall(function()'),
    (2, 'f:write(string.format(ledg2Fmt, %s))' % _lua_args),
    (2, 'for i = 1, #p.rows do f:write(prefix .. " " .. p.rows[i] .. "\\n") end'),
    (2, 'for i = 1, #p.hurts do f:write(prefix .. " " .. p.hurts[i] .. "\\n") end'),
    (2, 'f:flush()'),
    (2, 'f:close()'),
    (1, 'end)'),
    (1, 'if not ok then pcall(function() f:close() end); return end'),
    (1, 'p.at = now'),
    *lua_multi_assign_lines(1, RESET_NAMES),
    (1, 'p.rows, p.hurts = {}, {}'),
    (0, 'end'),
)

# ---------------------------------------------------------------------------
# exact-once replacements against the CE33 base
# ---------------------------------------------------------------------------

# 1) helper block after local function live()
R_HELPERS_OLD = block(
    (0, 'local function live(unit)'),
    (1, 'return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)'),
    (0, 'end'),
)
R_HELPERS = R_HELPERS_OLD + _HELPERS

# 2) lastHit.plan start: state load + per-call counter table
R_PLAN_START_OLD = block(
    (0, 'function lastHit.plan(ctx)'),
    (1, 'if NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return false end'),
    (1, 'local attackReady = ctx.attackNext'),
)
R_PLAN_START_NEW = block(
    (0, 'function lastHit.plan(ctx)'),
    (1, 'if NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return false end'),
    (1, 'local __l2 = ledg2Load(ctx)'),
    (1, 'if __l2 then __l2.calls = __l2.calls + 1 end'),
    (1, 'local __q = __l2 and {chkE = 0, evPosE = 0, passE = 0, noFlagE = 0, candsE = 0, chosenE = 0}'),
    (1, 'local attackReady = ctx.attackNext'),
)

# 3) creep-loop guards (527-535): seen split, guard split, failure counters.
#    API evaluation order is preserved exactly: gate -> ATTACK_IMMUNE ->
#    INVULNERABLE -> ctx.distance (distance is still taken only when the state
#    checks passed, so no new per-creep API calls are added).
R_GUARD_OLD = block(
    (2, 'if live(creep) and NPC.IsVisible(creep) and not ctx.hits.blocked[Entity.GetIndex(creep)] then'),
    (3, 'local allied = Entity.IsSameTeam(ctx.hero, creep)'),
    (3, 'local denyable = allied and laneRules.denyable(ctx.clock, Entity.GetHealth(creep), Entity.GetMaxHealth(creep),'),
    (4, 'NPC.GetModifierProperty(creep, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT))'),
    (3, 'if (denyable or not allied and laneRules.canLastHit(ctx, creep))'),
    (4, 'and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)'),
    (4, 'and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)'),
    (4, 'and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < math.max(cfg.searchRange, range + 500) then'),
)
R_GUARD_NEW = block(
    (2, 'if live(creep) and NPC.IsVisible(creep) and not ctx.hits.blocked[Entity.GetIndex(creep)] then'),
    (3, 'local allied = Entity.IsSameTeam(ctx.hero, creep)'),
    (3, 'if __l2 then'),
    (4, 'if allied then __l2.seenA = __l2.seenA + 1 else __l2.seenE = __l2.seenE + 1 end'),
    (3, 'end'),
    (3, 'local denyable = allied and laneRules.denyable(ctx.clock, Entity.GetHealth(creep), Entity.GetMaxHealth(creep),'),
    (4, 'NPC.GetModifierProperty(creep, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT))'),
    (3, 'local __gateOk = denyable or not allied and laneRules.canLastHit(ctx, creep)'),
    (3, 'local __stateOk, __dist, __rangeOk = false, nil, false'),
    (3, 'if __gateOk then'),
    (4, '__stateOk = not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)'),
    (5, 'and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)'),
    (4, 'if __stateOk then'),
    (5, '__dist = ctx.distance(ctx.position, Entity.GetAbsOrigin(creep))'),
    (5, '__rangeOk = __dist < math.max(cfg.searchRange, range + 500)'),
    (4, 'end'),
    (3, 'end'),
    (3, 'if __l2 and not (__gateOk and __stateOk and __rangeOk) then'),
    (4, 'if not __gateOk then'),
    (5, 'if allied then __l2.denyNo = __l2.denyNo + 1 else __l2.gateE = __l2.gateE + 1 end'),
    (4, 'elseif not __stateOk then'),
    (5, 'if allied then __l2.stateA = __l2.stateA + 1 else __l2.stateE = __l2.stateE + 1 end'),
    (4, 'else'),
    (5, 'if allied then __l2.farA = __l2.farA + 1 else __l2.farE = __l2.farE + 1 end'),
    (4, 'end'),
    (3, 'end'),
    (3, 'if __gateOk and __stateOk and __rangeOk then'),
)

# 4) maturity block (539-540): exact same condition, plus counters.
R_MATURITY_OLD = block(
    (4, 'local delay, windup = lastHit.timing(ctx, creep)'),
    (4, 'if delay and minimum > 0 and (health < minimum * 2 or #events > 0) then'),
)
R_MATURITY_NEW = block(
    (4, 'local delay, windup = lastHit.timing(ctx, creep)'),
    (4, 'local __ev = #events'),
    (4, 'local __flag = delay and minimum > 0 and (health < minimum * 2 or __ev > 0)'),
    (4, 'if __l2 then'),
    (5, 'if allied then'),
    (6, '__l2.chkA = __l2.chkA + 1'),
    (6, 'if __ev > 0 then __l2.evPosA = __l2.evPosA + 1 end'),
    (6, 'if __flag then __l2.passA = __l2.passA + 1'),
    (6, 'elseif delay and minimum > 0 and __ev == 0 and health >= minimum * 2 then __l2.noFlagA = __l2.noFlagA + 1 end'),
    (5, 'else'),
    (6, '__l2.chkE = __l2.chkE + 1'),
    (6, '__q.chkE = __q.chkE + 1'),
    (6, 'if __ev > 0 then __l2.evPosE = __l2.evPosE + 1; __q.evPosE = __q.evPosE + 1 end'),
    (6, 'for _, __evt in ipairs(events) do'),
    (7, 'if __evt.predicted then __l2.srcPredE = __l2.srcPredE + 1'),
    (7, 'elseif __evt.release then __l2.srcAnimE = __l2.srcAnimE + 1'),
    (7, 'else __l2.srcCycE = __l2.srcCycE + 1 end'),
    (6, 'end'),
    (6, 'if __ev == 1 then __l2.evN1E = __l2.evN1E + 1'),
    (6, 'elseif __ev == 2 or __ev == 3 then __l2.evN2E = __l2.evN2E + 1'),
    (6, 'elseif __ev >= 4 then __l2.evN4pE = __l2.evN4pE + 1'),
    (6, 'else __l2.ev0E = __l2.ev0E + 1 end'),
    (6, 'local __d = __dist or 1300'),
    (6, 'if __d < 350 then __l2.d350E = __l2.d350E + 1'),
    (6, 'elseif __d < 600 then __l2.d600E = __l2.d600E + 1'),
    (6, 'elseif __d < 900 then __l2.d900E = __l2.d900E + 1'),
    (6, 'else __l2.d1300E = __l2.d1300E + 1 end'),
    (6, 'if not delay then __l2.noDelayE = __l2.noDelayE + 1'),
    (6, 'elseif minimum <= 0 then __l2.min0E = __l2.min0E + 1'),
    (6, 'elseif __ev > 0 or health < minimum * 2 then'),
    (7, '__l2.passE = __l2.passE + 1'),
    (7, '__q.passE = __q.passE + 1'),
    (7, 'if __d < 600 then __l2.passCloseE = __l2.passCloseE + 1 end'),
    (6, 'else'),
    (7, '__l2.noFlagE = __l2.noFlagE + 1'),
    (7, '__q.noFlagE = __q.noFlagE + 1'),
    (7, 'if __d < 600 then __l2.noFlagCloseE = __l2.noFlagCloseE + 1 end'),
    (7, 'if health < minimum * 4 then __l2.noFlagKillE = __l2.noFlagKillE + 1 end'),
    (7, 'if __d < 600 and #__l2.rows < 3 then'),
    (8, 'local __name = "?"'),
    (8, 'if creep then __name = NPC.GetUnitName(creep) or "?" end'),
    (8, '__l2.rows[#__l2.rows + 1] = string.format("[ledg2 row] clock=%.1f creep=%s hp=%d min=%d max=%d ev=%d dist=%.0f",'),
    (9, 'ctx.now or -1, __name, health, minimum, maximum, __ev, __d)'),
    (7, 'end'),
    (6, 'end'),
    (5, 'end'),
    (4, 'end'),
    (4, 'if __flag then'),
)

# 5) route() returned nil for an out-of-range candidate
R_ROUTE_OLD = block(
    (7, 'impact, wait = window(ctx, candidate, earliest)'),
    (6, 'else impact = nil end'),
)
R_ROUTE_NEW = block(
    (7, 'impact, wait = window(ctx, candidate, earliest)'),
    (6, 'else'),
    (7, '-- ledg2: route() returned nil for this out-of-range enemy candidate; it may'),
    (7, '-- overlap nowinE (the same candidate is counted again at the final gate).'),
    (7, 'impact = nil'),
    (7, 'if __l2 and not allied then __l2.norouteE = __l2.norouteE + 1 end'),
    (6, 'end'),
)

# 6) candidate appended + final farmSafe-gate rejects (nowinE/unsafeE)
R_ACCEPT_OLD = block(
    (6, 'candidates[#candidates + 1] = candidate'),
    (5, 'end'),
)
R_ACCEPT_NEW = block(
    (6, 'candidates[#candidates + 1] = candidate'),
    (6, 'if __l2 then'),
    (7, 'if allied then __l2.candsA = __l2.candsA + 1'),
    (7, 'else __l2.candsE, __q.candsE = __l2.candsE + 1, __q.candsE + 1 end'),
    (6, 'end'),
    (5, 'elseif __l2 and not allied then'),
    (6, 'if impact then __l2.unsafeE = __l2.unsafeE + 1'),
    (6, 'else __l2.nowinE = __l2.nowinE + 1 end'),
    (5, 'end'),
)

# 7) plan end: chosen + tick counters + probe log write
R_PLAN_END_OLD = block(
    (1, 'if map then GridNav.ReleaseNpcMap(map) end'),
    (1, 'ctx.hits.candidateCount = #candidates'),
    (1, 'local best = timeline.choose(candidates, ctx.now, NPC.GetSecondsPerAttack(ctx.hero, false), speed)'),
    (1, 'if not best then ctx.hits.focus = nil; return false end'),
)
R_PLAN_END_NEW = block(
    (1, 'if map then GridNav.ReleaseNpcMap(map) end'),
    (1, 'ctx.hits.candidateCount = #candidates'),
    (1, 'local best = timeline.choose(candidates, ctx.now, NPC.GetSecondsPerAttack(ctx.hero, false), speed)'),
    (1, 'if __l2 then'),
    (2, 'if best then'),
    (3, 'if best.allied then __l2.chosenA = __l2.chosenA + 1'),
    (3, 'else __l2.chosenE, __q.chosenE = __l2.chosenE + 1, __q.chosenE + 1 end'),
    (2, 'end'),
    (2, '__l2.tickCall = __l2.tickCall + 1'),
    (2, 'if __q.chkE > 0 then __l2.tickChkE = __l2.tickChkE + 1 end'),
    (2, 'if __q.evPosE > 0 then __l2.tickEvE = __l2.tickEvE + 1 end'),
    (2, 'if __q.passE > 0 then __l2.tickPassE = __l2.tickPassE + 1 end'),
    (2, 'if __q.candsE > 0 then __l2.tickCandsE = __l2.tickCandsE + 1 end'),
    (2, 'if __q.chosenE > 0 then __l2.tickChosenE = __l2.tickChosenE + 1 end'),
    (2, 'ledg2Log(ctx, __l2)'),
    (1, 'end'),
    (1, 'if not best then ctx.hits.focus = nil; return false end'),
)

# 8) lastHit.hurt: impact-time coverage, counted BEFORE "if not matched then return end"
R_HURT_OLD = block(
    (1, 'local now, matched, closest = GameRules.GetGameTime(), nil, 0.35'),
    (1, 'for key, event in pairs(ctx.hits.events) do'),
    (2, 'local difference = math.abs(event.impact - now)'),
    (2, 'if event.source == data.source and event.target == data.target and difference < closest then matched, closest = key, difference end'),
    (1, 'end'),
    (1, 'if not matched then return end'),
)
R_HURT_NEW = block(
    (1, 'local now, matched, closest = GameRules.GetGameTime(), nil, 0.35'),
    (1, 'for key, event in pairs(ctx.hits.events) do'),
    (2, 'local difference = math.abs(event.impact - now)'),
    (2, 'if event.source == data.source and event.target == data.target and difference < closest then matched, closest = key, difference end'),
    (1, 'end'),
    (1, '-- ledg2: hurt coverage (before the matched early-return; behaviour unchanged).'),
    (1, 'local __l2h = ledg2Load(ctx)'),
    (1, 'if __l2h then'),
    (2, 'local __hreach = data.target and Entity.IsEntity(data.target) and Entity.IsNPC(data.target) and NPC.IsLaneCreep(data.target)'),
    (3, 'and data.source and Entity.IsEntity(data.source) and data.damage > 0 and not data.ability'),
    (2, 'if __hreach and ctx.distance(ctx.position, Entity.GetAbsOrigin(data.target)) <= 2500 then'),
    (3, 'if not Entity.IsSameTeam(ctx.hero, data.target) then'),
    (4, '__l2h.hurtE = __l2h.hurtE + 1'),
    (4, 'if data.source == ctx.hero then __l2h.hurtEHero = __l2h.hurtEHero + 1'),
    (4, 'elseif matched then __l2h.hurtEMatch = __l2h.hurtEMatch + 1'),
    (4, 'else'),
    (5, '__l2h.hurtENo = __l2h.hurtENo + 1'),
    (5, 'local __srcEv, __srcTgt = 0, 0'),
    (5, 'for __k, __e in pairs(ctx.hits.events) do'),
    (6, 'if __e.source == data.source then'),
    (7, '__srcEv = __srcEv + 1'),
    (7, 'if __e.target == data.target then __srcTgt = __srcTgt + 1 end'),
    (6, 'end'),
    (5, 'end'),
    (5, 'if __srcEv == 0 then __l2h.hurtENodetect = __l2h.hurtENodetect + 1'),
    (5, 'elseif __srcTgt == 0 then __l2h.hurtEMisattr = __l2h.hurtEMisattr + 1 end'),
    (5, 'if #__l2h.hurts < 3 then'),
    (6, 'local __sname, __tname = "?", "?"'),
    (6, 'if data.source then __sname = NPC.GetUnitName(data.source) or "?" end'),
    (6, 'if data.target then __tname = NPC.GetUnitName(data.target) or "?" end'),
    (6, 'local __cyc = 0'),
    (6, 'if ctx.hits.cycles[Entity.GetIndex(data.source)] then __cyc = 1 end'),
    (6, '__l2h.hurts[#__l2h.hurts + 1] = string.format("[ledg2 hurt] clock=%.1f target=%s source=%s dmg=%d srcEv=%d srcEvTgt=%d cyc=%d",'),
    (7, 'ctx.now or -1, __tname, __sname, data.damage, __srcEv, __srcTgt, __cyc)'),
    (5, 'end'),
    (4, 'end'),
    (3, 'else'),
    (4, 'if matched then __l2h.hurtAMatch = __l2h.hurtAMatch + 1 end'),
    (4, 'if ctx.hits.cycles[Entity.GetIndex(data.source)] then __l2h.hurtACyc = __l2h.hurtACyc + 1 end'),
    (3, 'end'),
    (2, 'end'),
    (1, 'end'),
    (1, 'if not matched then return end'),
)

REPLACEMENTS = [
    ('helpers', R_HELPERS, R_HELPERS_OLD),
    ('plan_start', R_PLAN_START_NEW, R_PLAN_START_OLD),
    ('guards', R_GUARD_NEW, R_GUARD_OLD),
    ('maturity', R_MATURITY_NEW, R_MATURITY_OLD),
    ('route_nil', R_ROUTE_NEW, R_ROUTE_OLD),
    ('candidate', R_ACCEPT_NEW, R_ACCEPT_OLD),
    ('plan_end', R_PLAN_END_NEW, R_PLAN_END_OLD),
    ('hurt', R_HURT_NEW, R_HURT_OLD),
]


class ProbeBuildError(RuntimeError):
    pass


def read_base():
    if not os.path.isfile(BASE):
        raise ProbeBuildError('base file missing: %s' % BASE)
    try:
        raw = open(BASE, 'rb').read()
    except OSError as exc:
        raise ProbeBuildError('cannot read base: %s' % exc)
    actual = md5_bytes(raw)
    if actual != BASE_MD5:
        raise ProbeBuildError('base hash mismatch: %s (expected %s)\n  file: %s'
                              % (actual, BASE_MD5, BASE))
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError as exc:
        raise ProbeBuildError('base is not valid UTF-8: %s' % exc)
    if '\r' in text:
        text = text.replace('\r\n', '\n').replace('\r', '\n')
    if text.count('\n') != EXPECTED_BASE_LINES:
        raise ProbeBuildError('base line count changed: %d (expected %d)'
                              % (text.count('\n'), EXPECTED_BASE_LINES))
    if not text.endswith('\n'):
        text += '\n'
    return text


def _context(text, anchor):
    """Short human-readable context around where an anchor should have matched."""
    head = anchor.split('\n', 1)[0]
    pos = text.find(head)
    if pos < 0:
        return 'first anchor line not found: %r' % head[:100]
    start = max(0, pos - 120)
    stop = min(len(text), pos + len(anchor) + 120)
    return 'nearest context:\n%s\n%s\n%s' % ('-' * 60, text[start:stop], '-' * 60)


def apply_replacements(text):
    out = text
    stats = []
    for label, new, old in REPLACEMENTS:
        count = out.count(old)
        if count != 1:
            raise ProbeBuildError(
                'replacement %r matched %d times (expected exactly 1)\n%s'
                % (label, count, _context(out, old)))
        out = out.replace(old, new, 1)
        delta = new.count('\n') - old.count('\n')
        stats.append((label, delta))
    return out, stats


def build():
    base = read_base()
    out, stats = apply_replacements(base)
    inserted = sum(delta for _label, delta in stats)
    expected_lines = base.count('\n') + inserted
    if out.count('\n') != expected_lines:
        raise ProbeBuildError('line-count check failed: %d produced, %d expected '
                              '(base %d + inserted %d)'
                              % (out.count('\n'), expected_lines, base.count('\n'), inserted))
    return base, out, stats


def marker_counts(text):
    return {marker: text.count(marker) for marker in MARKERS}


def check_markers(text):
    counts = marker_counts(text)
    bad = []
    for marker, expected in MARKERS.items():
        actual = counts[marker]
        if actual != expected:
            bad.append('%r: %d (expected %d)' % (marker, actual, expected))
    if bad:
        raise ProbeBuildError('marker check failed:\n  ' + '\n  '.join(bad))
    return counts


def check_roundtrip(base, out):
    current = out
    for label, new, old in reversed(REPLACEMENTS):
        count = current.count(new)
        if count != 1:
            raise ProbeBuildError('round-trip: replacement %r new-block matched %d '
                                  'times (expected 1)' % (label, count))
        current = current.replace(new, old, 1)
    if current != base:
        raise ProbeBuildError('round-trip mismatch: reversing the insertions did not '
                              'reproduce the base content (line endings are normalized to LF)')
    return True


def luajit_compile(text):
    if not os.path.isfile(LUAJIT):
        raise ProbeBuildError('luajit not found: %s' % LUAJIT)
    fd, tmp = tempfile.mkstemp(prefix='ledger_probe_', suffix='.lua')
    os.close(fd)
    try:
        with open(tmp, 'wb') as fh:
            fh.write(text.encode('utf-8'))
        script = ('local f,e=loadfile([[%s]]); '
                  'if not f then print(e); os.exit(1) end' % tmp)
        proc = subprocess.run([LUAJIT, '-e', script],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True)
        if proc.returncode != 0:
            raise ProbeBuildError('luajit loadfile compile failed (exit %d):\n%s%s'
                                  % (proc.returncode, proc.stdout, proc.stderr))
        return (proc.stdout + proc.stderr).strip()
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass


def write_output(path, text):
    directory = os.path.dirname(path)
    if directory and not os.path.isdir(directory):
        os.makedirs(directory)
    data = text.encode('utf-8')
    with open(path, 'wb') as fh:
        fh.write(data)
    return len(data)


def fmt_stats(stats):
    return ', '.join('%s:+%d' % (label, delta) for label, delta in stats)


def print_stats(base, out, stats, markers):
    print('  base lines      : %d' % base.count('\n'))
    print('  output lines    : %d' % out.count('\n'))
    print('  inserted lines  : +%d' % sum(delta for _label, delta in stats))
    print('  per-block       : %s' % fmt_stats(stats))
    print('  output bytes    : %d' % len(out.encode('utf-8')))
    print('  marker counts   :')
    for marker in MARKERS:
        print('    %-24s %d' % (marker, markers[marker]))


def main(argv=None):
    parser = argparse.ArgumentParser(
        description='Generate the read-only [ledg2] last_hit.lua probe build '
                    '(deterministic; exact-once replacements).')
    parser.add_argument('--check', action='store_true',
                        help='build in memory, assert markers/line math, compile '
                             'with luajit loadfile; writes no artifacts')
    parser.add_argument('--print-stats', action='store_true',
                        help='print per-block line deltas, bytes and marker counts')
    parser.add_argument('--out', metavar='PATH',
                        help='write the build to PATH instead of %s (tests)' % OUT)
    args = parser.parse_args(argv)

    try:
        base, out, stats = build()
        markers = check_markers(out)
        check_roundtrip(base, out)
        out_md5 = md5_bytes(out.encode('utf-8'))

        if args.check:
            luajit_out = luajit_compile(out)
            print('PASS make_ledger_probe --check')
            print('  base            : %s (md5 %s, %d lines)' % (BASE, BASE_MD5, base.count('\n')))
            print('  output md5      : %s (%d bytes, +%d lines)'
                  % (out_md5, len(out.encode('utf-8')), sum(delta for _l, delta in stats)))
            print('  exact-once      : %d/%d replacements matched exactly once'
                  % (len(REPLACEMENTS), len(REPLACEMENTS)))
            print('  markers         : OK')
            print('  round-trip      : OK (insertions reverse to the base content, EOL normalized to LF)')
            print('  luajit loadfile : OK (exit 0)%s'
                  % ((' - ' + luajit_out) if luajit_out else ''))
            if args.print_stats:
                print_stats(base, out, stats, markers)
            return 0

        target = args.out or OUT
        written = write_output(target, out)
        print('make_ledger_probe: wrote %s' % target)
        print('  source md5      : %s (%s)' % (md5_file(BASE), BASE))
        print('  output md5      : %s' % out_md5)
        print('  bytes           : %d' % written)
        print('  line delta      : base %d -> output %d (+%d)'
              % (base.count('\n'), out.count('\n'), sum(delta for _l, delta in stats)))
        if args.print_stats:
            print_stats(base, out, stats, markers)
        return 0
    except ProbeBuildError as exc:
        print('FAIL make_ledger_probe: %s' % exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())