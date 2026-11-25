#!/usr/bin/env python3
"""Extract Dota 2 NPC KeyValues from pak01_dir.vpk (VPK v1/v2) and merge into
the lotus loader's gamedata JSON (flat name->fields maps, wrapped by xhelpers
with the DOTAAbilities root key).

Phases:
  extract : read VPK dir tree, dump scripts/npc KV files to gamedata/vpk_extract/
  merge   : parse KV (with #base resolution), merge into npc_abilities.json /
            npc_heroes.json (existing entries preserved), rewrite .txt as
            self-contained concatenations, verify hero spells.
  all     : extract + merge (default)

Only writes under D:\\hake\\lotus\\gamedata\\ and this script's own directory.
"""
import io
import json
import os
import struct
import sys

GAME_DIR = r"E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota"
GAMEDATA = r"D:\hake\lotus\gamedata"
EXTRACT_ROOT = os.path.join(GAMEDATA, "vpk_extract")

# ---------------------------------------------------------------- VPK reader

class Vpk:
    def __init__(self, dir_path):
        self.dir_path = dir_path
        self.base = os.path.dirname(dir_path)
        with open(dir_path, "rb") as f:
            head = f.read(28)
            sig, ver, tree_size = struct.unpack_from("<III", head, 0)
            if sig != 0x55AA1234:
                raise ValueError("bad VPK signature %08x" % sig)
            if ver not in (1, 2):
                raise ValueError("unsupported VPK version %d" % ver)
            self.version = ver
            if ver == 2:
                (self.file_data_size, self.archive_md5_size,
                 self.other_md5_size, self.sig_size) = struct.unpack_from("<IIII", head, 12)
                header_size = 28
            else:
                self.file_data_size = 0
                header_size = 12
            self.tree_end = header_size + tree_size
            tree = f.read(tree_size)
        self.entries = {}          # full path -> (crc, preload, archive, offset, length)
        self._archive_handles = {}
        self._parse_tree(tree)

    @staticmethod
    def _cstr(buf, pos):
        end = buf.index(b"\0", pos)
        return buf[pos:end].decode("utf-8", "replace"), end + 1

    def _parse_tree(self, buf):
        pos = 0
        n = 0
        while True:
            ext, pos = self._cstr(buf, pos)
            if ext == "":
                break
            while True:
                path, pos = self._cstr(buf, pos)
                if path == "":
                    break
                while True:
                    name, pos = self._cstr(buf, pos)
                    if name == "":
                        break
                    crc, preload, archive, offset, length, term = \
                        struct.unpack_from("<IHHIIH", buf, pos)
                    pos += 18
                    if term != 0xFFFF:
                        raise ValueError("bad entry terminator at %d" % pos)
                    full = name if path == " " else path + "/" + name
                    if ext:
                        full += "." + ext
                    self.entries[full.replace("\\", "/")] = (crc, preload, archive, offset, length)
                    n += 1
        self.entry_count = n

    def read(self, path):
        crc, preload, archive, offset, length = self.entries[path]
        if archive == 0x7FFF:  # embedded in dir file data section (v2)
            with open(self.dir_path, "rb") as f:
                f.seek(self.tree_end + offset)
                data = f.read(length)
        else:
            apk = os.path.join(self.base, "pak01_%03d.vpk" % archive)
            fh = self._archive_handles.get(apk)
            if fh is None:
                fh = open(apk, "rb")
                self._archive_handles[apk] = fh
            fh.seek(offset)
            data = fh.read(length)
        if len(data) != length:
            raise IOError("short read for %s" % path)
        if preload:
            # preload bytes follow the tree sequentially (v1) / live in the
            # file data section (v2); tracked in tree order by caller if needed
            raise IOError("preload bytes not supported for %s" % path)
        return data

    def close(self):
        for fh in self._archive_handles.values():
            fh.close()

# ---------------------------------------------------------------- KV parser

class KVError(Exception):
    pass


def tokenize(text):
    """Yield (kind, value): ('str', s), ('{',), ('}',), ('cond', s)."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r\n":
            i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
        elif c == '"':
            i += 1
            out = []
            while i < n and text[i] != '"':
                if text[i] == "\\" and i + 1 < n:
                    nxt = text[i + 1]
                    out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, nxt))
                    i += 2
                else:
                    out.append(text[i])
                    i += 1
            i += 1  # closing quote
            yield ("str", "".join(out))
        elif c in "{}":
            yield (c,)
            i += 1
        elif c == "[":
            j = text.find("]", i)
            if j < 0:
                raise KVError("unterminated conditional")
            yield ("cond", text[i + 1:j].strip())
            i = j + 1
        else:
            j = i
            while j < n and text[j] not in ' \t\r\n"{}[]':
                j += 1
            yield ("str", text[i:j])
            i = j


def parse_kv(text, base_dir, stack=()):
    """Parse KeyValues text into a dict; resolves #base includes relative to
    base_dir. Duplicate keys: dicts merge recursively, scalars last-wins."""
    # pull #base directives out first (they are line-oriented)
    lines = []
    for line in text.splitlines():
        s = line.strip()
        low = s.lower()
        if low.startswith("#base") or low.startswith("#include"):
            rest = s.split(None, 1)[1].strip().strip('"')
            inc = os.path.normpath(os.path.join(base_dir, rest.replace("\\", "/")))
            if inc in stack:
                raise KVError("cyclic #base: %s" % inc)
            with open(inc, "r", encoding="utf-8-sig", errors="replace") as f:
                sub = parse_kv(f.read(), os.path.dirname(inc), stack + (inc,))
            lines.append(("__merge__", sub))
        else:
            lines.append(line)
    root = {}
    it = iter(tokenize("\n".join(l for l in lines if isinstance(l, str))))
    pending_merges = [m for l in lines if not isinstance(l, str) for m in (l[1],)]

    def merge_into(dst, src):
        for k, v in src.items():
            if k in dst and isinstance(dst[k], dict) and isinstance(v, dict):
                merge_into(dst[k], v)
            else:
                dst[k] = v

    def parse_block():
        d = {}
        while True:
            try:
                kind, *val = next(it)
            except StopIteration:
                raise KVError("unexpected EOF in block")
            if kind == "}":
                return d
            if kind != "str":
                raise KVError("expected key, got %r" % kind)
            key = val[0]
            kind2, *val2 = next(it)
            if kind2 == "{":
                sub = parse_block()
                try:
                    kind3, *val3 = next(it)
                except StopIteration:
                    kind3 = None
                cond_ok = True
                if kind3 == "cond":
                    cond_ok = val3[0].upper() not in ("X360", "PS3")
                elif kind3 is not None:
                    it_pushback.append((kind3, *val3))
                if cond_ok:
                    if key in d and isinstance(d[key], dict):
                        merge_into(d[key], sub)
                    else:
                        d[key] = sub
            elif kind2 == "str":
                value = val2[0]
                try:
                    kind3, *val3 = next(it)
                except StopIteration:
                    kind3 = None
                cond_ok = True
                if kind3 == "cond":
                    cond_ok = val3[0].upper() not in ("X360", "PS3")
                elif kind3 is not None:
                    # next key: stash it back
                    it_pushback.append((kind3, *val3))
                if cond_ok:
                    if key in d and isinstance(d[key], dict) and isinstance(value, dict):
                        merge_into(d[key], value)
                    else:
                        d[key] = value
            else:
                raise KVError("expected value or '{' after key %r" % key)

    # simple pushback wrapper around the token iterator
    it_pushback = []
    base_it = it

    def gen():
        while True:
            if it_pushback:
                yield it_pushback.pop(0)
            else:
                try:
                    yield next(base_it)
                except StopIteration:
                    return
    it = gen()
    # top level: key { ... } pairs (usually a single root)
    while True:
        try:
            kind, *val = next(it)
        except StopIteration:
            break
        if kind != "str":
            raise KVError("expected root key, got %r" % kind)
        key = val[0]
        kind2, *val2 = next(it)
        if kind2 == "{":
            sub = parse_block()
            try:
                kind3, *val3 = next(it)
            except StopIteration:
                kind3 = None
            cond_ok = True
            if kind3 == "cond":
                cond_ok = val3[0].upper() not in ("X360", "PS3")
            elif kind3 is not None:
                it_pushback.append((kind3, *val3))
            if cond_ok:
                if key in root and isinstance(root[key], dict):
                    merge_into(root[key], sub)
                else:
                    root[key] = sub
        elif kind2 == "str":
            root[key] = val2[0]
        else:
            raise KVError("bad root value for %r" % key)
    for m in pending_merges:
        merge_into(root, m)
    return root


def kv_to_jsonable(d):
    """KV values stay strings (matches existing gamedata JSON style)."""
    return d

# ---------------------------------------------------------------- phases

WANT_PREFIXES = ("scripts/npc/heroes/", "scripts/npc/abilities/")
WANT_FILES = ("scripts/npc/npc_abilities.txt", "scripts/npc/npc_heroes.txt")


def phase_extract():
    vpk = Vpk(os.path.join(GAME_DIR, "pak01_dir.vpk"))
    print("VPK v%d, %d entries, tree ends at %d" % (vpk.version, vpk.entry_count, vpk.tree_end))
    picked = sorted(p for p in vpk.entries
                    if p in WANT_FILES or
                    (p.startswith(WANT_PREFIXES) and p.endswith(".txt")))
    print("matched %d files" % len(picked))
    for p in picked:
        data = vpk.read(p)
        out = os.path.join(EXTRACT_ROOT, p.replace("/", os.sep))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "wb") as f:
            f.write(data)
    vpk.close()
    heroes = [p for p in picked if p.startswith("scripts/npc/heroes/")]
    abils = [p for p in picked if p.startswith("scripts/npc/abilities/")]
    print("heroes/: %d files, abilities/: %d files" % (len(heroes), len(abils)))
    # locate treant_natures_grasp
    hits = []
    for p in picked:
        out = os.path.join(EXTRACT_ROOT, p.replace("/", os.sep))
        with open(out, "r", encoding="utf-8-sig", errors="replace") as f:
            if "treant_natures_grasp" in f.read():
                hits.append(p)
    print("treant_natures_grasp found in:", hits)
    return picked


def concat_with_bases(path, stack=()):
    """Return file text with #base lines replaced by included content."""
    rp = os.path.realpath(path)
    if rp in stack:
        raise KVError("cyclic #base at %s" % path)
    with open(path, "r", encoding="utf-8-sig", errors="replace") as f:
        text = f.read()
    out = []
    base_dir = os.path.dirname(path)
    for line in text.splitlines():
        s = line.strip()
        if s.lower().startswith("#base") or s.lower().startswith("#include"):
            rest = s.split(None, 1)[1].strip().strip('"')
            inc = os.path.normpath(os.path.join(base_dir, rest.replace("\\", "/")))
            out.append(concat_with_bases(inc, stack + (rp,)))
        else:
            out.append(line)
    return "\n".join(out)


def phase_merge():
    ex = lambda *p: os.path.join(EXTRACT_ROOT, *p)
    abilities_root = parse_kv(concat_with_bases(ex("scripts", "npc", "npc_abilities.txt")),
                              ex("scripts", "npc"))
    abilities = abilities_root.get("DOTAAbilities", {})
    print("npc_abilities.txt (+bases): %d entries" % len(abilities))

    heroes = {}
    extra_abilities = {}
    n_ad = 0
    hero_dir = ex("scripts", "npc", "heroes")
    hero_files = sorted(f for f in os.listdir(hero_dir) if f.endswith(".txt"))

    def mm(dst, src):
        for k, v in src.items():
            if k in dst and isinstance(dst[k], dict) and isinstance(v, dict):
                mm(dst[k], v)
            else:
                dst[k] = v

    for fn in hero_files:
        parsed = parse_kv(concat_with_bases(os.path.join(hero_dir, fn)), hero_dir)
        for root_key, table in parsed.items():
            # hero files use "DOTAHeroes" root; accept DOTAAbilities too
            if not isinstance(table, dict):
                continue
            for name, fields in table.items():
                if not isinstance(fields, dict):
                    continue
                if name.startswith("npc_dota_hero_"):
                    # hero spells live in the hero's AbilityDefinitions block
                    ad = fields.pop("AbilityDefinitions", None)
                    if isinstance(ad, dict):
                        for an, af in ad.items():
                            if isinstance(af, dict):
                                extra_abilities[an] = af
                                n_ad += 1
                    if name in heroes and isinstance(heroes[name], dict):
                        mm(heroes[name], fields)
                    else:
                        heroes[name] = fields
                else:
                    extra_abilities[name] = fields
    print("hero files: %d, hero units: %d, AbilityDefinitions spells: %d, total extra abilities: %d"
          % (len(hero_files), len(heroes), n_ad, len(extra_abilities)))

    abil_dir = ex("scripts", "npc", "abilities")
    n_abfiles = 0
    if os.path.isdir(abil_dir):
        for fn in sorted(os.listdir(abil_dir)):
            if not fn.endswith(".txt"):
                continue
            n_abfiles += 1
            parsed = parse_kv(concat_with_bases(os.path.join(abil_dir, fn)), abil_dir)
            for root_key, table in parsed.items():
                if isinstance(table, dict):
                    for name, fields in table.items():
                        if isinstance(fields, dict):
                            extra_abilities[name] = fields
    print("abilities/ files: %d, total extra abilities: %d" % (n_abfiles, len(extra_abilities)))

    # merge into existing JSON, keeping existing entries untouched.
    # Modern hero KV keeps AbilityCastRange/Point/ManaCost/etc inside
    # AbilityValues; api.lua kvNum() only reads top-level keys, so promote
    # those nodes verbatim (string or {value=...} table) for hero spells.
    PROMOTE = ("AbilityCastRange", "AbilityCastPoint", "AbilityManaCost",
               "AbilityCooldown", "AbilityDuration", "AbilityChannelTime",
               "AbilityDamage", "AbilityCastRangeBuffer", "AbilityCharges",
               "AbilityChargeRestoreTime")

    def promote(fields):
        av = fields.get("AbilityValues")
        if isinstance(av, dict):
            for k in PROMOTE:
                if k not in fields and k in av:
                    fields[k] = av[k]
        return fields

    ab_path = os.path.join(GAMEDATA, "npc_abilities.json")
    with open(ab_path, "r", encoding="utf-8") as f:
        existing = json.load(f)
    before = len(existing)
    added = 0
    for src in (abilities, extra_abilities):
        for name, fields in src.items():
            if name not in existing:
                existing[name] = promote(fields) if isinstance(fields, dict) else fields
                added += 1
    # idempotent re-run: hero-spell entries were absent from the original
    # file, so promotion can be (re)applied to them safely
    promoted = 0
    for name in extra_abilities:
        e = existing.get(name)
        if isinstance(e, dict):
            av = e.get("AbilityValues")
            if isinstance(av, dict) and any(k not in e and k in av for k in PROMOTE):
                promote(e)
                promoted += 1
    with open(ab_path, "w", encoding="utf-8") as f:
        json.dump(existing, f, ensure_ascii=False, separators=(",", ":"))
    print("npc_abilities.json: %d -> %d entries (+%d new, existing kept, %d hero spells promoted)"
          % (before, len(existing), added, promoted))

    hero_path = os.path.join(GAMEDATA, "npc_heroes.json")
    try:
        with open(hero_path, "r", encoding="utf-8") as f:
            existing_heroes = json.load(f)
    except (OSError, ValueError):
        existing_heroes = {}
    if not isinstance(existing_heroes, dict):
        existing_heroes = {}
    # preserve hero order from the original npc_heroes.txt #base list
    # (InitUnitNameDict relies on it); new heroes appended at the end
    ordered = {}
    try:
        with open(os.path.join(GAMEDATA, "npc_heroes.txt"), "r", encoding="utf-8-sig") as f:
            for line in f:
                s = line.strip()
                if s.lower().startswith("#base"):
                    fn = os.path.basename(s.split(None, 1)[1].strip().strip('"'))
                    hname = fn[:-4] if fn.endswith(".txt") else fn
                    if hname in heroes:
                        ordered[hname] = heroes[hname]
    except OSError:
        pass
    for name, fields in heroes.items():
        ordered.setdefault(name, fields)
    h_before = len(existing_heroes)
    for name, fields in ordered.items():
        if name not in existing_heroes:
            existing_heroes[name] = fields
    with open(hero_path, "w", encoding="utf-8") as f:
        json.dump(existing_heroes, f, ensure_ascii=False, separators=(",", ":"))
    print("npc_heroes.json: %d -> %d entries (base-list order preserved)" % (h_before, len(existing_heroes)))

    # self-contained txt mirrors only where the source actually has #base
    for rel, dst in ((("scripts", "npc", "npc_abilities.txt"), "npc_abilities.txt"),
                     (("scripts", "npc", "npc_heroes.txt"), "npc_heroes.txt")):
        src = ex(*rel)
        with open(src, "r", encoding="utf-8-sig", errors="replace") as f:
            raw = f.read()
        if "#base" in raw.lower():
            out_text = concat_with_bases(src)
            if dst == "npc_heroes.txt":
                # keep the original include manifest (hero order) as comments
                try:
                    with open(os.path.join(GAMEDATA, dst), "r", encoding="utf-8-sig") as f:
                        manifest = f.read()
                    if any(l.strip().lower().startswith("#base") for l in manifest.splitlines()):
                        header = "\n".join("// " + l for l in manifest.splitlines())
                        out_text = header + "\n\n" + out_text
                except OSError:
                    pass
            with open(os.path.join(GAMEDATA, dst), "w", encoding="utf-8") as f:
                f.write(out_text)
            print("rewrote %s with #base inlined" % dst)
        else:
            print("%s has no #base; left gamedata copy untouched" % dst)

    # verification
    checks = ["treant_natures_grasp", "antimage_mana_break", "axe_berserkers_call",
              "crystal_maiden_crystal_nova", "pudge_meat_hook", "zuus_arc_lightning"]
    ok = True
    for name in checks:
        e = existing.get(name)
        if not isinstance(e, dict):
            print("MISSING: %s" % name)
            ok = False
            continue
        keys = ["AbilityCastRange", "AbilityCastPoint", "AbilityManaCost", "AbilityBehavior"]
        have = {k: e.get(k) for k in keys}
        av = e.get("AbilityValues")
        def brief(v):
            if isinstance(v, dict):
                return "{value=%s}" % v.get("value")
            return v
        print("%s: %s | AbilityValues=%s" % (
            name,
            " ".join("%s=%s" % (k, brief(v)) for k, v in have.items()),
            ("yes(%d)" % len(av)) if isinstance(av, dict) else av))
        # passives legitimately have no cast range/point/mana; behavior+values required
        if have["AbilityBehavior"] is None or not isinstance(av, dict):
            ok = False
    def scalar(v):
        if isinstance(v, dict):
            v = v.get("value")
        return v
    n_with_range = sum(1 for v in existing.values()
                       if isinstance(v, dict) and scalar(v.get("AbilityCastRange")) not in (None, "", "0"))
    n_with_behavior = sum(1 for v in existing.values()
                          if isinstance(v, dict) and v.get("AbilityBehavior"))
    n_with_values = sum(1 for v in existing.values()
                        if isinstance(v, dict) and isinstance(v.get("AbilityValues"), dict))
    print("totals: %d entries, %d with nonzero AbilityCastRange, %d with AbilityBehavior, %d with AbilityValues"
          % (len(existing), n_with_range, n_with_behavior, n_with_values))
    print("VERIFY:", "OK" if ok else "INCOMPLETE")


if __name__ == "__main__":
    phase = sys.argv[1] if len(sys.argv) > 1 else "all"
    if phase in ("extract", "all"):
        phase_extract()
    if phase in ("merge", "all"):
        phase_merge()
