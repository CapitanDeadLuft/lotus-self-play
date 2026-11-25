p = r"E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\bin\win64\client.dll"
data = open(p, "rb").read()
sig = bytes([0x4C,0x89,0x4C,0x24,0x20,0x44,0x89,0x44,0x24,0x18,0x89,0x54,0x24,0x10,
             0x48,0x89,0x4C,0x24,0x08,0x55,0x53,0x56,0x57,0x41,0x56])
hits=[]; i=0
while True:
    j=data.find(sig,i)
    if j<0: break
    hits.append(j); i=j+1
print("full sig hits:", [hex(h) for h in hits], "count", len(hits))
# also try prefix-only (first 7) to see relocation
pre = bytes([0x4C,0x89,0x4C,0x24,0x20])
h2=[]; i=0
while True:
    j=data.find(pre,i)
    if j<0: break
    h2.append(j); i=j+1
print("prefix hits:", [hex(h) for h in h2][:20], "count", len(h2))
