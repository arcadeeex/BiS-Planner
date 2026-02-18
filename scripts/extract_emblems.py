# -*- coding: utf-8 -*-
"""Extract emblem vendor equipment from AtlasLoot WotLK."""
import re
import os
from collections import defaultdict

SRC = r"C:\Users\Артем\Desktop\AtlasLoot\AtlasLoot_WrathoftheLichKing\wrathofthelichking.lua"

# AtlasLoot slot markers -> BisEquip slot IDs
SLOT_MAP = {
    "#s1#": 1, "#s2#": 2, "#s3#": 3, "#s4#": 15, "#s5#": 5,
    "#s8#": 9, "#s9#": 10, "#s10#": 6, "#s11#": 7, "#s12#": 8,
    "#s13#": 11, "#s14#": 13, "#s15#": 17, "#s16#": 18, "#s21#": 18,
    "#h1#": 16, "#h2#": 16, "#h3#": 16, "#h4#": 17,
    "#w1#": 16, "#w2#": 18, "#w4#": 16, "#w5#": 18, "#w6#": 16,
    "#w8#": 17, "#w9#": 16, "#w10#": 16, "#w11#": 18, "#w12#": 18,
    "#w13#": 17, "#w14#": 18, "#w15#": 18, "#w16#": 18, "#w17#": 18, "#w21#": 18,
}

# Exclude: tokens (#e15#), mounts (#e12#, #e13#), gems (#e7#), mats (#e6#), keys (#e9#), recipes (#p#)
EXCLUDE = ("#e15#", "#e12#", "#e13#", "#e7#", "#e6#", "#e9#", "#p1#", "#p2#", "#p3#")

TABLE_TO_SECTION = {
    "EmblemofHeroism": "emblem_200",
    "EmblemofHeroism2": "emblem_200",
    "EmblemofValor": "emblem_213",
    "EmblemofValor2": "emblem_213",
    "EmblemofConquest1": "emblem_226",
    "EmblemofConquest2": "emblem_226",
    "EmblemofTriumph2": "emblem_245",
    "EmblemofTriumph1_H": "emblem_245",
    "EmblemofFrost": "emblem_264",
    "EmblemofFrost2": "emblem_264",
    "EmblemofScorching": "emblem_277",
    "EmblemofScorching2": "emblem_277",
    "EmblemofScorching3": "emblem_277",
}

# Row regex: { index, itemId, "", "name", "=ds=...", "cost"};
ROW_RE = re.compile(
    r'\{\s*\d+\s*,\s*(\d+)\s*,\s*"[^"]*"\s*,\s*"[^"]*"\s*,\s*"([^"]*)"'
)


def extract_table_block(text, table_id):
    """Return the raw block between table start and next AtlasLoot_Data or EOF."""
    m = re.search(r'AtlasLoot_Data\["%s"\]\s*=\s*\{' % re.escape(table_id), text)
    if not m:
        return None
    start = m.start()
    block_start = text.find("{", m.end())
    # Find end: next AtlasLoot_Data[" or end of file; take content up to closing };
    next_table = re.search(r'\n\s*AtlasLoot_Data\["', text[block_start:])
    if next_table:
        block = text[block_start : block_start + next_table.start()]
    else:
        block = text[block_start:]
    return block


def is_equipment(desc):
    desc_lower = desc.lower()
    for ex in EXCLUDE:
        if ex in desc_lower:
            return False
    # Tokens have "=ds=" with no slot marker
    if "=ds=" in desc_lower and not re.search(r"#s\d+#|#h\d+#|#w\d+#", desc_lower):
        return False
    return True


def get_slot(desc):
    # Prefer slot markers in order (first match wins for ambiguity)
    for marker, slot in sorted(SLOT_MAP.items(), key=lambda x: -len(x[0])):
        if marker in desc:
            return slot
    return None


def main():
    text = open(SRC, encoding="utf-8", errors="ignore").read()
    items_by_section = defaultdict(lambda: defaultdict(set))

    for table_id, section_id in TABLE_TO_SECTION.items():
        block = extract_table_block(text, table_id)
        if not block:
            print("SKIP", table_id)
            continue
        for m in ROW_RE.finditer(block):
            item_id = int(m.group(1))
            desc = m.group(2)
            if not is_equipment(desc):
                continue
            slot = get_slot(desc)
            if slot is None:
                continue
            items_by_section[section_id][slot].add(item_id)

    # Output Lua
    sections = [
        ("emblem_200", "200 ilvl"),
        ("emblem_213", "213 ilvl"),
        ("emblem_226", "226 ilvl"),
        ("emblem_245", "245 ilvl"),
        ("emblem_264", "264 ilvl"),
        ("emblem_277", "277 ilvl"),
    ]
    lines = []
    lines.append("BisEquip_ModuleData = BisEquip_ModuleData or {}")
    lines.append('BisEquip_ModuleData["Emblems"] = {')
    lines.append('  id = "Emblems",')
    lines.append('  name = "Вендор",')
    lines.append("  sections = {")
    for sec_id, sec_name in sections:
        lines.append("    {")
        lines.append('      id = "%s",' % sec_id)
        lines.append('      name = "%s",' % sec_name)
        lines.append("    },")
    lines.append("  },")
    lines.append("  itemsBySection = {")
    for sec_id, sec_name in sections:
        rows = items_by_section.get(sec_id, {})
        if not rows:
            continue
        lines.append("    -- %s" % sec_name)
        lines.append('    ["%s"] = {' % sec_id)
        all_items = []
        for slot, items in sorted(rows.items()):
            for item in sorted(items):
                all_items.append((slot, item))
        for slot, item in sorted(all_items, key=lambda x: (x[0], x[1])):
            lines.append("      { slot = %d, item = %d }," % (slot, item))
        lines.append("    },")
    lines.append("  },")
    lines.append("}")
    out = "\n".join(lines)
    dst = os.path.join(
        os.path.dirname(__file__),
        "..",
        "Data",
        "Modules",
        "Emblems.lua",
    )
    with open(dst, "w", encoding="utf-8") as f:
        f.write(out)
    print("Wrote", dst)


if __name__ == "__main__":
    main()
