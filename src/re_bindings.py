import os, sys, json, struct, re

REG_DIR = r"D:\hake\lotus\dumps\ureg"
OUT_JSON = r"D:\hake\lotus\dumps\ureg\rfindings.json"

# module address range (private, from the live scan)
MOD_LO, MOD_HI = 0x2AE80000000, 0x2AF00000000

TARGET_NAMES = [
    # the 25 unimplemented
    "GetAutoCastState", "GetChannelStartTime", "GetOwner", "IsAttributes", "IsOwnersManaEnough",
    "GetDisplayNameByUnitName", "PlayVol", "GetAbsOriginXYZ", "IsAbility", "ChatMessage",
    "GetDOTATime", "GetGameEndTime", "GetLobbyID", "GetStrengthTotal", "InRadius",
    "GetAttackTime", "GetBaseSpellAmp", "GetCastRangeBonus", "GetMagicalArmorValue",
    "GetPhysicalArmorValue", "GetSpellAmplification", "IsBuilding", "IsPositionInRange",
    "Count", "Get",
    # control names (known implemented; used to validate the method)
    "GetAbsOrigin", "PrepareUnitOrders", "GetAttackRange", "IsDormant", "GetTeamData",
]

def load_regions():
    regs = []
    pat = re.compile(r"^ureg_([0-9A-F]+)\.bin$")
    for fn in os.listdir(REG_DIR):
        m = pat.match(fn)
        if not m:
            continue
        base = int(m.group(1), 16)
        path = os.path.join(REG_DIR, fn)
        try:
            with open(path, "rb") as f:
                data = f.read()
        except Exception:
            continue
        if data:
            regs.append((base, base + len(data), data, fn))
    regs.sort()
    return regs

def find_name_addrs(regs, names):
    """absolute addresses where each name string occurs"""
    hits = {n: [] for n in names}
    for base, end, data, fn in regs:
        for n in names:
            needle = n.encode("ascii") + b"\x00"
            start = 0
            while True:
                i = data.find(needle, start)
                if i < 0:
                    break
                hits[n].append(base + i)
                start = i + 1
                if len(hits[n]) > 200:
                    break
    return hits

def main():
    regs = load_regions()
    total = sum(len(d) for _, _, d, _ in regs)
    print(f"regions={len(regs)} bytes={total/1e6:.1f}MB", flush=True)

    name_addrs = find_name_addrs(regs, TARGET_NAMES)
    print("name occurrences:", {k: len(v) for k, v in name_addrs.items() if v}, flush=True)

    # build reverse map: address -> name
    addr2name = {}
    for n, addrs in name_addrs.items():
        for a in addrs:
            # store only the address right at string start (for luaL_Reg the pointer is exact)
            addr2name[a] = n

    findings = []
    # scan every region for 8-byte values that equal a name address
    for base, end, data, fn in regs:
        n8 = len(data) - (len(data) % 8)
        for off in range(0, n8, 8):
            v = struct.unpack_from("<Q", data, off)[0]
            nm = addr2name.get(v)
            if nm is None:
                continue
            # next qword should be a function pointer (into module range)
            if off + 16 <= n8:
                f = struct.unpack_from("<Q", data, off + 8)[0]
            else:
                f = 0
            findings.append({
                "name": nm,
                "name_addr": hex(v),
                "record_addr": hex(base + off),
                "next_qword": hex(f),
                "next_in_module": MOD_LO <= f < MOD_HI,
            })
    print(f"records with name pointer: {len(findings)}", flush=True)

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump({"name_addrs": {k: [hex(a) for a in v] for k, v in name_addrs.items()},
                   "findings": findings}, f, indent=1)
    print("saved", OUT_JSON, flush=True)

    # short report
    seen = set()
    for r in findings:
        key = (r["name"], r["next_qword"])
        if key in seen:
            continue
        seen.add(key)
        if r["next_in_module"] or len(seen) < 40:
            print(f"{r['name']:26s} rec={r['record_addr']:>16s} -> {r['next_qword']} inmod={r['next_in_module']}")

if __name__ == "__main__":
    main()