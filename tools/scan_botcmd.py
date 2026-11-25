import re
f=r"E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\bin\win64\client.dll"
data=open(f,'rb').read()
pat=re.compile(rb"dota_bot_[a-zA-Z0-9_]+")
seen=set()
for m in pat.finditer(data):
    s=m.group(0).decode()
    if s not in seen:
        seen.add(s)
        a=max(0,m.start()-150); b=min(len(data),m.end()+150)
        txt=''.join(chr(c) if 32<=c<127 else '.' for c in data[a:b])
        print("\n", s, "\n  ||", txt)
