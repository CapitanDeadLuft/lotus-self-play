import re, json, sys
from collections import Counter, defaultdict

REF = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.log"
OURS = sys.argv[2] if len(sys.argv) > 2 else r"D:\hake\lotus\self_play.log"
OUT = sys.argv[3] if len(sys.argv) > 3 else r"D:\hake\lotus\PARITY_DIFF.md"

score_re = re.compile(r"\[SelfPlay score\] clock=([\d.]+) hero=([\w_]+) role=(\d+) lane=(\d+) lastHits=(\d+) denies=(\d+) networth=(\d+) gold=(\d+) xp=(\d+) heroDamage=(\d+) laneGold=(\d+) jungleGold=(\d+)")
mode_re = re.compile(r"\[SelfPlay\] role=(\d+) lane=(\d+) mode=(.+?) hp=([\d.]+) pos=(\S+) busy=([\d.]+) attacks=(\d+) cancelled=(\d+).*order=(\w+)")
act_re = re.compile(r"\[SelfPlay actions\] time=([\d.]+) target=(\S+) lock=(\S+) creepAggro=(\d+) candidates=(\d+) lastSwing=(\S+)")
decide_re = re.compile(r"\[SelfPlay decide\] ran=(\w+) for=([\d.]+)s top=(\S+)")

def parse(path, hero_filter=None):
    scores, modes, acts, decides = [], [], [], []
    clock = 0.0
    try:
        fh = open(path, encoding="utf-8", errors="ignore")
    except OSError:
        return None
    for line in fh:
        m = re.match(r"^\[(-?)(\d+):(\d{2})\]", line)
        if m:
            clock = (-1 if m.group(1) else 1) * (int(m.group(2)) * 60 + int(m.group(3)))
        s = score_re.search(line)
        if s:
            if hero_filter and hero_filter not in s.group(2):
                continue
            scores.append(dict(clock=float(s.group(1)), hero=s.group(2), role=int(s.group(3)),
                               lane=int(s.group(4)), lh=int(s.group(5)), dn=int(s.group(6)),
                               nw=int(s.group(7)), gold=int(s.group(8)), xp=int(s.group(9)),
                               hd=int(s.group(10)), laneGold=int(s.group(11)), jungle=int(s.group(12))))
            continue
        m2 = mode_re.search(line)
        if m2:
            modes.append(dict(role=int(m2.group(1)), lane=int(m2.group(2)), mode=m2.group(3).strip(),
                              hp=float(m2.group(4)), attacks=int(m2.group(7)), order=m2.group(9), clock=clock))
            continue
        m3 = act_re.search(line)
        if m3:
            acts.append(dict(candidates=int(m3.group(5)), target=m3.group(2), clock=clock))
            continue
        m4 = decide_re.search(line)
        if m4:
            decides.append(dict(ran=m4.group(1), top=m4.group(3), clock=clock))
    return dict(scores=scores, modes=modes, acts=acts, decides=decides)

def summarize(d, label):
    out = {"label": label}
    scores = [s for s in d["scores"] if s["clock"] >= 0]
    out["score_lines"] = len(scores)
    buckets = {}
    for b in (1, 3, 5, 10, 15):
        sel = [s for s in scores if s["clock"] <= b * 60]
        if sel:
            last = max(sel, key=lambda s: s["clock"])
            buckets[b] = dict(lh=last["lh"], dn=last["dn"], xp=last["xp"], hd=last["hd"], nw=last["nw"])
    out["at_minute"] = buckets
    out["orders"] = Counter(m["order"] for m in d["modes"])
    out["modes"] = Counter(m["mode"] for m in d["modes"])
    out["max_attacks"] = max((m["attacks"] for m in d["modes"]), default=0)
    out["mode_lines"] = len(d["modes"])
    out["actions_lines"] = len(d["acts"])
    out["candidates_gt0"] = sum(1 for a in d["acts"] if a["candidates"] > 0)
    out["decide"] = Counter(x["ran"] for x in d["decides"])
    return out

ref = parse(REF, hero_filter="treant")
ours = parse(OURS)
if ref is None or ours is None:
    print("missing input"); sys.exit(1)

rs = summarize(ref, "ORIGINAL (treant)")
os_ = summarize(ours, "OURS")

def table_row(name, r, o):
    return f"| {name} | {r} | {o} |"

lines = []
lines.append("# PARITY DIFF — наш порт vs оригинал (Self Play, Treant role 4)\n")
lines.append("Источники: оригинал — `self_play.log` Umbrella (sessions Nov 17 + live), наш — `D:\\hake\\lotus\\self_play.log`.\n")
lines.append("## Контрольные точки (последнее значение к минуте)\n")
lines.append("| Минута | Оригинал lastHits/XP/heroDmg | Наш порт lastHits/XP/heroDmg |")
lines.append("|---|---|---|")
for b in (1, 3, 5, 10, 15):
    r = rs["at_minute"].get(b); o = os_["at_minute"].get(b)
    rf = f"{r['lh']} / {r['xp']} / {r['hd']}" if r else "—"
    of = f"{o['lh']} / {o['xp']} / {o['hd']}" if o else "—"
    lines.append(f"| {b} | {rf} | {of} |")

lines.append("\n## Приказы (строки mode ... order=)\n")
lines.append("| order | оригинал | наш порт |")
lines.append("|---|---|---|")
for k in ("move", "hold", "cast", "attack"):
    lines.append(f"| {k} | {rs['orders'].get(k,0)} | {os_['orders'].get(k,0)} |")

lines.append("\n## Покрытие режимов (топ-10)\n")
lines.append("| mode | оригинал | наш порт |")
lines.append("|---|---|---|")
all_modes = sorted(set(list(rs["modes"])[:12] + list(os_["modes"])[:12]),
                   key=lambda m: -(rs["modes"].get(m, 0) + os_["modes"].get(m, 0)))
for m in all_modes[:12]:
    lines.append(f"| {m} | {rs['modes'].get(m,0)} | {os_['modes'].get(m,0)} |")

lines.append("\n## Метрики\n")
lines.append("| метрика | оригинал | наш порт |")
lines.append("|---|---|---|")
lines.append(table_row("score-строк", rs["score_lines"], os_["score_lines"]))
lines.append(table_row("mode-строк", rs["mode_lines"], os_["mode_lines"]))
lines.append(table_row("max attacks (в строке mode)", rs["max_attacks"], os_["max_attacks"]))
lines.append(table_row("[SelfPlay actions] строк", rs["actions_lines"], os_["actions_lines"]))
lines.append(table_row("actions с candidates>0", rs["candidates_gt0"], os_["candidates_gt0"]))

lines.append("\n## Решения (decide ran=)\n")
lines.append("| ran | оригинал | наш порт |")
lines.append("|---|---|---|")
for k in sorted(set(list(rs["decide"]) + list(os_["decide"]))):
    lines.append(f"| {k} | {rs['decide'].get(k,0)} | {os_['decide'].get(k,0)} |")

open(OUT, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("\n".join(lines))
print("\nsaved", OUT)