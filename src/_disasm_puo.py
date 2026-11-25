import struct, sys, capstone, os

dll = r"E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\bin\win64\client.dll"
if not os.path.exists(dll):
    print("MISSING", dll); sys.exit(1)
pe = open(dll, "rb").read()
print("size", len(pe))
e_lfanew = struct.unpack_from("<I", pe, 0x3C)[0]
nsec = struct.unpack_from("<H", pe, e_lfanew + 6)[0]
optsize = struct.unpack_from("<H", pe, e_lfanew + 20)[0]
secoff = e_lfanew + 24 + optsize
sections = []
for i in range(nsec):
    s = secoff + i * 40
    name = pe[s:s+8].rstrip(b"\0").decode(errors="replace")
    vsize, va, rsize, rptr = struct.unpack_from("<IIII", pe, s + 8)
    sections.append((name, va, vsize, rptr, rsize))
    print(f"{name:10s} va={va:#x} vs={vsize:#x} raw={rptr:#x} rs={rsize:#x}")

def rva2off(rva):
    for name, va, vsize, rptr, rsize in sections:
        if va <= rva < va + max(vsize, rsize):
            return rptr + (rva - va)
    return None

RVA = int(sys.argv[1], 0) if len(sys.argv) > 1 else 0x1B5F860
N = int(sys.argv[2], 0) if len(sys.argv) > 2 else 400
off = rva2off(RVA)
print(f"\n== RVA {RVA:#x} -> file off {off:#x} ==")
code = pe[off:off + N * 15]
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
md.detail = True
count = 0
for ins in md.disasm(code, RVA):
    print(f"0x{ins.address:X}: {ins.mnemonic:8s} {ins.op_str}")
    count += 1
    if count >= N:
        break