#!/usr/bin/env python3
# auto_run_stats.py - measure the auto role/lane (widgets 0) run of 2026-11-23.
# Reads:
#   D:\hake\lotus\self_play.log        (last session = this run)
#   D:\hake\lotus\probe.log            (probe2 ledger windows)
#   D:\hake\lotus\host.log             ([roster], [laneprobe], widget load lines, clock anchor)
#   C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log (reference sessions S1 and S26)
import re, sys, collections

HOST = r'D:\hake\lotus\host.log'
PROBE = r'D:\hake\lotus\probe.log'
SP = r'D:\hake\lotus\self_play.log'
REF = r'C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log'

STAMP = re.compile(r'^\[(-?\d+):(\d+)\]')
SESS = re.compile(r'^===== Self Play session (.+) =====')


def stamp_clock(line):
    m = STAMP.match(line)
    return int(m.group(1)) * 60 + int(m.group(2)) if m else None


def sessions(path):
    out, cur = [], None
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = SESS.match(line.rstrip('\n'))
            if m:
                cur = {'name': m.group(1).strip(), 'lines': []}
                out.append(cur)
            elif cur is not None:
                cur['lines'].append(line.rstrip('\n'))
    return out


def selfplay_stats(lines):
    res = {'score': [], 'lane_switch': [], 'actions': [], 'last_hit': [], 'mode': []}
    for l in lines:
        c = stamp_clock(l)
        if '[SelfPlay score]' in l:
            m = re.search(r'clock=([-\d.]+).*?role=(\d+) lane=(\d+) lastHits=(\d+) denies=(\d+)', l)
            if m:
                res['score'].append((float(m.group(1)), int(m.group(2)), int(m.group(3)),
                                     int(m.group(4)), int(m.group(5))))
        if '[SelfPlay lane]' in l:
            res['lane_switch'].append((c, l.strip()))
        if '[SelfPlay actions]' in l:
            m = re.search(r'candidates=(\d+)', l)
            if m and c is not None:
                res['actions'].append((c, int(m.group(1))))
        if '[SelfPlay last hit]' in l:
            res['last_hit'].append((c, l.strip()))
        if '[SelfPlay] role=' in l:
            m = re.search(r'\[SelfPlay\] role=(\d+) lane=(\d+) mode=([^h]*?) hp=', l)
            if m:
                res['mode'].append((c, int(m.group(1)), int(m.group(2)), m.group(3).strip()))
    return res


def action_ratio(actions, lo, hi):
    xs = [v for c, v in actions if c is not None and lo <= c <= hi]
    return sum(1 for v in xs if v > 0), len(xs)


def ledger_stats(since):
    rows = []
    with open(PROBE, encoding='utf-8', errors='replace') as f:
        for line in f:
            if not line.startswith(' '):  # only main ledger lines carry the timestamp
                if line[:8] < since:
                    continue
            if '[ledger]' not in line:
                continue
            pairs = dict(re.findall(r'(\w+)=(-?\d+)', line))
            if 'clock' not in pairs:
                continue
            rows.append({k: int(v) for k, v in pairs.items()})
    return rows


def sums(rows, keys, lo, hi):
    tot = collections.Counter()
    n = 0
    for r in rows:
        c = r.get('clock', -1)
        if lo <= c < hi:
            n += 1
            for k in keys:
                tot[k] += r.get(k, 0)
    return n, tot


def main():
    since = sys.argv[1] if len(sys.argv) > 1 else '00:56:00'
    hint = sys.argv[2] if len(sys.argv) > 2 else None
    print('== since =', since, 'session hint =', hint)
    sess = sessions(SP)
    if hint:
        sess = [s for s in sess if hint in s['name']]
    cur = sess[-1]
    print('== our run: last self_play session =', cur['name'], 'lines', len(cur['lines']))
    sp = selfplay_stats(cur['lines'])

    print('\n-- [SelfPlay score] lines (clock, role, lane, lh, dn):')
    for row in sp['score']:
        print('  ', row)
    lh300 = [r for r in sp['score'] if r[0] <= 300]
    print('  LH at 5:00 (last score <=300):', lh300[-1] if lh300 else None)
    print('  LH at first score >=300:', next((r for r in sp['score'] if r[0] >= 300), None))

    print('\n-- [SelfPlay lane] switch lines:')
    for c, l in sp['lane_switch']:
        print('  ', c, l)
    if not sp['lane_switch']:
        print('   none')

    print('\n-- [SelfPlay actions] candidates (0..300 / 0..360):')
    for hi in (300, 360):
        pos, n = action_ratio(sp['actions'], 0, hi)
        print(f'  0..{hi}: cand>0 {pos}/{n} = {100.0*pos/n:.1f}%' if n else '  n/a')
    print('  per-minute cand>0:', end='')
    for m in range(6):
        pos, n = action_ratio(sp['actions'], m * 60, (m + 1) * 60)
        print('  %d: %d/%d' % (m, pos, n), end='')
    print()
    print('  last_hit lines 0..300:', sum(1 for c, _ in sp['last_hit'] if c is not None and 0 <= c <= 300))

    print('\n-- mode/lane/role lines (first/last, changes only):')
    prev = None
    for c, role, lane, mode in sp['mode']:
        key = (role, lane, mode)
        if key != prev:
            print(f'   [{c//60}:{c%60:02d}] role={role} lane={lane} mode={mode}')
            prev = key

    # host.log: anchor + roster + laneprobe + [lh5] (only lines of this run)
    host = open(HOST, encoding='utf-8', errors='replace').read().splitlines()
    anchor = None
    roster, laneprobe, lh5 = [], [], []
    for l in host:
        if not re.match(r'^\d\d:\d\d:\d\d ', l) or l[:8] < since:
            continue
        m = re.search(r'observed state transition <4 -> 5 at gs=([0-9.]+)', l)
        if not m:
            m = re.search(r'observed m_flGameStartTime transition -> ([0-9.]+)', l)
        if m:
            anchor = float(m.group(1))
        if '[roster]' in l:
            roster.append(l)
        if '[laneprobe]' in l:
            laneprobe.append(l)
        if '[lh5]' in l:
            lh5.append(l)
    print('\n== game start anchor gs =', anchor)
    print('\n-- [lh5] exact-clock score reads:')
    for l in lh5:
        print('  ', l)
    print('\n-- [roster] (all 5 team heroes, auto run):')
    for l in roster:
        print('  ', l)
    print('\n-- [laneprobe] last 8:')
    for l in laneprobe[-8:]:
        print('  ', l)
    if laneprobe:
        print('  (initial lane switch data: changes/lastChange in lines above)')

    rows = ledger_stats(since)
    if anchor:
        print('\n== probe ledger by game minute (gs=%.3f)' % anchor)
        keys = ['calls', 'seen', 'chk', 'gate', 'denyNo', 'far', 'cands', 'chosen']
        for m in range(5):
            n, tot = sums(rows, keys, anchor + m * 60, anchor + (m + 1) * 60)
            print('  min %d: windows=%3d ' % (m, n) + ' '.join('%s=%d' % (k, tot[k]) for k in keys))
        n, tot = sums(rows, keys, anchor, anchor + 300)
        print('  total 0..300: windows=%d ' % n + ' '.join('%s=%d' % (k, tot[k]) for k in keys))
        # ledger windows with cands>0 in 0..300
        w = [r for r in rows if anchor <= r.get('clock', -1) < anchor + 300]
        print('  ledger windows cands>0: %d/%d' % (sum(1 for r in w if r.get('cands', 0) > 0), len(w)))
        # chk vs gate ratio in 0..300
        if tot['chk']:
            print('  gate/chk = %.2f' % (tot['gate'] / tot['chk']))

    # ---- reference baselines, same methodology ----
    print('\n===== reference baselines (self_play.prev.log) =====')
    rl = open(REF, encoding='utf-8', errors='replace').readlines()

    def ref_session(name_hint):
        idx = [i for i, l in enumerate(rl) if l.strip().startswith('===== Self Play session') and name_hint in l]
        if not idx:
            return None
        a = idx[-1]
        b = next((i for i in range(a + 1, len(rl)) if rl[i].startswith('=====')), len(rl))
        return [l.rstrip('\n') for l in rl[a:b]]

    for label, hint in (('S26', '2026-11-17 01:04:57'), ('S1', '2026-11-16 03:12:52')):
        lines = ref_session(hint)
        if lines is None:
            print(label, 'session not found')
            continue
        sp = selfplay_stats(lines)
        print('\n--', label, 'session lines', len(lines))
        pos, n = action_ratio(sp['actions'], 0, 300)
        print('   actions 0..300: cand>0 %d/%d = %.1f%%' % (pos, n, 100.0 * pos / n if n else 0))
        print('   score lines <=330:', [r for r in sp['score'] if r[0] <= 330])
        print('   lane switches <=360:', [(c, l) for c, l in sp['lane_switch'] if c is None or c <= 360])
        print('   last_hit lines 0..300:', sum(1 for c, _ in sp['last_hit'] if c is not None and 0 <= c <= 300))


if __name__ == '__main__':
    main()