#!/usr/bin/env python3
"""Focused layer-2 tables from the extraction in layer2_fsl.py.

Outputs: archive/20261123_fsl/layer2_tables.txt
"""
import json
import math
import os
import statistics as st

import layer2_fsl as L

ROOT = r"D:\hake\lotus"
FSL = os.path.join(ROOT, "archive", "20261123_fsl")
OUT = os.path.join(FSL, "layer2_tables.txt")

# Treant base/with-boots move speed brackets for approach->distance reconstruction
SPEEDS = (285, 300, 325)
TREANT_RANGE = 150  # melee
REACH = 350         # last_hit.died(): attack range + bonus + 200
GATE = 1200


def fmt(v, nd=0):
    if v is None:
        return "-"
    return ("%." + str(nd) + "f") % v


def main():
    out = []

    def w(s=""):
        out.append(s)

    sp = L.read_lines(L.SP)
    host = L.read_lines(L.HOST)
    sess = [s for s in L.split_sessions(sp) if s["start"].startswith("2026-11-23 02:31:30")][0]
    d = L.parse_session(sess)
    fsl = L.parse_fsl_lines(host)
    treant = [{"t": m["t"], "clock": m["t"], "x": m["x"], "y": m["y"], "lane": m["lane"],
               "mode": m["mode"], "order": m["order"], "attacks": m["attacks"]} for m in d["mode"]]
    rows = L.join_treant_sk(treant, fsl)
    by_clock = {}
    for r in rows:
        by_clock.setdefault(r["clock"], r)

    def d_at(clock, tol=6.0):
        cand = [r for r in rows if abs(r["clock"] - clock) <= tol and r.get("d_sk_treant") is not None]
        if not cand:
            return None
        return min(cand, key=lambda r: abs(r["clock"] - clock))

    # ---------- 1. per-minute table ----------
    w("###### 1. FSL run3 per-minute (Treant role4 lane1; SK role3 lane1) ######")
    w("%-7s %5s %5s %6s %8s %7s %7s %7s %6s %5s %5s %5s %6s" % (
        "clock", "lane", "SKln", "SKset", "d_med", "d_min", "d_max", "<850", "<1200", "n", "inR", "ours", "LHd"))
    sc = d["score"]
    for m in range(0, 12):
        lo, hi = m * 60, (m + 1) * 60
        sel = [r for r in rows if lo <= r["clock"] < hi]
        ds = [r["d_sk_treant"] for r in sel if r.get("d_sk_treant") is not None]
        sts = L.stats_sum(d, lo, hi)
        lane = None
        for r in sel:
            if r["treant_lane"]:
                lane = r["treant_lane"]
                break
        sk = next((r for r in sel if r["sk"]), None)
        d1 = L.lh_delta(d, lo, hi + 1)
        w("%3d-%-3d %5s %5s %6s %8s %7s %7s %7s %6d %5d %5d %5d %6s" % (
            lo, hi, lane, sk["sk_lane"] if sk else "-", sk["sk_set"] if sk else "-",
            fmt(st.median(ds)) if ds else "-", fmt(min(ds)) if ds else "-", fmt(max(ds)) if ds else "-",
            sum(1 for x in ds if x < 850), sum(1 for x in ds if x < GATE), len(sel),
            sts["in_reach"], sts["ours"], d1))
    w("")
    w("Legend: d_med/d_min/d_max = SK->Treant distance over [fsl] samples in the minute (world units).")
    w("<850 = samples where every creep within Treant reach (<=350) is provably <1200 from SK -> gate CANNOT pass.")
    w("inR = enemy creeps that died within 350 of Treant (last_hit.stats), ours = those with our hero as last source.")
    w("LHd = lastHits delta from [SelfPlay score] within the minute.")
    w("")

    # ---------- 2. anchored decision distances ----------
    w("###### 2. Anchored distances at [SelfPlay last hit] decisions ######")
    w("%5s %-36s %8s %-6s %8s %7s | %-28s | SK->creep interval" % (
        "clock", "target", "approach", "inRng", "d_T->c", "d_SK->T", "at fsl / dt"))
    for x in d["lh"]:
        r = d_at(x["t"])
        dst = r["d_sk_treant"] if r else None
        dt = r["dt"] if r else None
        if x["inRange"]:
            dtc = "<=%d" % REACH
            lo = max(0, (dst or 0) - REACH)
            hi = (dst or 0) + REACH
        else:
            dtc = "/".join(fmt(x["approach"] * s + TREANT_RANGE - 35) for s in SPEEDS)
            lo, hi = None, None
        interval = "%s..%s" % (fmt(lo), fmt(hi)) if lo is not None else "n/a (target not in reach)"
        src = "%s/%s" % (fmt(dst), fmt(dt, 1)) if r else "-"
        w("%5d %-36s %8.2f %-6s %8s %7s | %-28s | %s" % (
            x["t"], x["target"], x["approach"], str(x["inRange"]).lower(), dtc, fmt(dst), src, interval))
    w("")
    w("d_T->c = Treant->creep distance reconstructed from approach*speed+range-35 (speed brackets 285/300/325).")
    w("SK->creep interval only where target is in attack range (<=350), else direction is unknown -> no interval.")
    w("")
    w("Distances at the [SelfPlay last hit stats] sampling clocks and at the single enemy decision:")
    for clk in (149, 210, 273, 336, 401, 564, 586, 624, 644):
        r = d_at(clk)
        if r:
            w("  clock=%4d  d(SK,Treant)=%7s (dt %.1f)  SK=%s  Treant=(%.0f,%.0f)  mode=%s" % (
                clk, fmt(r["d_sk_treant"]), r["dt"], r["sk"], r["treant"][0], r["treant"][1], r["mode"]))
        else:
            w("  clock=%4d  no fsl sample within 6 s" % clk)
    w("")

    # ---------- 3. LH accrual intervals ----------
    w("###### 3. LH accrual intervals (score deltas) with decision/counter context ######")
    for a, b in zip(sc, sc[1:]):
        if b["lh"] <= a["lh"] and b["dn"] <= a["dn"]:
            continue
        lines = [x for x in d["lh"] if a["clock"] <= x["t"] <= b["clock"]]
        enemy = [x for x in lines if "badguys" in x["target"]]
        sts = L.stats_sum(d, a["clock"], b["clock"])
        ds = [r["d_sk_treant"] for r in rows if a["clock"] <= r["clock"] <= b["clock"] and r.get("d_sk_treant") is not None]
        w("  %5.1f -> %5.1f : LH %d->%d (+%d), denies %d->%d | decisions=%d (enemy=%d) | in_reach=%d ours=%d | d(SK,T) median=%s min=%s" % (
            a["clock"], b["clock"], a["lh"], b["lh"], b["lh"] - a["lh"], a["dn"], b["dn"],
            len(lines), len(enemy), sts["in_reach"], sts["ours"],
            fmt(st.median(ds)) if ds else "-", fmt(min(ds)) if ds else "-"))
        for x in enemy:
            w("       enemy decision @%d: %s inRange=%s approach=%.2f" % (x["t"], x["target"], str(x["inRange"]).lower(), x["approach"]))
    w("")

    # ---------- 4. exposure / mode time ----------
    w("###### 4. Treant time share by mode class per minute (decision-tick lines) ######")
    def cls(mode):
        if mode.startswith("Support lane: deny and protect") or mode.startswith("Stop short"):
            return "support_lane"
        if "Dead" in mode or "respawn" in mode.lower():
            return "dead"
        if "Fight" in mode or "fight" in mode or "Kill" in mode or "Approach enemy" in mode:
            return "fight"
        if "Break enemy contact" in mode or "Regenerate" in mode or "Retreat" in mode or "retreat" in mode:
            return "retreat/regen"
        if "Last hit" in mode:
            return "last_hit"
        return "other"
    classes = {}
    for m in d["mode"]:
        classes.setdefault(m["t"] // 60, {}).setdefault(cls(m["mode"]), 0)
        classes[m["t"] // 60][cls(m["mode"])] += 1
    w("%-7s %8s %8s %8s %8s %8s %8s" % ("clock", "support", "dead", "fight", "retreat", "lasthit", "other"))
    for mm in range(0, 12):
        c = classes.get(mm, {})
        tot = sum(c.values()) or 1
        w("%3d-%-3d %7.0f%% %7.0f%% %7.0f%% %7.0f%% %7.0f%% %7.0f%%" % (
            mm * 60, mm * 60 + 60,
            100.0 * c.get("support_lane", 0) / tot, 100.0 * c.get("dead", 0) / tot,
            100.0 * c.get("fight", 0) / tot, 100.0 * c.get("retreat/regen", 0) / tot,
            100.0 * c.get("last_hit", 0) / tot, 100.0 * c.get("other", 0) / tot))
    w("")
    w("Non-support modes with counts: " + ", ".join(
        "%s=%d" % (k, sum(1 for m in d["mode"] if m["mode"] == k)) for k in
        sorted({m["mode"] for m in d["mode"]}, key=lambda k: -sum(1 for m in d["mode"] if m["mode"] == k))[:20]))
    w("")

    # ---------- 5. reference comparison ----------
    w("###### 5. Reference comparison (same extraction) ######")
    prev = L.read_lines(L.PREV)
    rsess = L.split_sessions(prev)
    w("%-6s %-8s %6s %6s %7s %7s %7s %7s %7s %7s" % (
        "ref", "window", "inR", "ours", "conv", "dec", "enemyDec", "LHd", "near", "diedNear"))
    for tag, start in (("S26", "2026-11-17 01:04:57"), ("S1", "2026-11-16 03:12:52")):
        cand = [s for s in rsess if s["start"].startswith(start)]
        if not cand:
            continue
        rd = L.parse_session(cand[0])
        for lo, hi in ((0, 300), (300, 600), (600, 700), (0, 600)):
            sts = L.stats_sum(rd, lo, hi)
            lh = L.lh_split(rd, lo, hi)
            dl = L.lh_delta(rd, lo, hi)
            conv = ("%.0f%%" % (100.0 * sts["ours"] / sts["in_reach"])) if sts["in_reach"] else "n/a"
            w("%-6s %3d-%-4d %6d %6d %7s %7d %7d %7s %7d %7d" % (
                tag, lo, hi, sts["in_reach"], sts["ours"], conv, lh["n"], lh["enemy"], dl,
                sts["died_near"] - sts["in_reach"], sts["died_near"]))
    # ours for same windows
    w("")
    w("FSL run3 rows:")
    for lo, hi in ((0, 300), (300, 600), (600, 700), (0, 600)):
        sts = L.stats_sum(d, lo, hi)
        lh = L.lh_split(d, lo, hi)
        dl = L.lh_delta(d, lo, hi)
        conv = ("%.0f%%" % (100.0 * sts["ours"] / sts["in_reach"])) if sts["in_reach"] else "n/a"
        w("%-6s %3d-%-4d %6d %6d %7s %7d %7d %7s %7d %7d" % (
            "FSL3", lo, hi, sts["in_reach"], sts["ours"], conv, lh["n"], lh["enemy"], dl,
            sts["died_near"] - sts["in_reach"], sts["died_near"]))
    w("")
    w("dec = [SelfPlay last hit] decision lines; enemyDec = those on npc_dota_creep_badguys_*;")
    w("LHd = score lastHits delta; near = enemy creeps that died 350..1000 from Treant; diedNear = 0..1000.")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print("\n".join(out))
    print("\nwrote", OUT)


if __name__ == "__main__":
    main()