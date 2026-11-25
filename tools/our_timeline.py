import re, collections
for f in [r"D:\hake\lotus\self_play.log", r"D:\hake\lotus\archive\20261122_animtarget_safefix\match1_v1_self_play.log"]:
    print("\n=========", f)
    data=open(f, encoding='utf-8', errors='replace').read()
    lines=data.splitlines()
    print("lines", len(lines))
    # sessions
    for i,l in enumerate(lines):
        if l.startswith("====="): print("SESSION", i, l.strip())
    # roles/lanes seen
    roles=collections.Counter(re.findall(r"\[SelfPlay\] role=(\d+) lane=(\d+)", data))
    print("role/lane counts:", dict(roles))
    # lane lines and score lines
    for l in lines:
        if "[SelfPlay lane]" in l or "[SelfPlay score]" in l:
            print(l[:240])
