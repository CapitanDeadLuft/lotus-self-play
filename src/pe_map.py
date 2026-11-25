import struct
p = r"E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\bin\win64\client.dll"
data = open(p,"rb").read()
lfanew = struct.unpack_from("<I", data, 0x3C)[0]
assert data[lfanew:lfanew+4] == b"PE\0\0"
nsec = struct.unpack_from("<H", data, lfanew+6)[0]
opt_size = struct.unpack_from("<H", data, lfanew+20)[0]
sec_off = lfanew + 24 + opt_size
secs = []
for i in range(nsec):
    o = sec_off + i*40
    name = data[o:o+8].rstrip(b"\0").decode(errors="ignore")
    vsize, vaddr, rsize, roff = struct.unpack_from("<IIII", data, o+8)
    secs.append((name, vaddr, vsize, roff, rsize))
    print(f"{name:8s} VA=0x{vaddr:08X} VSize=0x{vsize:08X} RawOff=0x{roff:08X} RawSize=0x{rsize:08X}")
target = 0x1C16810
for name, vaddr, vsize, roff, rsize in secs:
    if roff <= target < roff + rsize:
        rva = vaddr + (target - roff)
        print(f"\nfile 0x{target:X} in {name}: RVA = 0x{rva:X}")
        break
sig = bytes([0x4C,0x89,0x4C,0x24,0x20,0x44,0x89,0x44,0x24,0x18,0x89,0x54,0x24,0x10,
             0x48,0x89,0x4C,0x24,0x08,0x55,0x53,0x56,0x57,0x41,0x56])
# sanity: verify bytes at the RVA via VA->file mapping
for name, vaddr, vsize, roff, rsize in secs:
    if vaddr <= rva < vaddr + vsize:
        foff = roff + (rva - vaddr)
        print("verify bytes at RVA:", data[foff:foff+25].hex(), "match:", data[foff:foff+25]==sig)
        break
