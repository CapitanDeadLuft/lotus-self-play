#!/usr/bin/env python3
"""Composition filter for Treant role-4 lane-1 acceptance ("composition-matched" runs).

Статус: READ-ONLY фильтр, ничего не пишет в живые скрипты/логи. Решение 2026-11-23:
`self_play/lane_rules.lua:canLastHit` остаётся эталонным (md5 BEC5932A1C125C9A4E9C6541355D0CE1),
поэтому метрика LH@5>=6 из ACCEPTANCE_2026-11-23.md §10 засчитывается **только** на
composition-matched матчах. Этот инструмент и есть тот отбор:

- читает read-only зонд `[fsl]` (rosters+planner roles+pos, шаг ~10 с) из host-лога
  и `[SelfPlay score]`/`[SelfPlay lane]` из self_play-лога (формат archive/20261123_fsl);
- классифицирует состав линии в окне метрики: partner-support = MATCHED,
  partner-core = NOT-MATCHED, нет данных = UNKNOWN, наш role<4 = N/A-ROLE;
- отдаёт LH@5 / LH@10 (ground truth `[SelfPlay score]`, как в ACCEPTANCE) и
  acceptance-вердикт: LH@5>=6 только для MATCHED;
- `--early SEC`: решение по первым SEC секундам — чтобы прервать неподходящий
  матч (kill dota2) и не тратить 10 минут;
- `--ref`: та же классификация эталонных сессий (`self_play.prev.log`) по причине
  свича `lane_choice` (в эталоне нет roster-зонда, поэтому класс выводится из текста
  "<hero> already supports our lane" и помечается evidence_t).

Выход: 0 = MATCHED/MATCHED_SOLO, 2 = NOT-MATCHED, 3 = UNKNOWN/N-A-ROLE, 1 = ошибка.

Usage (Windows):
  python tools\\comp_filter.py
  python tools\\comp_filter.py --host archive\\20261123_fsl\\host.log.fsl ^
      --sp archive\\20261123_fsl\\self_play.log.fsl --session "2026-11-23 02:31:30"
  python tools\\comp_filter.py --early 120
  python tools\\comp_filter.py --ref --json archive\\20261123_fsl\\comp_filter_ref.json
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import layer2_fsl as L2  # noqa: E402  (validated read-only parser from the layer-2 run)

ROOT = r"D:\hake\lotus"
DEF_HOST = os.path.join(ROOT, "archive", "20261123_fsl", "host.log.fsl")
DEF_SP = os.path.join(ROOT, "archive", "20261123_fsl", "self_play.log.fsl")
DEF_REF = r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"

VERDICT_MATCHED = "MATCHED"
VERDICT_MATCHED_SOLO = "MATCHED_SOLO"
VERDICT_NOT_MATCHED = "NOT-MATCHED"
VERDICT_UNKNOWN = "UNKNOWN"
VERDICT_NA_ROLE = "N/A-ROLE"
MATCHED_SET = {VERDICT_MATCHED, VERDICT_MATCHED_SOLO}

RE_SCORE = re.compile(
    r"\[SelfPlay score\] clock=(-?[\d.]+) hero=(\S+) role=(-?\d+) lane=(-?\d+)"
    r" lastHits=(\d+) denies=(\d+)")
RE_SCORE_TAIL = re.compile(
    r"\[SelfPlay score\] clock=(-?[\d.]+) .*?\bxp=(\d+) heroDamage=(\d+)")
RE_FLH = re.compile(
    r"^(\d\d):(\d\d):(\d\d) \[fsl lh\] clock=(-?[\d.]+) lastHits=(\d+) denies=(\d+)"
    r" networth=(\d+) xp=(\d+) heroDamage=(\d+)")
RE_FSW = re.compile(
    r"^(\d\d):(\d\d):(\d\d) \[fsl (SWITCH|LANECHANGE)\] clock=(-?[\d.]+)"
    r" lane=(-?\d+)->(-?\d+) reason=(.*?)(?: \| LH=.*)?$")
RE_SLANE = re.compile(r"^\[(-?\d+):(\d\d)\] \[SelfPlay lane\] (.*)$")
RE_SESS = re.compile(r"^===== Self Play session (.+) =====$")
RE_PARTNER = re.compile(r"([\w_]+) already supports our lane")


# ---------------------------------------------------------------- small helpers
def as_int(text):
    if text is None:
        return None
    t = str(text).strip()
    return int(t) if t.isdigit() else None


def median(values):
    return round(float(L2.st.median(values)), 1) if values else None


def load_lines(path):
    return L2.read_lines(path)


# ------------------------------------------------------------------- parsers
def parse_scores(lines):
    scores = []
    for line in lines:
        m = RE_SCORE.search(line)
        if not m:
            continue
        tail = RE_SCORE_TAIL.search(line)
        scores.append({
            "clock": float(m.group(1)), "hero": m.group(2),
            "role": int(m.group(3)), "lane": int(m.group(4)),
            "lh": int(m.group(5)), "dn": int(m.group(6)),
            "xp": int(tail.group(2)) if tail else None,
            "hd": int(tail.group(3)) if tail else None,
        })
    return scores


def parse_fsl_lh(lines):
    out = []
    for line in lines:
        m = RE_FLH.match(line)
        if not m:
            continue
        out.append({"wall": "%s:%s:%s" % (m.group(1), m.group(2), m.group(3)),
                    "clock": float(m.group(4)), "lh": int(m.group(5)),
                    "dn": int(m.group(6)), "nw": int(m.group(7)),
                    "xp": int(m.group(8)), "hd": int(m.group(9))})
    return out


def parse_switches(lines):
    out = []
    for line in lines:
        m = RE_FSW.match(line)
        if m:
            out.append({"t": L2.seconds_of_day(m.group(0)[:8]),
                        "clock": float(m.group(5)), "kind": m.group(4),
                        "from": int(m.group(6)), "to": int(m.group(7)),
                        "reason": m.group(8).strip()})
    return out


def parse_lane_lines(lines):
    out = []
    for line in lines:
        m = RE_SLANE.match(line)
        if m:
            out.append({"t": int(m.group(1)) * 60 + int(m.group(2)), "text": m.group(3).strip()})
    return out


def parse_positions(lines):
    """[SelfPlay] mode-строки: координаты нашего героя на каждом решении (~2.8 с)."""
    out = []
    for line in lines:
        m = L2.RE_MODE.match(line)
        if not m:
            continue
        out.append({"t": int(m.group(1)) * 60 + int(m.group(2)) if m.group(1) is not None else 0,
                    "clock": float(m.group(1)) * 60 + float(m.group(2)),
                    "role": int(m.group(3)), "lane": int(m.group(4)),
                    "mode": m.group(5), "x": int(m.group(7)), "y": int(m.group(8))})
    return out


def attach_self_positions(samples, positions, max_dt=6.0):
    """Ближайшая по clock позиция [SelfPlay] к [fsl]-сэмплу (self-запись [fsl] есть не всегда)."""
    if not positions:
        return samples
    for s in samples:
        best, bdt = None, 1e9
        for p in positions:
            dt = abs(p["clock"] - s["clock"])
            if dt < bdt:
                best, bdt = p, dt
        if best is not None and bdt <= max_dt:
            s["selfpos"] = (best["x"], best["y"])
            s["selfpos_dt"] = round(bdt, 2)
    return samples


def split_runs(samples, wall_time, gap_s=45):
    """Сгруппировать [fsl]-сэмплы в прогоны: разрыв wall > gap_s = новый прогон."""
    samples = sorted(samples, key=wall_time)
    runs, cur = [], []
    for s in samples:
        if cur and wall_time(s) - wall_time(cur[-1]) > gap_s:
            runs.append(cur)
            cur = []
        cur.append(s)
    if cur:
        runs.append(cur)
    return runs


def pick_run(runs, wall0, wall_time, tol=120):
    """Прогон, начинающийся ближе всего к старту сессии (|first_wall - wall0| <= tol)."""
    best, best_d = None, 1e9
    for run in runs:
        first = wall_time(run[0])
        d = abs(first - wall0)
        if d < best_d:
            best, best_d = run, d
    if best is None or best_d > tol:
        return []
    return best


def split_sessions(lines):
    """[(start_string, session_lines)] — по маркеру '===== Self Play session ...'."""
    sessions, cur = [], None
    for line in lines:
        m = RE_SESS.match(line)
        if m:
            cur = {"start": m.group(1).strip(), "lines": []}
            sessions.append(cur)
        elif cur is not None:
            cur["lines"].append(line)
    return sessions


def choose_session(sessions, wanted):
    if not sessions:
        raise SystemExit("нет None: в self_play-логе не найдено 'Self Play session'")
    if wanted:
        cand = [s for s in sessions if wanted in s["start"]]
        if not cand:
            raise SystemExit("нет сессии '%s'; есть: %s" % (wanted, [s["start"] for s in sessions]))
        return cand[-1]
    return sessions[-1]


# ----------------------------------------------------------------- classify
def classify_window(samples, lo, hi, min_presence_s, roster_min_lane_samples=3):
    """Классификация состава линии в окне [lo, hi) по [fsl] samples."""
    sel = [s for s in samples if lo <= s["clock"] < hi and s["clock"] >= 0 and s["lane"] in (1, 2, 3)]
    res = {"window": [lo, hi], "n_samples": len(sel),
           "verdict": VERDICT_UNKNOWN, "reason": "", "partner": None,
           "partner_role": None, "partner_class": None,
           "presence": {}, "solo": False, "lanes": {}, "dominant_lane": None,
           "n_support_presence": 0, "n_core_presence": 0, "unstable": False}
    if not sel:
        res["reason"] = "нет [fsl]-сэмплов в окне (roster-зонд не запускался?)"
        return res

    lane_counts = {}
    for s in sel:
        lane = s["lane"]
        lane_counts[lane] = lane_counts.get(lane, 0) + 1
    dominant = max(lane_counts, key=lambda k: (lane_counts[k], -k))
    res["dominant_lane"] = dominant
    res["lanes"] = {str(k): v for k, v in sorted(lane_counts.items())}
    res["unstable"] = len(lane_counts) > 1

    presence = {}
    for s in sel:
        if s["lane"] != dominant:
            continue
        for name, rec in s["roster"].items():
            if rec.get("set") == 1 and rec.get("lane") == dominant:
                presence[name] = presence.get(name, 0) + 1

    # роли союзников: берём самый частый известный r= из сэмплов
    roles = {}
    for s in sel:
        for name, rec in s["roster"].items():
            r = as_int(rec.get("role"))
            if r is not None:
                roles[name] = roles.get(name, r)
    res["roles"] = roles

    if not presence:
        res.update(verdict=VERDICT_MATCHED_SOLO, solo=True,
                   reason="в нашей линии нет ни одного settled-союзника (solo lane)")
        return res

    ranked = sorted(presence.items(), key=lambda kv: (-kv[1], kv[0]))
    partner, cnt = ranked[0]
    role = roles.get(partner)
    if role is None:
        # роль неизвестна (r=? / r=-): пробуем роль из roster record напрямую
        for s in sel:
            role = as_int(s["roster"][partner].get("role"))
            if role is not None:
                break
    res["partner"] = partner
    res["partner_role"] = role
    res["presence"] = {k: v for k, v in ranked}
    res["presence_sec"] = {k: v * 10 for k, v in ranked}
    res["n_support_presence"] = sum(v for k, v in presence.items() if (roles.get(k) or 0) >= 4)
    res["n_core_presence"] = sum(v for k, v in presence.items() if (roles.get(k) or 99) <= 3)
    pres_sec = cnt * 10

    if role is None:
        res.update(verdict=VERDICT_UNKNOWN,
                   reason="роль partner=%s неизвестна (r=?)" % partner)
        return res
    if role >= 4:
        res["partner_class"] = "support"
        if pres_sec < min_presence_s:
            res.update(verdict=VERDICT_UNKNOWN,
                       reason="partner-support %s лишь %ds в линии (< %ds)" % (partner, pres_sec, min_presence_s))
        else:
            res.update(verdict=VERDICT_MATCHED,
                       reason="partner-support %s (role=%d, %ds в нашей линии)" % (partner, role, pres_sec))
        return res
    res["partner_class"] = "core"
    res.update(verdict=VERDICT_NOT_MATCHED,
               reason="partner-core %s (role=%d, %ds в нашей линии): гейт canLastHit активен"
                      % (partner, role, pres_sec))
    return res


def core_exposure(samples, lo, hi):
    """Прокси гейта: доля сэмплов, где ядро-союзник ближе 1200 к нашему герою.

    Координат крипов в логах нет, поэтому это прокси «ядро рядом», не точное
    условие гейта (d(core, creep) < 1200). Используется как предупреждение.
    """
    rows = []
    for s in samples:
        if not (lo <= s["clock"] < hi and s["clock"] >= 0):
            continue
        me = s.get("selfpos")
        if me is None:
            rec = s.get("self")
            me = (rec["x"], rec["y"]) if rec and rec.get("x") is not None else None
        if me is None:
            continue
        cores = []
        for name, rec in s["roster"].items():
            role = as_int(rec.get("role"))
            if role is not None and role <= 3 and rec.get("set") == 1 and rec.get("x") is not None:
                cores.append((name, L2.dist(me, (rec["x"], rec["y"]))))
        if not cores:
            continue
        dmin = min(d for _, d in cores)
        rows.append({"clock": s["clock"], "dmin": dmin,
                     "near": sorted(cores, key=lambda kv: kv[1])[0]})
    ds = [r["dmin"] for r in rows]
    return {"n": len(rows),
            "lt1200": sum(1 for d in ds if d < 1200),
            "lt600": sum(1 for d in ds if d < 600),
            "pct_lt1200": (round(100.0 * sum(1 for d in ds if d < 1200) / len(ds), 1) if ds else None),
            "median_dmin": median(ds),
            "min_dmin": (round(min(ds), 1) if ds else None)}


# ------------------------------------------------------------------- metrics
def first_ge(samples, limit):
    """Первый сэмпл с clock >= limit — конвенция checkpoints ACCEPTANCE (@1/@3/@5/@10)."""
    sel = [s for s in samples if s["clock"] >= limit]
    return sel[0] if sel else None


def compute_metrics(scores, fsl_lh):
    src = scores if scores else fsl_lh
    res = {"lh5": None, "lh10": None, "xp5": None, "xp10": None, "final": None,
           "source": "score" if scores else ("fsl lh" if fsl_lh else "none"),
           "anchor": "первый сэмпл с clock >= N (как @5/@10 в ACCEPTANCE)"}
    for tag, limit in (("lh5", 300), ("lh10", 600)):
        rec = first_ge(src, limit)
        if rec is not None:
            res[tag] = {"clock": round(rec["clock"], 1), "lh": rec["lh"], "dn": rec["dn"]}
    for tag, limit in (("xp5", 300), ("xp10", 600)):
        rec = first_ge(src, limit)
        if rec is not None and rec.get("xp") is not None:
            res[tag] = {"clock": round(rec["clock"], 1), "xp": rec["xp"]}
    if src:
        rec = src[-1]
        res["final"] = {"clock": round(rec["clock"], 1), "lh": rec["lh"],
                        "dn": rec["dn"], "xp": rec.get("xp"), "hd": rec.get("hd")}
    return res


def acceptance_block(verdict, metrics, early=False):
    matched = verdict in MATCHED_SET
    out = []
    if early:
        out.append(("composition (early)", verdict, "ранний отбор: при NOT-MATCHED матч прерывать"))
        return out
    lh5 = metrics.get("lh5")
    lh10 = metrics.get("lh10")
    if not matched:
        out.append(("LH@5 >= 6", "N/A",
                    "composition %s -> метрика не засчитывается (ACCEPTANCE §10)" % verdict))
        out.append(("LH@10 >= 10", "N/A", "то же"))
        return out
    if lh5 is None:
        out.append(("LH@5 >= 6", "N/A", "нет score-сэмпла с clock >= 300"))
    else:
        out.append(("LH@5 >= 6", "PASS" if lh5["lh"] >= 6 else "FAIL",
                    "LH=%d @ %.1fs" % (lh5["lh"], lh5["clock"])))
    if lh10 is None:
        out.append(("LH@10 >= 10", "N/A", "нет score-сэмпла с clock >= 600"))
    else:
        out.append(("LH@10 >= 10", "PASS" if lh10["lh"] >= 10 else "FAIL",
                    "LH=%d @ %.1fs" % (lh10["lh"], lh10["clock"])))
    return out


# ---------------------------------------------------------------- match mode
def analyze_match(args):
    host_lines = load_lines(args.host)
    sp_lines = load_lines(args.sp)
    sessions = split_sessions(sp_lines)
    sess = choose_session(sessions, args.session)
    scores = parse_scores(sess["lines"])
    lane_lines = parse_lane_lines(sess["lines"])

    start = sess["start"]
    # '2026-11-23 02:31:30' -> секунды суток; окно хоста [start-120, start+max_clock+120]
    try:
        wall0 = L2.seconds_of_day(start.split()[1])
    except (IndexError, ValueError):
        raise SystemExit("не удалось разобрать время сессии: %r" % start) from None
    wall_lo, wall_hi = wall0 - 120, wall0 + args.max_clock + 120

    def wall_time(sample):
        return L2.wall_on_or_after(L2.seconds_of_day(sample["wall"]), wall_lo)

    samples_all = L2.parse_fsl_lines(host_lines, wall_lo, wall_hi)
    run = pick_run(split_runs(samples_all, wall_time), wall0, wall_time)
    run_lo = wall_time(run[0]) if run else wall_lo
    run_hi = wall_time(run[-1]) if run else wall_hi
    samples = run
    positions = parse_positions(sess["lines"])
    samples = attach_self_positions(samples, positions)
    switches = parse_switches(host_lines)
    switches = [s for s in switches if run_lo <= L2.wall_on_or_after(s["t"], wall_lo) <= run_hi]
    # host-лог может содержать несколько прогонов: отбрасываем сэмплы с clock > max_clock
    samples = [s for s in samples if -5 <= s["clock"] <= args.max_clock]
    fsl_lh = [x for x in parse_fsl_lh(host_lines) if run_lo <= wall_time(x) <= run_hi]

    role = None
    hero = None
    our_lane = None
    if scores:
        hero, role, our_lane = scores[0]["hero"], scores[0]["role"], scores[0]["lane"]
    if samples:
        r = as_int(samples[0].get("role"))
        if r is not None:
            role = r
        lane = samples[0].get("lane")
        if our_lane is None and lane in (1, 2, 3):
            our_lane = lane

    windows = {}
    windows["lh5"] = classify_window(samples, 0, 300, args.min_presence_sec)
    windows["lh10"] = classify_window(samples, 0, 600, args.min_presence_sec)
    if args.early:
        early_min = args.min_presence_sec if args.min_presence_sec < args.early * 0.6 else max(20, int(args.early * 0.6))
        ew = classify_window(samples, 0, args.early, early_min)
        ready_at = None
        if ew["verdict"] in MATCHED_SET | {VERDICT_NOT_MATCHED}:
            cands = [round(s["clock"], 1) for s in samples if 60 <= s["clock"] <= args.early]
            cands = sorted(set(cands))
            for i in range(len(cands) - 2):
                ws = [classify_window(samples, 0, cands[i + k] + 0.01, early_min)
                      for k in (0, 1, 2)]
                if not all(w["verdict"] == ew["verdict"] for w in ws):
                    continue
                w = ws[0]
                if w["partner"] is None:
                    continue
                if w["presence"].get(w["partner"], 0) * 10 < 30:
                    continue
                ready_at = cands[i]
                break
        ew["ready_at"] = ready_at
        windows["early"] = ew

    if role is not None and role < 4:
        for key in windows:
            windows[key]["verdict"] = VERDICT_NA_ROLE
            windows[key]["reason"] = "наша planner-role=%d < 4: canLastHit не гейтит, сценарий не тот" % role

    primary_key = "early" if args.early else "lh5"
    primary = windows[primary_key]["verdict"]
    metrics = compute_metrics(scores, fsl_lh)
    exposure = {"lh5": core_exposure(samples, 0, 300), "lh10": core_exposure(samples, 0, 600)}

    result = {
        "kind": "match", "host": args.host, "sp": args.sp,
        "session": sess["start"], "our": {"hero": hero, "role": role, "lane": our_lane},
        "n_scores": len(scores), "samples_total": len(samples),
        "samples": {"0-300": windows["lh5"]["n_samples"],
                    "0-600": windows["lh10"]["n_samples"]},
        "wall_span": ([samples[0]["wall"], samples[-1]["wall"]] if samples else None),
        "windows": windows, "exposure": exposure, "switches": switches,
        "lane_lines": [x for x in lane_lines if x["t"] <= args.max_clock],
        "metrics": metrics, "primary": primary_key,
        "acceptance": acceptance_block(primary, metrics, early=bool(args.early)),
    }
    result["verdict"] = primary
    return result


def print_match(r):
    print("== comp_filter: composition-matched отбор (read-only) ==")
    print("host:       %s" % r["host"])
    print("self_play:  %s" % r["sp"])
    print("session:    %s   | score-сэмплов: %d" % (r["session"], r["n_scores"]))
    our = r["our"]
    print("наш герой:  %s  role=%s  lane=%s" % (our["hero"], our["role"], our["lane"]))
    print("[fsl] сэмплов: %d (0-300: %d, 0-600: %d), wall %s..%s"
          % (r["samples_total"], r["samples"]["0-300"], r["samples"]["0-600"],
             (r["wall_span"] or ["-", "-"])[0], (r["wall_span"] or ["-", "-"])[1]))
    labels = {"lh5": "0-300s (окно LH@5)", "lh10": "0-600s (окно LH@10)"}
    if "early" in r["windows"]:
        labels["early"] = "0-%ds (ранний отбор)" % r["windows"]["early"]["window"][1]
    for key in ("early", "lh5", "lh10"):
        if key not in r["windows"]:
            continue
        w = r["windows"][key]
        print("")
        print("-- composition %s --" % labels[key])
        print("   verdict: %s%s" % (w["verdict"], ("  (" + w["reason"] + ")") if w["reason"] else ""))
        if key == "early" and w.get("ready_at") is not None:
            print("   (решение устойчиво с clock %.1f; можно прерывать матч при NOT-MATCHED)" % w["ready_at"])
        if w["presence"]:
            print("   присутствие settled-союзников в НАШЕЙ линии (10 с/сэмпл):")
            for name, cnt in w["presence"].items():
                role = w.get("roles", {}).get(name)
                cls = "support" if role is not None and role >= 4 else ("core" if role is not None else "?")
                print("     %-16s role=%-4s %-7s %2d сэмплов = %3d c" % (
                    name, role if role is not None else "?", cls, cnt, cnt * 10))
        if w.get("solo"):
            print("   (линия одиночная: settled-союзников в нашей линии нет)")
        if w.get("unstable"):
            dom = str(w.get("dominant_lane"))
            print("   линии в окне: %s; доминирующая линия = %s (%d/%d сэмплов)"
                  % (w["lanes"], dom, w["lanes"].get(dom, 0), w["n_samples"]))
    e5 = r["exposure"]["lh5"]
    e10 = r["exposure"]["lh10"]
    print("")
    print("-- прокси гейта (ядро рядом с нами; координат крипов в логах нет) --")
    for tag, e in (("0-300s", e5), ("0-600s", e10)):
        print("   %s: n=%d, <1200: %d (%s%%), <600: %d, median dmin=%s"
              % (tag, e["n"], e["lt1200"], e["pct_lt1200"], e["lt600"], e["median_dmin"]))
    if r["switches"]:
        print("")
        print("-- свичи линии ([fsl]) --")
        for s in r["switches"]:
            print("   t=%.1f %d->%d %s" % (s["clock"], s["from"], s["to"], s["reason"]))
    m = r["metrics"]
    print("")
    print("-- метрики (ground truth [SelfPlay score]) --")
    for tag in ("lh5", "lh10"):
        rec = m.get(tag)
        if rec:
            print("   %s: LH=%d denies=%d @ clock %.1f" % (tag, rec["lh"], rec["dn"], rec["clock"]))
        else:
            print("   %s: нет сэмпла" % tag)
    for tag in ("xp5", "xp10"):
        rec = m.get(tag)
        if rec:
            print("   %s: xp=%d @ clock %.1f" % (tag, rec["xp"], rec["clock"]))
    if m.get("final"):
        f = m["final"]
        print("   final: LH=%d denies=%d xp=%s hd=%s @ clock %.1f (последний score)"
              % (f["lh"], f["dn"], f["xp"], f["hd"], f["clock"]))
    print("")
    print("-- acceptance --")
    for name, verdict, detail in r["acceptance"]:
        print("   %-14s %-4s %s" % (name, verdict, detail))
    print("")
    print("ИТОГ: %s (exit=%d)" % (r["verdict"], exit_code(r["verdict"])))
    print("напоминание: LH@5>=6 сравнивается только на MATCHED (ACCEPTANCE_2026-11-23.md §10);")
    print("            NOT-MATCHED = гейт canLastHit активен, матч в зачёт не идёт.")
    return r


def exit_code(verdict):
    if verdict in MATCHED_SET:
        return 0
    if verdict == VERDICT_NOT_MATCHED:
        return 2
    return 3


# ---------------------------------------------------------------- reference
def analyze_reference(args):
    lines = load_lines(args.ref_log)
    sessions = split_sessions(lines)
    rows = []
    skipped = {"no_score": 0, "hero": 0, "date": 0}
    for sess in sessions:
        start = sess["start"]
        day = start.split(" ")[0]
        if args.ref_from and day < args.ref_from:
            skipped["date"] += 1
            continue
        if args.ref_to and day > args.ref_to:
            skipped["date"] += 1
            continue
        scores = parse_scores(sess["lines"])
        if not scores:
            skipped["no_score"] += 1
            continue
        hero = scores[0]["hero"]
        if args.ref_hero and hero != args.ref_hero:
            skipped["hero"] += 1
            continue
        lane_lines = parse_lane_lines(sess["lines"])
        lh5 = first_ge(scores, 300)
        lh10 = first_ge(scores, 600)
        evidence = None
        for x in lane_lines:
            m = RE_PARTNER.search(x["text"])
            if m and x["t"] <= 600:
                evidence = {"hero": m.group(1), "t": x["t"], "text": x["text"]}
                break
        if evidence is None:
            verdict, note = VERDICT_UNKNOWN, "support-партнёр в логе не назван"
        else:
            verdict = VERDICT_MATCHED
            note = "support-партнёр %s по причине свича t=%ds" % (evidence["hero"], evidence["t"])
        rows.append({
            "session": start, "hero": hero, "role": scores[0]["role"],
            "lane": scores[0]["lane"],
            "lh5": ({"lh": lh5["lh"], "clock": round(lh5["clock"], 1)} if lh5 else None),
            "lh10": ({"lh": lh10["lh"], "clock": round(lh10["clock"], 1)} if lh10 else None),
            "switch_evidence": evidence, "verdict": verdict, "note": note,
            "switches": [x for x in lane_lines if "switch" in x["text"] or "->" in x["text"]],
        })
    return {"kind": "reference", "ref_log": args.ref_log, "sessions": rows,
            "skipped": skipped}


def print_reference(r):
    print("== comp_filter --ref: эталонные сессии (self_play.prev.log) ==")
    print("ВНИМАНИЕ: в эталоне НЕТ roster-зонда; класс выводится только из причины свича")
    print("lane_choice ('<hero> already supports our lane'), т.е. evidence_t — момент свича.")
    print("")
    print("%-22s %-6s %-4s %-4s %-9s %-9s %s" % (
        "session", "hero", "role", "lane", "LH@5", "LH@10", "composition / evidence"))
    for row in r["sessions"]:
        hex_ = (row["hero"] or "").replace("npc_dota_hero_", "")[:10]
        lh5 = str(row["lh5"]["lh"]) if row["lh5"] else "-"
        lh10 = str(row["lh10"]["lh"]) if row["lh10"] else "-"
        ev = row["switch_evidence"]
        note = row["verdict"]
        if ev:
            note += " %s @%ds" % (ev["hero"], ev["t"])
        print("%-22s %-6s %-4s %-4s %-9s %-9s %s" % (
            row["session"], hex_, row["role"], row["lane"], lh5, lh10, note))
    matched = [x for x in r["sessions"] if x["verdict"] == VERDICT_MATCHED]
    print("")
    print("MATCHED (по evidence из свича): %d из %d сессий в выборке" % (len(matched), len(r["sessions"])))
    if r.get("skipped"):
        print("пропущено: %s" % r["skipped"])
    lm = [x["lh5"]["lh"] for x in matched if x["lh5"]]
    if lm:
        print("их LH@5: %s (медиана %s); для сравнения REFERENCE max = 6 (S1, после свича 1:37)" % (
            sorted(lm), median(lm)))
    print("")
    print("NB: classification по свичу — нижняя оценка; roster-зонд эталона не писался, поэтому")
    print("    для собственных прогонов используйте [fsl]-зонд (см. ACCEPTANCE §10.3).")


# ------------------------------------------------------------------ selftest
def _wall_at(base_sod, clock):
    t = int(round(base_sod + clock)) % L2.SECONDS_PER_DAY
    return "%02d:%02d:%02d" % (t // 3600, (t // 60) % 60, t % 60)


def _fsl_line(base_sod, clock, allies, role=4, lane=1):
    parts = ["*treant r=4 pos=-6000,0"]
    for name, r, ln, setv, pos in allies:
        parts.append("%s r=%s lane=%d set=%d pos=%d,%d" % (name, r, ln, setv, pos[0], pos[1]))
    return ("%s [fsl] clock=%.1f role=%d lane=%d ls=0 rr=1 | %s"
            " | counts=1/0/0 sup=1/0/0 core=1/0/0 supNames=-/- free=nil"
            % (_wall_at(base_sod, clock), clock, role, lane, " | ".join(parts)))


def _score_line(clock, lh):
    return ("[%d:%02d] [SelfPlay score] clock=%.1f hero=npc_dota_hero_treant role=4 lane=1"
            " lastHits=%d denies=0 networth=600 gold=0 xp=1000 heroDamage=0"
            % (int(clock) // 60, int(clock) % 60, clock, lh))


def _fixture(tmpdir, allies, lh5, with_fsl=True, role=4, lane=1):
    base = L2.seconds_of_day("03:00:00")
    host = []
    if with_fsl:
        for i in range(30):
            host.append(_fsl_line(base, i * 10 + 0.1, allies, role=role, lane=lane))
    sp = ["===== Self Play session 2026-11-23 03:00:00 ====="]
    for clock in (61, 121, 181, 241, 301, 361, 421, 481, 541, 601):
        sp.append(_score_line(clock, lh5 if clock >= 301 else 0))
    host_path = os.path.join(tmpdir, "host.log")
    sp_path = os.path.join(tmpdir, "self_play.log")
    with open(host_path, "w", encoding="utf-8") as f:
        f.write("\n".join(host) + "\n")
    with open(sp_path, "w", encoding="utf-8") as f:
        f.write("\n".join(sp) + "\n")
    return host_path, sp_path


def _check_midnight(tmpdir, allies, session_wall):
    base = L2.seconds_of_day(session_wall)
    clocks = list(range(-1, 620, 10))
    host = [_fsl_line(base - 120, -1, allies)]
    host.extend(_fsl_line(base, clock, allies) for clock in clocks)
    host.append(_fsl_line(base + 801, -1, allies))
    for clock, lh in ((301, 6), (601, 10), (801, 99)):
        host.append("%s [fsl lh] clock=%d lastHits=%d denies=0 networth=900 xp=1000 heroDamage=0"
                    % (_wall_at(base, clock), clock, lh))
    for clock in (121, 801):
        host.append("%s [fsl SWITCH] clock=%d lane=1->2 reason=fixture"
                    % (_wall_at(base, clock), clock))
    host_path = os.path.join(tmpdir, "host.log")
    sp_path = os.path.join(tmpdir, "self_play.log")
    with open(host_path, "w", encoding="utf-8") as f:
        f.write("\n".join(host) + "\n")
    with open(sp_path, "w", encoding="utf-8") as f:
        f.write("===== Self Play session 2026-11-24 %s =====\n" % session_wall)

    first, last = _wall_at(base, clocks[0]), _wall_at(base, clocks[-1])
    parsed = L2.parse_fsl_lines(host, wall_from=first, wall_to=last)
    args = argparse.Namespace(host=host_path, sp=sp_path, session=None, max_clock=700.0,
                              min_presence_sec=60, early=None)
    result = analyze_match(args)
    return ([sample["clock"] for sample in parsed] == clocks
            and result["wall_span"] == [first, last]
            and result["samples_total"] == len(clocks)
            and result["samples"] == {"0-300": 30, "0-600": 60}
            and result["verdict"] == VERDICT_MATCHED
            and result["windows"]["lh10"]["verdict"] == VERDICT_MATCHED
            and [switch["clock"] for switch in result["switches"]] == [121]
            and result["metrics"]["source"] == "fsl lh"
            and result["metrics"]["lh5"]["lh"] == 6
            and result["metrics"]["lh10"]["lh"] == result["metrics"]["final"]["lh"] == 10)


def run_selftest():
    """Проверка всех ветвей вердикта на синтетических логах (без записи в lotus)."""
    import argparse as _ap
    import tempfile

    support_lane1 = [("lion", "5", 1, 1, (-5900, 100)),
                     ("skeleton_king", "3", 3, 1, (-5000, 5000))]
    core_lane1 = [("skeleton_king", "3", 1, 1, (-5900, 100)),
                  ("lion", "5", 3, 1, (-5000, 5000))]
    solo = [("skeleton_king", "3", 3, 1, (-5000, 5000))]
    cases = [
        ("matched", support_lane1, 6, True, 4, None, VERDICT_MATCHED, 0),
        ("matched-solo", solo, 6, True, 4, None, VERDICT_MATCHED_SOLO, 0),
        ("not-matched", core_lane1, 0, True, 4, None, VERDICT_NOT_MATCHED, 2),
        ("not-matched-early", core_lane1, 0, True, 4, 120.0, VERDICT_NOT_MATCHED, 2),
        ("unknown-no-probe", core_lane1, 0, False, 4, None, VERDICT_UNKNOWN, 3),
        ("na-role", support_lane1, 0, True, 3, None, VERDICT_NA_ROLE, 3),
    ]
    ok_all = True
    for name, allies, lh5, with_fsl, role, early, want, want_exit in cases:
        with tempfile.TemporaryDirectory() as td:
            host, sp = _fixture(td, allies, lh5, with_fsl=with_fsl, role=role)
            args = _ap.Namespace(host=host, sp=sp, session=None, max_clock=900.0,
                                 min_presence_sec=60, early=early, json=None)
            try:
                r = analyze_match(args)
            except Exception as exc:  # noqa: BLE001
                print("SELFTEST %-18s ERROR %r" % (name, exc))
                ok_all = False
                continue
            got = r["verdict"]
            ok = got == want and exit_code(got) == want_exit
            detail = ""
            if name == "matched":
                acc = dict((n, v) for n, v, _ in r["acceptance"])
                detail = " LH@5=%s" % acc.get("LH@5 >= 6")
                ok = ok and acc.get("LH@5 >= 6") == "PASS"
            print("SELFTEST %-18s want=%-12s got=%-12s exit=%d %s%s"
                  % (name, want, got, exit_code(got), "PASS" if ok else "FAIL", detail))
            ok_all = ok_all and ok
    for session_wall in ("23:59:00", "00:00:00"):
        with tempfile.TemporaryDirectory() as td:
            ok = _check_midnight(td, support_lane1, session_wall)
            print("SELFTEST midnight %s %s" % (session_wall, "PASS" if ok else "FAIL"))
            ok_all = ok_all and ok
    print("SELFTEST: %s" % ("all PASS" if ok_all else "FAIL"))
    return 0 if ok_all else 1


# -------------------------------------------------------------------- main
def main(argv=None):
    p = argparse.ArgumentParser(
        description="Composition filter: LH@5>=6 valid only on composition-matched runs "
                    "(partner-support; canLastHit stays reference).")
    p.add_argument("--host", default=DEF_HOST, help="host-лог с [fsl]-зондом")
    p.add_argument("--sp", default=DEF_SP, help="self_play-лог (сессии [SelfPlay score])")
    p.add_argument("--session", default=None, help="префикс/подстрока времени сессии")
    p.add_argument("--max-clock", type=float, default=900.0, help="обрезка сэмплов по clock")
    p.add_argument("--min-presence-sec", type=int, default=60,
                   help="минимум секунд settled-присутствия partner в нашей линии")
    p.add_argument("--early", type=float, default=None,
                   help="ранний режим: классифицировать по первым SEC секундам (abort)")
    p.add_argument("--json", default=None, help="куда сохранить результат (UTF-8 JSON)")
    p.add_argument("--ref", action="store_true", help="режим эталонных сессий")
    p.add_argument("--ref-log", default=DEF_REF, help="эталонный self_play.prev.log")
    p.add_argument("--ref-from", default=None, help="ref: с даты YYYY-MM-DD (вкл.)")
    p.add_argument("--ref-to", default=None, help="ref: по дату YYYY-MM-DD (вкл.)")
    p.add_argument("--ref-hero", default="npc_dota_hero_treant",
                   help="ref: фильтр героя ('' = все); по умолчанию Treant")
    p.add_argument("--selftest", action="store_true",
                   help="проверить все ветви вердикта на синтетических логах и выйти")
    args = p.parse_args(argv)

    if args.selftest:
        return run_selftest()

    if args.ref:
        result = analyze_reference(args)
        print_reference(result)
        if args.json:
            with open(args.json, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=1)
            print("wrote %s" % args.json)
        return 0

    if not os.path.exists(args.host):
        raise SystemExit("нет host-лога: %s" % args.host)
    if not os.path.exists(args.sp):
        raise SystemExit("нет self_play-лога: %s" % args.sp)
    result = analyze_match(args)
    print_match(result)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=1)
        print("wrote %s" % args.json)
    return exit_code(result["verdict"])


if __name__ == "__main__":
    sys.exit(main())
