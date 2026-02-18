--[[
BisEquip - Static item IDs by equip slot (fallback when AtlasLoot not used)
Format: BisEquip_ItemDB[slotId] = { itemId1, itemId2, ... }
]]
if not BisEquip_ItemDB then
    BisEquip_ItemDB = {}
end
for _, slotId in ipairs({ 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }) do
    if not BisEquip_ItemDB[slotId] then
        BisEquip_ItemDB[slotId] = {}
    end
end
