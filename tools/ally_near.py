import re, collections, os
cases = {
 "match1_v1": (r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_host.log", "23:35:18"),
 "match1_v2": (r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v2_host.log", "23:35:18"),
 "match3_final": (r"D:\hake\lotus\archive\20261122_animtarget_safefix\match3_final_host.log", "00:04:02"),
}
for name,(f,horn) in cases.items():
    if not os.path.exists(f): continue
    # parse wall time hh:mm:ss -> seconds since midnight
    lines=open(f, encoding='utf-8', errors='replace').readlines()
    series=collections.defaultdict(list)
    for l in lines:
        m=re.match(r"(\d\d):(\d\d):(\d\d) \[support\]", l)
        if not m: continue
        t=int(m.group(1))*3600+int(m.group(2))*60+int(m.group(3))
        for nm, d in re.findall(r"A:(npc_dota_hero_\w+) yaw=[-\d.]+ d=(\d+)", l):
            series[nm].append((t, int(d)))
    hh,mm,ss=map(int,horn.split(':')); h0=hh*3600+mm*60+ss
    print("\n==", name, "horn", horn, "allies tracked:", list(series.keys()))
    for nm, arr in series.items():
        early=[(t-h0,d) for t,d in arr if 0 <= t-h0 <= 300]
        if not early: print("  ", nm, "no data 0-300"); continue
        ds=[d for _,d in early]
        # time share within 300 / 600 / 1200
        import statistics
        n=len(early)
        print("  %-32s n=%3d  min=%4d med=%4d max=%4d  <=300:%.0f%% <=600:%.0f%% <=1200:%.0f%%" % (
            nm.split('hero_')[1], n, min(ds), int(statistics.median(ds)), max(ds),
            100*sum(1 for d in ds if d<=300)/n, 100*sum(1 for d in ds if d<=600)/n, 100*sum(1 for d in ds if d<=1200)/n))
