#!/usr/bin/env python3
# acceptance_stats.py - AI-13 acceptance measurement (clean instrumentation).
#
# Reads:
#   D:\hake\lotus\self_play.log        - last Self Play session (acceptance run)
#   D:\hake\lotus\host.log             - runner/loader evidence (widgets, BOT LOOP, clock anchor)
#   C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log - reference sessions S26/S1
# Reference checkpoints (max over original Treant role4 sessions) are embedded from
# REFERENCE_BEHAVIOR.md, which was extracted from the original Umbrella self_play.log.
import re
import sys
import collections

SP = r'D:\hake\lotus\self_play.log'
HOST = r'D:\hake\lotus\host.log'
REF = r'C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log'

# REFERENCE_BEHAVIOR.md, "Контрольные точки": minute -> (lastHits, XP, heroDamage)
REF_CKPT = {1: (4, 354, 483), 2: (4, 1068, 731), 3: (6, 1579, 1004), 4: (6, 1884, 1228),
            5: (6, 2882, 1533), 6: (8, 3937, 1954), 8: (9, 6700, 2024), 10: (12, 10878, 2689)}

STAMP = re.compile(r'^\[(-?\d+):(\d+)\]')
SESS = re.compile(r'^===== Self Play session (.+) =====')
RE_SCORE = re.compile(r'clock=([-\d.]+) hero=(\w+) role=(\d+) lane=(\d+) lastHits=(\d+) denies=(\d+)'
                      r' networth=(\d+) gold=(\d+) xp=(\d+) heroDamage=(\d+)')
RE_MODE = re.compile(r'\[SelfPlay\] role=(\d+) lane=(\d+) mode=(.+?) hp=.*?attacks=(\d+) cancelled=(\d+)'
                     r'.*?cast=([^\s]*) provider=\S+ order=(\w+)')
RE_ACT = re.compile(r'\[SelfPlay actions\] time=([\d.]+) target=(\S+) lock=(\S+) creepAggro=(\d+) candidates=(\d+)')
RE_DECIDE = re.compile(r'\[SelfPlay decide\] ran=(\w+)')


def stamp_clock(line):
    m = STAMP.match(line)
    return int(m.group(1)) * 60 + int(m.group(2)) if m else None


def sessions(path):
    out, cur = [], None
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            m = SESS.match(line.rstrip('\n'))
            if m:
                cur = {'name': m.group(1).strip(), 'lines': []}
                out.append(cur)
            elif cur is not None:
                cur['lines'].append(line.rstrip('\n'))
    return out


def parse(lines):
    d = {'score': [], 'modes': [], 'actions': [], 'last_hit': [], 'lane': [], 'decide': []}
    for line in lines:
        c = stamp_clock(line)
        if '[SelfPlay score]' in line:
            m = RE_SCORE.search(line)
            if m:
                d['score'].append(dict(clock=float(m.group(1)), hero=m.group(2), role=int(m.group(3)),
                                       lane=int(m.group(4)), lh=int(m.group(5)), dn=int(m.group(6)),
                                       nw=int(m.group(7)), gold=int(m.group(8)), xp=int(m.group(9)),
                                       hd=int(m.group(10))))
            continue
        if '[SelfPlay lane]' in line:
            d['lane'].append((c, line.strip()))
            continue
        if '[SelfPlay actions]' in line:
            m = RE_ACT.search(line)
            if m and c is not None:
                d['actions'].append((c, int(m.group(5))))
            continue
        if '[SelfPlay last hit]' in line:
            d['last_hit'].append((c, line.strip()))
            continue
        if '[SelfPlay decide]' in line:
            m = RE_DECIDE.search(line)
            if m:
                d['decide'].append(m.group(1))
            continue
        if '[SelfPlay] role=' in line:
            m = RE_MODE.search(line)
            if m and c is not None:
                d['modes'].append(dict(clock=c, role=int(m.group(1)), lane=int(m.group(2)),
                                       mode=m.group(3).strip(), attacks=int(m.group(4)),
                                       cancelled=int(m.group(5)), cast=m.group(6), order=m.group(7)))
    return d


def checkpoint(d, minute):
    lim = minute * 60 + 15  # score lines land at ~60.3/120.5/... game clock
    rows = [s for s in d['score'] if s['clock'] <= lim]
    last = rows[-1] if rows else None
    mx = max(rows, key=lambda s: s['lh']) if rows else None
    return last, mx


def window_counts(d, lo, hi):
    acts = [v for c, v in d['actions'] if c is not None and lo <= c <= hi]
    modes = [m for m in d['modes'] if lo <= m['clock'] <= hi]
    orders = collections.Counter(m['order'] for m in modes)
    casts = [m['cast'] for m in modes if m['cast'] not in ('-', '', 'nil')]
    return dict(act_n=len(acts), act_pos=sum(1 for v in acts if v > 0), orders=orders,
                mode_n=len(modes), attacks_max=max((m['attacks'] for m in modes), default=0),
                attacks_gt0=sum(1 for m in modes if m['attacks'] > 0), casts=casts)


def print_checkpoints(d, label):
    print('-- %s: checkpoints (last score <= minute; max LH in window)' % label)
    print('   min |  clock | role lane |  LH | denies |    XP | heroDmg |   NW | ref LH/XP/HD')
    for minute in (1, 2, 3, 4, 5, 6, 8, 10):
        last, mx = checkpoint(d, minute)
        if not last:
            continue
        rl, rx, rh = REF_CKPT.get(minute, ('-', '-', '-'))
        print('   %3d | %6.1f | %4d %4d | %3d | %6d | %5d | %7d | %4d | %s/%s/%s' % (
            minute, last['clock'], last['role'], last['lane'], last['lh'], last['dn'], last['xp'],
            last['hd'], last['nw'], rl, rx, rh))
    print()


def acceptance(d):
    print('== REFERENCE_BEHAVIOR.md acceptance criteria ==')
    checks = []
    last1, _ = checkpoint(d, 1)
    w1 = window_counts(d, 0, 75)
    checks.append(('1:00 lastsHits>=1', bool(last1 and last1['lh'] >= 1), 'LH=%s' % (last1['lh'] if last1 else 'n/a')))
    checks.append(('1:00 order=attack>=1', w1['orders'].get('attack', 0) >= 1, 'attack=%d move=%d' % (w1['orders'].get('attack', 0), w1['orders'].get('move', 0))))
    checks.append(('1:00 attacks>0', w1['attacks_gt0'] >= 1, 'mode-lines with attacks>0: %d, max attacks=%d' % (w1['attacks_gt0'], w1['attacks_max'])))
    checks.append(('1:00 heroDamage>0', bool(last1 and last1['hd'] > 0), 'heroDamage=%s' % (last1['hd'] if last1 else 'n/a')))
    last5, _ = checkpoint(d, 5)
    w5 = window_counts(d, 0, 315)
    support_mode = any('Support lane: deny and protect' in m['mode'] for m in d['modes'] if m['clock'] <= 315)
    checks.append(('5:00 lastHits>=5', bool(last5 and last5['lh'] >= 5), 'LH=%s' % (last5['lh'] if last5 else 'n/a')))
    checks.append(('5:00 XP>=1500', bool(last5 and last5['xp'] >= 1500), 'XP=%s' % (last5['xp'] if last5 else 'n/a')))
    checks.append(('5:00 mode Support lane: deny and protect', support_mode, 'present=%s' % support_mode))
    checks.append(('5:00 cast present (not only heal)', len(w5['casts']) > 0, 'casts=%s' % sorted(set(w5['casts']))[:6]))
    last10, _ = checkpoint(d, 10)
    w10 = window_counts(d, 0, 615)
    checks.append(('10:00 lastHits>=10', bool(last10 and last10['lh'] >= 10), 'LH=%s' % (last10['lh'] if last10 else 'n/a')))
    checks.append(('10:00 XP>=6000', bool(last10 and last10['xp'] >= 6000), 'XP=%s' % (last10['xp'] if last10 else 'n/a')))
    checks.append(('10:00 attack order present', w10['orders'].get('attack', 0) >= 1, 'attack=%d' % w10['orders'].get('attack', 0)))
    checks.append(('10:00 actions candidates>0', w10['act_pos'] >= 1, 'cand>0 %d/%d' % (w10['act_pos'], w10['act_n'])))
    checks.append(('[SelfPlay score] lines present', len(d['score']) >= 10, '%d lines' % len(d['score'])))
    for name, ok, detail in checks:
        print('   [%s] %-42s %s' % ('PASS' if ok else 'FAIL', name, detail))
    print()


def summary(d, label):
    print('===== %s =====' % label)
    print('score lines=%d  mode lines=%d  actions=%d  last_hit lines=%d  decide=%d  lane lines=%d' % (
        len(d['score']), len(d['modes']), len(d['actions']), len(d['last_hit']), len(d['decide']), len(d['lane'])))
    orders = collections.Counter(m['order'] for m in d['modes'])
    print('orders:', dict(orders))
    modes = collections.Counter(m['mode'] for m in d['modes'])
    print('top modes:', modes.most_common(10))
    print('max attacks in mode line:', max((m['attacks'] for m in d['modes']), default=0))
    for lo, hi in ((0, 300), (0, 360), (0, 600)):
        w = window_counts(d, lo, hi)
        pct = 100.0 * w['act_pos'] / w['act_n'] if w['act_n'] else 0.0
        print('actions %d..%d: cand>0 %d/%d = %.1f%%' % (lo, hi, w['act_pos'], w['act_n'], pct))
    per = []
    for m in range(11):
        w = window_counts(d, m * 60, (m + 1) * 60)
        per.append('%d:%d/%d' % (m, w['act_pos'], w['act_n']))
    print('per-minute cand>0:', ' '.join(per))
    if d['lane']:
        print('lane/switch lines:')
        for c, l in d['lane']:
            print('   ', c, l)
    if d['last_hit']:
        lh_good = sum(1 for _, l in d['last_hit'] if 'goodguys' in l)
        lh_bad = sum(1 for _, l in d['last_hit'] if 'badguys' in l)
        print('last hit lines:', len(d['last_hit']), '| enemy-creep targets (last hits): %d | allied-creep targets (denies): %d' % (
            lh_bad, lh_good))
        for c, l in d['last_hit'][:20]:
            print('   ', l)
    first_attack = next((m['clock'] for m in d['modes'] if m['order'] == 'attack'), None)
    first_hd = next((s['clock'] for s in d['score'] if s['hd'] > 0), None)
    first_cast = next((m['clock'] for m in d['modes'] if m['cast'] not in ('-', '', 'nil')), None)
    last_clock = d['score'][-1]['clock'] if d['score'] else None
    print('first order=attack: %s | first heroDamage>0: %s | first cast: %s | last score clock: %s' % (
        first_attack, first_hd, first_cast, last_clock))
    if last_clock:
        print('line cadence: %.0f mode lines/min, %.0f score lines/min (%.1f min)' % (
            len(d['modes']) * 60.0 / last_clock, len(d['score']) * 60.0 / last_clock, last_clock / 60.0))
    print()


def main():
    mine = sessions(SP)
    if not mine:
        print('no session in', SP)
        return
    our = parse(mine[-1]['lines'])
    print('== our session:', mine[-1]['name'], 'lines', len(mine[-1]['lines']))
    print_checkpoints(our, 'OURS (clean AI-13 run)')
    summary(our, 'OURS summary (all lines)')
    acceptance(our)

    # reference sessions S26 (role4 lane1) and S1 (lane1, had a switch)
    ref = sessions(REF)
    for label, hint in (('S26 (2026-11-17 01:04:57, role4 lane1)', '2026-11-17 01:04:57'),
                        ('S1 (2026-11-16 03:12:52, lane1)', '2026-11-16 03:12:52')):
        match = [s for s in ref if hint in s['name']]
        if not match:
            print('reference session not found:', hint)
            continue
        r = parse(match[-1]['lines'])
        print('== reference', label, 'lines', len(match[-1]['lines']))
        print_checkpoints(r, label)
        summary(r, 'REF ' + label)

    # host.log evidence
    host = open(HOST, encoding='utf-8', errors='replace').read().splitlines()
    widgets = [l for l in host if 'SELFPLAY role widget' in l or 'SELFPLAY lane widget' in l]
    botloops = [l for l in host if '=== BOT LOOP ===' in l]
    anchor = [l for l in host if 'observed state transition' in l or 'm_flGameStartTime transition' in l]
    print('===== host.log evidence =====')
    print('BOT LOOP markers:', len(botloops), botloops[:2])
    print('widget lines:', widgets)
    print('anchor lines:', anchor[:3])


if __name__ == '__main__':
    main()