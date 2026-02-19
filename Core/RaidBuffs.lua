--[[
BiSPlanner - Raid buffs for WoW 3.3.5a (WotLK).
Applies full raid buffs to stats when "С рейд баффами" is enabled.
]]

-- WotLK 3.3.5 level 80: rating per 1%
local RATING_HIT_MELEE = 32.79
local RATING_HIT_SPELL = 26.23
local RATING_CRIT = 45.91
local RATING_HASTE = 32.79

-- Melee/ranged physical classes
local MELEE_CLASSES = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true }
local RANGED_PHYS_CLASSES = { HUNTER = true }
local function IsPhysicalDPS(classId)
    return MELEE_CLASSES[classId] or RANGED_PHYS_CLASSES[classId]
end

-- Caster classes
local CASTER_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true }
local function IsCaster(classId)
    return CASTER_CLASSES[classId]
end

-- Hybrid: can be melee or caster depending on spec
local HYBRID_CLASSES = { DRUID = true, SHAMAN = true, PALADIN = true }

-- Raid buff values (full raid, best available)
local RAID_BUFFS = {
    -- Flat primary stats (Horn of Winter / Strength of Earth + Enhancing Totems)
    flatStr = 178,
    flatAgi = 178,
    flatSta = 214,   -- PW:F with Improved
    flatInt = 60,    -- Arcane Intellect / Fel Intelligence
    flatSpirit = 80, -- Divine Spirit / Fel Intelligence
    -- Mark of the Wild (Improved): +35% to base, so +16 to stats, +370 armor, +26 resist
    flatMotWStats = 16,
    flatMotWArmor = 370,
    -- Blessing of Kings: +10% to all primary stats
    kingsMult = 1.10,
    -- Physical crit: Leader of the Pack / Rampage
    physCritPct = 5,
    -- Spell crit: Moonkin Aura / Elemental Oath (5%). Improved Faerie Fire +3% — только друиду, не рейду
    spellCritPct = 5,
    -- Melee haste: Windfury Totem / Improved Icy Talons (категория "Melee Haste Buff")
    meleeHasteMajorPct = 20,
    -- Haste (all types): Swift Retribution / Improved Moonkin Aura (категория "Percentage Haste Increase (All Types)")
    hasteAllTypesPct = 3,
    -- Spell haste: Wrath of Air Totem (категория "Spell Haste Buff")
    spellHastePct = 5,
    -- Physical hit: нет рейд-баффа в WotLK (Improved Faerie Fire даёт только spell hit)
    -- Spell hit: Misery / Improved Faerie Fire (оба +3%)
    spellHitPct = 3,
    -- AP: Trueshot Aura / Unleashed Rage / Abomination's Might
    apMult = 1.10,
    -- Spell power: Totem of Wrath
    flatSpellPower = 280,
}

local function ApplyRaidBuffsToTotal(total, classId)
    local out = {}
    for k, v in pairs(total) do
        out[k] = v
    end

    -- 1. Flat primary stats
    out["ITEM_MOD_STRENGTH_SHORT"] = (out["ITEM_MOD_STRENGTH_SHORT"] or 0) + RAID_BUFFS.flatStr + RAID_BUFFS.flatMotWStats
    out["ITEM_MOD_AGILITY_SHORT"] = (out["ITEM_MOD_AGILITY_SHORT"] or 0) + RAID_BUFFS.flatAgi + RAID_BUFFS.flatMotWStats
    out["ITEM_MOD_STAMINA_SHORT"] = (out["ITEM_MOD_STAMINA_SHORT"] or 0) + RAID_BUFFS.flatSta + RAID_BUFFS.flatMotWStats
    out["ITEM_MOD_INTELLECT_SHORT"] = (out["ITEM_MOD_INTELLECT_SHORT"] or 0) + RAID_BUFFS.flatInt + RAID_BUFFS.flatMotWStats
    out["ITEM_MOD_SPIRIT_SHORT"] = (out["ITEM_MOD_SPIRIT_SHORT"] or 0) + RAID_BUFFS.flatSpirit + RAID_BUFFS.flatMotWStats

    -- 2. MotW armor
    out["ITEM_MOD_ARMOR_SHORT"] = (out["ITEM_MOD_ARMOR_SHORT"] or 0) + RAID_BUFFS.flatMotWArmor

    -- 3. Blessing of Kings: +10% to primary stats
    for _, key in ipairs({ "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
        "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT" }) do
        if out[key] then
            out[key] = math.floor(out[key] * RAID_BUFFS.kingsMult + 0.5)
        end
    end

    -- 4. Spell power flat
    out["ITEM_MOD_SPELL_POWER_SHORT"] = (out["ITEM_MOD_SPELL_POWER_SHORT"] or 0) + RAID_BUFFS.flatSpellPower

    -- 5. Percentage buffs (do NOT add fake rating; rating shown should stay gear-only).
    -- Store these so Stats.lua can compute effective % / speeds.
    local isPhys = IsPhysicalDPS(classId)
    local isCaster = IsCaster(classId)
    -- Hybrids get both physical and spell buffs (e.g. enh shaman, ret paladin)
    local applyPhys = isPhys or HYBRID_CLASSES[classId]
    local applySpell = isCaster or HYBRID_CLASSES[classId]

    out.__bisplannerRaidBuffs = out.__bisplannerRaidBuffs or {}
    local b = out.__bisplannerRaidBuffs
    b.applyPhys = not not applyPhys
    b.applySpell = not not applySpell
    b.physCritPct = RAID_BUFFS.physCritPct
    b.spellCritPct = RAID_BUFFS.spellCritPct
    b.spellHitPct = RAID_BUFFS.spellHitPct
    b.meleeHasteMajorPct = RAID_BUFFS.meleeHasteMajorPct
    b.hasteAllTypesPct = RAID_BUFFS.hasteAllTypesPct
    b.spellHastePct = RAID_BUFFS.spellHastePct

    -- 6. AP multiplier (Trueshot Aura / Unleashed Rage / Abomination's Might)
    if applyPhys then
        local ap = out["ITEM_MOD_ATTACK_POWER_SHORT"] or 0
        local rangedAp = out["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] or 0
        out["ITEM_MOD_ATTACK_POWER_SHORT"] = math.floor(ap * RAID_BUFFS.apMult + 0.5)
        out["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] = math.floor(rangedAp * RAID_BUFFS.apMult + 0.5)
    end

    -- AP from Str/Agi is handled in GetDerivedAttackPower - we already modified Str/Agi with BoK
    -- So the derived AP will include the buffed stats. But the flat AP from items needs the 10% mult.
    -- We applied it above. For derived AP (Str*2 etc), that comes from the modified total in BuildStatsSections.
    -- GetDerivedAttackPower uses total - so our modified total with BoK-applied Str/Agi will give correct derived AP.
    -- The +10% AP buff applies to TOTAL AP (base + derived). So we need to multiply the final AP, not just flat.
    -- BuildStatsSections calls GetDerivedAttackPower(classId, total) which sums: baseAP + str*mult + agi*mult.
    -- The baseAP is ITEM_MOD_ATTACK_POWER_SHORT. So if we multiply that by 1.1, we're only buffing the flat part.
    -- The full formula should be: totalAP = (baseAP + derived) * 1.1. So we need to either:
    -- A) Multiply total AP in BuildStatsSections when raid buffs on - but that would require changing Stats.lua
    -- B) Store a "apMult" and apply in BuildStatsSections
    -- C) Add fake rating to simulate: if base+derived = X, we want 1.1*X. So we need to add 0.1*X to AP.
    --    But X depends on Str/Agi which we already modified. So: finalAP = baseAP*1.1 + derived*1.1 = (baseAP+derived)*1.1.
    --    We can add 0.1*(baseAP+derived) to baseAP... but we don't know derived yet at ApplyRaidBuffs time.
    -- The simplest: in Stats.lua, when we have raid buffs, after GetDerivedAttackPower we multiply by 1.1.
    -- So we need to pass a flag to BuildStatsSections or handle AP mult in Stats.lua after getting total.
    -- Actually: we could add 10% of current flat AP to simulate. The derived part comes from Str/Agi which get BoK.
    -- So derived AP is already 10% higher. The flat AP we multiply by 1.1. So we're close - we're doing
    -- flatAP*1.1 + derivedAP. But the buff is (flatAP+derivedAP)*1.1 = flatAP*1.1 + derivedAP*1.1.
    -- So we're missing derivedAP*0.1. The derived part got BoK on Str/Agi, so str and agi are 1.1x. So
    -- derived = 1.1 * base_derived. So total = flat*1.1 + 1.1*base_derived = 1.1*(flat + base_derived). Good!
    -- Wait no. BoK multiplies Str by 1.1. So derived = str*2 = (base_str*1.1)*2 = 1.1 * base_derived. So we have
    -- total_ap = flat_ap*1.1 + 1.1*base_derived = 1.1*(flat_ap + base_derived). So we're correct!
    -- The Trueshot/Unleashed Rage gives +10% to total AP. So we need (flat + derived) * 1.1.
    -- We have flat*1.1 and derived from 1.1*str. So flat*1.1 + 1.1*base_derived = 1.1*(flat+base_derived). Yes!
    -- So we're good. The flat AP we multiply. The derived comes from Str/Agi which we already multiplied by BoK.
    -- So total = flat*1.1 + derived(str*1.1, agi*1.1) = flat*1.1 + 1.1*base_derived = 1.1 * total_base. Correct.

    return out
end

function BiSPlanner_ApplyRaidBuffs(total, classId)
    BisEquip_ApplyRaidBuffs = BiSPlanner_ApplyRaidBuffs -- Backward compatibility
    if not total or not next(total) then return total end
    return ApplyRaidBuffsToTotal(total, classId)
end
