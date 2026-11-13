#!/usr/bin/env python3
"""Regenerate RegionData.lua and RecipeData.lua for Recipe Radar (WoW Forever).

Sources, merged in this order:
  1. tools/data/classic_*.lua: the original vanilla vendor database (Jay Miller).
     Supplies gold prices, vendor notes, specialties and reputation requirements.
  2. QuestieDB (GPLv3, https://github.com/Questie/QuestieDB): which NPC sells which
     recipe item in Forever, NPC faction and spawn coordinates. Read from the baked
     QuestieDB_Forever.toc of an installed copy.
  3. AllTheThings Forever data (db/Camelot): required skill, Merchant's Favor and
     token costs, reputation requirements, and vendor recipes QuestieDB lacks.
  4. tools/data/overrides.json: hand-maintained exclusions and corrections.

Usage:
  python tools/build_data.py --questiedb <path to QuestieDB_Forever.toc> \
      --att <path to AllTheThings/db/Camelot/Categories> [--out <addon dir>]

Requires: cbor2 (pip install cbor2).
"""
import argparse, base64, glob, io, json, os, re, sys
from collections import OrderedDict, defaultdict

import cbor2

HERE = os.path.dirname(os.path.abspath(__file__))

PROFESSIONS = {  # QuestieDB / item subClass for class 9 (Recipe)
    1: "Leatherworking", 2: "Tailoring", 3: "Engineering", 4: "Blacksmithing",
    5: "Cooking", 6: "Alchemy", 7: "First Aid", 8: "Enchanting", 9: "Fishing",
}
SKILL_LINES = {  # profession skill line IDs (certifications name their skill line)
    171: "Alchemy", 164: "Blacksmithing", 333: "Enchanting", 202: "Engineering",
    165: "Leatherworking", 197: "Tailoring", 185: "Cooking", 129: "First Aid", 356: "Fishing",
}
CLASSIC_FACTION_IDS = {
    "Argent Dawn": 529, "Cenarion Circle": 609, "Thorium Brotherhood": 59,
    "Timbermaw Hold": 576, "Zandalar Tribe": 270,
}
MERCHANTS_FAVOR = 3402
MAX_COORDS = 5


def standing_from_raw(raw):
    """AllTheThings stores reputation thresholds as raw points from Neutral."""
    for limit, index in ((42000, 8), (21000, 7), (9000, 6), (3000, 5), (0, 4)):
        if raw >= limit:
            return index
    return 3


# --------------------------------------------------------------------------
# QuestieDB baked TOC reader
# --------------------------------------------------------------------------

class QuestieDB:
    def __init__(self, toc_path):
        self.meta = {}
        pat = re.compile(r'^## (X-[^:]+): ?(.*)$')
        with io.open(toc_path, encoding="utf-8", errors="replace") as f:
            for ln in f:
                m = pat.match(ln.rstrip("\r\n"))
                if m:
                    self.meta[m.group(1)] = m.group(2)
        self.version = self.meta.get("X-BUILD-COMMIT", "?")

    def _stored(self, key):
        v = self.meta.get(key)
        if v is None:
            return None
        m = re.match(r'^~(\d+)~$', v)
        if m:
            return "".join(self.meta[key + "-" + str(i)] for i in range(1, int(m.group(1)) + 1))
        return v

    def _decode(self, key):
        v = self._stored(key)
        return None if v is None else cbor2.loads(base64.b64decode(v))

    @staticmethod
    def _text(v):
        return v.decode("utf-8", "replace") if isinstance(v, bytes) else v

    def row(self, entity, id_):
        r = self._decode("X-%s-%s-S" % (entity, id_))
        if r is None:
            return None
        if isinstance(r, list):
            r = {i + 1: v for i, v in enumerate(r)}
        return {k: self._text(v) for k, v in r.items()}

    def field(self, entity, id_, index):
        return self._decode("X-%s-%s-%d" % (entity, id_, index))

    def item_ids(self):
        return sorted(int(m.group(1)) for k in self.meta
                      for m in [re.match(r'^X-Item-(\d+)-S$', k)] if m)

    def npc(self, nid):
        r = self.row("Npc", nid)
        if not r:
            return None
        spawns = self.field("Npc", nid, 7)
        if isinstance(spawns, list):
            # a Lua table keyed 1..n (e.g. only area 1, Dun Morogh) serializes as a CBOR array
            spawns = {i + 1: pts for i, pts in enumerate(spawns) if pts}
        elif not isinstance(spawns, dict):
            spawns = {}
        return {"name": r.get(1), "faction": r.get(13), "spawns": spawns}


def load_area_map(questiedb_dir):
    """areaID -> (uiMapID or None, zone name) from QuestieDB's Forever zone support files.

    Dungeon areas get their dungeon name and no uiMapID (QuestieDB marks those map IDs
    as legacy pre-entrance lookups, not Forever floor maps)."""
    zones = os.path.join(questiedb_dir, "support", "Forever", "Zones")
    dungeons = {}
    dpat = re.compile(r'^\s*\[(\d+)\]\s*=\s*\{"(.+?)",(nil|\{([\d,]*)\})')
    with io.open(os.path.join(zones, "dungeons.lua"), encoding="utf-8") as f:
        for ln in f:
            m = dpat.match(ln)
            if m:
                dungeons[int(m.group(1))] = m.group(2)
                for alt in (m.group(4) or "").split(","):
                    if alt:
                        dungeons.setdefault(int(alt), m.group(2))
    areas = {}
    pat = re.compile(r'^\s*\[(\d+)\]\s*=\s*(\d+),\s*--\s*(.+?)\s*$')
    with io.open(os.path.join(zones, "areaIdToUiMapId.lua"), encoding="utf-8") as f:
        for ln in f:
            m = pat.match(ln)
            if not m or int(m.group(2)) <= 0:
                continue
            area = int(m.group(1))
            if area in dungeons:
                areas.setdefault(area, (None, dungeons[area]))
            elif "Referenced dungeon area" not in m.group(3):
                areas.setdefault(area, (int(m.group(2)), m.group(3).split("->")[-1].strip()))
    for area, name in dungeons.items():
        areas.setdefault(area, (None, name))
    return areas


# --------------------------------------------------------------------------
# AllTheThings reader: recipes (r) and items (i) nested inside vendor NPCs (n)
# --------------------------------------------------------------------------

def parse_att(categories_dir):
    """Returns {itemID: {skill, cost, rep, vendors: {npcID: {coords, side}}}}."""
    text = "".join(io.open(f, encoding="utf-8", errors="replace").read()
                   for f in sorted(glob.glob(os.path.join(categories_dir, "*.lua"))))
    out = {}
    node_re = re.compile(r'\b([nri])\((\d+),\{')
    stack = []  # (kind, id, depth_at_open, header_end)
    depth = 0
    i, n = 0, len(text)
    in_str = None
    npc_header = {}
    while i < n:
        c = text[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c in "\"'":
            in_str = c
            i += 1
            continue
        m = node_re.match(text, i) if c in "nri" else None
        if m and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_")):
            depth += 1  # the "("
            stack.append((m.group(1), int(m.group(2)), depth, m.end()))
            i = m.end() - 1  # position at "{", handled below
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            if stack and stack[-1][2] == depth:
                kind, id_, _, start = stack.pop()
                body = text[start:i]
                if kind == "n":
                    pass
                else:
                    entry = _att_entry(kind, id_, body)
                    if entry:
                        vendor = next((s for s in reversed(stack) if s[0] == "n"), None)
                        if vendor:
                            entry["npc"] = vendor[1]
                            hdr = npc_header.get(vendor[1])
                            if hdr is None:
                                hdr = _att_npc_header(text[vendor[3]:vendor[3] + 400])
                                npc_header[vendor[1]] = hdr
                            rec = out.setdefault(entry["itemID"], {
                                "skill": entry.get("skill"), "cost": entry.get("cost"),
                                "rep": entry.get("rep"), "skillLine": entry.get("skillLine"),
                                "kind": kind, "vendors": {}})
                            if entry.get("cost") and not rec.get("cost"):
                                rec["cost"] = entry["cost"]
                            rec["vendors"][vendor[1]] = hdr
            depth -= 1
        i += 1
    return out


def _att_entry(kind, id_, body):
    # only the entry's own fields, not nested groups
    own = re.split(r'\bg=\{', body, maxsplit=1)[0]
    item = re.search(r'\bitemID=(\d+)', own)
    item_id = int(item.group(1)) if item else (id_ if kind == "i" else None)
    if not item_id:
        return None
    cost = re.search(r'\bcost=\{\{"(\w)",(\d+),(\d+)\}', own)
    gold = re.search(r'\bcost=(\d+)\b', own)
    if not cost and not gold:
        return None  # not something a vendor sells
    e = {"itemID": item_id}
    if cost:
        e["cost"] = (cost.group(1), int(cost.group(2)), int(cost.group(3)))
    else:
        e["cost"] = ("g", 0, int(gold.group(1)))
    skill = re.search(r'\blearnedAt=(\d+)', own)
    if skill:
        e["skill"] = int(skill.group(1))
    sl = re.search(r'\brequireSkill=(\d+)', own)
    if sl:
        e["skillLine"] = int(sl.group(1))
    rep = re.search(r'\bminReputation=\{(\d+),(-?\d+)\}', own)
    if rep and int(rep.group(2)) > 0:
        e["rep"] = (int(rep.group(1)), standing_from_raw(int(rep.group(2))))
    return e


def _att_npc_header(head):
    coords = []
    m = re.search(r'coords=\{\[(\d+)\]=\{((?:\{[\d.]+,[\d.]+\},?)+)\}', head)
    if m:
        for x, y in re.findall(r'\{([\d.]+),([\d.]+)\}', m.group(2)):
            coords.append((int(m.group(1)), float(x), float(y)))
    side = re.search(r'\br=(\d)\b', head)
    return {"coords": coords, "side": {"1": "Horde", "2": "Alliance"}.get(side.group(1)) if side else None}


# --------------------------------------------------------------------------
# Classic data (the original Lua files, parsed with regexes; the format is regular)
# --------------------------------------------------------------------------

def parse_classic(region_path, recipe_path):
    rtext = io.open(region_path, encoding="utf-8").read()
    regions = OrderedDict()
    for m in re.finditer(r'^\[RRS\("(.+?)"\)\] = \{(.*?)^\},', rtext, re.M | re.S):
        name, body = m.group(1), m.group(2)
        cont = int(re.search(r'Continent = (\d+)', body).group(1))
        vendors = []
        for vm in re.finditer(r'\n      \{\n(.*?)\n      \},', body, re.S):
            vb = vm.group(1)
            v = {"name": re.search(r'Name = RRS\("(.+?)"\)', vb).group(1),
                 "team": re.search(r'Team = "(\w+)"', vb).group(1),
                 "coords": [(float(x), float(y)) for x, y in
                            re.findall(r'\{ x = ([\d.]+), y = ([\d.]+) \}', vb)],
                 "recipes": [int(x) for x in re.findall(r'\{ ID = (\d+),', vb)]}
            note = re.search(r'Notes = RRS\("(.+?)"\)', vb)
            if note:
                v["notes"] = note.group(1)
            vendors.append(v)
        regions[name] = {"continent": cont, "vendors": vendors}

    ctext = io.open(recipe_path, encoding="utf-8").read()
    recipes = {}
    for pm in re.finditer(r'^\[RRS\("(.+?)"\)\] = \{(.*?)^\},', ctext, re.M | re.S):
        for rm in re.finditer(r'\n      \{\n(.*?)\n      \},', pm.group(2), re.S):
            rb = rm.group(1)
            rid = int(re.search(r'ID = (\d+),', rb).group(1))
            r = {"type": pm.group(1),
                 "skill": int(re.search(r'Skill = (\d+)', rb).group(1)),
                 "cost": int(re.search(r'Cost = (\d+)', rb).group(1))}
            for key, pat in (("faction", r'Faction = RRS\("(.+?)"\)'),
                             ("specialty", r'Specialty = RRS\("(.+?)"\)'),
                             ("notes", r'Notes = RRS\("(.+?)"\)')):
                m = re.search(pat, rb)
                if m:
                    r[key] = m.group(1)
            lvl = re.search(r'Level = (\d+)', rb)
            if lvl:
                r["level"] = int(lvl.group(1))
            recipes[rid] = r
    return regions, recipes


# --------------------------------------------------------------------------
# Merge
# --------------------------------------------------------------------------

def team_of(faction_flag, side=None):
    if faction_flag in ("A",):
        return "Alliance"
    if faction_flag in ("H",):
        return "Horde"
    if side:
        return side
    return "Neutral"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--questiedb", required=True)
    ap.add_argument("--att", required=True)
    ap.add_argument("--out", default=os.path.dirname(HERE))
    args = ap.parse_args()

    overrides = json.load(io.open(os.path.join(HERE, "data", "overrides.json"), encoding="utf-8"))
    exclude = set(int(x) for x in overrides.get("exclude_items", {}))

    classic_regions, classic_recipes = parse_classic(
        os.path.join(HERE, "data", "classic_RegionData.lua"),
        os.path.join(HERE, "data", "classic_RecipeData.lua"))
    qdb = QuestieDB(args.questiedb)
    areas = load_area_map(os.path.dirname(args.questiedb))
    att = parse_att(args.att)

    map_to_zone = {}
    for area, (map_id, name) in areas.items():
        if map_id:
            map_to_zone.setdefault(map_id, name)
    # classic vendor notes and continents by zone name
    classic_notes = {(rn, v["name"]): v.get("notes") for rn, r in classic_regions.items() for v in r["vendors"]}
    classic_cont = {rn: r["continent"] for rn, r in classic_regions.items()}
    overrides_cont = {k: v for k, v in overrides.get("continents", {}).items()}

    # recipe metadata: classic first, then QuestieDB names/professions, then ATT
    recipes = {}
    item_names = {}
    for iid in qdb.item_ids():
        row = qdb.row("Item", iid)
        if not row:
            continue
        item_names[iid] = row.get(1)
        if row.get(12) == 9 and row.get(13) in PROFESSIONS:
            recipes[iid] = {"type": PROFESSIONS[row[13]], "qdb_vendors": list(qdb.field("Item", iid, 14) or [])}
    for rid, r in classic_recipes.items():
        recipes.setdefault(rid, {"qdb_vendors": []}).update(r)
    for iid, a in att.items():
        if iid not in recipes:
            cost = a.get("cost") or ()
            if (a["kind"] == "i" and a.get("skillLine") in SKILL_LINES and cost[:2] == ("c", MERCHANTS_FAVOR)
                    and cost[2] >= 1000):
                recipes[iid] = {"type": SKILL_LINES[a["skillLine"]], "qdb_vendors": [], "certification": True}
            elif a["kind"] == "r" and a.get("skillLine") in SKILL_LINES:
                recipes[iid] = {"type": SKILL_LINES[a["skillLine"]], "qdb_vendors": []}
            else:
                continue
        r = recipes[iid]
        if a.get("skill") and not r.get("skill"):
            r["skill"] = a["skill"]
        cost = a.get("cost")
        if cost:
            kind, cid, amount = cost
            if kind == "c":
                r["currency"], r["amount"] = cid, amount
            elif kind == "i":
                r["token"], r["amount"] = cid, amount
            elif kind == "g" and amount and not r.get("cost"):
                r["cost"] = amount
        if a.get("rep") and not r.get("faction_id"):
            r["faction_id"], r["level"] = a["rep"]
        r["att_vendors"] = a["vendors"]
    for rid, skill in overrides.get("skills", {}).items():
        if int(rid) in recipes and not recipes[int(rid)].get("skill"):
            recipes[int(rid)]["skill"] = int(skill)
    for rid, r in recipes.items():
        if r.get("faction") and not r.get("faction_id"):
            r["faction_id"] = CLASSIC_FACTION_IDS.get(r["faction"])

    # vendors: region -> npc key -> vendor record
    regions = defaultdict(OrderedDict)
    npc_cache = {}

    def add_vendor(region, key, name, team, coords, rid, notes=None):
        # one entry per vendor name and region, whatever source it came from
        key = ("vendor", name)
        reg = regions[region]
        v = reg.get(key)
        if not v:
            v = reg[key] = {"name": name, "team": team, "coords": [], "recipes": [], "notes": notes}
        for c in coords:
            if c not in v["coords"] and len(v["coords"]) < MAX_COORDS:
                v["coords"].append(c)
        if rid not in v["recipes"]:
            v["recipes"].append(rid)
        if notes and not v.get("notes"):
            v["notes"] = notes

    def spawn_spots(npc):
        spots = []
        for area, pts in npc["spawns"].items():
            zone = areas.get(int(area))
            if zone:
                coords = [(round(p[0] / 100, 4), round(p[1] / 100, 4)) for p in pts
                          if isinstance(p, list) and len(p) >= 2 and p[0] >= 0]
                spots.append((zone[1], coords, team_of(npc["faction"])))
        return spots

    npc_spawns_by_name = {}
    _all_names = {}

    def all_npcs_by_name():
        if not _all_names:
            for k in qdb.meta:
                m = re.match(r'^X-Npc-(\d+)-S$', k)
                if m:
                    row = qdb.row("Npc", int(m.group(1)))
                    if row and row.get(1):
                        _all_names.setdefault(row[1], int(m.group(1)))
        return _all_names
    for r in recipes.values():
        for nid in r.get("qdb_vendors", []):
            if nid not in npc_cache:
                npc_cache[nid] = qdb.npc(nid)
            npc = npc_cache[nid]
            if npc and npc["name"] and npc["spawns"] and npc["name"] not in npc_spawns_by_name:
                npc_spawns_by_name[npc["name"]] = spawn_spots(npc)

    stats = defaultdict(int)
    for rid, r in sorted(recipes.items()):
        if rid in exclude or "type" not in r:
            continue
        placed = False
        # QuestieDB vendors (Forever spawns)
        for nid in r.get("qdb_vendors", []):
            if nid not in npc_cache:
                npc_cache[nid] = qdb.npc(nid)
            npc = npc_cache[nid]
            if not npc or not npc["name"]:
                continue
            for area, pts in npc["spawns"].items():
                zone = areas.get(int(area))
                if not zone:
                    stats["spawn_area_unknown"] += 1
                    continue
                coords = [(round(p[0] / 100, 4), round(p[1] / 100, 4)) for p in pts
                          if isinstance(p, list) and len(p) >= 2 and p[0] >= 0]
                add_vendor(zone[1], ("npc", nid), npc["name"], team_of(npc["faction"]), coords, rid,
                           classic_notes.get((zone[1], npc["name"])))
                placed = True
        # AllTheThings vendors not known to QuestieDB for this item
        for nid, hdr in (r.get("att_vendors") or {}).items():
            if nid not in npc_cache:
                npc_cache[nid] = qdb.npc(nid)
            npc = npc_cache[nid]
            name = npc["name"] if npc else None
            if name and any(rid in reg[("vendor", name)]["recipes"]
                            for reg in regions.values() if ("vendor", name) in reg):
                continue
            for map_id, x, y in hdr["coords"]:
                zone = map_to_zone.get(map_id)
                if zone and name:
                    add_vendor(zone, ("npc", nid), name, team_of(npc and npc["faction"], hdr["side"]),
                               [(round(x / 100, 4), round(y / 100, 4))], rid)
                    placed = True
                    stats["att_vendor"] += 1
        # classic vendors QuestieDB doesn't list (kept with original coordinates)
        for rn, creg in classic_regions.items():
            for v in creg["vendors"]:
                if rid not in v["recipes"]:
                    continue
                if any(rv["name"] == v["name"] and rid in rv["recipes"]
                       for reg in regions.values() for rv in reg.values()):
                    continue
                spots = npc_spawns_by_name.get(v["name"])
                if spots is None:
                    # not a recipe vendor in QuestieDB: look the NPC up by name
                    nid = all_npcs_by_name().get(v["name"])
                    npc = nid and qdb.npc(nid)
                    spots = npc_spawns_by_name[v["name"]] = (spawn_spots(npc) if npc and npc["spawns"] else [])
                if spots:
                    for zone, coords, team in spots:
                        add_vendor(zone, None, v["name"], team, coords, rid, v.get("notes"))
                    stats["classic_pair_moved_to_forever_spawn"] += 1
                else:
                    add_vendor(rn, None, v["name"], v["team"], v["coords"], rid, v.get("notes"))
                    stats["classic_only"] += 1
                placed = True
        stats["placed" if placed else "unplaced"] += 1

    # region metadata
    zone_maps = {}
    instances = set()
    for area, (map_id, name) in areas.items():
        if map_id:
            zone_maps.setdefault(name, map_id)
        else:
            instances.add(name)
    region_out = OrderedDict()
    for rn in sorted(regions):
        vendors = [v for k, v in regions[rn].items() if isinstance(k, tuple)]
        if not vendors:
            continue
        cont = classic_cont.get(rn, overrides_cont.get(rn))
        if cont is None and rn in instances and rn not in zone_maps:
            cont = 0
        region_out[rn] = {"map": zone_maps.get(rn), "continent": cont, "vendors": vendors}

    write_region(os.path.join(args.out, "RegionData.lua"), region_out, recipes, qdb.version)
    write_recipes(os.path.join(args.out, "RecipeData.lua"), region_out, recipes, qdb.version)

    used = {rid for reg in region_out.values() for v in reg["vendors"] for rid in v["recipes"]}
    by_prof = defaultdict(int)
    for rid in used:
        by_prof[recipes[rid]["type"]] += 1
    print("regions:", len(region_out), "vendors:", sum(len(r["vendors"]) for r in region_out.values()),
          "recipes:", len(used))
    print("by profession:", dict(sorted(by_prof.items())))
    print("new (>200000):", len([r for r in used if r > 200000]),
          "Merchant's Favor:", len([r for r in used if recipes[r].get("currency") == MERCHANTS_FAVOR]),
          "token:", len([r for r in used if recipes[r].get("token")]),
          "certifications:", len([r for r in used if recipes[r].get("certification")]))
    print("skill unknown (filled at runtime):", len([r for r in used if not recipes[r].get("skill")]),
          "price unknown:", len([r for r in used if not (recipes[r].get("cost") or recipes[r].get("currency") or recipes[r].get("token"))]))
    print("regions without uiMapID:", [r for r, v in region_out.items() if not v["map"]])
    print("regions without continent:", [r for r, v in region_out.items() if v["continent"] is None])
    print("stats:", dict(stats))


def recipe_fields(rid, r):
    parts = ["ID = %d" % rid, "Type = RRS(%s)" % lua_str(r["type"])]
    if r.get("skill"):
        parts.append("Skill = %d" % r["skill"])
    if r.get("cost"):
        parts.append("Cost = %d" % r["cost"])
    if r.get("currency"):
        parts.append("Currency = %d, Amount = %d" % (r["currency"], r["amount"]))
    if r.get("token"):
        parts.append("Token = %d, Amount = %d" % (r["token"], r["amount"]))
    if r.get("faction"):
        parts.append("Faction = RRS(%s)" % lua_str(r["faction"]))
    if r.get("faction_id"):
        parts.append("FactionID = %d, Level = %d" % (r["faction_id"], r.get("level", 4)))
    if r.get("specialty"):
        parts.append("Specialty = RRS(%s)" % lua_str(r["specialty"]))
    if r.get("notes"):
        parts.append("Notes = RRS(%s)" % lua_str(r["notes"]))
    if r.get("certification"):
        parts.append("IsCertification = true")
    return ", ".join(parts)


HEADER = """-- %s: GENERATED by tools/build_data.py. Do not edit by hand; rerun the script.
-- Data: original Recipe Radar vendor database (Jay Miller), QuestieDB (GPLv3,
-- build %s) and AllTheThings Forever data. See tools/build_data.py and PORTING.md.

local addonName, ns = ...

"""


def write_region(path, regions, recipes, version):
    out = io.StringIO()
    out.write(HEADER % ("RegionData.lua", version))
    out.write("RecipeRadar_RegionData = {\n\n")
    for rn, reg in regions.items():
        out.write("[%s] = {\n" % lua_str(rn))
        if reg["continent"] is not None:
            out.write("   Continent = %d,\n" % reg["continent"])
        if reg["map"]:
            out.write("   UiMapID = %d,\n" % reg["map"])
        out.write("   Vendors = {\n")
        for v in sorted(reg["vendors"], key=lambda v: v["name"]):
            out.write("      {\n         Name = RRS(%s),\n         Team = %s,\n" % (lua_str(v["name"]), lua_str(v["team"])))
            if v.get("notes"):
                out.write("         Notes = RRS(%s),\n" % lua_str(v["notes"]))
            if v["coords"]:
                out.write("         Coordinates = {\n")
                for x, y in v["coords"]:
                    out.write("            { x = %s, y = %s },\n" % (round(x, 4), round(y, 4)))
                out.write("         },\n")
            out.write("         Recipes = {\n")
            for rid in sorted(v["recipes"]):
                out.write("            { %s },\n" % recipe_fields(rid, recipes[rid]))
            out.write("         },\n      },\n")
        out.write("   },\n},\n\n")
    out.write("}\n\nRecipeRadar_MaxVendorCoordinates = %d\n" % MAX_COORDS)
    io.open(path, "w", encoding="utf-8", newline="\n").write(out.getvalue())


def write_recipes(path, regions, recipes, version):
    locations = defaultdict(list)
    for rn, reg in regions.items():
        for v in reg["vendors"]:
            for rid in v["recipes"]:
                locations[rid].append((rn, v["name"], v["team"]))
    by_prof = defaultdict(list)
    for rid in locations:
        by_prof[recipes[rid]["type"]].append(rid)
    out = io.StringIO()
    out.write(HEADER % ("RecipeData.lua", version))
    out.write("RecipeRadar_RecipeData = {\n\n")
    for prof in sorted(by_prof):
        out.write("[RRS(%s)] = {\n   Recipes = {\n" % lua_str(prof))
        for rid in sorted(by_prof[prof]):
            out.write("      {\n         %s,\n         Locations = {\n" % recipe_fields(rid, recipes[rid]))
            for rn, vn, team in sorted(set(locations[rid])):
                out.write("            { Region = %s, Vendor = RRS(%s), Team = %s },\n" % (lua_str(rn), lua_str(vn), lua_str(team)))
            out.write("         },\n      },\n")
        out.write("   },\n},\n\n")
    out.write("}\n")
    io.open(path, "w", encoding="utf-8", newline="\n").write(out.getvalue())


if __name__ == "__main__":
    sys.exit(main())
