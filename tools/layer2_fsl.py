#!/usr/bin/env python3
"""Layer-2 (canLastHit / positioning) extraction for archive/20261123_fsl.

Reads:
  - D:/hake/lotus/archive/20261123_fsl/self_play.log.fsl  (session 2026-11-23 02:31:30)
  - D:/hake/lotus/archive/20261123_fsl/host.log.fsl       ([fsl] roster probe, run 3)
  - C:/Users/USER/AppData/Roaming/xYjGsPeqoWTEzbif/self_play.prev.log (S26/S1 reference)

Writes:
  - archive/20261123_fsl/layer2_data.json
  - archive/20261123_fsl/layer2_stats.txt

No log/script is modified.
"""
import json
import math
import os
import re
import statistics as st

ROOT = r"D:\hake\lotus"
FSL = os.path.join(ROOT, "archive", "20261123_fsl")
SP = os.path.join(FSL, "self_play.log.fsl")
HOST = os.path.join(FSL, "host.log.fsl")
PREV = r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
OUT_JSON = os.path.join(FSL, "layer2_data.json")
OUT_TXT = os.path.join(FSL, "layer2_stats.txt")
SECONDS_PER_DAY = 24 * 60 * 60

PRE = r"^\[(-?\d+):(\d\d)\]"
RE_SCORE = re.compile(PRE + r" \[SelfPlay score\] clock=([-\d.]+) .*?lastHits=(\d+) denies=(\d+) .*?xp=(\d+) heroDamage=(\d+) laneGold=(\d+)")
RE_MODE = re.compile(PRE + r" \[SelfPlay\] role=(\d+) lane=(-?\d+) mode=(.*?) hp=([\d.]+) pos=(-?\d+),(-?\d+) busy=([\d.]+) attacks=(\d+) cancelled=(\d+).*?order=(\w+)")
RE_LH = re.compile(PRE + r" \[SelfPlay last hit\] target=(\S+) hp=(\d+) damage=(\d+) events=(\d+) start=(-?[\d.]+) impact=(-?[\d.]+) approach=(-?[\d.]+) inRange=(true|false)")
RE_STATS = re.compile(PRE + r" \[SelfPlay last hit stats\] \d+s: (\d+) enemy creeps died near us \((\d+) in reach\) -> ours (\d+), our creeps/tower (\d+), ally heroes (\d+), enemy heroes (\d+); denies (\d+), enemy denies (\d+); attempts (\d+)")
RE_ACT = re.compile(PRE + r" \[SelfPlay actions\] time=([\d.]+) target=(\S+) lock=(\S+) creepAggro=(\S+) candidates=(\d+) lastSwing=(\S+)")
RE_LANE = re.compile(PRE + r" \[SelfPlay lane\] (.*)$")
RE_FSL = re.compile(r"^(\d\d):(\d\d):(\d\d) \[fsl\] clock=([-\d.]+) role=(-?\d+) lane=(-?\d+) ls=(-?\d+) rr=(\d) \| (.*?) \| counts=(\d+)/(\d+)/(\d+) sup=(\d+)/(\d+)/(\d+) core=(\d+)/(\d+)/(\d+) supNames=(\S+)/(\S+) free=(\S+)")
RE_ALLY = re.compile(r"(\w+) r=(\S+) lane=(\S+) set=(\d) pos=(?:(-?\d+),(-?\d+)|nil)")
RE_SELF = re.compile(r"\*(\w+) r=(\S+) pos=(?:(-?\d+),(-?\d+)|nil)")


def ts(m):
    """[mm:ss] prefix -> seconds."""
    mm, ss = int(m.group(1)), int(m.group(2))
    return mm * 60 + ss


def read_lines(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def split_sessions(lines):
    out, cur = [], None
    for i, l in enumerate(lines):
        m = re.match(r"===== Self Play session (.+) =====", l)
        if m:
            cur = {"start": m.group(1).strip(), "from": i, "lines": []}
            out.append(cur)
        elif cur is not None:
            cur["lines"].append(l)
    return out


def parse_session(sess):
    d = {"start": sess["start"], "score": [], "mode": [], "lh": [], "stats": [], "actions": [], "lane": []}
    for l in sess["lines"]:
        m = RE_SCORE.match(l)
        if m:
            d["score"].append({"t": ts(m), "clock": float(m.group(3)), "lh": int(m.group(4)),
                               "dn": int(m.group(5)), "xp": int(m.group(6)), "hd": int(m.group(7)),
                               "laneGold": int(m.group(8))})
            continue
        m = RE_MODE.match(l)
        if m:
            d["mode"].append({"t": ts(m), "role": int(m.group(3)), "lane": int(m.group(4)),
                              "mode": m.group(5), "hp": float(m.group(6)),
                              "x": int(m.group(7)), "y": int(m.group(8)),
                              "attacks": int(m.group(10)), "order": m.group(12)})
            continue
        m = RE_LH.match(l)
        if m:
            d["lh"].append({"t": ts(m), "target": m.group(3), "hp": int(m.group(4)),
                            "damage": int(m.group(5)), "events": int(m.group(6)),
                            "start": float(m.group(7)), "impact": float(m.group(8)),
                            "approach": float(m.group(9)), "inRange": m.group(10) == "true"})
            continue
        m = RE_STATS.match(l)
        if m:
            d["stats"].append({"t": ts(m), "died_near": int(m.group(3)), "in_reach": int(m.group(4)),
                               "ours": int(m.group(5)), "our_creeps": int(m.group(6)),
                               "ally_heroes": int(m.group(7)), "enemy_heroes": int(m.group(8)),
                               "denies": int(m.group(9)), "enemy_denies": int(m.group(10)),
                               "attempts": int(m.group(11))})
            continue
        m = RE_ACT.match(l)
        if m:
            d["actions"].append({"t": ts(m), "target": m.group(4), "candidates": int(m.group(7))})
            continue
        m = RE_LANE.match(l)
        if m:
            d["lane"].append({"t": ts(m), "text": m.group(3)})
    return d


def seconds_of_day(wall):
    """Convert HH:MM:SS to seconds since midnight."""
    h, m, s = (int(part) for part in wall.split(":"))
    return h * 3600 + m * 60 + s


def wall_on_or_after(seconds, start):
    """Place an undated host timestamp on the timeline starting at start."""
    return start + (seconds - start) % SECONDS_PER_DAY


def parse_fsl_lines(lines, wall_from="02:31:25", wall_to="02:45:00"):
    """Read [fsl] rosters in an inclusive wall-clock window.

    Bounds can be HH:MM:SS strings or seconds relative to session midnight.
    An end given as HH:MM:SS can fall on the next day.
    """
    if isinstance(wall_from, str):
        wall_from = seconds_of_day(wall_from)
    if isinstance(wall_to, str):
        wall_to = wall_on_or_after(seconds_of_day(wall_to), wall_from)
    out = []
    for l in lines:
        m = RE_FSL.match(l)
        if not m:
            continue
        wall = "%s:%s:%s" % (m.group(1), m.group(2), m.group(3))
        if wall_on_or_after(seconds_of_day(wall), wall_from) > wall_to:
            continue
        clock = float(m.group(4))
        if clock < -2:
            continue
        roster = {}
        for sm in RE_ALLY.finditer(m.group(9)):
            roster[sm.group(1)] = {"role": sm.group(2),
                                   "lane": (None if sm.group(3) in ("-", "nil") else int(sm.group(3))),
                                   "set": int(sm.group(4)),
                                   "x": (None if sm.group(5) is None else int(sm.group(5))),
                                   "y": (None if sm.group(6) is None else int(sm.group(6)))}
        selfm = RE_SELF.search(m.group(9))
        rec = {"wall": wall, "clock": clock, "role": int(m.group(5)), "lane": int(m.group(6)),
               "ls": int(m.group(7)), "rr": int(m.group(8)), "roster": roster,
               "counts": [int(m.group(i)) for i in (10, 11, 12)],
               "sup": [int(m.group(i)) for i in (13, 14, 15)],
               "core": [int(m.group(i)) for i in (16, 17, 18)],
               "supNames": [m.group(19), m.group(20)],
               "free": m.group(21),
               "self": (None if not selfm else {"name": selfm.group(1),
                                                "x": None if selfm.group(3) is None else int(selfm.group(3)),
                                                "y": None if selfm.group(4) is None else int(selfm.group(4))})}
        out.append(rec)
    return out


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def join_treant_sk(treant_samples, fsl_samples, max_dt=6.0):
    """Nearest [fsl] sample in clock for each Treant position; returns SK distance rows."""
    rows = []
    for tr in treant_samples:
        best, bdt = None, 1e9
        for f in fsl_samples:
            dt = abs(f["clock"] - tr["clock"])
            if dt < bdt:
                best, bdt = f, dt
        if best is None or bdt > max_dt:
            continue
        sk = best["roster"].get("skeleton_king")
        rec = {"clock": tr["clock"], "treant": (tr["x"], tr["y"]), "dt": bdt,
               "sk": (None if not sk or sk["x"] is None else (sk["x"], sk["y"])),
               "sk_lane": None if not sk else sk["lane"],
               "sk_set": None if not sk else sk["set"],
               "sk_role": None if not sk else sk["role"],
               "sk_present": sk is not None and sk["x"] is not None,
               "treant_lane": tr["lane"], "mode": tr["mode"]}
        if rec["sk"]:
            rec["d_sk_treant"] = round(dist(rec["treant"], rec["sk"]), 1)
        rows.append(rec)
    return rows


def window_stats(rows, lo, hi):
    sel = [r for r in rows if lo <= r["clock"] < hi]
    ds = [r["d_sk_treant"] for r in sel if r.get("d_sk_treant") is not None]
    absent = sum(1 for r in sel if not r["sk_present"])
    return {"n": len(sel), "n_with_sk": len(ds), "sk_absent": absent,
            "min": min(ds) if ds else None, "median": st.median(ds) if ds else None,
            "mean": round(sum(ds) / len(ds), 1) if ds else None,
            "max": max(ds) if ds else None,
            "lt1200": sum(1 for d in ds if d < 1200), "lt600": sum(1 for d in ds if d < 600),
            "ge1200": sum(1 for d in ds if d >= 1200)}


def per_minute(rows, lo, hi, step=60):
    out = []
    t = lo
    while t < hi:
        sel = [r for r in rows if t <= r["clock"] < t + step]
        ds = [r["d_sk_treant"] for r in sel if r.get("d_sk_treant") is not None]
        out.append({"lo": t, "hi": t + step, "n": len(sel),
                    "sk_absent": sum(1 for r in sel if not r["sk_present"]),
                    "median": round(st.median(ds), 1) if ds else None,
                    "min": min(ds) if ds else None, "max": max(ds) if ds else None,
                    "lt1200": sum(1 for d in ds if d < 1200), "n_d": len(ds)})
        t += step
    return out


def stats_sum(d, lo, hi):
    sel = [s for s in d["stats"] if lo <= s["t"] < hi]
    return {"n_lines": len(sel),
            "died_near": sum(s["died_near"] for s in sel),
            "in_reach": sum(s["in_reach"] for s in sel),
            "ours": sum(s["ours"] for s in sel),
            "attempts": sum(s["attempts"] for s in sel),
            "denies": sum(s["denies"] for s in sel),
            "enemy_denies": sum(s["enemy_denies"] for s in sel)}


def lh_split(d, lo, hi):
    sel = [x for x in d["lh"] if lo <= x["t"] < hi]
    enemy = [x for x in sel if "badguys" in x["target"]]
    allied = [x for x in sel if "goodguys" in x["target"]]
    return {"n": len(sel), "enemy": len(enemy), "allied": len(allied),
            "inRange": sum(1 for x in sel if x["inRange"]),
            "enemy_inRange": sum(1 for x in enemy if x["inRange"]),
            "targets": [x["target"] for x in sel]}


def lh_delta(d, lo, hi):
    pts = [x for x in d["score"] if lo <= x["clock"] <= hi]
    if len(pts) < 2:
        return None
    return pts[-1]["lh"] - pts[0]["lh"]


def summarize(name, d, lo=0, hi=700, do_print=True):
    sc = [x for x in d["score"] if lo <= x["clock"] <= hi]
    lines = []
    lines.append("== %s ==" % name)
    lines.append("score samples=%d  first=%s  last=%s" % (len(sc), sc[0]["clock"] if sc else None,
                                                          sc[-1]["clock"] if sc else None))
    if sc:
        lines.append("LH timeline: " + ", ".join("%.0f:%d/%d" % (x["clock"], x["lh"], x["dn"]) for x in sc))
    for a, b, label in ((0, 300, "0-300"), (300, 600, "300-600"), (600, 700, "600-700")):
        s = stats_sum(d, a, b)
        lh = lh_split(d, a, b)
        delta = lh_delta(d, a, b)
        conv = ("%.0f%%" % (100.0 * s["ours"] / s["in_reach"])) if s["in_reach"] else "n/a"
        lines.append("%s: in_reach=%d ours=%d conv=%s died_near=%d | last_hit lines=%d (enemy=%d, allied=%d; enemy inRange=%d) | LH delta=%s | attempts=%d denies=%d"
                     % (label, s["in_reach"], s["ours"], conv, s["died_near"], lh["n"], lh["enemy"],
                        lh["allied"], lh["enemy_inRange"], delta, s["attempts"], s["denies"]))
    lane = d["lane"]
    lines.append("lane lines: " + (" ; ".join("[%d] %s" % (x["t"], x["text"]) for x in lane) or "none"))
    modes = {}
    for m in d["mode"]:
        modes[m["mode"]] = modes.get(m["mode"], 0) + 1
    top = sorted(modes.items(), key=lambda kv: -kv[1])[:8]
    lines.append("top modes: " + " | ".join("%s=%d" % (k, v) for k, v in top))
    if do_print:
        print("\n".join(lines))
    return lines


def main():
    report = []
    print("Reading logs...")
    sp_lines = read_lines(SP)
    host_lines = read_lines(HOST)

    sess = split_sessions(sp_lines)
    print("self_play sessions:", [(s["start"], len(s["lines"])) for s in sess])
    target = [s for s in sess if s["start"].startswith("2026-11-23 02:31:30")][0]
    d3 = parse_session(target)
    fsl = parse_fsl_lines(host_lines)
    print("fsl samples:", len(fsl), "first clock", fsl[0]["clock"] if fsl else None,
          "last clock", fsl[-1]["clock"] if fsl else None)

    # Treant samples with positions = [SelfPlay] mode lines
    treant = [{"t": m["t"], "clock": m["t"], "x": m["x"], "y": m["y"], "lane": m["lane"],
               "mode": m["mode"], "order": m["order"]} for m in d3["mode"]]
    rows = join_treant_sk(treant, fsl)
    print("joined rows:", len(rows))

    # LH windows: last score with lh=0 and first with lh=1
    lh1 = next((x["clock"] for x in d3["score"] if x["lh"] >= 1), None)
    lh0_last = max((x["clock"] for x in d3["score"] if x["lh"] == 0), default=None)
    print("first LH>=1 at clock", lh1, "| last LH==0 sample at", lh0_last)

    w0 = window_stats(rows, 0, lh0_last + 1)
    w1 = window_stats(rows, lh1, 700)
    pm = per_minute(rows, 0, 700)

    report.append("########## FSL run 3 (session 2026-11-23 02:31:30, Treant role4 lane1) ##########")
    report.append("SK=[Skeleton King] available only in [fsl] roster probe (10 s cadence); creep coordinates")
    report.append("are not recorded anywhere in the archive -> SK->creep cannot be measured directly.")
    report.append("Measured: SK position, Treant position (each decision tick), LH/deny counters (10 s),")
    report.append("last-hit decisions, per-60s 'in reach' vs 'ours' counter.")
    report.append("")
    report.append("LH window boundary: last score LH=0 at clock %s; first score LH>=1 at clock %s" % (lh0_last, lh1))
    report.append("")
    report.append("SK->Treant distance, LH=0 window [0, %s): %s" % (lh0_last, json.dumps(w0)))
    report.append("SK->Treant distance, LH>0 window [%s, 700): %s" % (lh1, json.dumps(w1)))
    report.append("")
    report.append("per-minute: clock | n | sk_absent | median d(SK,Treant) | min | max | <1200/n")
    for b in pm:
        report.append("%4d-%4d | %2d | %d | %s | %s | %s | %d/%d" %
                      (b["lo"], b["hi"], b["n"], b["sk_absent"], b["median"], b["min"], b["max"],
                       b["lt1200"], b["n_d"]))
    report.append("")
    report.append("LH-delta per minute (score samples):")
    sc = d3["score"]
    for a, b in zip(sc, sc[1:]):
        report.append("  %5.1f -> %5.1f  LH %d->%d (dn %d->%d)  xp=%d hd=%d laneGold=%d"
                      % (a["clock"], b["clock"], a["lh"], b["lh"], a["dn"], b["dn"], b["xp"], a["hd"], a["laneGold"]))
    report.append("")
    report.append("\n".join(summarize("FSL run3", d3)))

    # last-hit decisions detail
    report.append("")
    report.append("last-hit decisions (session 3):")
    for x in d3["lh"]:
        report.append("  [%4d] %-38s hp=%3d dmg=%3d ev=%2d inRange=%-5s start=%.2f impact=%.2f approach=%.2f"
                      % (x["t"], x["target"], x["hp"], x["damage"], x["events"],
                         str(x["inRange"]).lower(), x["start"], x["impact"], x["approach"]))
    report.append("")
    report.append("last-hit stats lines (session 3):")
    for s in d3["stats"]:
        report.append("  [%4d] died_near=%2d in_reach=%d ours=%d attempts=%d denies=%d enemy_denies=%d"
                      % (s["t"], s["died_near"], s["in_reach"], s["ours"], s["attempts"], s["denies"], s["enemy_denies"]))
    report.append("")
    report.append("fsl roster samples around LH transition (clock>=480):")
    for f in fsl:
        if f["clock"] >= 480:
            sk = f["roster"].get("skeleton_king")
            report.append("  %s clock=%6.1f lane=%d free=%s | SK=%s | counts=%s core=%s sup=%s"
                          % (f["wall"], f["clock"], f["lane"], f["free"],
                             json.dumps(sk), f["counts"], f["core"], f["sup"]))

    # ---------- reference S26 / S1 ----------
    prev = read_lines(PREV)
    rsess = split_sessions(prev)
    refs = {}
    for tag, start in (("S26", "2026-11-17 01:04:57"), ("S1", "2026-11-16 03:12:52")):
        cand = [s for s in rsess if s["start"].startswith(start)]
        if not cand:
            report.append("MISSING reference session " + start)
            continue
        d = parse_session(cand[0])
        refs[tag] = d
        report.append("")
        report.append("########## reference %s (session %s) ##########" % (tag, start))
        report.append("\n".join(summarize(tag, d, do_print=False)))
        report.append("score samples: " + ", ".join("%.0f:%d/%d" % (x["clock"], x["lh"], x["dn"]) for x in d["score"][:30]))
        report.append("last-hit decisions: n=%d" % len(d["lh"]))
        for x in d["lh"][:40]:
            report.append("  [%4d] %-38s hp=%3d dmg=%3d inRange=%-5s approach=%.2f"
                          % (x["t"], x["target"], x["hp"], x["damage"], str(x["inRange"]).lower(), x["approach"]))
        report.append("stats lines:")
        for s in d["stats"]:
            report.append("  [%4d] died_near=%2d in_reach=%d ours=%d attempts=%d denies=%d"
                          % (s["t"], s["died_near"], s["in_reach"], s["ours"], s["attempts"], s["denies"]))

    data = {"fsl_session3": d3, "fsl_samples": fsl, "join_rows": rows,
            "windows": {"lh0": [0, lh0_last + 1], "lh1": [lh1, 700],
                        "stats_lh0": w0, "stats_lh1": w1}, "per_minute": pm,
            "refs": refs}
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    with open(OUT_TXT, "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")
    print("\n".join(report[-12:]))
    print("\nwrote", OUT_TXT, OUT_JSON)


if __name__ == "__main__":
    main()
