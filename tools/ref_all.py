import re, collections, json
f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
# all sessions: parse score and lane switch lines to build per-session lane timeline
sessions=[]
cur=None
for i,l in enumerate(lines):
    if l.startswith("====="):
        cur=dict(header=l.strip(), start=i, scores=[], lanes=[], matches=0)
        sessions.append(cur)
    elif cur is not None:
        m=re.search(r"\[SelfPlay score\] clock=([-\d.]+) hero=npc_dota_hero_treant role=(\d+) lane=(\d+) lastHits=(\d+)", l)
        if m: cur['scores'].append((float(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), i))
        m2=re.search(r"\[SelfPlay lane\] (\w+) -> (\w+): (.*)$", l.rstrip())
        if m2: cur['lanes'].append((l.split(']')[0]+']', m2.group(1), m2.group(2), m2.group(3), i))
        if "[SelfPlay draft] Pick requested" in l: cur['matches']+=1
print("sessions", len(sessions))
for si,s in enumerate(sessions):
    # only sessions with treant role4 lane1 score lines
    tr=[x for x in s['scores'] if x[1]==4 and x[2] in (1,3)]
    if not tr: continue
    lh300=[x for x in tr if x[0]<=300]
    print("\nS%d %s scores=%d lane_switches=%d" % (si, s['header'], len(s['scores']), len(s['lanes'])))
    for ev in s['lanes'][:6]: print("   LANE", ev[:4])
    # print score timeline sampled every ~120s for lanewise
    prevlane=None
    for x in tr:
        if x[2]!=prevlane or x[0] in (72.3,132.3,192.3,252.3,312.3):
            print("   score clock=%.1f lane=%d lh=%d" % (x[0],x[2],x[3]))
            prevlane=x[2]
