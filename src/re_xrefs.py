import os, re, struct, json
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
from capstone.x86 import X86_OP_MEM, X86_REG_RIP

REG_DIR = r"D:\hake\lotus\dumps\ureg"
REPORT = r"D:\hake\lotus\dumps\ureg\xrefs.txt"

NAMES = [
    "GetAutoCastState","GetChannelStartTime","GetOwner","IsAttributes","IsOwnersManaEnough",
    "GetDisplayNameByUnitName","PlayVol","GetAbsOriginXYZ","IsAbility","ChatMessage",
    "GetDOTATime","GetGameEndTime","GetLobbyID","GetStrengthTotal","InRadius",
    "GetAttackTime","GetBaseSpellAmp","GetCastRangeBonus","GetMagicalArmorValue",
    "GetPhysicalArmorValue","GetSpellAmplification","IsBuilding","IsPositionInRange",
    "GetAbsOrigin","PrepareUnitOrders","GetAttackRange","IsDormant","GetTeamData",
]

def parse_prot():
    prot = {}
    path = os.path.join(REG_DIR, "uregions.txt")
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            m = re.match(r"base=0x([0-9A-F]+) size=0x([0-9A-F]+) state=0x([0-9A-F]+) type=0x([0-9A-F]+) prot=0x([0-9A-F]+)", line.strip())
            if m:
                base = int(m.group(1), 16); size = int(m.group(2), 16); p = int(m.group(5), 16)
                prot[base] = (size, p)
    return prot

def load_exec_regions(prot):
    regs = []
    for fn in os.listdir(REG_DIR):
        m = re.match(r"^ureg_([0-9A-F]+)\.bin$", fn)
        if not m: continue
        base = int(m.group(1), 16)
        info = prot.get(base)
        if not info: continue
        size, p = info
        # executable if protect has execute bit (0x10/0x20/0x40/0x80)
        if p & 0x10 or p & 0x20 or p & 0x40 or p & 0x80:
            with open(os.path.join(REG_DIR, fn), "rb") as f:
                data = f.read()
            if data:
                regs.append((base, data))
    return regs

def main():
    prot = parse_prot()
    regs = load_exec_regions(prot)
    total = sum(len(d) for _, d in regs)
    print(f"exec regions={len(regs)} bytes={total/1e6:.1f}MB", flush=True)

    # find name string addresses in ALL regions first
    name_addr = {}
    for fn in os.listdir(REG_DIR):
        m = re.match(r"^ureg_([0-9A-F]+)\.bin$", fn)
        if not m: continue
        base = int(m.group(1), 16)
        try:
            data = open(os.path.join(REG_DIR, fn), "rb").read()
        except Exception:
            continue
        for n in NAMES:
            if n in name_addr: continue
            i = data.find(n.encode() + b"\x00")
            if i >= 0:
                name_addr[n] = base + i
    print("resolved names:", len(name_addr), flush=True)

    targets = {}
    for n, a in name_addr.items():
        for delta, lbl in ((0, "str"), (-8, "str-8"), (-16, "str-16"), (-24, "str-24")):
            targets[a + delta] = f"{n}{'' if delta==0 else lbl}"

    md = Cs(CS_ARCH_X86, CS_MODE_64)
    md.detail = True
    out = []
    hits = 0
    for base, data in regs:
        try:
            for ins in md.disasm(data, base):
                for op in ins.operands:
                    if op.type != X86_OP_MEM:
                        continue
                    if op.mem.base != X86_REG_RIP:
                        continue
                    tgt = ins.address + ins.size + op.mem.disp
                    if tgt in targets:
                        hits += 1
                        out.append((hex(ins.address), ins.mnemonic, ins.op_str, targets[tgt], hex(tgt)))
                        if hits <= 60:
                            print(f"XREF {ins.address:X} {ins.mnemonic} {ins.op_str}   -> {targets[tgt]} ({hex(tgt)})", flush=True)
        except Exception as e:
            continue
    print("xrefs:", hits, flush=True)
    with open(REPORT, "w", encoding="utf-8") as f:
        for row in out:
            f.write("\t".join(row) + "\n")
    print("saved", REPORT, flush=True)

if __name__ == "__main__":
    main()