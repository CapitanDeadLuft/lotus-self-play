"""AI-13: strip temporary instrumentation from src/bot_loop_run.lua.

Keeps the functional parts (menu widget enforcement + auto Role/Lane = 0) and
removes:
  1. tpack/tunpack timing-wrapper helpers (only used by the wrappers below),
  2. _G.__CTXDUMP/_G.__APITIME + API timing wrappers,
  3. _G.__ROUTEDBG + entity iter counter,
  4. perf instrumentation (wraps every self_play module function / callbacks),
  5. [roster]/[laneprobe] probe setup block,
  6. per-tick "loop" heartbeat, [armor]/[kv]/[support]/[aspd]/[pregame]/[roster]/
     [laneprobe]/[lh5] probe blocks, one-shot LANE dump.

Anchors are literal substrings; the script fails loudly if an anchor is missing.
"""
import io
import sys

path = sys.argv[1]
with io.open(path, "r", encoding="utf-8", newline="") as fh:
    lines = fh.read().split("\n")


def find(sub, start=0):
    for i in range(start, len(lines)):
        if sub in lines[i]:
            return i
    raise SystemExit("anchor not found: %r" % sub)


def cut(start_sub, end_sub):
    i0 = find(start_sub)
    i1 = find(end_sub, i0 + 1)
    del lines[i0:i1]
    return i0, i1


# 1) timing-wrapper helper comment + tpack/tunpack definitions
cut("-- Return-count-safe timing wrappers", "local script, err = loader.load()")
# 2) CTXDUMP/APITIME/ROUTEDBG/perf instrumentation blocks
cut("_G.__CTXDUMP = true", "if not script then")
# 3) [roster]/[laneprobe] probe setup block
cut("-- [roster]/[laneprobe] temporary probes", 'local overlay = require("overlay")')
# 4) loop heartbeat + all per-tick probes + one-shot LANE dump
cut("local h = entity.getLocalHero()", "for _ = 1, 4 do pcall(overlay.pump)")

with io.open(path, "w", encoding="utf-8", newline="") as fh:
    fh.write("\n".join(lines))
print("OK lines=%d" % len(lines))