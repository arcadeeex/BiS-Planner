# -*- coding: utf-8 -*-
"""Integrity checks for generated BisEquip legacy + module snapshots."""
import os
import re
import sys
from collections import defaultdict


ROW_RE = re.compile(r'\{\s*(\d+)\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\}')
SLOT_RE = re.compile(r"BisEquip_ItemDB\[(\d+)\]\s*=\s*\{")
SRC_RE = re.compile(r'BisEquip_ItemSources\[(\d+)\]\s*=\s*\{\s*source\s*=\s*"([^"]+)"\s*,\s*difficulty\s*=\s*"([^"]+)"')
MODULE_ROW_RE = re.compile(
    r'\{\s*slot\s*=\s*(\d+)\s*,\s*item\s*=\s*(\d+)\s*,\s*source\s*=\s*"([^"]+)"\s*,\s*difficulty\s*=\s*"([^"]+)"\s*,\s*category\s*=\s*"([^"]+)"\s*,\s*instance\s*=\s*"([^"]+)"\s*,\s*sourceLabel\s*=\s*"([^"]+)"\s*,\s*classLabel\s*=\s*"([^"]+)"\s*\}'
)

PVP_CLASSES = {
    "Воин",
    "Паладин",
    "Охотник",
    "Разбойник",
    "Жрец",
    "Рыцарь смерти",
    "Шаман",
    "Маг",
    "Чернокнижник",
    "Друид",
    "Общее",
}


def parse_items_full(path):
    with open(path, encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    slot_to_items = defaultdict(dict)
    item_sources = {}
    current_slot = None
    for line in lines:
        m_slot = SLOT_RE.search(line)
        if m_slot:
            current_slot = int(m_slot.group(1))
            continue
        if current_slot is not None:
            m_row = ROW_RE.search(line)
            if m_row:
                item_id = int(m_row.group(1))
                table_id = m_row.group(2)
                difficulty = m_row.group(3)
                slot_to_items[current_slot][item_id] = (table_id, difficulty)
        m_src = SRC_RE.search(line)
        if m_src:
            item_id = int(m_src.group(1))
            item_sources[item_id] = (m_src.group(2), m_src.group(3))

    return slot_to_items, item_sources


def parse_module_rows(path):
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            m = MODULE_ROW_RE.search(line)
            if not m:
                continue
            rows.append(
                {
                    "slot": int(m.group(1)),
                    "item": int(m.group(2)),
                    "source": m.group(3),
                    "difficulty": m.group(4),
                    "category": m.group(5),
                    "instance": m.group(6),
                    "sourceLabel": m.group(7),
                    "classLabel": m.group(8),
                }
            )
    return rows


def main():
    addon_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_file = os.path.join(addon_root, "Data", "ItemsFull.lua")
    if not os.path.exists(data_file):
        print("ERROR: missing", data_file)
        return 2

    slot_to_items, item_sources = parse_items_full(data_file)
    total_items = sum(len(v) for v in slot_to_items.values())
    unique_items = set()
    invalid_difficulty = []
    missing_source_refs = []

    for slot, by_id in slot_to_items.items():
        for item_id, (table_id, diff) in by_id.items():
            unique_items.add(item_id)
            if diff not in ("10N", "25N", "10H", "25H"):
                invalid_difficulty.append((slot, item_id, diff))
            src = item_sources.get(item_id)
            if not src:
                missing_source_refs.append((slot, item_id, table_id))

    print("Snapshot validation")
    print("===================")
    print("Slots:", len(slot_to_items))
    print("Rows:", total_items)
    print("Unique items:", len(unique_items))
    print("ItemSources:", len(item_sources))

    if invalid_difficulty:
        print("ERROR: invalid difficulty rows:", len(invalid_difficulty))
        print("First 10:", invalid_difficulty[:10])
        return 1
    if missing_source_refs:
        print("ERROR: missing ItemSources refs:", len(missing_source_refs))
        print("First 10:", missing_source_refs[:10])
        return 1

    if len(slot_to_items) < 15 or len(unique_items) < 3000:
        print("ERROR: snapshot looks incomplete")
        return 1

    modules_dir = os.path.join(addon_root, "Data", "Modules")
    pvp_file = os.path.join(modules_dir, "PVP.lua")
    pvp_rows = parse_module_rows(pvp_file)
    if not pvp_rows:
        print("ERROR: empty/missing PVP module:", pvp_file)
        return 1

    by_season = defaultdict(int)
    by_slot_season = defaultdict(int)
    bad_classes = []
    for r in pvp_rows:
        if r["instance"].startswith("A"):
            by_season[r["instance"]] += 1
            by_slot_season[(r["slot"], r["instance"])] += 1
            if r["classLabel"] not in PVP_CLASSES:
                bad_classes.append((r["item"], r["classLabel"]))

    print("PVP module rows:", len(pvp_rows))
    print("PVP season counts:", dict(sorted(by_season.items())))

    # Required seasons and slot coverage (A7 fix focus).
    for req in ("A5", "A6", "A7", "A8", "A9", "A10", "A11"):
        if by_season[req] <= 0:
            print("ERROR: missing season in PVP module:", req)
            return 1
    for slot in (1, 3, 5):
        if by_slot_season[(slot, "A7")] <= 0:
            print("ERROR: A7 missing for slot", slot)
            return 1
    if bad_classes:
        print("ERROR: unexpected PVP class labels:", bad_classes[:10])
        return 1

    print("OK: snapshot looks consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())

