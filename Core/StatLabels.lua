--[[
BiSPlanner - Shared stat display labels (nominative and dative cases).
Used by Stats.lua and ItemPicker.lua.
]]

BiSPlanner_StatLabels = BiSPlanner_StatLabels or {}
BisEquip_StatLabels = BiSPlanner_StatLabels

local DISPLAY_NAMES = {
    ["ITEM_MOD_STRENGTH_SHORT"] = "Сила", ["ITEM_MOD_AGILITY_SHORT"] = "Ловкость",
    ["ITEM_MOD_STAMINA_SHORT"] = "Выносливость", ["ITEM_MOD_INTELLECT_SHORT"] = "Интеллект",
    ["ITEM_MOD_SPIRIT_SHORT"] = "Дух", ["ITEM_MOD_ATTACK_POWER_SHORT"] = "Сила атаки",
    ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] = "Сила атаки (дальний бой)",
    ["ITEM_MOD_SPELL_POWER_SHORT"] = "Сила заклинаний", ["ITEM_MOD_ARMOR_SHORT"] = "Броня",
    ["ITEM_MOD_BLOCK_RATING_SHORT"] = "Блок", ["ITEM_MOD_DODGE_RATING_SHORT"] = "Уклонение",
    ["ITEM_MOD_PARRY_RATING_SHORT"] = "Парирование", ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] = "Защита",
    ["ITEM_MOD_HIT_RATING_SHORT"] = "Меткость", ["ITEM_MOD_HIT_MELEE_RATING_SHORT"] = "Меткость",
    ["ITEM_MOD_HIT_RANGED_RATING_SHORT"] = "Меткость", ["ITEM_MOD_HIT_SPELL_RATING_SHORT"] = "Меткость",
    ["ITEM_MOD_CRIT_RATING_SHORT"] = "Крит", ["ITEM_MOD_CRIT_MELEE_RATING_SHORT"] = "Крит",
    ["ITEM_MOD_CRIT_RANGED_RATING_SHORT"] = "Крит", ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"] = "Крит",
    ["ITEM_MOD_HASTE_RATING_SHORT"] = "Скорость", ["ITEM_MOD_HASTE_MELEE_RATING_SHORT"] = "Скорость",
    ["ITEM_MOD_HASTE_RANGED_RATING_SHORT"] = "Скорость", ["ITEM_MOD_HASTE_SPELL_RATING_SHORT"] = "Скорость",
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = "Мастерство", ["ITEM_MOD_RESILIENCE_RATING_SHORT"] = "Устойчивость",
    ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = "Пробивание брони",
    ["ITEM_MOD_ARMOR_PENETRATION_RATING"] = "Пробивание брони",
    ["ITEM_MOD_SPELL_PENETRATION_SHORT"] = "Проникновение заклинаний",
    ["ITEM_MOD_SPELL_PENETRATION"] = "Проникновение заклинаний",
    ["EMPTY_SOCKET_YELLOW"] = "желтое гнездо", ["EMPTY_SOCKET_RED"] = "красное гнездо",
    ["EMPTY_SOCKET_BLUE"] = "синее гнездо", ["EMPTY_SOCKET_META"] = "мета гнездо",
    ["RESISTANCE0_NAME"] = "Броня", ["RESISTANCE1_NAME"] = "Сопр. свету",
    ["RESISTANCE2_NAME"] = "Сопр. огню", ["RESISTANCE3_NAME"] = "Сопр. природе",
    ["RESISTANCE4_NAME"] = "Сопр. льду", ["RESISTANCE5_NAME"] = "Сопр. тьме",
    ["RESISTANCE6_NAME"] = "Сопр. тайной магии",
    ["ARMOR"] = "Броня",
    ["ITEM_MOD_MANA_REGENERATION_SHORT"] = "Мана в 5 сек",
}

local DISPLAY_NAMES_DATIVE = {
    ["ITEM_MOD_STRENGTH_SHORT"] = "силе", ["ITEM_MOD_AGILITY_SHORT"] = "ловкости",
    ["ITEM_MOD_STAMINA_SHORT"] = "выносливости", ["ITEM_MOD_INTELLECT_SHORT"] = "интеллекту",
    ["ITEM_MOD_SPIRIT_SHORT"] = "духу", ["ITEM_MOD_ATTACK_POWER_SHORT"] = "силе атаки",
    ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] = "силе атаки (дальний бой)",
    ["ITEM_MOD_SPELL_POWER_SHORT"] = "силе заклинаний", ["ITEM_MOD_ARMOR_SHORT"] = "броне",
    ["ITEM_MOD_BLOCK_RATING_SHORT"] = "блоку", ["ITEM_MOD_DODGE_RATING_SHORT"] = "уклонению",
    ["ITEM_MOD_PARRY_RATING_SHORT"] = "парированию", ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] = "защите",
    ["ITEM_MOD_HIT_RATING_SHORT"] = "меткости", ["ITEM_MOD_HIT_MELEE_RATING_SHORT"] = "меткости",
    ["ITEM_MOD_HIT_RANGED_RATING_SHORT"] = "меткости", ["ITEM_MOD_HIT_SPELL_RATING_SHORT"] = "меткости",
    ["ITEM_MOD_CRIT_RATING_SHORT"] = "криту", ["ITEM_MOD_CRIT_MELEE_RATING_SHORT"] = "криту",
    ["ITEM_MOD_CRIT_RANGED_RATING_SHORT"] = "криту", ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"] = "криту",
    ["ITEM_MOD_HASTE_RATING_SHORT"] = "скорости", ["ITEM_MOD_HASTE_MELEE_RATING_SHORT"] = "скорости",
    ["ITEM_MOD_HASTE_RANGED_RATING_SHORT"] = "скорости", ["ITEM_MOD_HASTE_SPELL_RATING_SHORT"] = "скорости",
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = "мастерству", ["ITEM_MOD_RESILIENCE_RATING_SHORT"] = "устойчивости",
    ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = "пробиванию брони",
    ["ITEM_MOD_ARMOR_PENETRATION_RATING"] = "пробиванию брони",
    ["ITEM_MOD_SPELL_PENETRATION_SHORT"] = "проникновению заклинаний",
    ["ITEM_MOD_SPELL_PENETRATION"] = "проникновению заклинаний",
    ["RESISTANCE0_NAME"] = "броне", ["RESISTANCE1_NAME"] = "сопр. свету",
    ["RESISTANCE2_NAME"] = "сопр. огню", ["RESISTANCE3_NAME"] = "сопр. природе",
    ["RESISTANCE4_NAME"] = "сопр. льду", ["RESISTANCE5_NAME"] = "сопр. тьме",
    ["RESISTANCE6_NAME"] = "сопр. тайной магии",
    ["ARMOR"] = "броне",
    ["ITEM_MOD_MANA_REGENERATION_SHORT"] = "мане в 5 сек",
}

BiSPlanner_StatLabels.DISPLAY_NAMES = DISPLAY_NAMES
BiSPlanner_StatLabels.DISPLAY_NAMES_DATIVE = DISPLAY_NAMES_DATIVE
