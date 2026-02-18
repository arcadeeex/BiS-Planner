--[[ Static module registry for BiSPlanner module data layer. ]]

BiSPlanner_ModuleRegistry = {
    enabled = true,
    fallbackToLegacy = false,
    modules = {
        { id = "PVP", file = "Data\\Modules\\PVP.lua", enabled = true, priority = 10 },
        { id = "WotLKDungeons", file = "Data\\Modules\\WotLKDungeons.lua", enabled = true, priority = 20 },
        { id = "BCDungeonsHeroic", file = "Data\\Modules\\BCDungeonsHeroic.lua", enabled = true, priority = 30 },
        { id = "WotLKRaid", file = "Data\\Modules\\WotLKRaid.lua", enabled = true, priority = 40 },
        { id = "BCRaid", file = "Data\\Modules\\BCRaid.lua", enabled = true, priority = 50 },
        { id = "Reputations", file = "Data\\Modules\\Reputations.lua", enabled = true, priority = 60 },
        { id = "WorldEvents", file = "Data\\Modules\\WorldEvents.lua", enabled = true, priority = 70 },
        { id = "WorldBosses", file = "Data\\Modules\\WorldBosses.lua", enabled = true, priority = 80 },
        { id = "Crafting", file = "Data\\Modules\\Crafting.lua", enabled = true, priority = 90 },
        { id = "Dailies", file = "Data\\Modules\\Dailies.lua", enabled = true, priority = 100 },
        { id = "Sets", file = "Data\\Modules\\Sets.lua", enabled = true, priority = 110 },
        { id = "Emblems", file = "Data\\Modules\\Emblems.lua", enabled = true, priority = 120 },
        { id = "Legendary", file = "Data\\Modules\\Legendary.lua", enabled = true, priority = 130 },
    },
}
-- Backward compatibility
BisEquip_ModuleRegistry = BiSPlanner_ModuleRegistry

