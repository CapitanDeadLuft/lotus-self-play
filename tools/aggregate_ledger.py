#!/usr/bin/env python3
# Aggregate [ledger] probe lines. Usage: aggregate_ledger.py [path] [--since HH:MM:SS] [--clock-min N]
import re, sys, collections

path = r'D:\hake\lotus\probe.log'
since = None
cmin = None
args = sys.argv[1:]
i = 0
while i < len(args):
    a = args[i]
    if a == '--since':
        since = args[i + 1]; i += 2; continue
    if a == '--clock-min':
        cmin = float(args[i + 1]); i += 2; continue
    if not a.startswith('--'):
        path = a
    i += 1

fields = ['calls','seen','chk','gate','denyNo','far','imm','evPos','ev0','act','ev0act',
          'ev0actDp','ev0actTgtMe','ev0actTgtOther','ev0actTgtNil','ev0actCyc','ev0actEvSrc',
          'ev0actDpSrc','anim','cyc','pred','noDelay','min0','hpHiEv0','flag','nowin','noroute',
          'unsafe','cands','chosen','ua','dpt']
tot = collections.Counter()
lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
n = 0
samples = []
for l in lines:
    if since and not l.startswith(' ') and l[:8] < since:
        continue
    if '[ledger]' in l:
        m = re.search(r'(\w+)=(-?\d+)', l)
        if not m:
            continue
        pairs = dict(re.findall(r'(\w+)=(-?\d+)', l))
        if cmin is not None and float(pairs.get('clock', -1)) < cmin:
            continue
        n += 1
        for f in fields:
            tot[f] += int(pairs.get(f, 0))
    elif l.strip().startswith('s1 ') or l.strip().startswith('s2 ') or l.strip().startswith('s3 '):
        key = l.strip()[:2]
        samples.append((key, l.strip()))

print(f'windows={n}')
if n:
    for f in fields:
        print(f'{f:10s} {tot[f]:8d}', end='   ')
        if f in ('seen','ev0','act','flag','cands','evPos','chk'):
            pass
        print()
print()
def pct(a, b):
    return f'{100.0*a/b:.1f}%' if b else 'n/a'
print('per-window means:')
for f in fields:
    print(f'  {f:10s} {tot[f]/n:9.2f}')
print()
print('ratios:')
print('  evPos/chk      =', pct(tot['evPos'], tot['chk']), f"({tot['evPos']}/{tot['chk']})")
print('  ev0/chk        =', pct(tot['ev0'], tot['chk']))
print('  hpHiEv0/chk    =', pct(tot['hpHiEv0'], tot['chk']))
print('  active/chk     =', pct(tot['act'], tot['chk']))
print('  ev0act/ev0     =', pct(tot['ev0act'], tot['ev0']))
print('  ev0actDp/ev0act=', pct(tot['ev0actDp'], tot['ev0act']))
print('  ev0actTgtMe/ev0act=', pct(tot['ev0actTgtMe'], tot['ev0act']))
print('  ev0actTgtOther/ev0act=', pct(tot['ev0actTgtOther'], tot['ev0act']))
print('  ev0actTgtNil/ev0act=', pct(tot['ev0actTgtNil'], tot['ev0act']))
print('  ev0actCyc/ev0act=', pct(tot['ev0actCyc'], tot['ev0act']))
print('  ev0actEvSrc/ev0act=', pct(tot['ev0actEvSrc'], tot['ev0act']))
print('  ev0actDpSrc/ev0act=', pct(tot['ev0actDpSrc'], tot['ev0act']))
print('  flag/chk       =', pct(tot['flag'], tot['chk']))
print('  cands/flag     =', pct(tot['cands'], tot['flag']))
print('  chosen/calls   =', pct(tot['chosen'], tot['calls']))
print('  nowin/chk      =', pct(tot['nowin'], tot['chk']))
print('  unsafe/cands   =', pct(tot['unsafe'], tot['cands'] + tot['unsafe']))
print('  anim/evPos     =', pct(tot['anim'], tot['evPos']))
print('  cyc/evPos      =', pct(tot['cyc'], tot['evPos']))
print('  pred/evPos     =', pct(tot['pred'], tot['evPos']))
print('  ua/dpt means   =', tot['ua']/n, tot['dpt']/n)
print()
print('sample lines:')
seen = set()
for k, s in samples:
    if k in seen:
        continue
    seen.add(k)
    print(' ', s)