#!/usr/bin/env python3
"""Cross-session decision/attack/mode comparison for the layer-2 report."""
import sys
from collections import Counter

sys.path.insert(0, r"D:\hake\lotus\tools")
import layer2_fsl as L


def summarize(name, d):
    print("==", name, "==")
    dec = d["lh"]
    enemy = [x for x in dec if "badguys" in x["target"]]
    allied = [x for x in dec if "goodguys" in x["target"]]
    first_enemy = next((x["t"] for x in enemy), None)
    print(" decisions:", len(dec), "enemy:", len(enemy), "allied:", len(allied),
          "first_enemy_dec:", first_enemy)
    for lo, hi in ((0, 300), (300, 600), (600, 700)):
        sub = [x for x in dec if lo <= x["t"] < hi]
        se = [x for x in sub if "badguys" in x["target"]]
        print("  %d-%d: dec=%d enemy=%d" % (lo, hi, len(sub), len(se)))
    tgt = Counter()
    for a in d["actions"]:
        t = a["target"]
        if t == "none":
            tgt["none"] += 1
        elif "hero" in t:
            tgt["hero"] += 1
        elif "goodguys" in t:
            tgt["allied creep"] += 1
        elif "badguys" in t:
            tgt["enemy creep"] += 1
        else:
            tgt["other"] += 1
    print(" attack targets:", dict(tgt), "| actions cand>0:", sum(1 for a in d["actions"] if a["candidates"] > 0))
    modes = Counter(m["mode"] for m in d["mode"])
    print(" mode total lines:", len(d["mode"]))
    print(" top10 modes:", modes.most_common(10))
    print(" score points <=700:", [(x["clock"], x["lh"], x["dn"]) for x in d["score"] if x["clock"] <= 700])
    print()


if __name__ == "__main__":
    lines = L.read_lines(L.SP)
    sess = [s for s in L.split_sessions(lines) if s["start"].startswith("2026-11-23 02:31:30")][0]
    summarize("FSL run3", L.parse_session(sess))
    prev = L.read_lines(L.PREV)
    rs = L.split_sessions(prev)
    for tag, start in (("S26", "2026-11-17 01:04:57"), ("S1", "2026-11-16 03:12:52")):
        s = [x for x in rs if x["start"].startswith(start)][0]
        summarize(tag, L.parse_session(s))