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
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = "Экспертоза",
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
local RATING_TO_PCT = {
    ["ITEM_MOD_HIT_RATING_SHORT"] = 32.79, ["ITEM_MOD_HIT_MELEE_RATING_SHORT"] = 32.79,
    ["ITEM_MOD_HIT_RANGED_RATING_SHORT"] = 32.79, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"] = 26.23,
    ["ITEM_MOD_CRIT_RATING_SHORT"] = 45.91, ["ITEM_MOD_CRIT_MELEE_RATING_SHORT"] = 45.91,
    ["ITEM_MOD_CRIT_RANGED_RATING_SHORT"] = 45.91, ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"] = 45.91,
    ["ITEM_MOD_HASTE_RATING_SHORT"] = 32.79, ["ITEM_MOD_HASTE_MELEE_RATING_SHORT"] = 32.79,
    ["ITEM_MOD_HASTE_RANGED_RATING_SHORT"] = 32.79, ["ITEM_MOD_HASTE_SPELL_RATING_SHORT"] = 32.79,
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = 32.79, ["ITEM_MOD_RESILIENCE_RATING_SHORT"] = 45.91,
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
    -- Sync to both DBs
    if BiSPlannerDB then BiSPlannerDB.selectedClass = classId end
    if BisEquipDB then BisEquipDB.selectedClass = classId end
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

local STAT_LINE_HEIGHT = 16
local SECTION_HEADER_HEIGHT = 18
local SECTION_GAP = 6
local STAT_LABEL_WIDTH = 140
local STAT_VALUE_WIDTH = 80
local STAT_COLUMN_GAP = 8

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

local function BuildStatsSections(total, classId)
    local profile = CLASS_SECTION_VISIBILITY[classId] or { melee = true, ranged = true, magic = true, defense = true }
    local sections = {}

    sections[#sections + 1] = {
        title = "Основные",
        rows = {
            { "Сила", FormatNumberValue(total["ITEM_MOD_STRENGTH_SHORT"]) },
            { "Ловкость", FormatNumberValue(total["ITEM_MOD_AGILITY_SHORT"]) },
            { "Выносливость", FormatNumberValue(total["ITEM_MOD_STAMINA_SHORT"]) },
            {
                "Интеллект",
                FormatNumberValue(total["ITEM_MOD_INTELLECT_SHORT"]),
                { "Крит от интеллекта: " .. FormatIntCritBonus(classId, total["ITEM_MOD_INTELLECT_SHORT"] or 0) }
            },
            { "Дух", FormatNumberValue(total["ITEM_MOD_SPIRIT_SHORT"]) },
            { "Броня", FormatNumberValue(total["ITEM_MOD_ARMOR_SHORT"]) },
        }
    }

    if profile.melee then
        local meleeAP = GetDerivedAttackPower(classId, total)
        local meleeDmg, meleeSpeed = GetMeleeWeaponDisplay(meleeAP)
        local meleeHit = StatValue(total, { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT" })
        local meleeCrit = StatValue(total, { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT" })
        local meleeHaste = StatValue(total, { "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_MELEE_RATING_SHORT" })
        local expertise = total["ITEM_MOD_EXPERTISE_RATING_SHORT"] or 0
        local arp = StatAny(total, { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", "ITEM_MOD_ARMOR_PENETRATION_RATING" })
        sections[#sections + 1] = {
            title = "Ближний бой",
            rows = {
                { "Урон", meleeDmg },
                { "Скорость", meleeSpeed },
                { "Сила атаки", FormatNumberValue(meleeAP) },
                { "Рейт. меткости", FormatRating(meleeHit, 32.79) },
                { "Крит. удар", FormatRating(meleeCrit, 45.91) },
                { "Рейт. скорости", FormatRating(meleeHaste, 32.79) },
                { "Мастерство", FormatConvertedValue(expertise, EXPERTISE_RATING_PER_MASTERY) },
                { "Пробивание брони", FormatRating(arp, 13.99) },
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
                { "Урон", "—" },
                { "Скорость", "—" },
                { "Сила атаки", FormatNumberValue(rangedAP) },
                { "Рейт. меткости", FormatRating(rangedHit, 32.79) },
                { "Крит. удар", FormatRating(rangedCrit, 45.91) },
                { "Рейт. скорости", FormatRating(rangedHaste, 32.79) },
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
                { "Доп. урон", FormatNumberValue(spellPower) },
                { "Доп. лечение", FormatNumberValue(spellPower) },
                { "Рейт. меткости", FormatRating(spellHit, 26.23) },
                { "Крит. удар", FormatRating(spellCrit, 45.91) },
                { "Рейт. скорости", FormatRating(spellHaste, 32.79) },
                { "Пенетра", FormatNumberValue(spellPen) },
                { "Крит от интеллекта", FormatIntCritBonus(classId, intellect) },
                { "Дух", FormatNumberValue(total["ITEM_MOD_SPIRIT_SHORT"]) },
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
                { "Броня", FormatNumberValue(total["ITEM_MOD_ARMOR_SHORT"]) },
                { "Рейт. защиты", FormatDefenseRating(total["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]) },
                { "Уклонение", FormatRating(dodge, 39.35) },
                { "Парирование", FormatRating(parry, 45.25) },
                { "Блок", FormatRating(block, 16.39) },
                { "Устойчивость", FormatRating(resilience, 81.97) },
            }
        }
    end

    return sections
end

-- Stats panel: формат как в стандартном интерфейсе WoW - две колонки (название слева, значение справа)
local statRows = {}
local sectionHeaders = {}

function BiSPlanner_RefreshStatsImpl()
    BisEquip_RefreshStatsImpl = BiSPlanner_RefreshStatsImpl -- Backward compatibility
    local container = BiSPlanner_StatsContainer or BisEquip_StatsContainer
    if not container then 
        -- Попытка найти контейнер если он не установлен
        container = _G["BiSPlanner_StatsChild"] or _G["BisEquip_StatsChild"]
        if container then BiSPlanner_StatsContainer = container; BisEquip_StatsContainer = container end
    end
    if not container then return end
    container:Show() -- Убеждаемся что контейнер виден

    local total = BiSPlanner_GetTotalStats()
    local classId = GetCurrentClassId()
    local sections = BuildStatsSections(total, classId)

    local y = -8
    local sectionTitleFont = "GameFontNormal"
    local rowFont = "GameFontHighlightSmall"

    local function EnsureSectionHeader(idx, title)
        if not sectionHeaders[idx] then
            sectionHeaders[idx] = container:CreateFontString(nil, "OVERLAY", sectionTitleFont)
            sectionHeaders[idx]:SetJustifyH("LEFT")
        end
        sectionHeaders[idx]:ClearAllPoints()
        sectionHeaders[idx]:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
        sectionHeaders[idx]:SetText(title)
        sectionHeaders[idx]:Show()
        y = y - SECTION_HEADER_HEIGHT
    end

    local function EnsureRow(i)
        if not statRows[i] then
            statRows[i] = {}
            statRows[i].label = container:CreateFontString(nil, "OVERLAY", rowFont)
            statRows[i].value = container:CreateFontString(nil, "OVERLAY", rowFont)
            statRows[i].hit = CreateFrame("Frame", nil, container)
            statRows[i].label:SetJustifyH("LEFT")
            statRows[i].value:SetJustifyH("RIGHT")
            statRows[i].value:SetTextColor(0.2, 1, 0.2)
            statRows[i].hit:SetScript("OnEnter", function(self)
                local row = self.__row
                if not row or not row.tooltipLines or #row.tooltipLines == 0 then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(row.tooltipTitle or "Детали", 1, 0.82, 0)
                for _, line in ipairs(row.tooltipLines) do
                    GameTooltip:AddLine(line, 0.9, 0.9, 0.9)
                end
                GameTooltip:Show()
            end)
            statRows[i].hit:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        local row = statRows[i]
        -- Формат как в стандартном интерфейсе: label слева, value справа, выровнено по левому краю контейнера
        local containerWidth = math.max(container:GetWidth() or 220, 180)
        local labelWidth = math.max(math.floor(containerWidth * 0.62), 120)
        local valueWidth = math.max(containerWidth - labelWidth - STAT_COLUMN_GAP, 70)
        row.label:ClearAllPoints()
        row.value:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
        row.label:SetWidth(labelWidth)
        row.value:SetPoint("TOPLEFT", container, "TOPLEFT", labelWidth + STAT_COLUMN_GAP, y)
        row.value:SetWidth(valueWidth)
        row.hit:ClearAllPoints()
        row.hit:SetPoint("TOPLEFT", row.label, "TOPLEFT", 0, 0)
        row.hit:SetSize(labelWidth + STAT_COLUMN_GAP + valueWidth, STAT_LINE_HEIGHT)
        row.hit:EnableMouse(true)
        row.hit.__row = row
        y = y - STAT_LINE_HEIGHT
        return row
    end

    local rowIdx = 1
    for sectionIdx, section in ipairs(sections) do
        EnsureSectionHeader(sectionIdx, section.title)
        for _, statRow in ipairs(section.rows) do
            local row = EnsureRow(rowIdx)
            row.label:SetText((statRow[1] or "—") .. ":")
            row.value:SetText(statRow[2] or "0")
            row.tooltipTitle = statRow[1]
            row.tooltipLines = statRow[3]
            row.label:Show()
            row.value:Show()
            if row.tooltipLines and #row.tooltipLines > 0 then
                row.hit:Show()
            else
                row.hit:Hide()
            end
            rowIdx = rowIdx + 1
        end
        y = y - SECTION_GAP
    end

    for i = 1, #sectionHeaders do
        if i > #sections then sectionHeaders[i]:Hide() end
    end
    for i = rowIdx, #statRows do
        if statRows[i] and statRows[i].label then
            statRows[i].label:Hide()
            statRows[i].value:Hide()
            if statRows[i].hit then statRows[i].hit:Hide() end
        end
    end

    local totalHeight = math.abs(y) + 16
    container:SetHeight(math.max(totalHeight, 120))
    local scroll = BiSPlanner_StatsScroll or BisEquip_StatsScroll
    if scroll then
        local maxScroll = scroll:GetVerticalScrollRange() or 0
        local cur = scroll:GetVerticalScroll() or 0
        if cur > maxScroll then
            scroll:SetVerticalScroll(maxScroll)
        end
    end
end
