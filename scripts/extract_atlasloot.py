# -*- coding: utf-8 -*-
"""Generate static BisEquip snapshots (legacy + module-based)."""
import argparse
import os
import re
from collections import defaultdict

from module_rules import classify_entry


SLOT_MAP = {
    "#s1#": 1, "#s2#": 2, "#s3#": 3, "#s4#": 15, "#s5#": 5, "#s6#": 4, "#s7#": 19,
    "#s8#": 9, "#s9#": 10, "#s10#": 6, "#s11#": 7, "#s12#": 8, "#s13#": 11,
    "#s14#": 13, "#s15#": 17, "#s16#": 18, "#h1#": 16, "#h2#": 16, "#h3#": 16, "#h4#": 17,
    "#w1#": 16, "#w2#": 18, "#w4#": 16, "#w5#": 18, "#w6#": 16, "#w8#": 17,
    "#w9#": 16, "#w10#": 16, "#w12#": 16, "#w13#": 17, "#w17#": 18,
}

RUS_SLOT_KEYWORDS = [
    ("голова", 1),
    ("шея", 2),
    ("плеч", 3),
    ("груд", 5),
    ("пояс", 6),
    ("ног", 7),
    ("ступ", 8),
    ("запясть", 9),
    ("кисти", 10),
    ("кольц", 11),
    ("аксессуар", 13),
    ("плащ", 15),
    ("спина", 15),
    ("правая рука", 16),
    ("левая рука", 17),
    ("щит", 17),
    ("дальний бой", 18),
    ("реликвия", 18),
]

DEFAULT_MODULE_ORDER = [
    "AtlasLoot_OriginalWoW",
    "AtlasLoot_BurningCrusade",
    "AtlasLoot_Crafting",
    "AtlasLoot_WorldEvents",
    "AtlasLoot_WrathoftheLichKing",
    "AtlasLoot_Sirus",
    "AtlasLoot_PVP",
]

OUTPUT_MODULES = [
    "PVP",
    "WotLKDungeons",
    "BCDungeonsHeroic",
    "WotLKRaid",
    "BCRaid",
    "Reputations",
    "WorldEvents",
    "WorldBosses",
    "Crafting",
    "Dailies",
    "Sets",
    "Emblems",
    "Legendary",
]

MODULE_DISPLAY_NAMES = {
    "PVP": "PvP награды",
    "WotLKDungeons": "Подземелья WotLK",
    "BCDungeonsHeroic": "Подземелья BC",
    "WotLKRaid": "Рейды WotLK",
    "BCRaid": "Рейды BC",
    "Reputations": "Репутации",
    "WorldEvents": "Мировые события",
    "WorldBosses": "Мировые боссы",
    "Crafting": "Ремесло",
    "Dailies": "Дейлики",
    "Sets": "Сеты",
    "Emblems": "Вещи за ОД",
    "Legendary": "Легендарные предметы",
}

ARENASET_TO_SEASON = {
    "5": "A5",
    "6": "A6",
    "7": "A7",
    "8": "A8",
    "9": "A9",
    "10": "A10",
    "11": "A11",
    "12": "A12",
    "13": "A13",
}

CLASS_BY_TOKEN = {
    "deathknight": "Рыцарь смерти",
    "warrior": "Воин",
    "paladin": "Паладин",
    "hunter": "Охотник",
    "rogue": "Разбойник",
    "priest": "Жрец",
    "shaman": "Шаман",
    "mage": "Маг",
    "warlock": "Чернокнижник",
    "druid": "Друид",
}


def parse_difficulty(table_id):
    t = table_id.upper()
    if "25MANHEROIC" in t:
        return "25H"
    if "HEROIC" in t:
        return "25H" if "25" in t else "10H"
    if "25MAN" in t or "_X4" in t:
        return "25N"
    if "_258" in t or "_271" in t or "_284" in t:
        return "25H"
    if "_245" in t or "_X2" in t:
        return "10N"
    return "10N"


def find_matching_brace(text, open_brace_index):
    depth = 0
    for i in range(open_brace_index, len(text)):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
    return -1


def parse_module_toc(addons_path, module_name):
    toc_path = os.path.join(addons_path, module_name, module_name + ".toc")
    if not os.path.exists(toc_path):
        return []
    rel_files = []
    with open(toc_path, encoding="utf-8", errors="ignore") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("##"):
                continue
            if line.lower().endswith(".lua"):
                rel_files.append(os.path.join(module_name, line.replace("\\", os.sep)))
    return rel_files


def parse_pvp_season_marker(text):
    m = re.search(r"#arenaset(\d+)#", text or "", re.IGNORECASE)
    if not m:
        return None
    return ARENASET_TO_SEASON.get(m.group(1))


def parse_pvp_class_from_table(table_id):
    low = str(table_id or "").lower()
    for token, label in CLASS_BY_TOKEN.items():
        if token in low:
            return label
    return None


def infer_pvp_slot_by_row_index(row_index):
    if row_index in (2, 9, 17, 24):
        return 1   # head
    if row_index in (3, 10, 18, 25):
        return 3   # shoulders
    if row_index in (4, 11, 19, 26):
        return 5   # chest
    if row_index in (5, 12, 20, 27):
        return 10  # hands
    if row_index in (6, 13, 21, 28):
        return 7   # legs
    return None


def infer_lili_t5_slot_by_row_index(row_index):
    # AtlasLoot_Sirus LiliT5 tables encode set pieces by row position.
    if row_index in (2, 4, 16):
        return 3   # shoulders
    if row_index in (3, 5, 17):
        return 10  # hands
    return None


def infer_t4_slot_by_row_index(row_index):
    # AtlasLoot BC T4/T4DQ tables mostly encode set slots by row index.
    if row_index in (2, 9):
        return 1   # head
    if row_index in (3, 10, 17, 18):
        return 3   # shoulders
    if row_index in (4, 11, 19):
        return 5   # chest
    if row_index in (5, 12, 20):
        return 10  # hands
    if row_index in (6, 13, 21):
        return 7   # legs
    return None


def infer_tier_slot_by_row_index(row_index):
    # Общий порядок слотов для T5/T7/T8 (Naxxramas, Ulduar, SSC/TK tier tables).
    if row_index in (2, 9):
        return 1   # head
    if row_index in (3, 10, 17, 18):
        return 3   # shoulders
    if row_index in (4, 11, 19):
        return 5   # chest
    if row_index in (5, 12, 20):
        return 10  # hands
    if row_index in (6, 13, 21):
        return 7   # legs
    return None


def parse_atlasloot_data_file(abs_path, all_items, module_items, table_ids_seen):
    with open(abs_path, encoding="utf-8", errors="ignore") as f:
        content = f.read()
    for m in re.finditer(r'AtlasLoot_Data\["([^"]+)"\]\s*=\s*\{', content):
        table_id = m.group(1)
        table_ids_seen.add(table_id)
        open_brace = content.find("{", m.end() - 1)
        close_brace = find_matching_brace(content, open_brace)
        if open_brace < 0 or close_brace < 0:
            continue
        block = content[open_brace + 1 : close_brace]
        current_pvp_season = None
        pvp_class = parse_pvp_class_from_table(table_id)
        for row in re.finditer(r'\{\s*(\d+)\s*,\s*("?[sS]?\d+"?)\s*,\s*"[^"]*"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"', block):
            row_index = int(row.group(1))
            item_token = row.group(2).strip('"')
            if item_token.lower().startswith("s"):
                continue
            if not item_token.isdigit():
                continue
            item_id = int(item_token)
            name_field = row.group(3)
            slot_desc = row.group(4)

            if item_id <= 0:
                season_marker = parse_pvp_season_marker(name_field)
                if season_marker:
                    current_pvp_season = season_marker
                continue

            slot_id = None
            for marker, mapped_slot in SLOT_MAP.items():
                if marker in slot_desc:
                    slot_id = mapped_slot
                    break
            if slot_id is None and slot_desc:
                low_desc = slot_desc.lower()
                if "декоратив" not in low_desc:
                    for token, mapped_slot in RUS_SLOT_KEYWORDS:
                        if token in low_desc:
                            slot_id = mapped_slot
                            break
            if slot_id is None and current_pvp_season and str(table_id).startswith("PvP80"):
                slot_id = infer_pvp_slot_by_row_index(row_index)
            if slot_id is None and str(table_id).startswith("LiliT5"):
                slot_id = infer_lili_t5_slot_by_row_index(row_index)
            if slot_id is None and str(table_id).startswith("T4"):
                slot_id = infer_t4_slot_by_row_index(row_index)
            if slot_id is None and any(str(table_id).lower().startswith(p) for p in ("t5", "t7", "t8")):
                slot_id = infer_tier_slot_by_row_index(row_index)
            if slot_id is None:
                continue
            diff = parse_difficulty(table_id)
            meta = classify_entry(table_id, diff, item_id, slot_id=slot_id)
            if not meta:
                continue
            all_items[slot_id][item_id] = (table_id, diff)
            if meta:
                if meta["module"] == "PVP":
                    meta = classify_entry(
                        table_id,
                        diff,
                        item_id,
                        slot_id=slot_id,
                        pvp_season_override=current_pvp_season,
                        pvp_class_override=pvp_class,
                    )
                module_name = meta["module"]
                module_items[module_name].append(
                    {
                        "slot": slot_id,
                        "item": item_id,
                        "source": table_id,
                        "difficulty": diff,
                        "category": meta["category"],
                        "instance": meta["instance"],
                        "source_label": meta["source_label"],
                        "class_label": meta["class_label"],
                    }
                )


def collect_module_lua_files(addons_path):
    rel_files = []
    for module in DEFAULT_MODULE_ORDER:
        rel_files.extend(parse_module_toc(addons_path, module))
    core_toc = os.path.join(addons_path, "AtlasLoot", "AtlasLoot.toc")
    if os.path.exists(core_toc):
        with open(core_toc, encoding="utf-8", errors="ignore") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("##"):
                    continue
                if line.lower().endswith(".lua"):
                    rel_files.append(os.path.join("AtlasLoot", line.replace("\\", os.sep)))
    seen = set()
    out = []
    for rf in rel_files:
        if rf in seen:
            continue
        seen.add(rf)
        out.append(rf)
    return out


def collect_module_lua_files_from_roots(roots):
    out = []
    for root in roots:
        for rel in collect_module_lua_files(root):
            out.append((root, rel))
    return out


def count_unique_items(all_items):
    unique = set()
    for slot_data in all_items.values():
        unique.update(slot_data.keys())
    return len(unique)


def write_module_files(output_root, module_items):
    base = os.path.join(output_root, "Data", "Modules")
    os.makedirs(base, exist_ok=True)
    out_paths = []

    def section_slug(text):
        s = str(text or "").strip().lower()
        s = re.sub(r"\s+", "_", s)
        s = re.sub(r"[^\w\-]", "_", s, flags=re.UNICODE)
        s = re.sub(r"_+", "_", s).strip("_")
        return s or "section"

    def unique_id(base_id, used_ids):
        out = base_id
        idx = 2
        while out in used_ids:
            out = f"{base_id}_{idx}"
            idx += 1
        used_ids.add(out)
        return out

    def render_sections(fh, sections, indent):
        pad = " " * indent
        for sec in sections:
            fh.write(pad + "{\n")
            fh.write(pad + '  id = "%s",\n' % sec["id"])
            fh.write(pad + '  name = "%s",\n' % sec["name"])
            if sec.get("priority") is not None:
                fh.write(pad + "  priority = %d,\n" % int(sec["priority"]))
            if sec.get("children"):
                fh.write(pad + "  children = {\n")
                render_sections(fh, sec["children"], indent + 4)
                fh.write(pad + "  },\n")
            fh.write(pad + "},\n")

    for module_name in OUTPUT_MODULES:
        rows = module_items.get(module_name, [])
        path = os.path.join(base, module_name + ".lua")

        used_ids = set()
        categories = []
        cat_map = {}
        items_by_section = defaultdict(list)
        items_seen = defaultdict(set)

        def ensure_category(cat_name):
            key = str(cat_name or "Секция")
            if key in cat_map:
                return cat_map[key]
            sec_id = unique_id("cat_" + section_slug(key), used_ids)
            node = {"id": sec_id, "name": key, "priority": None, "children": [], "_instances": {}}
            categories.append(node)
            cat_map[key] = node
            return node

        def ensure_instance(cat_node, inst_name):
            key = str(inst_name or "Подсекция")
            inst_map = cat_node["_instances"]
            if key in inst_map:
                return inst_map[key]
            sec_id = unique_id(cat_node["id"] + "__" + section_slug(key), used_ids)
            node = {"id": sec_id, "name": key, "priority": None, "children": [], "_leaves": {}}
            cat_node["children"].append(node)
            inst_map[key] = node
            return node

        def ensure_leaf(inst_node, leaf_name):
            key = str(leaf_name or "")
            if key == "" or key == inst_node["name"]:
                return inst_node
            leaf_map = inst_node["_leaves"]
            if key in leaf_map:
                return leaf_map[key]
            sec_id = unique_id(inst_node["id"] + "__" + section_slug(key), used_ids)
            node = {"id": sec_id, "name": key, "priority": None, "children": []}
            inst_node["children"].append(node)
            leaf_map[key] = node
            return node

        for r in sorted(rows, key=lambda x: (x["category"], x["instance"], x["source_label"], x["slot"], x["item"])):
            cat_node = ensure_category(r.get("category") or "Секция")
            inst_node = ensure_instance(cat_node, r.get("instance") or "Подсекция")
            target_node = ensure_leaf(inst_node, r.get("source_label") or "")
            sec_id = target_node["id"]
            slot = int(r["slot"])
            item = int(r["item"])
            key = (slot, item)
            if key in items_seen[sec_id]:
                continue
            items_seen[sec_id].add(key)
            items_by_section[sec_id].append({"slot": slot, "item": item})

        # cleanup helper maps
        for cat in categories:
            cat.pop("_instances", None)
            for inst in cat.get("children", []):
                inst.pop("_leaves", None)

        with open(path, "w", encoding="utf-8") as f:
            f.write("--[[ Auto-generated module data. Do not edit manually. ]]\n")
            f.write("BisEquip_ModuleData = BisEquip_ModuleData or {}\n")
            f.write('BisEquip_ModuleData["%s"] = {\n' % module_name)
            f.write('  id = "%s",\n' % module_name)
            f.write('  name = "%s",\n' % MODULE_DISPLAY_NAMES.get(module_name, module_name))
            f.write("  sections = {\n")
            render_sections(f, categories, 4)
            f.write("  },\n")
            f.write("  itemsBySection = {\n")
            for sec_id in sorted(items_by_section.keys()):
                f.write('    ["%s"] = {\n' % sec_id)
                for row in sorted(items_by_section[sec_id], key=lambda x: (x["slot"], x["item"])):
                    f.write("      { slot = %d, item = %d },\n" % (row["slot"], row["item"]))
                f.write("    },\n")
            f.write("  },\n")
            f.write("}\n")
        out_paths.append(path)
    return out_paths


def write_report(output_root, parsed_files, table_ids_seen, all_items, total_items, module_items):
    report_path = os.path.join(output_root, "Data", "AtlasLootExtractReport.txt")
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("AtlasLoot extraction report\n")
        f.write("==========================\n")
        f.write("Parsed files: %d\n" % len(parsed_files))
        f.write("Unique AtlasLoot tables: %d\n" % len(table_ids_seen))
        f.write("BisEquip slots generated: %d\n" % len(all_items))
        f.write("Unique item IDs generated: %d\n\n" % total_items)
        f.write("Module rows:\n")
        for module_name in OUTPUT_MODULES:
            f.write("- %s: %d\n" % (module_name, len(module_items.get(module_name, []))))
        f.write("\nFiles:\n")
        for p in parsed_files:
            f.write("- %s\n" % p)
    return report_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--addons-path", default=None, help="Absolute path where AtlasLoot folders are located")
    parser.add_argument("--output-root", default=None, help="Absolute path to BisEquip addon root for output files")
    args = parser.parse_args()

    if args.addons_path:
        addons_path = os.path.abspath(args.addons_path)
    else:
        addons_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    if args.output_root:
        output_root = os.path.abspath(args.output_root)
    else:
        output_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    roots = [addons_path]
    desktop_root = os.path.join(os.path.expanduser("~"), "Desktop", "AtlasLoot")
    if os.path.isdir(desktop_root):
        if os.path.abspath(desktop_root) != os.path.abspath(addons_path):
            roots.append(desktop_root)

    rel_lua_files = collect_module_lua_files_from_roots(roots)
    all_items = defaultdict(dict)
    module_items = defaultdict(list)
    parsed_files = []
    table_ids_seen = set()

    for root, rel in rel_lua_files:
        abs_path = os.path.join(root, rel)
        if not os.path.exists(abs_path):
            continue
        try:
            parse_atlasloot_data_file(abs_path, all_items, module_items, table_ids_seen)
            parsed_files.append((os.path.basename(root) + ":" + rel).replace(os.sep, "\\"))
        except Exception as exc:
            print("WARN: failed to parse %s: %s" % (rel, exc))

    total_items = count_unique_items(all_items)
    module_paths = write_module_files(output_root, module_items)
    report_path = write_report(output_root, parsed_files, table_ids_seen, all_items, total_items, module_items)
    for p in module_paths:
        print("Wrote %s" % p)
    print("Wrote %s" % report_path)
    print(
        "Slots: %d, items: %d, tables: %d, parsed files: %d"
        % (len(all_items), total_items, len(table_ids_seen), len(parsed_files))
    )


if __name__ == "__main__":
    main()
