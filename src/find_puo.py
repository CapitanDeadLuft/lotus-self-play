import re
p = r"E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\bin\win64\client.dll"
data = open(p, "rb").read()
print("client.dll size", len(data))
# old verified prologue (25 bytes) at PUO: 4C 89 4C 24 20 44 89 44 89 44 ...
pats = {
 "puo_old25": bytes.fromhex("4C 89 4C 24 20 44 89 44 89 44"),
}
for name, pat in pats.items():
    idx = 0; hits = []
    while True:
        i = data.find(pat, idx)
        if i < 0: break
        hits.append(i); idx = i + 1
    print(name, "hits:", [hex(h) for h in hits][:12], "count", len(hits))
