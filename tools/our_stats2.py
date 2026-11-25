import re, collections
files = {
 "match1_v1": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_self_play.log",
 "match1_v2": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v2_self_play.log",
 "match2_crash": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match2_crash_self_play.log",
 "match3_final": r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_self_play.log",
 "current_copy": r"D:\hake\lotus\self_play.log",
}
for k,f in files.items():
    lines=open(f, encoding='utf-8', errors='replace').readlines()
    acts=0; candpos=0; candsum=0; lastlines=0; modes=collections.Counter(); scores=[]
    for l in lines:
        m=re.match(r"\[(-?\d+):(\d+)\]", l)
        c = int(m.group(1))*60+int(m.group(2)) if m else None
        if "[SelfPlay actions]" in l and c is not None and 0<=c<=300:
            acts+=1
            mc=re.search(r"candidates=(\d+)", l)
            if mc:
                v=int(mc.group(1)); candsum+=v
                if v>0: candpos+=1
        elif "[SelfPlay last hit]" in l:
            lastlines+=1
        elif "[SelfPlay] " in l and "mode=" in l and c is not None and 0<=c<=300:
            mm=re.search(r"mode=(.*?) hp=", l)
            if mm: modes[mm.group(1).strip()[:40]]+=1
        elif "[SelfPlay score]" in l:
            ms=re.search(r"clock=([-\d.]+).*?lastHits=(\d+) denies=(\d+)", l)
            if ms: scores.append((float(ms.group(1)), int(ms.group(2)), int(ms.group(3))))
    print("\n==", k, "lines", len(lines))
    print("  0-300s(actions): n=%d cand_pos=%d cand_sum=%d last_hit_lines=%d" % (acts,candpos,candsum,lastlines))
    print("  first scores:", scores[:8])
    print("  modes:", modes.most_common(4))
