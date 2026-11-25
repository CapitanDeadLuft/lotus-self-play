#!/usr/bin/env python3
# Analyze self_play.log: split runs by clock resets and report per-run metrics.
import re, sys, collections

path = sys.argv[1] if len(sys.argv) > 1 else r'D:\hake\lotus\self_play.log'
lines = open(path, encoding='utf-8', errors='replace').read().splitlines()

# parse clock from most lines (minute:second prefix = match clock OR wall time?)
# Format: "[11:25] ..." is match clock mm:ss. A new match starts near -0:01/0:00.
runs = []
cur = []
prev = None
for i, l in enumerate(lines):
    m = re.match(r'\[(-?\d+):(\d+)\]', l)
    if not m:
        cur.append((i, l, None))
        continue
    t = int(m.group(1)) * 60 + int(m.group(2))
    if prev is not None and t < prev - 30:  # clock reset -> new run
        runs.append(cur)
        cur = []
    cur.append((i, l, t))
    prev = t
runs.append(cur)
print(f'total lines {len(lines)}, runs {len(runs)}')
print('run sizes:', [len(r) for r in runs])

for ri, run in enumerate(runs):
    if not run:
        continue
    clock_lines = [t for (_, _, t) in run if t is not None]
    if not clock_lines:
        continue
    print(f'\n=== RUN {ri}: {len(run)} lines, clock {min(clock_lines)}..{max(clock_lines)} ===')
    scores = [l for (_, l, t) in run if '[SelfPlay score]' in l]
    for l in scores:
        m = re.search(r'\[(-?\d+):(\d+)\].*clock=([\d.]+).*lastHits=(\d+) denies=(\d+).*xp=(\d+)', l)
        if m:
            print('  score', f"{int(m.group(1))}:{int(m.group(2))}", 'clock', m.group(3), 'lh', m.group(4), 'hd', m.group(5), 'xp', m.group(6))
    stats = [l for (_, l, t) in run if 'last hit stats' in l]
    for l in stats:
        print('  lhstats', l)
    preds = [l for (_, l, t) in run if '[SelfPlay prediction]' in l]
    vz = [int(m.group(1)) for l in preds for m in [re.search(r'addedHits=(\d+)', l)] if m]
    if vz:
        print(f'  prediction lines={len(vz)} addedHits>0={sum(1 for v in vz if v>0)} ({100*sum(1 for v in vz if v>0)/len(vz):.0f}%) sum={sum(vz)}')
    modes = collections.Counter()
    for (_, l, t) in run:
        m = re.search(r'\[SelfPlay\] role=.*?mode=([^ ]+)', l)
        if m:
            modes[m.group(1)] += 1
    print('  modes', modes.most_common(12))
    orders = collections.Counter()
    for (_, l, t) in run:
        m = re.search(r'order=([a-z]+)', l)
        if m:
            orders[m.group(1)] += 1
    print('  orders', orders.most_common(8))