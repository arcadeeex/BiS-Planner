--[[
BiSPlanner - Sum stats from current set; convert ratings to percent (level 80 WotLK).
Class-specific display and rating-to-% conversion.
]]

-- Level 80 WotLK 3.3.5: rating per 1% (same for all classes at 80)
BiSPlanner_RATING_PER_PCT = {
    HIT = 32.79,
    SPELL_HIT = 26.23,
    CRIT = 45.91,
    HASTE = 32.79,
    EXPERTISE = 32.79,
}
BisEquip_RATING_PER_PCT = BiSPlanner_RATING_PER_PCT -- Backward compatibility

local RATING_KEYS = {
    "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT", "ITEM_MOD_HIT_RANGED_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT",
    "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT", "ITEM_MOD_CRIT_RANGED_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT",
    "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_MELEE_RATING_SHORT", "ITEM_MOD_HASTE_RANGED_RATING_SHORT", "ITEM_MOD_HASTE_SPELL_RATING_SHORT",
    "ITEM_MOD_EXPERTISE_RATING_SHORT", "ITEM_MOD_RESILIENCE_RATING_SHORT",
}
local PRIMARY_STAT_KEYS = {
    "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
    "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT",
}
local OTHER_KEYS = {
    "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_SPELL_POWER_SHORT",
    "ITEM_MOD_ARMOR_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT",
    "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
}

local DISPLAY_NAMES = {
    ["ITEM_MOD_STRENGTH_SHORT"] = "Сила",
    ["ITEM_MOD_AGILITY_SHORT"] = "Ловкость",
    ["ITEM_MOD_STAMINA_SHORT"] = "Выносливость",
    ["ITEM_MOD_INTELLECT_SHORT"] = "Интеллект",
    ["ITEM_MOD_SPIRIT_SHORT"] = "Дух",
    ["ITEM_MOD_HIT_RATING_SHORT"] = "Меткость",
    ["ITEM_MOD_CRIT_RATING_SHORT"] = "Крит",
    ["ITEM_MOD_HASTE_RATING_SHORT"] = "Скорость",
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = "Мастерство",
    ["ITEM_MOD_RESILIENCE_RATING_SHORT"] = "Устойчивость",
    ["ITEM_MOD_ATTACK_POWER_SHORT"] = "Сила атаки",
    ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] = "Сила атаки (дальний бой)",
    ["ITEM_MOD_SPELL_POWER_SHORT"] = "Сила заклинаний",
    ["ITEM_MOD_ARMOR_SHORT"] = "Броня",
    ["ITEM_MOD_BLOCK_RATING_SHORT"] = "Блок",
    ["ITEM_MOD_DODGE_RATING_SHORT"] = "Уклонение",
    ["ITEM_MOD_PARRY_RATING_SHORT"] = "Парирование",
    ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] = "Защита",
}
-- WotLK 3.3.5: armor pen 1339.6 rating = 100%, so 1% = 13.396
local RATING_TO_PCT = {
    ["ITEM_MOD_HIT_RATING_SHORT"] = 32.79, ["ITEM_MOD_HIT_MELEE_RATING_SHORT"] = 32.79,
    ["ITEM_MOD_HIT_RANGED_RATING_SHORT"] = 32.79, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"] = 26.23,
    ["ITEM_MOD_CRIT_RATING_SHORT"] = 45.91, ["ITEM_MOD_CRIT_MELEE_RATING_SHORT"] = 45.91,
    ["ITEM_MOD_CRIT_RANGED_RATING_SHORT"] = 45.91, ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"] = 45.91,
    ["ITEM_MOD_HASTE_RATING_SHORT"] = 32.79, ["ITEM_MOD_HASTE_MELEE_RATING_SHORT"] = 32.79,
    ["ITEM_MOD_HASTE_RANGED_RATING_SHORT"] = 32.79, ["ITEM_MOD_HASTE_SPELL_RATING_SHORT"] = 32.79,
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = 32.79, ["ITEM_MOD_RESILIENCE_RATING_SHORT"] = 45.91,
    ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = 13.396, ["ITEM_MOD_ARMOR_PENETRATION_RATING"] = 13.396,
}

-- WotLK 3.3.5 (level 80): 1 expertise point ~= 8.197387 expertise rating.
-- In RU client this stat is shown as "Мастерство".
local EXPERTISE_RATING_PER_MASTERY = 8.197387
-- WotLK 3.3.5 (level 80): defense rating to defense skill.
local DEFENSE_RATING_PER_SKILL = 4.9185

-- Class id for stat display (nil = use player)
function BiSPlanner_GetSelectedClass()
    BisEquip_GetSelectedClass = BiSPlanner_GetSelectedClass -- Backward compatibility
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.selectedClass then return nil end
    return db.selectedClass
end

function BiSPlanner_SetSelectedClass(classId)
    BisEquip_SetSelectedClass = BiSPlanner_SetSelectedClass -- Backward compatibility
    local db = BiSPlannerDB or BisEquipDB
    if not db then return end
    db.selectedClass = classId
    -- Clear spec if it doesn't belong to new class
    if db.selectedSpec and classId then
        local specs = BiSPlanner_CLASS_SPECS and BiSPlanner_CLASS_SPECS[classId]
        local valid = false
        if specs then
            for _, sp in ipairs(specs) do
                if sp.id == db.selectedSpec then valid = true break end
            end
        end
        if not valid then db.selectedSpec = nil end
    end
    if BiSPlannerDB then BiSPlannerDB.selectedClass = classId; BiSPlannerDB.selectedSpec = db.selectedSpec end
    if BisEquipDB then BisEquipDB.selectedClass = classId; BisEquipDB.selectedSpec = db.selectedSpec end
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() elseif BisEquip_RefreshStats then BisEquip_RefreshStats() end
end

-- Caster classes: show spell hit/crit/haste labels
local CASTER_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true }
local function IsCasterClass(classId)
    if not classId then return nil end
    return CASTER_CLASSES[classId]
end

function BiSPlanner_GetTotalStatsWithBreakdown()
    BisEquip_GetTotalStatsWithBreakdown = BiSPlanner_GetTotalStatsWithBreakdown -- Backward compatibility
    local total = {}
    local byItem = {}
    local set = (BiSPlanner and BiSPlanner:GetCurrentSet()) or (BisEquip and BisEquip:GetCurrentSet())
    if not set then return { total = total, byItem = byItem } end
    for slotId, itemId in pairs(set) do
        if itemId and BiSPlanner_GetItemStats then
            local st = BiSPlanner_GetItemStats(itemId) or {}
            byItem[#byItem + 1] = { slotId = slotId, itemId = itemId, stats = st }
            for k, v in pairs(st) do
                if type(v) == "number" then total[k] = (total[k] or 0) + v end
            end
        elseif itemId and BisEquip_GetItemStats then
            local st = BisEquip_GetItemStats(itemId) or {}
            byItem[#byItem + 1] = { slotId = slotId, itemId = itemId, stats = st }
            for k, v in pairs(st) do
                if type(v) == "number" then total[k] = (total[k] or 0) + v end
            end
        end
    end
    return { total = total, byItem = byItem }
end

function BiSPlanner_GetTotalStats()
    BisEquip_GetTotalStats = BiSPlanner_GetTotalStats -- Backward compatibility
    local result = BiSPlanner_GetTotalStatsWithBreakdown()
    return result.total
end

-- For ItemPicker preview: stats with one slot overridden by itemId
function BiSPlanner_GetTotalStatsWithDelta(baseSet, overrideSlot, overrideItemId)
    BisEquip_GetTotalStatsWithDelta = BiSPlanner_GetTotalStatsWithDelta -- Backward compatibility
    local total = {}
    local set = baseSet or ((BiSPlanner and BiSPlanner:GetCurrentSet()) or (BisEquip and BisEquip:GetCurrentSet()))
    if not set then return total, {} end
    local getStats = BiSPlanner_GetItemStats or BisEquip_GetItemStats
    if not getStats then return total, {} end
    for slotId, itemId in pairs(set) do
        if itemId and slotId ~= overrideSlot then
            local st = getStats(itemId) or {}
            for k, v in pairs(st) do
                if type(v) == "number" then total[k] = (total[k] or 0) + v end
            end
        end
    end
    if overrideSlot and overrideItemId then
        local st = getStats(overrideItemId) or {}
        for k, v in pairs(st) do
            if type(v) == "number" then total[k] = (total[k] or 0) + v end
        end
    end
    return total
end

function BiSPlanner_FormatStatLine(key, value)
    BisEquip_FormatStatLine = BiSPlanner_FormatStatLine -- Backward compatibility
    local name = DISPLAY_NAMES[key] or key
    local ratingPerPct = RATING_TO_PCT[key]
    if ratingPerPct and ratingPerPct > 0 then
        local pct = value / ratingPerPct
        return name, string.format("%d (%.2f%%)", value, pct)
    end
    return name, tostring(value)
end

-- For ItemPicker delta display: returns rating divisor for percent, or nil for non-rating stats
function BiSPlanner_GetRatingPercentDivisor(key)
    BisEquip_GetRatingPercentDivisor = BiSPlanner_GetRatingPercentDivisor -- Backward compatibility
    return RATING_TO_PCT[key]
end

local S = BiSPlanner_Styles or {}
local ROW_HEIGHT = (S.ROW_HEIGHT or 18)
local CARD_HEADER = (S.CARD_HEADER or 24)
local STAT_LINE_HEIGHT = ROW_HEIGHT
local SECTION_HEADER_HEIGHT = CARD_HEADER
local SECTION_GAP = (S.PADDING_BLOCK or 8)
local STAT_LABEL_WIDTH = 140
local STAT_VALUE_WIDTH = 80
local STAT_COLUMN_GAP = 8
local CARD_COLLAPSED = {}

local CLASS_SECTION_VISIBILITY = {
    WARRIOR = { melee = true, ranged = false, magic = false, defense = true },
    PALADIN = { melee = true, ranged = false, magic = true, defense = true },
    HUNTER = { melee = false, ranged = true, magic = false, defense = false },
    ROGUE = { melee = true, ranged = false, magic = false, defense = false },
    PRIEST = { melee = false, ranged = false, magic = true, defense = false },
    SHAMAN = { melee = true, ranged = false, magic = true, defense = true },
    MAGE = { melee = false, ranged = false, magic = true, defense = false },
    WARLOCK = { melee = false, ranged = false, magic = true, defense = false },
    DRUID = { melee = true, ranged = false, magic = true, defense = true },
    DEATHKNIGHT = { melee = true, ranged = false, magic = false, defense = true },
}

-- Spec dropdown: id -> { melee, ranged, magic, defense }
BiSPlanner_CLASS_SPECS = {
    WARRIOR = { { id = "arms", name = "Оружие" }, { id = "fury", name = "Неистовство" }, { id = "prot", name = "Защита" } },
    PALADIN = { { id = "ret", name = "Ретри" }, { id = "holy", name = "Свет" }, { id = "prot", name = "Защита" } },
    HUNTER = { { id = "bm", name = "Повелитель зверей" }, { id = "mm", name = "Стрельба" }, { id = "sv", name = "Выживание" } },
    ROGUE = { { id = "assass", name = "Ликвидация" }, { id = "combat", name = "Бой" }, { id = "subtl", name = "Скрытность" } },
    PRIEST = { { id = "disc", name = "Послушание" }, { id = "holy", name = "Свет" }, { id = "shadow", name = "Тьма" } },
    SHAMAN = { { id = "elem", name = "Стихии" }, { id = "enh", name = "Совершенствование" }, { id = "resto", name = "Исцеление" } },
    MAGE = { { id = "arcane", name = "Тайная магия" }, { id = "fire", name = "Огонь" }, { id = "frost", name = "Лёд" } },
    WARLOCK = { { id = "affl", name = "Колдовство" }, { id = "demo", name = "Демонология" }, { id = "destr", name = "Разрушение" } },
    DRUID = { { id = "balance", name = "Баланс" }, { id = "feral", name = "Сила зверя" }, { id = "resto", name = "Исцеление" } },
    DEATHKNIGHT = { { id = "blood", name = "Кровь" }, { id = "frost", name = "Лёд" }, { id = "unholy", name = "Нечестивость" } },
}
BisEquip_CLASS_SPECS = BiSPlanner_CLASS_SPECS

local SPEC_PROFILES = {
    ret = { melee = true, ranged = false, magic = false, defense = false },
    holy = { melee = false, ranged = false, magic = true, defense = true },
    prot = { melee = true, ranged = false, magic = false, defense = true },
    arms = { melee = true, ranged = false, magic = false, defense = false },
    fury = { melee = true, ranged = false, magic = false, defense = false },
    bm = { melee = false, ranged = true, magic = false, defense = false },
    mm = { melee = false, ranged = true, magic = false, defense = false },
    sv = { melee = false, ranged = true, magic = false, defense = false },
    assass = { melee = true, ranged = false, magic = false, defense = false },
    combat = { melee = true, ranged = false, magic = false, defense = false },
    subtl = { melee = true, ranged = false, magic = false, defense = false },
    disc = { melee = false, ranged = false, magic = true, defense = false },
    shadow = { melee = false, ranged = false, magic = true, defense = false },
    elem = { melee = false, ranged = false, magic = true, defense = false },
    enh = { melee = true, ranged = false, magic = false, defense = false },
    resto = { melee = false, ranged = false, magic = true, defense = false },
    arcane = { melee = false, ranged = false, magic = true, defense = false },
    fire = { melee = false, ranged = false, magic = true, defense = false },
    frost = { melee = false, ranged = false, magic = true, defense = false },
    affl = { melee = false, ranged = false, magic = true, defense = false },
    demo = { melee = false, ranged = false, magic = true, defense = false },
    destr = { melee = false, ranged = false, magic = true, defense = false },
    balance = { melee = false, ranged = false, magic = true, defense = false },
    feral = { melee = true, ranged = false, magic = false, defense = false },
    blood = { melee = true, ranged = false, magic = false, defense = true },
    unholy = { melee = true, ranged = false, magic = false, defense = false },
}

function BiSPlanner_GetSelectedSpec()
    BisEquip_GetSelectedSpec = BiSPlanner_GetSelectedSpec
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.selectedSpec then return nil end
    return db.selectedSpec
end

function BiSPlanner_SetSelectedSpec(specId)
    BisEquip_SetSelectedSpec = BiSPlanner_SetSelectedSpec
    local db = BiSPlannerDB or BisEquipDB
    if not db then return end
    db.selectedSpec = specId
    if BiSPlannerDB then BiSPlannerDB.selectedSpec = specId end
    if BisEquipDB then BisEquipDB.selectedSpec = specId end
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() end
end

local function GetCurrentClassId()
    local selected = BiSPlanner_GetSelectedClass()
    if selected and selected ~= "" then return selected end
    if UnitClass then
        local _, cls = UnitClass("player")
        return cls
    end
    return nil
end

local function StatValue(total, keys)
    local sum = 0
    for _, k in ipairs(keys) do
        sum = sum + (total[k] or 0)
    end
    return sum
end

local function StatAny(total, keys)
    for _, k in ipairs(keys) do
        if total[k] and total[k] ~= 0 then
            return total[k]
        end
    end
    return 0
end

local function FormatNumberValue(v)
    return tostring(math.floor((v or 0) + 0.5))
end

local function FormatRating(v, perPct)
    if not perPct or perPct <= 0 then return FormatNumberValue(v) end
    local rating = math.floor((v or 0) + 0.5)
    local pct = (v or 0) / perPct
    return string.format("%d (%.2f%%)", rating, pct)
end

local function FormatConvertedValue(v, perUnit)
    if not perUnit or perUnit <= 0 then return FormatNumberValue(v) end
    return string.format("%.2f", (v or 0) / perUnit)
end

local function FormatDefenseRating(v)
    local rating = math.floor((v or 0) + 0.5)
    local skill = (v or 0) / DEFENSE_RATING_PER_SKILL
    return string.format("%d (+%.2f)", rating, skill)
end

local INT_PER_SPELL_CRIT_PCT = {
    PALADIN = 166.67, SHAMAN = 166.67, DRUID = 166.67,
    MAGE = 166.67, PRIEST = 166.67, WARLOCK = 166.67,
}

local function FormatIntCritBonus(classId, intellect)
    local perPct = INT_PER_SPELL_CRIT_PCT[classId]
    if not perPct or perPct <= 0 then
        return "0.00%"
    end
    local pct = (intellect or 0) / perPct
    return string.format("%.2f%%", pct)
end

local AP_PER_STRENGTH = {
    WARRIOR = 2, PALADIN = 2, DEATHKNIGHT = 2, SHAMAN = 2, DRUID = 2,
    ROGUE = 1, HUNTER = 1,
}
local AP_PER_AGILITY = {
    ROGUE = 1,
    HUNTER = 1,
    DRUID = 1,
}

local function GetDerivedAttackPower(classId, total)
    local baseAP = total["ITEM_MOD_ATTACK_POWER_SHORT"] or 0
    local str = total["ITEM_MOD_STRENGTH_SHORT"] or 0
    local agi = total["ITEM_MOD_AGILITY_SHORT"] or 0
    local strMult = AP_PER_STRENGTH[classId] or 0
    local agiMult = AP_PER_AGILITY[classId] or 0
    return baseAP + (str * strMult) + (agi * agiMult)
end

function BiSPlanner_GetDerivedAttackPowerForPreview(classId, total)
    if not total then return 0 end
    return GetDerivedAttackPower(classId, total)
end

local function GetDerivedRangedAttackPower(classId, total)
    local rangedBase = total["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] or 0
    local agi = total["ITEM_MOD_AGILITY_SHORT"] or 0
    local agiMult = AP_PER_AGILITY[classId] or 0
    if classId == "HUNTER" then
        return rangedBase + (agi * agiMult)
    end
    return rangedBase
end

local WeaponScanTooltip = CreateFrame("GameTooltip", "BiSPlannerWeaponScanTooltip", UIParent, "GameTooltipTemplate")
BisEquipWeaponScanTooltip = WeaponScanTooltip -- Backward compatibility
WeaponScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function NormalizeTooltipLine(s)
    if not s then return "" end
    -- Strip color codes and normalize decimal separators/spaces.
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("\194\160", " ") -- NBSP in UTF-8
    s = s:gsub(",", ".")
    return s
end

local function ParseWeaponTooltipLine(line)
    if not line or line == "" then return nil, nil, nil end
    local s = NormalizeTooltipLine(line)

    local d1, d2 = s:match("(%d+)%s*[%-%–—]%s*(%d+)")
    if d1 and d2 then
        return tonumber(d1), tonumber(d2), nil
    end

    -- Handles formats like:
    -- "Скорость атаки (сек.): 3.29", "Скорость: 3.29", "Speed 3.29"
    local speed = s:match("[Сс]корость.-([%d%.]+)%s*$")
        or s:match("[Ss]peed.-([%d%.]+)%s*$")
        or s:match("([%d%.]+)%s*[Сс]ек")
    if speed then
        return nil, nil, tonumber(speed)
    end

    return nil, nil, nil
end

local function GetMeleeWeaponDisplay(meleeAP)
    local itemId = (BiSPlanner and BiSPlanner.GetSlot and BiSPlanner:GetSlot(16)) or (BisEquip and BisEquip.GetSlot and BisEquip:GetSlot(16)) or nil
    if not itemId then return "—", "—" end

    local minDmg, maxDmg, speed

    local function ScanOnce()
        WeaponScanTooltip:ClearLines()
        WeaponScanTooltip:SetHyperlink("item:" .. itemId .. ":0:0:0:0:0:0:0")
        WeaponScanTooltip:Show()
        WeaponScanTooltip:Hide()

        for i = 1, 40 do
            local left = _G["BiSPlannerWeaponScanTooltipTextLeft" .. i] or _G["BisEquipWeaponScanTooltipTextLeft" .. i]
            local right = _G["BiSPlannerWeaponScanTooltipTextRight" .. i] or _G["BisEquipWeaponScanTooltipTextRight" .. i]
            local lines = {
                left and left:GetText() or nil,
                right and right:GetText() or nil,
            }
            for _, line in ipairs(lines) do
                if line and line ~= "" then
                    local a, b, s = ParseWeaponTooltipLine(line)
                    if a and b and not minDmg then
                        minDmg = a
                        maxDmg = b
                    end
                    if s and not speed then
                        speed = s
                    end
                end
            end
        end
    end

    -- First scan might miss uncached tooltip text; retry once.
    ScanOnce()
    if not speed or not minDmg or not maxDmg then
        ScanOnce()
    end

    if not speed then return "—", "—" end
    local speedText = string.format("%.2f", speed)
    if not minDmg or not maxDmg then return "—", speedText end

    local bonus = ((meleeAP or 0) / 14) * speed
    local finalMin = math.floor(minDmg + bonus + 0.5)
    local finalMax = math.floor(maxDmg + bonus + 0.5)
    return string.format("%d-%d", finalMin, finalMax), speedText
end

local function BuildStatsSections(total, classId, baseTotal)
    -- No spec-based filtering; use class visibility only
    local profile = CLASS_SECTION_VISIBILITY[classId] or { melee = true, ranged = true, magic = true, defense = true }
    local sections = {}
    baseTotal = baseTotal or {}

    local function deltaNum(key)
        if not baseTotal[key] and not total[key] then return nil end
        return (total[key] or 0) - (baseTotal[key] or 0)
    end
    local function deltaArmor()
        local baseA = (baseTotal["ITEM_MOD_ARMOR_SHORT"] or 0) + (baseTotal["ARMOR"] or 0)
        local curA = (total["ITEM_MOD_ARMOR_SHORT"] or 0) + (total["ARMOR"] or 0)
        if baseA == 0 and curA == 0 then return nil end
        return curA - baseA
    end

    sections[#sections + 1] = {
        title = "Основные",
        rows = {
            { "Сила", FormatNumberValue(total["ITEM_MOD_STRENGTH_SHORT"]), deltaNum("ITEM_MOD_STRENGTH_SHORT") },
            { "Ловкость", FormatNumberValue(total["ITEM_MOD_AGILITY_SHORT"]), deltaNum("ITEM_MOD_AGILITY_SHORT") },
            { "Выносливость", FormatNumberValue(total["ITEM_MOD_STAMINA_SHORT"]), deltaNum("ITEM_MOD_STAMINA_SHORT") },
            {
                "Интеллект",
                FormatNumberValue(total["ITEM_MOD_INTELLECT_SHORT"]),
                deltaNum("ITEM_MOD_INTELLECT_SHORT"),
                { "Крит от интеллекта: " .. FormatIntCritBonus(classId, total["ITEM_MOD_INTELLECT_SHORT"] or 0) }
            },
            { "Дух", FormatNumberValue(total["ITEM_MOD_SPIRIT_SHORT"]), deltaNum("ITEM_MOD_SPIRIT_SHORT") },
            { "Броня", FormatNumberValue((total["ITEM_MOD_ARMOR_SHORT"] or 0) + (total["ARMOR"] or 0)), deltaArmor() },
        }
    }

    if profile.melee then
        local meleeAP = GetDerivedAttackPower(classId, total)
        local baseAP = GetDerivedAttackPower(classId, baseTotal)
        local meleeDmg, meleeSpeed = GetMeleeWeaponDisplay(meleeAP)
        local meleeHit = StatValue(total, { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT" })
        local meleeCrit = StatValue(total, { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT" })
        local meleeHaste = StatValue(total, { "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_MELEE_RATING_SHORT" })
        local expertise = total["ITEM_MOD_EXPERTISE_RATING_SHORT"] or 0
        local arp = StatAny(total, { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", "ITEM_MOD_ARMOR_PENETRATION_RATING" })
        sections[#sections + 1] = {
            title = "Ближний бой",
            rows = {
                { "Урон", meleeDmg, nil },
                { "Скорость", meleeSpeed, nil },
                { "Сила атаки", FormatNumberValue(meleeAP), meleeAP - baseAP },
                { "Меткость", FormatRating(meleeHit, 32.79), nil },
                { "Крит", FormatRating(meleeCrit, 45.91), nil },
                { "Скорость", FormatRating(meleeHaste, 32.79), nil },
                { "Мастерство", FormatConvertedValue(expertise, EXPERTISE_RATING_PER_MASTERY), nil },
                { "Пробивание брони", FormatRating(arp, 13.99), nil },
            }
        }
    end

    if profile.ranged then
        local rangedHit = StatValue(total, { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_RANGED_RATING_SHORT" })
        local rangedCrit = StatValue(total, { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_RANGED_RATING_SHORT" })
        local rangedHaste = StatValue(total, { "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_RANGED_RATING_SHORT" })
        local rangedAP = GetDerivedRangedAttackPower(classId, total) + (total["ITEM_MOD_ATTACK_POWER_SHORT"] or 0)
        sections[#sections + 1] = {
            title = "Дальний бой",
            rows = {
                { "Урон", "—", nil },
                { "Скорость", "—", nil },
                { "Сила атаки", FormatNumberValue(rangedAP), nil },
                { "Меткость", FormatRating(rangedHit, 32.79), nil },
                { "Крит", FormatRating(rangedCrit, 45.91), nil },
                { "Скорость", FormatRating(rangedHaste, 32.79), nil },
            }
        }
    end

    if profile.magic then
        local spellHit = StatValue(total, { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT" })
        local spellCrit = StatValue(total, { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT" })
        local spellHaste = StatValue(total, { "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_SPELL_RATING_SHORT" })
        local spellPower = total["ITEM_MOD_SPELL_POWER_SHORT"] or 0
        local spellPen = StatAny(total, { "ITEM_MOD_SPELL_PENETRATION_SHORT", "ITEM_MOD_SPELL_PENETRATION" })
        local intellect = total["ITEM_MOD_INTELLECT_SHORT"] or 0
        sections[#sections + 1] = {
            title = "Магия",
            rows = {
                { "Доп. урон", FormatNumberValue(spellPower), nil },
                { "Доп. лечение", FormatNumberValue(spellPower), nil },
                { "Меткость", FormatRating(spellHit, 26.23), nil },
                { "Крит", FormatRating(spellCrit, 45.91), nil },
                { "Скорость", FormatRating(spellHaste, 32.79), nil },
                { "Пенетра", FormatNumberValue(spellPen), nil },
                { "Крит от интеллекта", FormatIntCritBonus(classId, intellect), nil },
                { "Дух", FormatNumberValue(total["ITEM_MOD_SPIRIT_SHORT"]), nil },
            }
        }
    end

    if profile.defense then
        local dodge = total["ITEM_MOD_DODGE_RATING_SHORT"] or 0
        local parry = total["ITEM_MOD_PARRY_RATING_SHORT"] or 0
        local block = total["ITEM_MOD_BLOCK_RATING_SHORT"] or 0
        local resilience = total["ITEM_MOD_RESILIENCE_RATING_SHORT"] or 0
        sections[#sections + 1] = {
            title = "Защита",
            rows = {
                { "Броня", FormatNumberValue((total["ITEM_MOD_ARMOR_SHORT"] or 0) + (total["ARMOR"] or 0)), deltaArmor() },
                { "Рейт. защиты", FormatDefenseRating(total["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]), nil },
                { "Уклонение", FormatRating(dodge, 39.35), nil },
                { "Парирование", FormatRating(parry, 45.25), nil },
                { "Блок", FormatRating(block, 16.39), nil },
                { "Устойчивость", FormatRating(resilience, 81.97), nil },
            }
        }
    end

    return sections
end

-- Stats panel: StatsCards with collapsible sections, Label | Value | Delta
local statCards = {}
local GREEN = (BiSPlanner_Styles and BiSPlanner_Styles.GREEN) or { 0.2, 0.8, 0.2, 1 }
local RED = (BiSPlanner_Styles and BiSPlanner_Styles.RED) or { 0.85, 0.2, 0.2, 1 }
local TEXT_VALUE = (BiSPlanner_Styles and BiSPlanner_Styles.TEXT_VALUE) or { 0.9, 0.9, 0.9, 1 }

function BiSPlanner_RefreshStatsImpl()
    BisEquip_RefreshStatsImpl = BiSPlanner_RefreshStatsImpl -- Backward compatibility
    local container = BiSPlanner_StatsContainer or BisEquip_StatsContainer
    if not container then
        container = _G["BiSPlanner_StatsChild"] or _G["BisEquip_StatsChild"]
        if container then BiSPlanner_StatsContainer = container; BisEquip_StatsContainer = container end
    end
    if not container then return end
    container:Show()

    local total = BiSPlanner_GetTotalStats()
    local classId = GetCurrentClassId()
    local sections = BuildStatsSections(total, classId, nil)

    local scroll = BiSPlanner_StatsScroll or BisEquip_StatsScroll
    local viewportH = (scroll and scroll:GetHeight()) or 120

    local y = 0  -- align with gear panel top border (equipment backdrop)
    local containerWidth = math.max(container:GetWidth() or 280, 200)

    for sectionIdx, section in ipairs(sections) do
        local card = statCards[sectionIdx]
        if not card then
            card = CreateFrame("Frame", "BiSPlanner_StatsCard" .. sectionIdx, container)
            statCards[sectionIdx] = card
            if BiSPlanner_ApplyPanelBackdrop then
                BiSPlanner_ApplyPanelBackdrop(card)
            end
            card.header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            card.header:SetJustifyH("LEFT")
            card.header:SetTextColor(TEXT_VALUE[1], TEXT_VALUE[2], TEXT_VALUE[3])
            card.collapseIcon = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            card.collapseIcon:SetText("-")
            card.collapseIcon:SetTextColor(0.7, 0.7, 0.7)
            card.rows = {}
        end
        local collapsed = CARD_COLLAPSED[section.title]
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
        card:SetPoint("RIGHT", container, "RIGHT", 0, 0)
        card:SetHeight(CARD_HEADER + 2)
        card.header:SetText(section.title)
        card.header:SetPoint("TOPLEFT", 8, -6)
        card.collapseIcon:SetPoint("LEFT", card.header, "RIGHT", 4, 0)
        card.collapseIcon:SetText(collapsed and "+" or "-")
        card.header:GetParent():SetScript("OnMouseUp", nil)
        card:SetScript("OnMouseUp", function(self, btn)
            if btn == "LeftButton" then
                CARD_COLLAPSED[section.title] = not CARD_COLLAPSED[section.title]
                BiSPlanner_RefreshStats()
            end
        end)
        card:EnableMouse(true)

        local CARD_BOTTOM_PAD = 10
        local rowY = -CARD_HEADER - 4
        if collapsed then
            for i = 1, #card.rows do
                if card.rows[i] and card.rows[i].frame then
                    card.rows[i].frame:Hide()
                end
            end
        else
            for i, statRow in ipairs(section.rows) do
                local row = card.rows[i]
                if not row then
                    row = {}
                    row.frame = CreateFrame("Frame", nil, card)
                    row.label = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.value = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.delta = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.hit = CreateFrame("Frame", nil, row.frame)
                    row.label:SetJustifyH("LEFT")
                    row.value:SetJustifyH("RIGHT")
                    row.delta:SetJustifyH("RIGHT")
                    row.hit:SetScript("OnEnter", function(self)
                        local r = self.__row
                        if r and r.tooltipLines and #r.tooltipLines > 0 then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:AddLine(r.tooltipTitle or "Детали", 1, 0.82, 0)
                            for _, line in ipairs(r.tooltipLines) do
                                GameTooltip:AddLine(line, 0.9, 0.9, 0.9)
                            end
                            GameTooltip:Show()
                        end
                    end)
                    row.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    card.rows[i] = row
                end
                local valueW = 68
                local valueRightInset = 10
                local gapBetweenLabelAndValue = 6
                local rowInnerWidth = math.max(120, containerWidth - 16)
                local labelW = math.max(60, rowInnerWidth - valueW - valueRightInset - gapBetweenLabelAndValue)
                row.frame:ClearAllPoints()
                row.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 8, rowY)
                row.frame:SetPoint("RIGHT", card, "RIGHT", -8, 0)
                row.frame:SetHeight(ROW_HEIGHT)
                row.frame:Show()
                row.label:SetPoint("LEFT", 0, 0)
                row.label:SetWidth(labelW)
                row.delta:SetPoint("RIGHT", row.frame, "RIGHT", 0, 0)
                row.delta:SetWidth(0)
                row.value:SetPoint("RIGHT", row.frame, "RIGHT", -valueRightInset, 0)
                row.value:SetWidth(valueW)
                row.label:SetText((statRow[1] or "—") .. ":")
                row.value:SetText(statRow[2] or "0")
                row.value:SetTextColor(TEXT_VALUE[1], TEXT_VALUE[2], TEXT_VALUE[3])
                local tooltip = (type(statRow[4]) == "table") and statRow[4] or (type(statRow[3]) == "table" and statRow[3] or nil)
                row.tooltipTitle = statRow[1]
                row.tooltipLines = tooltip
                row.delta:SetText("")
                row.delta:SetWidth(0)
                row.hit:SetAllPoints(row.frame)
                row.hit:EnableMouse(row.tooltipLines and #row.tooltipLines > 0)
                row.hit.__row = row
                rowY = rowY - ROW_HEIGHT
            end
            card:SetHeight(CARD_HEADER + 4 + #section.rows * ROW_HEIGHT + CARD_BOTTOM_PAD)
        end
        if collapsed then
            card:SetHeight(CARD_HEADER + 2)
        end
        for i = #section.rows + 1, #card.rows do
            if card.rows[i] then card.rows[i].frame:Hide() end
        end
        y = y - (card:GetHeight() + SECTION_GAP)
    end

    for i = #sections + 1, #statCards do
        if statCards[i] then statCards[i]:Hide() end
    end

    local totalHeight = math.abs(y)
    container:SetHeight(math.max(totalHeight, viewportH))

    if scroll then
        local maxScroll = scroll:GetVerticalScrollRange() or 0
        local cur = scroll:GetVerticalScroll() or 0
        if cur > maxScroll then scroll:SetVerticalScroll(maxScroll) end
    end
end
