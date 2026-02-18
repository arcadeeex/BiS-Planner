"""Rules for splitting AtlasLoot data into BisEquip modules."""

from __future__ import annotations

import re
from typing import Dict, Optional


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

ALLOWED_LEGENDARY_IDS = {
    46017,   # Val'anyr
    151821,  # Val'anyr (Sirus variant)
    49623,   # Shadowmourne
    436,     # EternityChill (Вечный Холод)
}

SIRUS_HISTORIES_PREFIXES = (
    "goblinh",
    "nagah",
    "vorgenh",
    "helfh",
    "pandhhor",
    "vulphhor",
    "drakthhor",
    "pandhal",
    "vulphal",
    "drakthal",
)


def _norm(table_id: str) -> str:
    return (
        str(table_id or "")
        .replace("_A", "")
        .replace("_H", "")
        .replace("25ManHEROIC", "")
        .replace("25Man", "")
        .replace("HEROIC", "")
        .lower()
    )


def _pvp_season(table_id: str) -> Optional[str]:
    b = _norm(table_id)
    if "pvp80" not in b and "toravon" not in b:
        return None
    if any(x in b for x in ("unset10", "unset9", "unset8", "unset66", "nonset4")) or b.endswith("3"):
        return "A11"
    if any(x in b for x in ("unset7", "unset55")):
        return "A10"
    if any(x in b for x in ("unset6", "unset44")):
        return "A9"
    if any(x in b for x in ("unset5", "nonset3")):
        return "A8"
    if any(x in b for x in ("unset4", "nonset2")):
        return "A7"
    if b.endswith("2"):
        return "A6"
    if any(x in b for x in ("unset3", "unset2", "unset1", "nonset1", "nonset0")):
        return "A5"
    if "toravon" in b:
        # On Sirus a large subset of set pieces comes from VoA(Toravon).
        return "A7"
    return "A6"


def _pvp_class(table_id: str) -> str:
    b = _norm(table_id)
    for token, label in CLASS_BY_TOKEN.items():
        if token in b:
            return label
    return "Общее"


def classify_entry(
    table_id: str,
    difficulty: str,
    item_id: int,
    slot_id: Optional[int] = None,
    pvp_season_override: Optional[str] = None,
    pvp_class_override: Optional[str] = None,
) -> Optional[Dict[str, str]]:
    """Return module metadata for an item row or None if excluded."""
    b = _norm(table_id)
    if item_id <= 0:
        return None
    # Drop obvious non-item placeholders from AtlasLoot rows.
    if item_id < 1000 and item_id not in ALLOWED_LEGENDARY_IDS:
        return None

    # Hard excludes
    if any(
        b.startswith(p)
        for p in (
            "aq20",
            "aq40",
            "brd",
            "lbrs",
            "ubrs",
            "strat",
            "scholo",
            "gnomer",
            "gnomeregan",
            "uldaman",
            "deadmines",
            "thedeadmines",
            "wailingcaverns",
            "razorfen",
            "vwow",
            "vwowsets",
            "worldbossesclassic",
            "t0",
            "t11",
            "winterfinretreat",
        )
    ):
        return None

    # PvP + Wintergrasp
    if "lakewintergrasp" in b or "venturebay" in b:
        return {
            "module": "PVP",
            "category": "PvP награды",
            "instance": "Озеро Ледяных Оков",
            "source_label": "Озеро Ледяных Оков",
            "class_label": "Общее",
        }
    if "pvp80" in b or "gladiator" in b or "toravon" in b:
        season = pvp_season_override or _pvp_season(table_id) or "A6"
        class_label = pvp_class_override or _pvp_class(table_id)
        return {
            "module": "PVP",
            "category": "PvP награды",
            "instance": season,
            "source_label": class_label,
            "class_label": class_label,
        }

    # Emblems / vendor for points
    if b.startswith("emblemof") or b.startswith("hardmode"):
        return {
            "module": "Emblems",
            "category": "Вещи за ОД",
            "instance": "Артефакты",
            "source_label": "Эмблемы",
            "class_label": "Общее",
        }

    # Sets (t4,t5,t7,t8,t9,t10; t6 excluded by request)
    if b.startswith("t4") or b.startswith("t5") or b.startswith("t7") or b.startswith("t8") or b.startswith("t9") or b.startswith("t10") or b.startswith("maar'nt9") or b.startswith("lilit5"):
        tier = "Т5"
        m = re.match(r"^t(\d+)", b)
        if m:
            tier = f"Т{m.group(1)}"
        elif b.startswith("maar'nt9"):
            tier = "Т9"
        elif b.startswith("lilit5"):
            tier = "Т5"
        return {
            "module": "Sets",
            "category": "Сеты",
            "instance": tier,
            "source_label": "Сеты",
            "class_label": _pvp_class(table_id),
        }
    if b.startswith("t6"):
        return None

    # Legendary (requested limited set)
    if b.startswith("legendaries"):
        if item_id not in ALLOWED_LEGENDARY_IDS:
            return None
        return {
            "module": "Legendary",
            "category": "Легендарные предметы",
            "instance": "Легендарки",
            "source_label": "Легендарные",
            "class_label": "Общее",
        }
    if item_id in ALLOWED_LEGENDARY_IDS:
        return {
            "module": "Legendary",
            "category": "Легендарные предметы",
            "instance": "Легендарки",
            "source_label": "Легендарные",
            "class_label": "Общее",
        }

    # Dailies (Sirus): Кель'Данас, Тол'Гарод (по фракции), Истории прошлого
    if any(
        x in b
        for x in (
            "tol'garod",
            "keldanas",
            "sunoffensive",
            "seventh_legion",
            "kor'kron_battalion",
            "golden_scorpid",
            "history",
            "historiesofthepast",
            "historyofthepast",
        )
    ) or b.startswith(SIRUS_HISTORIES_PREFIXES):
        instance = "Дейлики"
        source_label = "Дейлики"
        if "sunoffensive" in b or "keldanas" in b:
            instance = "Кель'Данас"
            source_label = "Кель'Данас"  # одна секция без подсекций
        elif "seventh_legion" in b or "kor'kron_battalion" in b or "kor'kron_batallion" in b or "golden_scorpid" in b or "tol'garod" in b:
            instance = "Тол'Гарод"
            source_label = "Тол'Гарод"  # фракция фильтруется в ModuleData
        elif b.startswith(SIRUS_HISTORIES_PREFIXES) or "history" in b:
            instance = "Истории прошлого"
            source_label = "Истории прошлого"
        return {
            "module": "Dailies",
            "category": "Дейлики",
            "instance": instance,
            "source_label": source_label,
            "class_label": "Общее",
        }

    # Crafting
    if any(
        b.startswith(p)
        for p in (
            "blacksmithing",
            "tailoring",
            "leatherworking",
            "engineering",
            "alchemy",
            "jewelcrafting",
            "inscription",
            "enchanting",
            "cooking",
        )
    ):
        return {
            "module": "Crafting",
            "category": "Ремесло",
            "instance": "Профессии",
            "source_label": "Профессии",
            "class_label": "Общее",
        }

    # Reputations
    if any(
        b.startswith(p)
        for p in (
            "argentcrusade",
            "kirintor",
            "knightsoftheebonblade",
            "thewyrmrestaccord",
            "thesonsofhodir",
            "alliancevanguard",
            "hordeexpedition",
            "violeteye",
            "thekaluak",
            "skyguard",
            "peppa",
            "history",
            "historiesofthepast",
            "historyofthepast",
        )
    ):
        return {
            "module": "Reputations",
            "category": "Репутации",
            "instance": "Фракции",
            "source_label": "Репутация",
            "class_label": "Общее",
        }

    # World events
    if any(
        b.startswith(p)
        for p in (
            "darkmoon",
            "halloween",
            "headlesshorseman",
            "loveisintheair",
            "valentineday",
            "midsummer",
            "lordahune",
            "lordeahune",
            "brewfest",
            "lunarfestival",
        )
    ):
        # Keep only meaningful stat gear in event section.
        if slot_id in (4, 19):
            return None
        if b.startswith("halloween2") and item_id < 30000:
            return None
        instance = "Ивенты"
        source_label = instance
        if b.startswith("darkmoon"):
            instance = "Ярмарка Новолуния"
            source_label = "Ярмарка"
        elif b.startswith("halloween") or b.startswith("headlesshorseman"):
            instance = "Тыквовин"
            source_label = instance
        elif b.startswith("loveisintheair") or b.startswith("valentineday"):
            instance = "Любовная лихорадка"
            source_label = instance
        elif b.startswith("midsummer") or b.startswith("lordahune") or b.startswith("lordeahune"):
            instance = "Огненный солнцеворот"
            source_label = instance
        elif b.startswith("brewfest"):
            instance = "Хмельной фестиваль"
            source_label = instance
        elif b.startswith("lunarfestival"):
            instance = "Лунный фестиваль"
            source_label = instance
        return {
            "module": "WorldEvents",
            "category": "Мировые события",
            "instance": instance,
            "source_label": source_label,
            "class_label": "Общее",
        }

    # World boss Norigorn only
    if b.startswith("norigorn"):
        return {
            "module": "WorldBosses",
            "category": "Мировые боссы",
            "instance": "Норигорн",
            "source_label": "Норигорн",
            "class_label": "Общее",
        }

    # Wrath dungeons
    if any(
        b.startswith(p)
        for p in (
            "utgardekeep",
            "upsvala",
            "upgortok",
            "upskadi",
            "upymiron",
            "thenexus",
            "draktharonkeep",
            "hallsofstone",
            "hallsoflightning",
            "azjolnerub",
            "ahnkahet",
            "gundrak",
            "violethold",
            "cotstratholme",
            "trialofthechampion",
            "pos",
            "fos",
            "hor",
        )
    ):
        return {
            "module": "WotLKDungeons",
            "category": "Подземелья WotLK",
            "instance": "Подземелья",
            "source_label": table_id,
            "class_label": "Общее",
        }

    # BC dungeons heroic only
    if any(b.startswith(p) for p in ("auch", "cfr", "tkbot", "tkarc", "tkmech", "hcfurnace", "hchalls", "hcramp", "cothillsbrad")):
        raw = str(table_id).lower()
        heroic = "heroic" in raw or raw.startswith("hc")
        if not heroic:
            return None
        return {
            "module": "BCDungeonsHeroic",
            "category": "Подземелья BC",
            "instance": "5хм",
            "source_label": table_id,
            "class_label": "Общее",
        }

    # WotLK raids
    if any(
        b.startswith(p)
        for p in (
            "naxx80",
            "ulduar",
            "icc",
            "sartharion",
            "malygos",
            "halion",
            "trialofthecrusader",
            "vaultofarchavon",
            "onyxia",
        )
    ):
        return {
            "module": "WotLKRaid",
            "category": "Рейды WotLK",
            "instance": "Рейды",
            "source_label": table_id,
            "class_label": "Общее",
        }

    # BC raids whitelist from request
    if any(
        b.startswith(p)
        for p in (
            "gruul",
            "gruulslair",
            "hcmagtheridon",
            "karazhan",
            "kara",
            "blacktemple",
            "bt",
            "mounthyjal",
            "serpentshrine",
            "ssc",
            "tempestkeep",
            "tkeye",
            "zulaman",
            "za",
        )
    ):
        source_label = table_id
        if b.startswith("zanalorakk"):
            source_label = "Налоракк"
        elif b.startswith("zaakilzon"):
            source_label = "Акил'зон"
        elif b.startswith("zajanalai"):
            source_label = "Джан'алай"
        elif b.startswith("zahalazzi"):
            source_label = "Халаззи"
        elif b.startswith("zamalacrass"):
            source_label = "Малакрасс"
        elif b.startswith("zazuljin"):
            source_label = "Зул'джин"
        return {
            "module": "BCRaid",
            "category": "Рейды BC",
            "instance": "Рейды",
            "source_label": source_label,
            "class_label": "Общее",
        }

    # Sirus custom raids: Bronze Sanctuary and variants (Elonus/ElonusHARD, Imporus/ImporusHARD, etc. — объединяем в одну секцию).
    if b.startswith("elonus") or b.startswith("imporus") or b.startswith("murozond"):
        source_label = "Элонус"
        if b.startswith("imporus"):
            source_label = "Импорус"
        elif b.startswith("murozond"):
            source_label = "Мурозонд"
        return {
            "module": "WotLKRaid",
            "category": "Рейды Sirus",
            "instance": "Бронзовое святилище",
            "source_label": source_label,
            "class_label": "Общее",
        }

    return None
