--[[
BiSPlanner - Item database by slot; get stats via GetItemInfo/GetItemStats or tooltip fallback
]]

-- EquipSlot (9th return of GetItemInfo) to our slotId. Finger/Trinket map to first slot of pair.
local EQUIP_SLOT_TO_ID = {
    ["INVTYPE_HEAD"] = 1,
    ["INVTYPE_NECK"] = 2,
    ["INVTYPE_SHOULDER"] = 3,
    ["INVTYPE_BODY"] = 4,
    ["INVTYPE_CHEST"] = 5,
    ["INVTYPE_ROBE"] = 5,
    ["INVTYPE_WAIST"] = 6,
    ["INVTYPE_LEGS"] = 7,
    ["INVTYPE_FEET"] = 8,
    ["INVTYPE_WRIST"] = 9,
    ["INVTYPE_HAND"] = 10,
    ["INVTYPE_FINGER"] = 11,
    ["INVTYPE_TRINKET"] = 13,
    ["INVTYPE_CLOAK"] = 15,
    ["INVTYPE_2HWEAPON"] = 16,
    ["INVTYPE_WEAPONMAINHAND"] = 16,
    ["INVTYPE_WEAPON"] = 16,
    ["INVTYPE_WEAPONOFFHAND"] = 17,
    ["INVTYPE_SHIELD"] = 17,
    ["INVTYPE_HOLDABLE"] = 17,
    ["INVTYPE_RANGED"] = 18,
    ["INVTYPE_RANGEDRIGHT"] = 18,
    ["INVTYPE_THROWN"] = 18,
    ["INVTYPE_TABARD"] = 19,
}

-- BiSPlanner_ItemDB and BiSPlanner_ItemSources are loaded from Data/ItemsFull.lua
-- Format: BiSPlanner_ItemDB[slotId] = { { itemId, tableId, difficulty }, ... }
--         BiSPlanner_ItemSources[itemId] = { source = tableId, difficulty = "10N"|"25N"|"10H"|"25H" }
-- Backward compatibility aliases
BisEquip_ItemDB = BiSPlanner_ItemDB or BisEquip_ItemDB
BisEquip_ItemSources = BiSPlanner_ItemSources or BisEquip_ItemSources
BisEquip_SourceBySlot = BiSPlanner_SourceBySlot or BisEquip_SourceBySlot or nil
local NormalizeTableId
local IsLikelySourceMatch
local function ResolveSlotQuery(slotId)
    if slotId == 12 then return 11 end
    if slotId == 14 then return 13 end
    return slotId
end

local function ResolveSlotQueryList(slotId)
    if slotId == 12 then return { 11 } end
    if slotId == 14 then return { 13 } end
    if slotId == 17 then return { 17, 16 } end
    return { slotId }
end

local function NormalizeForSourceFilter(tableId)
    if not tableId then return "" end
    return tostring(tableId)
        :gsub("_[AH]$", "")
        :gsub("25ManHEROIC$", "")
        :gsub("25Man$", "")
        :gsub("HEROIC$", "")
        :gsub("_x2$", "")
        :gsub("_x4$", "")
        :gsub("_%d+$", "")
        :lower()
end

local VANILLA_BLOCK_PREFIXES = {
    "aq20", "aq40", "brd", "lbrs", "ubrs", "strat", "scholo", "dme", "dmw", "dmn",
    "moltencore", "mc", "blackwinglair", "bwl", "zg", "zulgurub", "onyxia60", "naxx40",
    "gnomer", "gnomeregan", "uldaman", "maraudon", "rfd", "rfk", "wc", "deadmines", "stockades",
    "blackfathom", "wailingcaverns", "razorfen", "zf", "sm", "scarlet", "temple", "sunken",
    "scholo", "strath", "uld", "vwow", "worldbossesbc", "worldbossesclassic",
}

local BC_DUNGEON_PREFIXES = {
    "auch", "cfr", "tkbot", "tkarc", "tkmech", "cothillsbrad",
}

local BC_CLASSIC_ILVL_FILTER_PREFIXES = {
    "t0", "karazhan", "kara", "gruul", "gruulslair", "magtheridon", "hcmagtheridon",
    "serpentshrine", "ssc", "tempestkeep", "tk", "blacktemple", "bt", "sunwell", "swp", "zulaman",
    "auch", "cfr", "hcramp", "hchalls", "hcfurnace", "tkbot", "tkarc", "tkmech", "cohillsbrad",
    "hardmode",
}

local PVP_SEASON_BY_ILVL = {
    { max = 213, name = "А5" },
    { max = 232, name = "А6" },
    { max = 251, name = "А7" },
    { max = 270, name = "А8" },
    { max = 280, name = "А9" },
    { max = 290, name = "А10" },
    { max = 999, name = "А11" },
}

local function StartsWithAny(text, prefixes)
    for _, p in ipairs(prefixes) do
        if text:sub(1, #p) == p then return true end
    end
    return false
end

local function IsAllowedSourceTable(tableId)
    if not tableId then return false end
    local raw = tostring(tableId):lower()
    local base = NormalizeForSourceFilter(tableId)

    -- Remove classic (vanilla) raid/dungeon sources entirely.
    if StartsWithAny(base, VANILLA_BLOCK_PREFIXES) then
        return false
    end

    -- Hide tiers not used on this server.
    if base:find("^t11") or base:find("^t0") then
        return false
    end

    -- Keep BC dungeons only in heroic mode.
    if StartsWithAny(base, BC_DUNGEON_PREFIXES) then
        local heroic = raw:find("heroic") or raw:sub(1, 2) == "hc"
        if not heroic then return false end
    end

    return true
end

local function IsClassicOrBCSourceForIlvlGate(tableId)
    if not tableId then return false end
    local base = NormalizeForSourceFilter(tableId)
    return StartsWithAny(base, BC_CLASSIC_ILVL_FILTER_PREFIXES)
end

local function ShouldHideByIlvlPolicy(itemId, tableId)
    if not itemId or not tableId then return false end
    if not IsClassicOrBCSourceForIlvlGate(tableId) then return false end
    local _, _, _, itemLevel = GetItemInfo(itemId)
    if not itemLevel then return false end
    return itemLevel < 200
end

local SOURCE_MAX_ILVL_CACHE = nil

local function BuildSourceMaxIlvlCache()
    if SOURCE_MAX_ILVL_CACHE then return SOURCE_MAX_ILVL_CACHE end
    local out = {}
    local itemDB = BiSPlanner_ItemDB or BisEquip_ItemDB
    for _, rows in pairs(itemDB or {}) do
        for _, row in ipairs(rows) do
            local itemId = type(row) == "table" and row[1] or nil
            local tableId = type(row) == "table" and row[2] or nil
            if itemId and tableId then
                local _, _, _, itemLevel = GetItemInfo(itemId)
                if itemLevel then
                    local key = NormalizeForSourceFilter(tableId)
                    if key and key ~= "" then
                        local prev = out[key]
                        if (not prev) or itemLevel > prev then
                            out[key] = itemLevel
                        end
                    end
                end
            end
        end
    end
    SOURCE_MAX_ILVL_CACHE = out
    return out
end

local function GetSourceMaxIlvl(sourceId)
    local key = NormalizeForSourceFilter(sourceId)
    if not key or key == "" then return nil end
    local c = BuildSourceMaxIlvlCache()
    return c and c[key] or nil
end

local function GetPvPSeasonForSource(sourceId)
    local base = NormalizeForSourceFilter(sourceId)
    -- Stable pattern mapping first: source IDs in this DB encode PvP generations.
    if base:find("unset10") or base:find("unset9") or base:find("unset8") or base:find("unset66") or base:find("nonset4") or base:find("3$") then
        return "А11"
    end
    if base:find("unset7") or base:find("unset55") then
        return "А10"
    end
    if base:find("unset6") or base:find("unset44") then
        return "А9"
    end
    if base:find("unset5") or base:find("nonset3") then
        return "А8"
    end
    if base:find("unset4") or base:find("nonset2") then
        return "А7"
    end
    if base:find("2$") then
        return "А6"
    end
    if base:find("unset3") or base:find("unset2") or base:find("unset1") or base:find("nonset1") or base:find("nonset0") then
        return "А5"
    end

    -- Then use ilvl where available for ambiguous sources.
    local ilvl = GetSourceMaxIlvl(sourceId)
    if ilvl then
        for _, row in ipairs(PVP_SEASON_BY_ILVL) do
            if ilvl <= row.max then return row.name end
        end
    end
    return "А6"
end

function BisEquip_GetPvpSeasonForSource(sourceId)
    return GetPvPSeasonForSource(sourceId)
end

local function GetBCTierForSource(sourceId)
    local base = NormalizeForSourceFilter(sourceId)
    -- On Sirus DB, T6 groups are commonly encoded with trailing "2".
    if base:find("2$") then return "Тир 6" end
    local ilvl = GetSourceMaxIlvl(sourceId)
    if ilvl then
        if ilvl <= 260 then return "Тир 4" end
        if ilvl <= 280 then return "Тир 5" end
        return "Тир 6"
    end
    return "Тир 4"
end

local function ShouldHideSourceByIlvlPolicy(sourceId)
    if not IsClassicOrBCSourceForIlvlGate(sourceId) then return false end
    local ilvl = GetSourceMaxIlvl(sourceId)
    if not ilvl then return false end
    return ilvl < 200
end

local PVP_SEASON_SLOT_CACHE = nil
local PVP_ITEM_SEASON_CACHE = {}
local PVP_ITEMINFO_WARMUP_TT = nil
local PVP_ITEM_CLASS_CACHE = nil
local GetItemInfoWarm
local PVP_CLASS_SCAN_TT = nil

local function IsWintergraspSource(sourceId)
    local base = NormalizeForSourceFilter(sourceId)
    return base:find("lakewintergrasp") or base:find("venturebay")
end

local function IsLikelyPvpSource(sourceId)
    local base = NormalizeForSourceFilter(sourceId)
    if base == "" then return false end
    if IsWintergraspSource(sourceId) then return true end
    return base:find("pvp") or base:find("gladiator") or base:find("wintergrasp") or base:find("venturebay")
end

local function GetPvpClassLabelFromSource(sourceId)
    if not sourceId then return nil end
    local base = NormalizeForSourceFilter(sourceId)
    if not base:find("^pvp80") then return nil end
    if base:find("deathknight") then return "Рыцарь смерти" end
    if base:find("druid") then return "Друид" end
    if base:find("hunter") then return "Охотник" end
    if base:find("mage") then return "Маг" end
    if base:find("paladin") then return "Паладин" end
    if base:find("priest") then return "Жрец" end
    if base:find("rogue") then return "Разбойник" end
    if base:find("shaman") then return "Шаман" end
    if base:find("warlock") then return "Чернокнижник" end
    if base:find("warrior") then return "Воин" end
    return nil
end

local function BuildPvpItemClassCache()
    if PVP_ITEM_CLASS_CACHE then return PVP_ITEM_CLASS_CACHE end
    local out = {}
    local itemDB = BiSPlanner_ItemDB or BisEquip_ItemDB
    for _, rows in pairs(itemDB or {}) do
        for _, row in ipairs(rows) do
            local itemId = type(row) == "table" and row[1] or nil
            local sourceId = type(row) == "table" and row[2] or nil
            if itemId and sourceId then
                local cls = GetPvpClassLabelFromSource(sourceId)
                if cls then
                    out[itemId] = { cls }
                end
            end
        end
    end
    PVP_ITEM_CLASS_CACHE = out
    return out
end

local function GuessPvpClassByName(nameLower)
    if not nameLower or nameLower == "" then return nil end
    if nameLower:find("жутк") then return "Рыцарь смерти" end
    if nameLower:find("латн") then return "Воин" end
    if nameLower:find("украшен") or nameLower:find("орнамент") then return "Паладин" end
    if nameLower:find("чешуйч") then return "Охотник" end
    if nameLower:find("плетен") then return "Шаман" end
    if nameLower:find("кожан") then return "Друид" end
    if nameLower:find("клепан") then return "Разбойник" end
    if nameLower:find("атлас") then return "Жрец" end
    if nameLower:find("шелков") then return "Маг" end
    if nameLower:find("боев") then return "Чернокнижник" end
    return nil
end

local function GetPvpClassesFromTooltip(itemId)
    if not itemId then return nil end
    if not (CreateFrame and UIParent) then return nil end
    if not PVP_CLASS_SCAN_TT then
        PVP_CLASS_SCAN_TT = CreateFrame("GameTooltip", "BisEquipPvpClassScanTooltip", UIParent, "GameTooltipTemplate")
        PVP_CLASS_SCAN_TT:SetOwner(UIParent, "ANCHOR_NONE")
    end
    PVP_CLASS_SCAN_TT:ClearLines()
    PVP_CLASS_SCAN_TT:SetHyperlink("item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0")
    local labels = {
        { "Воин", "воин", "warrior" },
        { "Паладин", "паладин", "paladin" },
        { "Охотник", "охотник", "hunter" },
        { "Разбойник", "разбойник", "rogue" },
        { "Жрец", "жрец", "priest" },
        { "Рыцарь смерти", "рыцарь смерти", "death knight" },
        { "Шаман", "шаман", "shaman" },
        { "Маг", "маг", "mage" },
        { "Чернокнижник", "чернокнижник", "warlock" },
        { "Друид", "друид", "druid" },
    }
    local out, seen = {}, {}
    for i = 2, 20 do
        local left = _G["BisEquipPvpClassScanTooltipTextLeft" .. i]
        if left then
            local t = tostring(left:GetText() or ""):lower()
            if t:find("классы:") or t:find("classes:") then
                for _, row in ipairs(labels) do
                    if t:find(row[2], 1, true) or t:find(row[3], 1, true) then
                        if not seen[row[1]] then
                            seen[row[1]] = true
                            out[#out + 1] = row[1]
                        end
                    end
                end
            end
        end
    end
    if #out > 0 then return out end
    return nil
end

local function GetPvpClassLabelsForItem(itemId, sourceId)
    local byItem = BuildPvpItemClassCache()
    if byItem[itemId] then return byItem[itemId] end
    local fromTooltip = GetPvpClassesFromTooltip(itemId)
    if fromTooltip and #fromTooltip > 0 then
        byItem[itemId] = fromTooltip
        return fromTooltip
    end
    local bySource = GetPvpClassLabelFromSource(sourceId)
    if bySource then
        byItem[itemId] = { bySource }
        return byItem[itemId]
    end
    local name = GetItemInfoWarm and GetItemInfoWarm(itemId) or GetItemInfo(itemId)
    local byName = GuessPvpClassByName(tostring(name or ""):lower())
    if byName then
        byItem[itemId] = { byName }
        return byItem[itemId]
    end
    return nil
end

GetItemInfoWarm = function(itemId)
    local name, link, quality, itemLevel = GetItemInfo(itemId)
    if name then
        return name, link, quality, itemLevel
    end
    if CreateFrame and UIParent then
        if not PVP_ITEMINFO_WARMUP_TT then
            PVP_ITEMINFO_WARMUP_TT = CreateFrame("GameTooltip", "BisEquipPvpWarmupTooltip", UIParent, "GameTooltipTemplate")
            PVP_ITEMINFO_WARMUP_TT:SetOwner(UIParent, "ANCHOR_NONE")
        end
        PVP_ITEMINFO_WARMUP_TT:ClearLines()
        PVP_ITEMINFO_WARMUP_TT:SetHyperlink("item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0")
        PVP_ITEMINFO_WARMUP_TT:Show()
        PVP_ITEMINFO_WARMUP_TT:Hide()
        name, link, quality, itemLevel = GetItemInfo(itemId)
    end
    return name, link, quality, itemLevel
end

local function ClassifyPvPSeasonByName(nameLower)
    if not nameLower or nameLower == "" then return nil end
    if (not nameLower:find("гладиатор")) and (not nameLower:find("gladiator")) then
        return nil
    end
    -- Account for declensions: "бездушного", "деспотичного", etc.
    if nameLower:find("бездуш") then return "А13" end
    if nameLower:find("деспотич") then return "А12" end
    if nameLower:find("злонрав") then return "А11" end
    if nameLower:find("беспощад") then return "А10" end
    if nameLower:find("яростн") then return "А9" end
    if nameLower:find("разгневан") then return "А8" end
    if nameLower:find("неумолим") then return "А7" end
    if nameLower:find("гневн") then return "А6" end
    if nameLower:find("свиреп") or nameLower:find("злобн") or nameLower:find("смертонос") then return "А5" end
    return nil
end

local function ClassifyPvPSeasonByIlvl(itemLevel)
    if not itemLevel then return nil end
    if itemLevel >= 303 then return "А13" end
    if itemLevel >= 297 then return "А12" end
    if itemLevel >= 290 then return "А11" end
    if itemLevel >= 284 then return "А10" end
    if itemLevel >= 277 then return "А9" end
    if itemLevel >= 270 then return "А8" end
    if itemLevel >= 251 then return "А7" end
    if itemLevel >= 232 then return "А6" end
    if itemLevel >= 200 then return "А5" end
    return nil
end

function BisEquip_GetPvpSeasonForItem(itemId, sourceId)
    if not itemId then return nil end
    if PVP_ITEM_SEASON_CACHE[itemId] then
        return PVP_ITEM_SEASON_CACHE[itemId]
    end
    local name, _, _, itemLevel = GetItemInfoWarm(itemId)
    local lowerName = tostring(name or ""):lower()
    local byName = ClassifyPvPSeasonByName(lowerName)
    if not byName and not IsLikelyPvpSource(sourceId) and not lowerName:find("гладиатор") and not lowerName:find("gladiator") then
        return nil
    end
    local season = byName or ClassifyPvPSeasonByIlvl(itemLevel)
    if season then
        PVP_ITEM_SEASON_CACHE[itemId] = season
    end
    return season
end

local function GetEffectiveClassId()
    local cid = (BiSPlanner_GetSelectedClass and BiSPlanner_GetSelectedClass()) or (BisEquip_GetSelectedClass and BisEquip_GetSelectedClass()) or nil
    if cid and cid ~= "" then return cid end
    local unitClass = nil
    if UnitClass then
        local _, cls = UnitClass("player")
        unitClass = cls
    end
    return unitClass
end

local function LowerSafe(v)
    return tostring(v or ""):lower()
end

local function ContainsAny(text, needles)
    if not text or text == "" then return false end
    for _, n in ipairs(needles) do
        if text:find(n) then return true end
    end
    return false
end

local function IsItemAllowedForSlot(slotId, itemId)
    if not slotId or not itemId then return true end
    local itemName, _, _, _, _, _, itemSubType, _, equipSlot = GetItemInfo(itemId)
    if not equipSlot or equipSlot == "" then
        return false
    end

    local classId = GetEffectiveClassId()

    local allowedEquipSlotsBySlot = {
        [1] = { INVTYPE_HEAD = true },
        [2] = { INVTYPE_NECK = true },
        [3] = { INVTYPE_SHOULDER = true },
        [4] = { INVTYPE_BODY = true },
        [5] = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
        [6] = { INVTYPE_WAIST = true },
        [7] = { INVTYPE_LEGS = true },
        [8] = { INVTYPE_FEET = true },
        [9] = { INVTYPE_WRIST = true },
        [10] = { INVTYPE_HAND = true },
        [11] = { INVTYPE_FINGER = true },
        [12] = { INVTYPE_FINGER = true },
        [13] = { INVTYPE_TRINKET = true },
        [14] = { INVTYPE_TRINKET = true },
        [15] = { INVTYPE_CLOAK = true },
        [16] = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true },
        [19] = { INVTYPE_TABARD = true },
    }

    local slotAllowed = allowedEquipSlotsBySlot[slotId]
    if slotAllowed and not slotAllowed[equipSlot] then
        return false
    end

    if slotId == 17 then
        if equipSlot == "INVTYPE_WEAPONOFFHAND" or equipSlot == "INVTYPE_SHIELD" or equipSlot == "INVTYPE_HOLDABLE" then
            return true
        end
        if equipSlot == "INVTYPE_WEAPON" then
            return true
        end
        if equipSlot == "INVTYPE_2HWEAPON" then
            return classId == "WARRIOR"
        end
        return false
    end

    if slotId == 18 then
        if not classId then return true end
        local isRelicEquip = (equipSlot == "INVTYPE_RANGEDRIGHT" or equipSlot == "INVTYPE_RELIC")
        local st = LowerSafe(itemSubType)
        local nm = LowerSafe(itemName)
        local isRelicSigil = ContainsAny(st, { "печат", "sigil" }) or ContainsAny(nm, { "печать", "sigil" })
        local isRelicLibram = ContainsAny(st, { "манускрип", "libram" }) or ContainsAny(nm, { "манускрип", "libram" })
        local isRelicTotem = ContainsAny(st, { "тотем", "totem" }) or ContainsAny(nm, { "тотем", "totem" })
        local isRelicIdol = ContainsAny(st, { "идол", "idol" }) or ContainsAny(nm, { "идол", "idol" })
        local isWand = ContainsAny(st, { "жезл", "wand" })
        local isPhysicalRanged = ContainsAny(st, { "лук", "арбал", "руж", "метатель", "bow", "crossbow", "gun", "thrown" })

        if classId == "DEATHKNIGHT" then
            return isRelicEquip and (isRelicSigil or (not isRelicLibram and not isRelicTotem and not isRelicIdol and not isWand))
        elseif classId == "PALADIN" then
            return isRelicEquip and (isRelicLibram or (not isRelicSigil and not isRelicTotem and not isRelicIdol and not isWand))
        elseif classId == "SHAMAN" then
            return isRelicEquip and (isRelicTotem or (not isRelicSigil and not isRelicLibram and not isRelicIdol and not isWand))
        elseif classId == "DRUID" then
            return isRelicEquip and (isRelicIdol or (not isRelicSigil and not isRelicLibram and not isRelicTotem and not isWand))
        elseif classId == "MAGE" or classId == "PRIEST" or classId == "WARLOCK" then
            return equipSlot == "INVTYPE_RANGEDRIGHT" and isWand
        elseif classId == "HUNTER" or classId == "ROGUE" or classId == "WARRIOR" then
            if equipSlot == "INVTYPE_RANGED" or equipSlot == "INVTYPE_THROWN" or equipSlot == "INVTYPE_RANGEDRIGHT" then
                return true
            end
            return isRelicEquip and isPhysicalRanged
        end
    end

    return true
end

local KNOWN_SOURCE_NAME_BY_ID = {
    -- Trial of the Crusader
    TrialoftheCrusaderNorthrendBeasts = "Звери Нордскола",
    TrialoftheCrusaderLordJaraxxus = "Лорд Джараксус",
    TrialoftheCrusaderFactionChampions = "Чемпионы фракций",
    TrialoftheCrusaderTwinValkyrs = "Валь'киры-близнецы",
    TrialoftheCrusaderAnubarak = "Ануб'арак",

    -- BC raids
    GruulsLairHighKingMaulgar = "Короли",
    GruulMaulgar = "Короли",
    GruulsLairGruulTheDragonkiller = "Груул",
    GruulGruul = "Груул",
}

local function GetKnownSourceName(tableId)
    if not tableId then return nil end
    local base = tostring(tableId)
        :gsub("_[AH]$", "")
        :gsub("25ManHEROIC$", "")
        :gsub("25Man$", "")
        :gsub("HEROIC$", "")
        :gsub("_x2$", "")
        :gsub("_x4$", "")
        :gsub("_%d+$", "")
    if KNOWN_SOURCE_NAME_BY_ID[base] then
        return KNOWN_SOURCE_NAME_BY_ID[base]
    end
    local baseLower = base:lower()
    -- Trial of the Crusader (all faction/difficulty variants collapse to 5 bosses)
    if base:find("^TrialoftheCrusader") then
        if base:find("NorthrendBeasts") then return "Звери Нордскола" end
        if base:find("LordJaraxxus") then return "Лорд Джараксус" end
        if base:find("FactionChampions") then return "Чемпионы фракций" end
        if base:find("TwinValkyrs") then return "Валь'киры-близнецы" end
        if base:find("Anubarak") then return "Ануб'арак" end
    end
    -- BC raids
    if base:find("^GruulsLair") or base:find("^Gruul") then
        if base:find("Maulgar") or base:find("HighKing") then return "Короли" end
        if base:find("Gruul") then return "Груул" end
    end
    if base:find("^Karazhan") then
        if base:find("Attumen") then return "Аттумен Охотник" end
        if base:find("Moroes") then return "Мороуз" end
        if base:find("Maiden") then return "Дева Скорби" end
        if base:find("Opera") then return "Опера" end
        if base:find("Curator") then return "Смотритель" end
        if base:find("Illhoof") then return "Ил'хоф" end
        if base:find("Shade") then return "Тень Арана" end
        if base:find("Netherspite") then return "Гнев Пустоты" end
        if base:find("Chess") then return "Шахматы" end
        if base:find("Prince") then return "Принц Малчезар" end
        if base:find("Nightbane") then return "Ночная Погибель" end
        if base:find("Trash") then return "Треш" end
    end
    if base:find("^SerpentshrineCavern") or base:find("^SSC") then
        if base:find("Hydross") then return "Гидросс Нестабильный" end
        if base:find("Lurker") then return "Скрытень из глубин" end
        if base:find("Leotheras") then return "Леотерас Слепец" end
        if base:find("Karathress") or base:find("FathomLord") then return "Повелитель глубин Каратресс" end
        if base:find("Morogrim") then return "Морогрим Волноступ" end
        if base:find("Vashj") then return "Леди Вайш" end
        if base:find("Trash") then return "Треш" end
    end
    if base:find("^TempestKeep") or base:find("^TK") then
        if base:find("Alar") then return "Ал'ар" end
        if base:find("VoidReaver") then return "Страж Бездны" end
        if base:find("Solarian") then return "Верховный звездочет Солариан" end
        if base:find("Kael") then return "Кель'тас Солнечный Скиталец" end
        if base:find("Trash") then return "Треш" end
    end
    if base:find("^BlackTemple") or base:find("^BT") then
        if base:find("Najentus") then return "Верховный Полководец Надж'ентус" end
        if base:find("Supremus") then return "Супремус" end
        if base:find("ShadeofAkama") then return "Тень Акамы" end
        if base:find("Teron") then return "Терон Кровожад" end
        if base:find("Gurtogg") then return "Гуртогг Кипящая Кровь" end
        if base:find("Reliquary") then return "Реликварий Душ" end
        if base:find("MotherShahraz") then return "Матушка Шахраз" end
        if base:find("IllidariCouncil") then return "Совет Иллидари" end
        if base:find("Illidan") then return "Иллидан Ярость Бури" end
        if base:find("Trash") then return "Треш" end
    end
    if base:find("^ZulAman") or base:find("^ZA") then
        if base:find("Nalorakk") then return "Налоракк" end
        if base:find("Akilzon") then return "Акил'зон" end
        if base:find("Janalai") then return "Джан'алай" end
        if base:find("Halazzi") then return "Халаззи" end
        if base:find("HexLord") then return "Хекс Лорд Малакрасс" end
        if base:find("Zuljin") then return "Зул'джин" end
        if base:find("Trash") then return "Треш" end
    end
    if base:find("^SunwellPlateau") or base:find("^SWP") then
        if base:find("Kalecgos") then return "Калесгос" end
        if base:find("Brutallus") then return "Бруталл" end
        if base:find("Felmyst") then return "Фелмист" end
        if base:find("EredarTwins") then return "Эредарские близнецы" end
        if base:find("Muru") then return "М'уру" end
        if base:find("Kiljaeden") then return "Кил'джеден" end
        if base:find("Trash") then return "Треш" end
    end
    if base:find("Magtheridon") then
        if base:find("Trash") then return "Треш" end
        return "Магтеридон"
    end
    if base:find("^EmblemofHeroism") then return "Эмблема героизма" end
    if base:find("^EmblemofValor") then return "Эмблема доблести" end
    if base:find("^EmblemofConquest") then return "Эмблема завоевания" end
    if base:find("^EmblemofTriumph") then return "Эмблема триумфа" end
    if base:find("^EmblemofFrost") then return "Эмблема льда" end
    if base:find("^EmblemofScorching") then return "Эмблема Испепеления" end
    if base:find("^Kara") then
        if base:find("Attumen") then return "Аттумен Охотник" end
        if base:find("Moroes") then return "Мороуз" end
        if base:find("Maiden") then return "Дева Скорби" end
        if base:find("Opera") then return "Опера" end
        if base:find("Curator") then return "Смотритель" end
        if base:find("Illhoof") then return "Терестиан Больное Копыто" end
        if base:find("Aran") then return "Тень Арана" end
        if base:find("Netherspite") then return "Гнев Пустоты" end
        if base:find("Chess") then return "Шахматы" end
        if base:find("Prince") then return "Принц Малчезар" end
        if base:find("Nightbane") then return "Ночная Погибель" end
        if base:find("Trash") then return "Треш" end
    end
    if base:find("^HCFurnace") then
        if base:find("Breaker") then return "Разрушитель" end
        if base:find("Broggok") then return "Броггок" end
        if base:find("Maker") then return "Создатель" end
    end
    if base:find("^HCHalls") then
        if base:find("Kargath") then return "Вождь Каргат" end
        if base:find("Nethekurse") then return "Нетеркурсе" end
        if base:find("Omrogg") then return "Воевода Омрогг" end
    end
    if base:find("^HCRamp") then
        if base:find("Omor") then return "Омор Неуязвимый" end
        if base:find("Vazruden") then return "Вазруден и Назан" end
        if base:find("Watchkeeper") then return "Страж Плато" end
    end
    if base:find("^AuchMana") then
        if base:find("Pandemonius") then return "Пандемониус" end
        if base:find("Tavarok") then return "Таварок" end
        if base:find("NexusPrince") then return "Принц Нексус" end
        if base:find("Yor") then return "Йор" end
    end
    if base:find("^AuchCrypts") then
        if base:find("Shirrak") then return "Ширрак Мертвый Страж" end
        if base:find("Exarch") then return "Экзарх Маладар" end
        if base:find("Avatar") then return "Аватара Мученик" end
    end
    if base:find("^AuchShadow") then
        if base:find("Hellmaw") then return "Хеллмау" end
        if base:find("Blackheart") then return "Черносерд Подстрекатель" end
        if base:find("Grandmaster") then return "Великий мастер Ворпил" end
        if base:find("Murmur") then return "Мурмур" end
    end
    if base:find("^AuchSethekk") then
        if base:find("TalonKing") then return "Король Когтей Айкисс" end
        if base:find("Darkweaver") then return "Темный Ткач Ситх" end
    end
    if base:find("^CFRSlave") then
        if base:find("Mennu") then return "Менну Предатель" end
        if base:find("Rokmar") then return "Рокмар Трескун" end
        if base:find("Quagmirran") then return "Квагмирран" end
    end
    if base:find("^CFRUnder") then
        if base:find("Hungarfen") then return "Голодный Топетун" end
        if base:find("Ghazan") then return "Газ'ан" end
        if base:find("Swamplord") then return "Болотный лорд Муссел'ек" end
        if base:find("Stalker") then return "Черный Сталкер" end
    end
    if base:find("^CFRSteam") then
        if base:find("Hydromancer") then return "Гидромант Теспия" end
        if base:find("Thespia") then return "Гидромант Теспия" end
        if base:find("Mekgineer") then return "Мекгинер Паропуск" end
        if base:find("Steamrigger") then return "Мекгинер Паропуск" end
        if base:find("Warlord") then return "Воевода Калитреш" end
    end
    if base:find("^TKArc") then
        if base:find("Dalliah") then return "Даллия Всеподчиняющая" end
        if base:find("Scryer") then return "Провидец Гнева Соккорат" end
        if base:find("Harbinger") then return "Предвестник Скайрисс" end
        if base:find("Unbound") then return "Пустомант" end
    end
    if base:find("^TKBot") then
        if base:find("Sarannis") then return "Командир Саранис" end
        if base:find("Freywinn") then return "Верховный ботаник Фрейвин" end
        if base:find("Thorngrin") then return "Торнгрин Укротитель" end
        if base:find("Laj") then return "Ладж" end
        if base:find("WarpSplinter") or base:find("Splinter") then return "Узлодревень" end
    end
    if base:find("^TKMech") then
        if base:find("Capacitus") then return "Механолорд Конденсатор" end
        if base:find("Sepethrea") then return "Пустомант Сепетрея" end
        if base:find("Pathaleon") then return "Паталеон Вычислитель" end
        if base:find("Calc") then return "Паталеон Вычислитель" end
        if base:find("CacheoftheLegion") then return "Тайник Легиона" end
    end
    if base:find("^MountHyjal") then
        if base:find("RageWinterchill") then return "Ледяной яростень" end
        if base:find("Anetheron") then return "Анетерон" end
        if base:find("Kazrogal") then return "Каз'рогал" end
        if base:find("Azgalor") then return "Азгалор" end
        if base:find("Archimonde") then return "Архимонд" end
        return "Битва за гору Хиджал"
    end
    if base:find("^PoS") then
        if base:find("Tyrannus") then return "Тираний" end
        if base:find("Ick") then return "Гниломорд и Тухлопуз" end
        if base:find("Forgemaster") then return "Начальник кузни Гархлад" end
        return "Яма Сарона"
    end
    if base:find("^FoS") then return "Кузня Душ" end
    if base:find("^HoR") then return "Залы Отражений" end
    if base:find("^SP") then
        if base:find("Kiljaeden") then return "Кил'джеден" end
        if base:find("Muru") then return "М'уру" end
        if base:find("Eredar") then return "Эредарские близнецы" end
        if base:find("Felmyst") then return "Фелмист" end
        if base:find("Brutallus") then return "Бруталл" end
        return "Плато Солнечного Колодца"
    end
    if base:find("^CFRSerpent") then return "Змеиное святилище" end
    if base:find("^HardMode") then
        if base:find("Plate2") then return "Латы (Тир 6)" end
        if base:find("Leather2") then return "Кожа (Тир 6)" end
        if base:find("Accessories2") then return "Аксессуары (Тир 6)" end
        if base:find("Plate") then return "Латы (Воин/Паладин/Рыцарь смерти)" end
        if base:find("Mail") then return "Кольчуга (Охотник/Шаман)" end
        if base:find("Leather") then return "Кожа (Разбойник/Друид)" end
        if base:find("Cloth") then return "Ткань (Маг/Жрец/Чернокнижник)" end
        if base:find("Relic") then return "Реликвии" end
        if base:find("Weapons") then return "Оружие" end
        if base:find("Cloaks") then return "Плащи" end
        if base:find("Accessories") then return "Аксессуары" end
        return "Сеты BC"
    end
    if base:find("^PvP80") then
        local classSpecMap = {
            DeathKnight = "Рыцарь смерти",
            DruidBalance = "Друид - Баланс",
            DruidFeral = "Друид - Сила зверя",
            DruidRestoration = "Друид - Исцеление",
            Hunter = "Охотник",
            Mage = "Маг",
            PaladinHoly = "Паладин - Свет",
            PaladinRetribution = "Паладин - Воздаяние",
            PriestHoly = "Жрец - Свет",
            PriestShadow = "Жрец - Тьма",
            Rogue = "Разбойник",
            ShamanElemental = "Шаман - Стихии",
            ShamanEnhancement = "Шаман - Совершенствование",
            ShamanRestoration = "Шаман - Исцеление",
            Warlock = "Чернокнижник",
            Warrior = "Воин",
            UnSet = "Оффсеты PvP",
        }
        for token, ru in pairs(classSpecMap) do
            if baseLower:find(token:lower()) then
                return ru
            end
        end
        return "PvP комплект"
    end
    if baseLower:find("^t10") then
        local t10Map = {
            WarriorFury = "Воин - Неистовство",
            WarriorProtection = "Воин - Защита",
            PaladinHoly = "Паладин - Свет",
            PaladinRetribution = "Паладин - Воздаяние",
            PaladinProtection = "Паладин - Защита",
            DeathKnightDPS = "Рыцарь смерти - Урон",
            DeathKnightTank = "Рыцарь смерти - Танк",
            DruidBalance = "Друид - Баланс",
            DruidFeral = "Друид - Сила зверя",
            DruidRestoration = "Друид - Исцеление",
            Hunter = "Охотник",
            Mage = "Маг",
            PriestHoly = "Жрец - Свет",
            PriestShadow = "Жрец - Тьма",
            Rogue = "Разбойник",
            ShamanElemental = "Шаман - Стихии",
            ShamanEnhancement = "Шаман - Совершенствование",
            ShamanRestoration = "Шаман - Исцеление",
            Warlock = "Чернокнижник",
        }
        for token, ru in pairs(t10Map) do
            if baseLower:find(token:lower()) then return ru end
        end
        return "Тир 10"
    end
    if baseLower:find("^t9") or baseLower:find("^maar'nt9") then
        return "Тир 9"
    end
    if base:find("^Darkmoon") then return "Ярмарка Новолуния" end
    if base:find("^Halloween") then return "Тыквовин" end
    if base:find("^Blacksmithing") then return "Кузнечное дело" end
    if base:find("^Tailoring") then return "Портняжное дело" end
    if base:find("^Leatherworking") then return "Кожевничество" end
    if base:find("^Engineering") then return "Инженерное дело" end
    if base:find("^Inscription") then return "Начертание" end
    if base:find("^Jewelcrafting") then return "Ювелирное дело" end
    return nil
end

local function FindBossNameInLootSubTables(tableId)
    if not tableId or not BisEquip_LootMenu_SubTables then return nil end
    for _, bosses in pairs(BisEquip_LootMenu_SubTables) do
        if type(bosses) == "table" then
            for _, boss in ipairs(bosses) do
                if boss and boss.tableId and boss.name and IsLikelySourceMatch and IsLikelySourceMatch(tableId, boss.tableId) then
                    return boss.name
                end
            end
        end
    end
    return nil
end

-- Get source info for item
function BiSPlanner_GetItemSource(itemId)
    BisEquip_GetItemSource = BiSPlanner_GetItemSource -- Backward compatibility
    local sources = BiSPlanner_ItemSources or BisEquip_ItemSources
    return sources and sources[itemId]
end

-- Format tableId for display (uses BiSPlanner_TableNames from Data/LootMenu.lua or fallback)
function BiSPlanner_FormatSourceName(tableId)
    BisEquip_FormatSourceName = BiSPlanner_FormatSourceName -- Backward compatibility
    if not tableId or tableId == "" then return "?" end
    local known = GetKnownSourceName(tableId)
    if known then return known end
    -- Сначала проверяем точное совпадение
    local tableNames = BiSPlanner_TableNames or BisEquip_TableNames
    if tableNames and tableNames[tableId] then
        return tableNames[tableId]
    end
    -- Пробуем нормализованный вариант (без суффиксов сложности)
    local normalized = NormalizeTableId(tableId)
    if normalized and tableNames and tableNames[normalized] then
        return tableNames[normalized]
    end
    local fromSubtables = FindBossNameInLootSubTables(tableId)
    if fromSubtables then
        return fromSubtables
    end
    -- Fallback: нормализованное название вместо технического
    local displayName = normalized or tableId
    return (displayName:gsub("_", " "):gsub("(%l)(%u)", "%1 %2"):gsub("(%d)(%u)", "%1 %2"))
end
local FormatSourceName = BiSPlanner_FormatSourceName or BisEquip_FormatSourceName

local function BuildPvpSeasonSlotCache()
    if PVP_SEASON_SLOT_CACHE then return PVP_SEASON_SLOT_CACHE end
    local out = {}
    for slotId, rows in pairs(BisEquip_ItemDB or {}) do
        local bySeason = {}
        local function AddSeasonGroup(season, sourceId, className, itemId)
            if not season then return end
            bySeason[season] = bySeason[season] or {}
            if not bySeason[season][className] then
                bySeason[season][className] = { name = className, ids = {}, itemIds = {} }
            end
            bySeason[season][className].ids[sourceId] = true
            if itemId then
                bySeason[season][className].itemIds[itemId] = true
            end
        end
        for _, row in ipairs(rows) do
            local itemId = type(row) == "table" and row[1] or nil
            local sourceId = type(row) == "table" and row[2] or nil
            if itemId and sourceId and IsAllowedSourceTable(sourceId) then
                local sourceBase = NormalizeForSourceFilter(sourceId)
                local classLabels = GetPvpClassLabelsForItem(itemId, sourceId)
                local itemSeason = BisEquip_GetPvpSeasonForItem(itemId, sourceId)

                if classLabels and #classLabels > 0 then
                    -- Primary path: classify by actual item (name/ilvl), even when source is not PvP80
                    -- (e.g. VaultOfArchavon* on Sirus for PvP set pieces).
                    if itemSeason and (not IsWintergraspSource(sourceId)) then
                        for _, className in ipairs(classLabels) do
                            AddSeasonGroup(itemSeason, sourceId, className, itemId)
                        end
                    elseif IsLikelyPvpSource(sourceId) and (not IsWintergraspSource(sourceId)) then
                        -- Fallback for uncached item info.
                        local fallbackSeason = GetPvPSeasonForSource(sourceId)
                        for _, className in ipairs(classLabels) do
                            AddSeasonGroup(fallbackSeason, sourceId, className, itemId)
                        end
                        -- If item info is not yet cached, *2 sources may belong to A6/A7.
                        -- Add A7 bucket to keep the season visible; exact filtering happens later per item.
                        if sourceBase:find("2$") then
                            for _, className in ipairs(classLabels) do
                                AddSeasonGroup("А6", sourceId, className, itemId)
                                AddSeasonGroup("А7", sourceId, className, itemId)
                            end
                        elseif sourceBase:find("^pvp80[a-z]+$") then
                            -- Class set sources without explicit season suffix can contain A5/A6/A7.
                            for _, className in ipairs(classLabels) do
                                AddSeasonGroup("А6", sourceId, className, itemId)
                                AddSeasonGroup("А7", sourceId, className, itemId)
                            end
                        end
                    end
                end
            end
        end
        out[slotId] = bySeason
    end
    if out[11] and not out[12] then out[12] = out[11] end
    if out[13] and not out[14] then out[14] = out[13] end
    PVP_SEASON_SLOT_CACHE = out
    return out
end

function BisEquip_GetPvpSeasonGroupsForSlot(slotId)
    local cache = BuildPvpSeasonSlotCache()
    return cache[ResolveSlotQuery(slotId)] or {}
end

function BisEquip_ResetPvpSeasonCaches()
    PVP_SEASON_SLOT_CACHE = nil
    PVP_ITEM_SEASON_CACHE = {}
    PVP_ITEM_CLASS_CACHE = nil
end

local function BuildSourceBySlotCache()
    if BisEquip_SourceBySlot then return BisEquip_SourceBySlot end
    local out = {}
    for slotId, rows in pairs(BisEquip_ItemDB or {}) do
        local seen = {}
        local list = {}
        for _, row in ipairs(rows) do
            local itemId = type(row) == "table" and row[1] or row
            local tableId = type(row) == "table" and row[2] or nil
            if tableId then
                if not IsAllowedSourceTable(tableId) then
                    tableId = nil
                elseif ShouldHideByIlvlPolicy(itemId, tableId) then
                    tableId = nil
                end
            end
            if tableId then
                local canonicalId = NormalizeTableId(tableId) or tableId
                -- В ИК показываем только 5 боссов, без "Tribute" служебных таблиц.
                if canonicalId and canonicalId:find("^TrialoftheCrusaderTribute") then
                    canonicalId = nil
                end
                if canonicalId and not seen[canonicalId] then
                    seen[canonicalId] = true
                    list[#list + 1] = { id = canonicalId, name = FormatSourceName(tableId) }
                end
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        out[slotId] = list
    end
    if out[11] and not out[12] then out[12] = out[11] end
    if out[13] and not out[14] then out[14] = out[13] end
    BisEquip_SourceBySlot = out
    return out
end

-- Warm heavy source cache proactively to avoid first-open hitch in picker.
function BisEquip_WarmItemDataCaches()
    BuildSourceBySlotCache()
    BuildPvpSeasonSlotCache()
end

-- Extract instance prefix from tableId (for hierarchy grouping)
local function GetTablePrefix(tableId)
  if not tableId or tableId == "" then return nil end
  local s = tableId
  -- Strip difficulty/format suffixes
  s = s:gsub("25Man$", ""):gsub("HEROIC$", ""):gsub("_A$", ""):gsub("_H$", "")
  s = s:gsub("_x2$", ""):gsub("_x4$", ""):gsub("_%d+$", "")
  for _, prefix in ipairs(BisEquip_SourcePrefixList or {}) do
    if s:sub(1, #prefix) == prefix then
      return prefix
    end
  end
  return nil -- no known prefix, treat as standalone
end

-- Get hierarchical source tree for slot: { { cat = "Рейды WotLK", children = { { inst = "Наксрамас", sources = { {id, name}, ... } }, ... } }, ... }
-- Standalone sources (no prefix match) go to category "Прочее"
function BiSPlanner_GetSourceHierarchy(slotId)
    BisEquip_GetSourceHierarchy = BiSPlanner_GetSourceHierarchy -- Backward compatibility
  local flat = BisEquip_GetSourcesForSlot(slotId)
  if not flat or #flat == 0 then return {} end

  local byCat = {} -- cat -> { inst -> { {id, name}, ... } }
  local byCatSeen = {} -- cat -> inst -> id -> true
  local byCatOrder = {}
  local standalone = {}

  local function AddToCategory(cat, inst, id, name)
    cat = cat or "Прочее"
    inst = inst or "Прочее"
    if not byCat[cat] then
      byCat[cat] = {}
      byCatSeen[cat] = {}
      byCatOrder[#byCatOrder + 1] = cat
    end
    if not byCat[cat][inst] then
      byCat[cat][inst] = {}
      byCatSeen[cat][inst] = {}
    end
    if not byCatSeen[cat][inst][id] then
      byCatSeen[cat][inst][id] = true
      byCat[cat][inst][#byCat[cat][inst] + 1] = { id = id, name = name }
    end
  end

  local function GetDerivedCategory(id)
    local base = NormalizeForSourceFilter(id)
    if base:find("^emblemof") then
      local inst = "Эмблемы"
      if base:find("heroism") then inst = "Эмблема героизма"
      elseif base:find("valor") then inst = "Эмблема доблести"
      elseif base:find("conquest") then inst = "Эмблема завоевания"
      elseif base:find("triumph") then inst = "Эмблема триумфа"
      elseif base:find("frost") then inst = "Эмблема льда"
      elseif base:find("scorching") then inst = "Эмблема Испепеления"
      end
      return "Эмблемы/Значки", inst
    end
    if base:find("^pvp80") then
      local season = GetPvPSeasonForSource(id)
      return "PvP награды", season
    end
    if base:find("^t11") or base:find("^t0") then return nil, nil end
    if base:find("^hardmode") then
      return "Сеты", GetBCTierForSource(id)
    end
    if base:find("^t10") then return "Сеты", "Тир 10" end
    if base:find("^t9") or base:find("^maar'nt9") then return "Сеты", "Тир 9" end
    if base:find("^mounthyjal") then return "Рейды BC", "Битва за гору Хиджал" end
    if base:find("^cfrserpent") then return "Рейды BC", "Змеиное святилище" end
    if base:find("^sp") then return "Рейды BC", "Плато Солнечного Колодца" end
    if base:find("^pos") then return "Подземелья WotLK", "Яма Сарона" end
    if base:find("^fos") then return "Подземелья WotLK", "Кузня Душ" end
    if base:find("^hor") then return "Подземелья WotLK", "Залы Отражений" end
    if base:find("^kara") then return "Рейды BC", "Каражан" end
    if base:find("^hcfurnace") then return "Подземелья BC (героик)", "Кузня Крови (героик)" end
    if base:find("^hchalls") then return "Подземелья BC (героик)", "Разрушенные залы (героик)" end
    if base:find("^hcramp") then return "Подземелья BC (героик)", "Бастионы Адского Пламени (героик)" end
    if base:find("^cfrslave") then return "Подземелья BC (героик)", "Узилище (героик)" end
    if base:find("^cfrunder") then return "Подземелья BC (героик)", "Нижетопь (героик)" end
    if base:find("^cfrsteam") then return "Подземелья BC (героик)", "Паровое подземелье (героик)" end
    if base:find("^auchmana") then return "Подземелья BC (героик)", "Гробницы Маны (героик)" end
    if base:find("^auchcrypts") then return "Подземелья BC (героик)", "Аукенайские гробницы (героик)" end
    if base:find("^auchsethekk") then return "Подземелья BC (героик)", "Сетеккские залы (героик)" end
    if base:find("^auchshadow") then return "Подземелья BC (героик)", "Темный лабиринт (героик)" end
    if base:find("^tkbot") then return "Подземелья BC (героик)", "Ботаника (героик)" end
    if base:find("^tkarc") then return "Подземелья BC (героик)", "Аркатрац (героик)" end
    if base:find("^tkmech") then return "Подземелья BC (героик)", "Механар (героик)" end
    return nil, nil
  end

  for _, s in ipairs(flat) do
    local id, name = s.id, s.name
    local dCat, dInst = GetDerivedCategory(id)
    if dCat then
      AddToCategory(dCat, dInst, id, name)
    else
      local prefix = GetTablePrefix(id)
      if prefix and BisEquip_SourceCategories and BisEquip_SourceCategories[prefix] then
        local info = BisEquip_SourceCategories[prefix]
        local cat = info.cat
        local inst = info.inst or prefix
        AddToCategory(cat, inst, id, name)
      else
        if IsAllowedSourceTable(id) and (not ShouldHideSourceByIlvlPolicy(id)) then
          standalone[#standalone + 1] = { id = id, name = name }
        end
      end
    end
  end

  local SETS_INSTANCE_ORDER = {
    ["Т4"] = 1, ["Тир 4"] = 1,
    ["Т5"] = 2, ["Тир 5"] = 2,
    ["Т7"] = 3, ["Тир 7"] = 3,
    ["Т8"] = 4, ["Тир 8"] = 4,
    ["Т9"] = 5, ["Тир 9"] = 5, ["Тир 9 (героический)"] = 5,
    ["Т10"] = 6, ["Тир 10"] = 6,
  }
  local function getSetsSortKey(inst)
    return SETS_INSTANCE_ORDER[tostring(inst)] or 999
  end

  local result = {}
  for _, cat in ipairs(byCatOrder) do
    local insts = byCat[cat]
    local instList = {}
    for inst, sources in pairs(insts) do
      instList[#instList + 1] = { inst = inst, sources = sources }
    end
    if cat == "Сеты" then
      table.sort(instList, function(a, b)
        local ka, kb = getSetsSortKey(a.inst), getSetsSortKey(b.inst)
        if ka ~= kb then return ka < kb end
        return tostring(a.inst) < tostring(b.inst)
      end)
    else
      table.sort(instList, function(a, b) return a.inst < b.inst end)
    end
    result[#result + 1] = { cat = cat, children = instList }
  end
  -- Разное убрано: вещи добавляются только через целевые модули
  return result
end

-- Нормализовать tableId: убрать суффиксы сложности для сравнения
NormalizeTableId = function(tableId)
    if not tableId then return nil end
    -- Убираем суффиксы сложности/режима, чтобы не дублировать одного босса.
    local normalized = tableId
        :gsub("_[AH]$", "")
        :gsub("25ManHEROIC$", "")
        :gsub("25Man$", "")
        :gsub("HEROIC$", "")
        :gsub("_x2$", "")
        :gsub("_x4$", "")
        :gsub("_%d+$", "")
    return normalized
end

local function SplitTokens(s)
    if not s then return {} end
    local tokenized = s:gsub("(%l)(%u)", "%1 %2")
    tokenized = tokenized:gsub("[^%w]+", " ")
    tokenized = tokenized:lower()
    local out = {}
    for t in tokenized:gmatch("%w+") do
        out[#out + 1] = t
    end
    return out
end

IsLikelySourceMatch = function(srcId, filterId)
    if not srcId or not filterId then return false end
    if srcId == filterId then return true end
    local srcNorm = NormalizeTableId(srcId)
    local filterNorm = NormalizeTableId(filterId)
    if srcNorm and filterNorm and srcNorm == filterNorm then return true end
    local srcBase = tostring(srcNorm or srcId):gsub("_[AH]$", ""):lower()
    local filterBase = tostring(filterNorm or filterId):gsub("_[AH]$", ""):lower()
    return srcBase == filterBase
end

-- Build menu for slot from built-in BisEquip_LootMenu.
function BisEquip_GetBuiltInMenuForSlot(slotId)
    if not BisEquip_LootMenu or not BisEquip_LootMenu_SubTables then return {} end
    local flat = BisEquip_GetSourcesForSlot(slotId)
    local validIds = {}
    local normalizedToOriginal = {}
    if flat and #flat > 0 then
        for _, s in ipairs(flat) do
            validIds[s.id] = true
            local norm = NormalizeTableId(s.id)
            if norm then
                normalizedToOriginal[norm] = normalizedToOriginal[norm] or {}
                normalizedToOriginal[norm][#normalizedToOriginal[norm] + 1] = s.id
            end
        end
    end
    local flatIds = {}
    if flat and #flat > 0 then
        for _, s in ipairs(flat) do flatIds[#flatIds + 1] = s.id end
    end
    local function ResolveToExistingId(preferredId)
        if not preferredId then return nil end
        if validIds[preferredId] then return preferredId end
        local norm = NormalizeTableId(preferredId)
        if norm and normalizedToOriginal[norm] and normalizedToOriginal[norm][1] then
            return normalizedToOriginal[norm][1]
        end
        for _, candidate in ipairs(flatIds) do
            if IsLikelySourceMatch(candidate, preferredId) then return candidate end
        end
        return preferredId
    end

    local result = {}
    for _, cat in ipairs(BisEquip_LootMenu) do
        local children = {}
        for _, entry in ipairs(cat.entries) do
            if entry.tableId then
                children[#children + 1] = { name = entry.name, tableId = ResolveToExistingId(entry.tableId) }
            elseif entry.submenuId and BisEquip_LootMenu_SubTables[entry.submenuId] then
                local bosses = {}
                for _, b in ipairs(BisEquip_LootMenu_SubTables[entry.submenuId]) do
                    if b.tableId then
                        local norm = NormalizeTableId(b.tableId)
                        if norm and normalizedToOriginal[norm] then
                            for _, origId in ipairs(normalizedToOriginal[norm]) do
                                bosses[#bosses + 1] = { name = b.name, tableId = origId }
                            end
                        else
                            bosses[#bosses + 1] = { name = b.name, tableId = ResolveToExistingId(b.tableId) }
                        end
                    end
                end
                children[#children + 1] = { name = entry.name, submenuId = entry.submenuId, bosses = bosses }
            end
        end
        if #children > 0 then
            result[#result + 1] = { catName = cat.catName, children = children }
        end
    end
    return result
end

-- Get unique loot sources (tableIds) that have items for this slot
function BiSPlanner_GetSourcesForSlot(slotId)
    BisEquip_GetSourcesForSlot = BiSPlanner_GetSourcesForSlot -- Backward compatibility
    local itemDB = BiSPlanner_ItemDB or BisEquip_ItemDB
    local list = nil
    if slotId == 17 or slotId == 18 then
        local seen = {}
        local dynamic = {}
        for _, querySlot in ipairs(ResolveSlotQueryList(slotId)) do
            for _, row in ipairs((itemDB and itemDB[querySlot]) or {}) do
                local itemId = type(row) == "table" and row[1] or row
                local tableId = type(row) == "table" and row[2] or nil
                if itemId and tableId and IsAllowedSourceTable(tableId) and (not ShouldHideByIlvlPolicy(itemId, tableId)) and IsItemAllowedForSlot(slotId, itemId) then
                    local canonicalId = NormalizeTableId(tableId) or tableId
                    if canonicalId and not seen[canonicalId] then
                        seen[canonicalId] = true
                        dynamic[#dynamic + 1] = { id = canonicalId, name = FormatSourceName(tableId) }
                    end
                end
            end
        end
        list = dynamic
    else
        local cached = BuildSourceBySlotCache()
        list = cached and cached[ResolveSlotQuery(slotId)]
    end
    if not list then return {} end
    local result = {}
    local rawIds = {}
    for _, src in ipairs(list) do
        rawIds[src.id] = true
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    for _, src in ipairs(list) do
        local tableId = src.id
        local use = true
        if faction == "Horde" and tableId:find("_A$") and rawIds[tableId:gsub("_A$", "_H")] then
            use = false
        elseif faction == "Alliance" and tableId:find("_H$") and rawIds[tableId:gsub("_H$", "_A")] then
            use = false
        end
        if use then
            result[#result + 1] = { id = tableId, name = src.name }
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

-- Get list of item IDs for a slot, optionally filtered by difficulty/source
-- difficultyFilter: nil or "10N"|"25N"|"10H"|"25H"
-- sourceFilter: nil or tableId string (partial match)
function BiSPlanner_GetItemsForSlot(slotId, difficultyFilter, sourceFilter)
    BisEquip_GetItemsForSlot = BiSPlanner_GetItemsForSlot -- Backward compatibility
    local itemDB = BiSPlanner_ItemDB or BisEquip_ItemDB
    local result = {}
    local seen = {}
    for _, querySlot in ipairs(ResolveSlotQueryList(slotId)) do
        local list = itemDB and itemDB[querySlot]
        if list then
            for _, row in ipairs(list) do
                local itemId = type(row) == "table" and row[1] or row
                if not seen[itemId] then
                    seen[itemId] = true
                    local ok = true
                    local rowSource = type(row) == "table" and row[2] or nil
                    if rowSource and not IsAllowedSourceTable(rowSource) then
                        ok = false
                    end
                    if ok and rowSource and ShouldHideByIlvlPolicy(itemId, rowSource) then
                        ok = false
                    end
                    if difficultyFilter then
                        local diff = type(row) == "table" and row[3] or (BisEquip_ItemSources and BisEquip_ItemSources[itemId] and BisEquip_ItemSources[itemId].difficulty)
                        if not diff then
                            -- Если diff нет в row[3], пытаемся определить из tableId
                            local tableId = type(row) == "table" and row[2] or nil
                            if tableId then
                                -- Проверяем суффиксы в правильном порядке: сначала полный "25ManHEROIC", потом отдельные
                                if string.find(tableId, "25ManHEROIC") or string.find(tableId, "25Man.*HEROIC") then
                                    diff = "25H"
                                elseif string.find(tableId, "HEROIC") then
                                    -- Если есть HEROIC но нет 25Man, это может быть 10H или 25H
                                    -- Проверяем контекст: если в tableId есть что-то указывающее на 25, то 25H, иначе 10H
                                    if string.find(tableId, "25") then
                                        diff = "25H"
                                    else
                                        diff = "10H"
                                    end
                                elseif string.find(tableId, "25Man") then
                                    diff = "25N"
                                else
                                    -- Если нет суффиксов, предполагаем 10N (обычная сложность)
                                    diff = "10N"
                                end
                            end
                        end
                        -- Сравниваем нормализованные значения сложности
                        if diff ~= difficultyFilter then
                            ok = false
                        end
                    end
                    if ok and sourceFilter and sourceFilter ~= "" then
                        -- Фильтрация с учетом отличий tableId между AtlasLoot-модулями.
                        local src = type(row) == "table" and row[2] or (BisEquip_ItemSources and BisEquip_ItemSources[itemId] and BisEquip_ItemSources[itemId].source)
                        ok = src and IsLikelySourceMatch(src, sourceFilter) or false
                        -- В AtlasLoot часть накс-тринкетов лежит в общих TrinketChests* таблицах.
                        -- Разрешаем их при фильтре Наксрамаса, чтобы не пропадали ключевые тринкеты.
                        if not ok and src and sourceFilter and tostring(sourceFilter):find("^Naxx80") then
                            if tostring(src):find("^TrinketChests") then
                                local naxxTrinkets = {
                                    [40255] = true, -- Исчезающее проклятие
                                    [40256] = true, -- Мрачный перезвон
                                    [40371] = true,
                                    [40372] = true,
                                    [40373] = true,
                                    [40382] = true,
                                }
                                if naxxTrinkets[itemId] then
                                    ok = true
                                end
                            end
                        end
                    end
                    if ok and not IsItemAllowedForSlot(slotId, itemId) then
                        ok = false
                    end
                    if ok then result[#result + 1] = itemId end
                end
            end
        end
    end
    return result
end

-- Scan tooltip for stats (fallback when GetItemInfo returns nil or GetItemStats fails)
-- Use our own tooltip; LibItemSearchTooltipScanner returns NumLines()=0 when we SetHyperlink.
local ScanTooltip = CreateFrame("GameTooltip", "BisEquipScanTooltip", UIParent, "GameTooltipTemplate")
ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
ScanTooltip:Hide()
local ScanTooltipName = ScanTooltip:GetName() or "BisEquipScanTooltip"

-- Some clients/templates may miss initial font strings for custom scanner tooltips.
local function EnsureScanTooltipFontStrings()
    if _G[ScanTooltipName .. "TextLeft1"] then return end
    local left = ScanTooltip:CreateFontString(ScanTooltipName .. "TextLeft1", nil, "GameTooltipText")
    local right = ScanTooltip:CreateFontString(ScanTooltipName .. "TextRight1", nil, "GameTooltipText")
    ScanTooltip:AddFontStrings(left, right)
end
EnsureScanTooltipFontStrings()

-- Armor cache: itemId -> armor value (populated by deferred scan when sync fails)
local ARMOR_CACHE = {}
local PENDING_ARMOR_SCAN = {}
local ARMOR_UPDATE_FRAME = nil
local ARMOR_DEBUG_ENABLED = false
local ARMOR_DEBUG_ITEMID = nil -- set itemId for focused logs (e.g. via BiSPlanner_DebugArmorForItem)

local function ArmorDebug(itemId, msg)
    if not ARMOR_DEBUG_ENABLED then return end
    if ARMOR_DEBUG_ITEMID and tonumber(itemId) ~= ARMOR_DEBUG_ITEMID then return end
    local out = "|cff33ff99BiSPlanner ArmorDebug|r [" .. tostring(itemId or "?") .. "] " .. tostring(msg or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(out)
    elseif ChatFrame1 and ChatFrame1.AddMessage then
        ChatFrame1:AddMessage(out)
    end
end

-- Strip color codes for tooltip parsing (WoW uses |cAARRGGBB and |r)
local function StripTooltipColors(s)
    if not s or s == "" then return "" end
    return s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function NormalizeTooltipText(s)
    if not s or s == "" then return "" end
    s = StripTooltipColors(s)
    s = s:gsub("|T.-|t", "") -- embedded textures/icons
    s = s:gsub("\194\160", " ") -- NBSP
    s = s:gsub("\226\128\175", " ") -- narrow NBSP
    return s
end

local ARMOR_LABEL_RU = "броня"
local ARMOR_LABEL_EN = "armor"
local ARMOR_GLOBAL_LABEL = _G["ARMOR"] and tostring(_G["ARMOR"]):lower() or ARMOR_LABEL_RU

local function LooksLikeArmorLine(text)
    local s = tostring(text or ""):lower()
    return s:find(ARMOR_LABEL_RU, 1, true) or s:find(ARMOR_LABEL_EN, 1, true) or s:find(ARMOR_GLOBAL_LABEL, 1, true)
end

-- Пропускать строки из описания прока/эффекта (напр. "повышает броню на 657 на 15 сек") — не должны попадать в сравнение статов
local ARMOR_PROC_SKIP_PATTERNS = {
    -- RU
    "при получении урона", "при активации", "при нанесении", "при применении",
    "повышает ваш показатель брони", "который повышает", "вероятностью",
    "суммируясь", "на 15 сек", "на 10 раз", "на 20 раз",
    -- EN
    "upon taking damage", "upon dealing", "increases your armor by", "stacking",
    "for 15 sec", "chance to", "when you",
}
local function IsArmorProcEffectLine(text)
    if not text or #text < 40 then return false end
    local s = tostring(text):lower()
    for _, pat in ipairs(ARMOR_PROC_SKIP_PATTERNS) do
        if s:find(pat, 1, true) then return true end
    end
    return false
end

local function ExtractFirstNumber(text)
    if not text or text == "" then return nil end
    local token = text:match("(%d[%d%s\194\160\226\128\175]*)")
    if not token then return nil end
    local digits = token:gsub("%D", "")
    if digits == "" then return nil end
    local n = tonumber(digits)
    if n and n > 0 then return n end
    return nil
end

local function DumpTooltipSample(tooltip, itemId, stage)
    if not ARMOR_DEBUG_ENABLED or not tooltip then return end
    local numLines = (tooltip.NumLines and tooltip:NumLines()) or 0
    local name = tooltip:GetName() or ScanTooltipName or "?"
    ArmorDebug(itemId, tostring(stage) .. " tooltip=" .. tostring(name) .. " lines=" .. tostring(numLines))
    local maxLines = math.min(math.max(numLines, 12), 20)
    for i = 1, maxLines do
        local left = _G[name .. "TextLeft" .. i] or _G[ScanTooltipName .. "TextLeft" .. i] or _G["GameTooltipTextLeft" .. i]
        local right = _G[name .. "TextRight" .. i] or _G[ScanTooltipName .. "TextRight" .. i] or _G["GameTooltipTextRight" .. i]
        local ltext = NormalizeTooltipText(left and left:GetText() or "")
        local rtext = NormalizeTooltipText(right and right:GetText() or "")
        if ltext ~= "" or rtext ~= "" then
            ArmorDebug(itemId, string.format("%s line %d: L='%s' R='%s'", tostring(stage), i, ltext, rtext))
        end
    end
end

-- Parse armor from tooltip (RU: "Броня" + value, EN: "Armor" + value)
-- Accepts tooltip frame or nil to use GameTooltip
local function ParseArmorFromTooltip(tooltip, itemId, stage)
    tooltip = tooltip or GameTooltip
    if not tooltip then return nil end
    local name = tooltip:GetName() or ScanTooltipName or "GameTooltip"
    local numLines = (tooltip.NumLines and tooltip:NumLines()) or 0
    local maxLines = math.max(numLines, 40)
    for i = 1, maxLines do
        local left = _G[name .. "TextLeft" .. i] or _G[ScanTooltipName .. "TextLeft" .. i] or _G["GameTooltipTextLeft" .. i]
        local right = _G[name .. "TextRight" .. i] or _G[ScanTooltipName .. "TextRight" .. i] or _G["GameTooltipTextRight" .. i]
        local ltext = NormalizeTooltipText(left and left:GetText() or "")
        local rtext = NormalizeTooltipText(right and right:GetText() or "")
        if ltext ~= "" and (LooksLikeArmorLine(ltext) or LooksLikeArmorLine(ltext .. " " .. rtext)) then
            if IsArmorProcEffectLine(ltext) or IsArmorProcEffectLine(rtext) or IsArmorProcEffectLine(ltext .. " " .. rtext) then
                -- skip proc/effect lines (e.g. trinket "increases armor by 657 for 15 sec")
            else
                local armor = ExtractFirstNumber(ltext) or ExtractFirstNumber(rtext) or ExtractFirstNumber(ltext .. " " .. rtext)
                ArmorDebug(itemId, string.format("%s match line %d: L='%s' R='%s' => %s", tostring(stage or "scan"), i, ltext, rtext, tostring(armor)))
                return armor
            end
        end
    end

    -- Region fallback: handles clients where named TextLeftN globals are unreliable.
    local regions = { tooltip:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local text = NormalizeTooltipText(region:GetText() or "")
            if text ~= "" and LooksLikeArmorLine(text) and not IsArmorProcEffectLine(text) then
                local n = ExtractFirstNumber(text)
                ArmorDebug(itemId, string.format("%s region match: '%s' => %s", tostring(stage or "scan"), text, tostring(n)))
                if n then return n end
            end
        end
    end
    ArmorDebug(itemId, tostring(stage or "scan") .. " no armor parsed")
    return nil
end

-- Sync scan: SetHyperlink (LibItemSearch style, no Show) + Show/Hide retries
local function ScanTooltipForArmorSync(itemId)
    local link = "item:" .. itemId .. ":0:0:0:0:0:0:0"
    ArmorDebug(itemId, "ScanTooltipForArmorSync start link=" .. link)
    -- Try 1: SetHyperlink only (like LibItemSearch - no Show)
    ScanTooltip:ClearLines()
    ScanTooltip:SetHyperlink(link)
    DumpTooltipSample(ScanTooltip, itemId, "try1")
    local armor = ParseArmorFromTooltip(ScanTooltip, itemId, "try1")
    if armor then return armor end
    -- Try 2-4: Show, parse while visible, then Hide (parsing after Hide may read empty)
    for attempt = 2, 4 do
        ScanTooltip:ClearLines()
        ScanTooltip:SetHyperlink(link)
        ScanTooltip:Show()
        if attempt == 2 then
            DumpTooltipSample(ScanTooltip, itemId, "try2")
        end
        armor = ParseArmorFromTooltip(ScanTooltip, itemId, "try" .. tostring(attempt))
        ScanTooltip:Hide()
        if armor then return armor end
    end
    ArmorDebug(itemId, "ScanTooltipForArmorSync failed")
    return nil
end

-- Scan armor using GameTooltip (populates reliably when shown); backup/restore to avoid disrupting user.
local function ScanArmorWithGameTooltip(itemId)
    local link = "item:" .. itemId .. ":0:0:0:0:0:0:0"
    local prevOwner = GameTooltip:GetOwner()
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
    local armor = ParseArmorFromTooltip(GameTooltip, itemId, "GameTooltip")
    GameTooltip:Hide()
    if prevOwner then
        GameTooltip:SetOwner(prevOwner, "ANCHOR_NONE")
    end
    return armor
end

-- Items we've already tried (and failed) - avoid infinite retry loop
local ARMOR_SCAN_FAILED = {}

function BiSPlanner_ClearArmorScanFailed()
    ARMOR_SCAN_FAILED = {}
end
BisEquip_ClearArmorScanFailed = BiSPlanner_ClearArmorScanFailed

-- Deferred scan: use GameTooltip (populates reliably); runs next frame to avoid blocking.
local function DoDeferredArmorScan()
    if next(PENDING_ARMOR_SCAN) == nil then return end
    local toScan = {}
    for itemId, _ in pairs(PENDING_ARMOR_SCAN) do
        toScan[#toScan + 1] = itemId
    end
    PENDING_ARMOR_SCAN = {}
    local cachedCount = 0
    for _, itemId in ipairs(toScan) do
        local armor = ScanArmorWithGameTooltip(itemId) or ScanTooltipForArmorSync(itemId)
        if armor and armor > 0 then
            ARMOR_CACHE[itemId] = armor
            cachedCount = cachedCount + 1
        else
            ARMOR_SCAN_FAILED[itemId] = true
        end
    end
    if cachedCount > 0 then
        if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats()
        elseif BisEquip_RefreshStats then BisEquip_RefreshStats() end
    end
end

local function ScheduleDeferredArmorScan(itemId)
    if ARMOR_SCAN_FAILED[itemId] then return end
    if PENDING_ARMOR_SCAN[itemId] then return end
    PENDING_ARMOR_SCAN[itemId] = true
    if not ARMOR_UPDATE_FRAME then
        ARMOR_UPDATE_FRAME = CreateFrame("Frame")
    end
    ARMOR_UPDATE_FRAME:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        DoDeferredArmorScan()
    end)
end

-- GetItemStats in 3.3.5 uses keys from GlobalStrings (e.g. ITEM_MOD_STRENGTH_SHORT).
-- Returns table of stat key -> value (number). Uses tooltip scan if item not in cache.
function BiSPlanner_GetItemStats(itemId)
    BisEquip_GetItemStats = BiSPlanner_GetItemStats -- Backward compatibility
    local function hasPositiveArmor(t)
        return ((t["ITEM_MOD_ARMOR_SHORT"] or 0) > 0) or ((t["ARMOR"] or 0) > 0)
    end
    local function addArmorIfNeeded(t)
        if hasPositiveArmor(t) then return end
        ArmorDebug(itemId, "GetItemStats missing armor keys; ITEM_MOD_ARMOR_SHORT=" .. tostring(t["ITEM_MOD_ARMOR_SHORT"]) .. ", ARMOR=" .. tostring(t["ARMOR"]))
        local armor = ARMOR_CACHE[itemId] or ScanArmorWithGameTooltip(itemId) or ScanTooltipForArmorSync(itemId)
        if armor and armor > 0 then
            t["ARMOR"] = armor
            ArmorDebug(itemId, "Armor assigned from scanner: " .. tostring(armor))
        elseif not ARMOR_CACHE[itemId] then
            ArmorDebug(itemId, "Armor not found, scheduling deferred scan")
            ScheduleDeferredArmorScan(itemId)
        end
    end
    local link = select(2, GetItemInfo(itemId))
    if link and GetItemStats then
        local t = {}
        GetItemStats(link, t)
        if next(t) then
            addArmorIfNeeded(t)
            return t
        end
    end
    -- Fallback: force tooltip so client may cache item; then retry GetItemInfo once
    ScanTooltip:ClearLines()
    ScanTooltip:SetHyperlink("item:" .. itemId .. ":0:0:0:0:0:0:0")
    ScanTooltip:Show()
    ScanTooltip:Hide()
    link = select(2, GetItemInfo(itemId))
    if link and GetItemStats then
        local t = {}
        GetItemStats(link, t)
        if next(t) then
            addArmorIfNeeded(t)
            return t
        end
    end
    -- Last resort: parse armor from tooltip only
    local armor = ARMOR_CACHE[itemId] or ScanArmorWithGameTooltip(itemId) or ScanTooltipForArmorSync(itemId)
    if armor and armor > 0 then
        ArmorDebug(itemId, "Last resort armor-only return: " .. tostring(armor))
        return { ["ARMOR"] = armor }
    end
    ArmorDebug(itemId, "Last resort failed; returning empty stats")
    ScheduleDeferredArmorScan(itemId)
    return {}
end

-- Manual one-shot armor debug for a specific item (used from slot hover).
-- When source=slot:N: GameTooltip is ALREADY showing the item - parse it directly.
-- Otherwise use ScanArmorWithGameTooltip.
function BiSPlanner_DebugArmorForItem(itemId, sourceTag)
    if not itemId then return nil end
    local id = tonumber(itemId)
    if not id then return nil end
    local prevEnabled = ARMOR_DEBUG_ENABLED
    local prevFilter = ARMOR_DEBUG_ITEMID
    ARMOR_DEBUG_ENABLED = true
    ARMOR_DEBUG_ITEMID = id
    ArmorDebug(id, "manual debug start source=" .. tostring(sourceTag or "manual"))
    local link = select(2, GetItemInfo(id))
    local t = {}
    if link and GetItemStats then
        GetItemStats(link, t)
    end
    ArmorDebug(id, "manual getItemStats ITEM_MOD_ARMOR_SHORT=" .. tostring(t["ITEM_MOD_ARMOR_SHORT"]) .. ", ARMOR=" .. tostring(t["ARMOR"]))
    local armor
    if sourceTag and sourceTag:match("^slot:") and GameTooltip:IsShown() then
        local numLines = (GameTooltip.NumLines and GameTooltip:NumLines()) or 0
        armor = ParseArmorFromTooltip(GameTooltip, id, "hover")
        if not armor and numLines == 0 then
            local f = CreateFrame("Frame")
            f:SetScript("OnUpdate", function(self)
                self:SetScript("OnUpdate", nil)
                ARMOR_DEBUG_ITEMID = id
                ARMOR_DEBUG_ENABLED = true
                numLines = (GameTooltip.NumLines and GameTooltip:NumLines()) or 0
                armor = ParseArmorFromTooltip(GameTooltip, id, "hover-deferred")
                ARMOR_DEBUG_ITEMID = prevFilter
                ARMOR_DEBUG_ENABLED = prevEnabled
            end)
            ARMOR_DEBUG_ITEMID = prevFilter
            ARMOR_DEBUG_ENABLED = prevEnabled
            return nil
        end
    else
        armor = ScanArmorWithGameTooltip(id)
    end
    ArmorDebug(id, "result=" .. tostring(armor))
    ARMOR_DEBUG_ITEMID = prevFilter
    ARMOR_DEBUG_ENABLED = prevEnabled
    return armor
end
BisEquip_DebugArmorForItem = BiSPlanner_DebugArmorForItem

