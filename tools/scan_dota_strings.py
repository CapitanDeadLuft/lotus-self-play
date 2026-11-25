import os, re, glob
root = r"E:\SteamLibrary\steamapps\common\dota 2 beta"
cands=[]
for pat in ["game/bin/win64/*.dll","game/bin/win64/*.exe","game/dota/bin/*.dll","game/dota/bin/win64/*.dll"]:
    cands += glob.glob(os.path.join(root, pat))
print("files:", len(cands))
for f in cands:
    try:
        data=open(f,'rb').read()
    except Exception as e:
        continue
    found=set(re.findall(rb"[ -~]{4,}?dota_bot_[a-z_]+", data))
    if found:
        print(os.path.basename(f), len(data), [x.decode('latin-1')[-60:] for x in sorted(found)][:20])
