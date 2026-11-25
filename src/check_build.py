import json, os, struct, sys

DOTA = r"E:\SteamLibrary\steamapps\common\dota 2 beta"
CLIENT = os.path.join(DOTA, r"game\dota\bin\win64\client.dll")
STEAM_INF = os.path.join(DOTA, r"game\dota\steam.inf")
BASELINE = r"D:\hake\lotus\build_baseline.json"
OFFSETS = r"D:\hake\lotus\dumper\dota2_dump\offsets.json"

# last known-good RVAs for build 988312 (2026-11-19 02:xx)
KNOWN = {
    "build": "988312-1dd77a06d103d1a",
    "client_version": "6989",
    "puo_rva": 0x1C191E0,
    "local_player_controller_rva": 0x63E30A0,
    "entity_list_rva": 0x66493F0,
}

def read_steam_inf():
    out = {}
    try:
        for line in open(STEAM_INF, encoding="utf-8", errors="ignore"):
            if "=" in line:
                k, v = line.strip().split("=", 1)
                out[k] = v
    except OSError:
        pass
    return out

def pe_sections(path):
    data = open(path, "rb").read()
    lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    nsec = struct.unpack_from("<H", data, lfanew + 6)[0]
    opt_size = struct.unpack_from("<H", data, lfanew + 20)[0]
    sec_off = lfanew + 24 + opt_size
    secs = []
    for i in range(nsec):
        o = sec_off + i * 40
        name = data[o:o + 8].rstrip(b"\0").decode(errors="ignore")
        vsize, vaddr, rsize, roff = struct.unpack_from("<IIII", data, o + 8)
        secs.append((name, vaddr, vsize, roff, rsize))
    return data, secs

def file_off_to_rva(secs, foff):
    for name, vaddr, vsize, roff, rsize in secs:
        if roff <= foff < roff + rsize:
            return vaddr + (foff - roff)
    return None

def find_puo():
    if not os.path.exists(CLIENT):
        return None
    data, secs = pe_sections(CLIENT)
    sig = bytes([0x4C,0x89,0x4C,0x24,0x20,0x44,0x89,0x44,0x24,0x18,0x89,0x54,0x24,0x10,
                 0x48,0x89,0x4C,0x24,0x08,0x55,0x53,0x56,0x57,0x41,0x56])
    hits, i = [], 0
    while True:
        j = data.find(sig, i)
        if j < 0:
            break
        hits.append(j)
        i = j + 1
    if len(hits) != 1:
        return {"matches": len(hits), "file_offsets": [hex(h) for h in hits], "rva": None}
    rva = file_off_to_rva(secs, hits[0])
    return {"matches": 1, "file_offset": hex(hits[0]), "rva": rva}

def main():
    inf = read_steam_inf()
    st = {"client_version": inf.get("ClientVersion"), "source_revision": inf.get("SourceRevision")}
    if os.path.exists(CLIENT):
        fi = os.stat(CLIENT)
        st["client_dll_size"], st["client_dll_mtime"] = fi.st_size, int(fi.st_mtime)
    puo = find_puo()
    st["puo"] = puo
    if os.path.exists(OFFSETS):
        try:
            d = json.load(open(OFFSETS, encoding="utf-8"))
            st["dumper_build"] = d.get("build")
            st["dumper_engine"] = {k: hex(v) if isinstance(v, int) else v for k, v in d.get("engine", {}).items()}
        except Exception as e:
            st["dumper_error"] = str(e)

    print("== current build ==")
    print("ClientVersion      :", st.get("client_version"))
    print("SourceRevision     :", st.get("source_revision"))
    print("client.dll         : size=%s mtime=%s" % (st.get("client_dll_size"), st.get("client_dll_mtime")))
    if st.get("dumper_build"):
        print("dumper build       :", st["dumper_build"])
        print("dumper engine RVAs :", st.get("dumper_engine"))
    if puo:
        if puo.get("matches") == 1:
            print("PUO signature      : UNIQUE rva=0x%X (file 0x%s)" % (puo["rva"], puo["file_offset"][2:]))
        else:
            print("PUO signature      : matches=%d offsets=%s -> needs manual follow-up" % (puo["matches"], puo.get("file_offsets")))

    changed = []
    if KNOWN["client_version"] != st.get("client_version"):
        changed.append("ClientVersion %s -> %s" % (KNOWN["client_version"], st.get("client_version")))
    if st.get("dumper_build") and KNOWN["build"] != st["dumper_build"]:
        changed.append("build %s -> %s" % (KNOWN["build"], st["dumper_build"]))
    if puo and puo.get("rva") and puo["rva"] != KNOWN["puo_rva"]:
        changed.append("PUO rva 0x%X -> 0x%X" % (KNOWN["puo_rva"], puo["rva"]))
    eng = st.get("dumper_engine") or {}
    lpc = eng.get("dwLocalPlayerController")
    if lpc and int(lpc, 16) != KNOWN["local_player_controller_rva"]:
        changed.append("dwLocalPlayerController 0x%X -> %s" % (KNOWN["local_player_controller_rva"], lpc))

    print()
    if changed:
        print("!! BUILD CHANGED — update before any live run:")
        for c in changed:
            print("   -", c)
        print("   1) rerun dumper (elevated, live game): dumper\\dota2_dumper.exe")
        print("   2) update src/entity.lua M.gamerulesRVA + src/api.lua gamerules line (dwLocalPlayerController)")
        print("   3) update src/orders.lua M.prepareUnitOrdersRVA with the PUO rva above")
        print("   4) update KNOWN in this script")
    else:
        print("OK: build matches the last known-good baseline (988312). Safe to run.")
    json.dump(st, open(BASELINE, "w", encoding="utf-8"), indent=1)
    print("\nbaseline saved:", BASELINE)

if __name__ == "__main__":
    main()




