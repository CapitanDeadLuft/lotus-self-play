import re, collections, os
files = {
 "match1_v1": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_self_play.log",
 "match1_v2": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v2_self_play.log",
 "match2_crash": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match2_crash_self_play.log",
 "match3_final": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_self_play.log",
 "ref_like_current": r"D:\hake\lotus\self_play.log",
}
for k,f in files.items():
    lines=open(f, encoding='utf-8', errors='replace').readlines()
    # session boundaries and match clock via line prefix [m:ss]
    acts=0; candpos=0; candsum=0; lastlines=0; modes=collections.Counter()
    for l in lines:
        if "[SelfPlay actions]" in l:
            m=re.search(r"\[(-?\d+):(\d+)\]", l)
            if not m: continue
            c=int(m.group(1))*60+int(m.group(2))
            if 0<=c<=300:
                acts+=1
                mc=re.search(r"candidates=(\d+)", l)
                if mc:
                    v=int(mc.group(1)); candsum+=v
                    if v>0: candpos+=1
        elif "[SelfPlay last hit]" in l:
            lastlines+=1
        elif "[SelfPlay] " in l and "mode=" in l:
            m=re.search(r"\[(-?\d+):(\d+)\]", l)
            if m:
                c=int(m.group(1))*60+int(m.group(2))
                if 0<=c<=300: modes[re.search(r"mode=([^h]*?) hp=", l).group(1).strip()[:40]]+=1
    print("\n==", k, "lines", len(lines))
    print("  0-300s: actions=%d cand_pos=%d cand_sum=%d last_hit_lines=%d" % (acts,candpos,candsum,lastlines))
    for md,c in modes.most_common(5): print("   mode", c, md)
