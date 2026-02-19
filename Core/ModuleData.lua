--[[ Module-based data API. Single source of truth: Data/Modules/*.lua ]]
-- Modules load first and populate BisEquip_ModuleData; we must preserve it after rename to BiSPlanner
BiSPlanner_ModuleData = BiSPlanner_ModuleData or BisEquip_ModuleData or {}
BisEquip_ModuleData = BiSPlanner_ModuleData -- Backward compatibility
BiSPlanner_ItemDB = BiSPlanner_ItemDB or {}
BisEquip_ItemDB = BiSPlanner_ItemDB -- Backward compatibility
BiSPlanner_ItemSources = BiSPlanner_ItemSources or {}
BisEquip_ItemSources = BiSPlanner_ItemSources -- Backward compatibility

local MODULE_CACHE = nil

local function IsModuleLayerEnabled()
    return (BiSPlanner_ModuleRegistry and BiSPlanner_ModuleRegistry.enabled) or (BisEquip_ModuleRegistry and BisEquip_ModuleRegistry.enabled)
end

local function SortedKeys(map)
    local out = {}
    for k, _ in pairs(map or {}) do
        out[#out + 1] = k
    end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

local function FlattenSet(map)
    local out = {}
    for id, _ in pairs(map or {}) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

local function MergeSet(dst, src)
    for k, _ in pairs(src or {}) do
        dst[k] = true
    end
end

-- Собирает множество id сложностей из payload.sections (difficulties могут быть в любой секции)
local function CollectValidDifficultyIds(payload)
    local set = {}
    local function walk(sections)
        for _, sec in ipairs(sections or {}) do
            if sec.difficulties then
                for _, d in ipairs(sec.difficulties) do
                    local id = tostring((d and d.id) or ""):lower()
                    if id ~= "" then set[id] = true end
                end
            end
            walk(sec.children or {})
        end
    end
    walk(payload.sections or {})
    return set
end

-- Суффикс сложности из localId (если id заканчивается на _<diff>, где diff из validSet)
local function ParseDifficultyIdFromLocalId(localId, validDiffIds)
    local s = tostring(localId or "")
    local base, suffix = s:match("^(.+)_([^_]+)$")
    if base and suffix then
        local sid = suffix:lower()
        if validDiffIds and validDiffIds[sid] then
            return sid
        end
        -- Обратная совместимость: ob/hm без validDiffIds
        if (not validDiffIds or next(validDiffIds) == nil) and (sid == "ob" or sid == "hm") then
            return sid
        end
    end
    return nil
end

-- Выделяет базовый id и суффикс сложности из ключа itemsBySection.
-- Суффикс признаётся только если он есть в validDiffIds (из difficulties секций).
local function ParseSectionIdWithDifficulty(localSectionId, validDiffIds)
    local s = tostring(localSectionId or "")
    local baseId, suffix = s:match("^(.+)_([^_]+)$")
    if baseId and suffix and baseId ~= "" then
        local sid = suffix:lower()
        if validDiffIds and validDiffIds[sid] then
            return baseId, sid
        end
        -- Обратная совместимость: ob/hm без validDiffIds
        if (not validDiffIds or next(validDiffIds) == nil) and (sid == "ob" or sid == "hm") then
            return baseId, sid
        end
    end
    return nil, nil
end

local function NormalizeDifficulties(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, d in ipairs(list) do
        local id = tostring((d and d.id) or ""):lower()
        local name = tostring((d and d.name) or "")
        if id ~= "" and name ~= "" then
            out[#out + 1] = { id = id, name = name }
        end
    end
    if #out == 0 then return nil end
    return out
end

local function BuildModuleCache()
    if MODULE_CACHE then return MODULE_CACHE end
    if not IsModuleLayerEnabled() then return nil end

    local out = {
        modules = {},          -- ordered module descriptors
        nodesById = {},        -- fullSectionId -> node
        rootIdsByModule = {},  -- moduleId -> { fullSectionId, ... }
        itemsBySlot = {},      -- slotId -> { itemId=true }
        itemsBySlotByDifficulty = {}, -- slotId -> diffId -> { itemId=true }
    }

    local registry = BiSPlanner_ModuleRegistry or BisEquip_ModuleRegistry
    local allModules = (registry and registry.modules) or {}
    table.sort(allModules, function(a, b) return (a.priority or 1000) < (b.priority or 1000) end)

    local directItemRows = {}
    local itemSources = {}
    local itemRowBySlot = {}

    local function ensureNode(fullId, moduleId, localId, name, parentId, priority, difficulties, validDiffIds)
        local n = out.nodesById[fullId]
        if n then return n end
        n = {
            id = fullId,
            moduleId = moduleId,
            localId = localId,
            localDifficultyId = ParseDifficultyIdFromLocalId(localId, validDiffIds),
            name = tostring(name or localId or fullId),
            parentId = parentId,
            priority = tonumber(priority or 0) or 0,
            difficulties = NormalizeDifficulties(difficulties),
            children = {},
            directBySlot = {},
            aggBySlot = {},
            directBySlotByDifficulty = {},
            aggBySlotByDifficulty = {},
        }
        out.nodesById[fullId] = n
        return n
    end

    local function addSectionRecursive(moduleId, section, parentId, validDiffIds)
        if type(section) ~= "table" then return nil end
        local localId = tostring(section.id or "")
        if localId == "" then return nil end
        local fullId = moduleId .. "|" .. localId
        local node = ensureNode(fullId, moduleId, localId, section.name, parentId, section.priority, section.difficulties, validDiffIds)
        if parentId then
            local p = out.nodesById[parentId]
            if p then
                p.children[#p.children + 1] = fullId
            end
        else
            out.rootIdsByModule[moduleId] = out.rootIdsByModule[moduleId] or {}
            out.rootIdsByModule[moduleId][#out.rootIdsByModule[moduleId] + 1] = fullId
        end
        for _, child in ipairs(section.children or {}) do
            addSectionRecursive(moduleId, child, fullId, validDiffIds)
        end
        return fullId
    end

    for _, mod in ipairs(allModules) do
        if mod.enabled then
            local payload = (BiSPlanner_ModuleData and BiSPlanner_ModuleData[mod.id]) or (BisEquip_ModuleData and BisEquip_ModuleData[mod.id])
            if payload and type(payload) == "table" then
                out.modules[#out.modules + 1] = {
                    id = mod.id,
                    name = tostring(payload.name or mod.id),
                    priority = tonumber(mod.priority or 1000) or 1000,
                }

                local validDiffIds = CollectValidDifficultyIds(payload)

                for _, section in ipairs(payload.sections or {}) do
                    addSectionRecursive(mod.id, section, nil, validDiffIds)
                end

                for localSectionId, rows in pairs(payload.itemsBySection or {}) do
                    local fullSectionId = mod.id .. "|" .. tostring(localSectionId)
                    local node = out.nodesById[fullSectionId]
                    local resolvedDiffId = nil
                    if not node then
                        local baseId, suffix = ParseSectionIdWithDifficulty(localSectionId, validDiffIds)
                        if baseId and suffix then
                            node = out.nodesById[mod.id .. "|" .. baseId]
                            resolvedDiffId = suffix
                        end
                    else
                        resolvedDiffId = node.localDifficultyId
                    end
                    if node and type(rows) == "table" then
                        for _, row in ipairs(rows) do
                            local slotId = tonumber(row.slot or 0)
                            local itemId = tonumber(row.item or 0)
                            if slotId > 0 and itemId > 0 then
                                node.directBySlot[slotId] = node.directBySlot[slotId] or {}
                                node.directBySlot[slotId][itemId] = true

                                out.itemsBySlot[slotId] = out.itemsBySlot[slotId] or {}
                                out.itemsBySlot[slotId][itemId] = true

                                local diffId = resolvedDiffId or node.localDifficultyId
                                if diffId then
                                    node.directBySlotByDifficulty[slotId] = node.directBySlotByDifficulty[slotId] or {}
                                    node.directBySlotByDifficulty[slotId][diffId] = node.directBySlotByDifficulty[slotId][diffId] or {}
                                    node.directBySlotByDifficulty[slotId][diffId][itemId] = true

                                    out.itemsBySlotByDifficulty[slotId] = out.itemsBySlotByDifficulty[slotId] or {}
                                    out.itemsBySlotByDifficulty[slotId][diffId] = out.itemsBySlotByDifficulty[slotId][diffId] or {}
                                    out.itemsBySlotByDifficulty[slotId][diffId][itemId] = true
                                end

                                itemRowBySlot[slotId] = itemRowBySlot[slotId] or {}
                                if not itemRowBySlot[slotId][itemId] then
                                    itemRowBySlot[slotId][itemId] = { itemId, node.name }
                                end
                                if not itemSources[itemId] then
                                    itemSources[itemId] = { source = node.name }
                                end
                                directItemRows[#directItemRows + 1] = { sectionId = node.id, slot = slotId, item = itemId }
                            end
                        end
                    end
                end
            end
        end
    end

    local function aggregateNode(nodeId)
        local node = out.nodesById[nodeId]
        if not node then return end
        -- start from direct
        for slotId, items in pairs(node.directBySlot) do
            node.aggBySlot[slotId] = node.aggBySlot[slotId] or {}
            MergeSet(node.aggBySlot[slotId], items)
        end
        for slotId, byDiff in pairs(node.directBySlotByDifficulty) do
            node.aggBySlotByDifficulty[slotId] = node.aggBySlotByDifficulty[slotId] or {}
            for diffId, items in pairs(byDiff or {}) do
                node.aggBySlotByDifficulty[slotId][diffId] = node.aggBySlotByDifficulty[slotId][diffId] or {}
                MergeSet(node.aggBySlotByDifficulty[slotId][diffId], items)
            end
        end
        table.sort(node.children, function(a, b)
            local na, nb = out.nodesById[a], out.nodesById[b]
            local pa = na and na.priority or 0
            local pb = nb and nb.priority or 0
            if pa ~= pb then return pa < pb end
            local sa = na and na.name or tostring(a)
            local sb = nb and nb.name or tostring(b)
            return tostring(sa) < tostring(sb)
        end)
        for _, childId in ipairs(node.children) do
            aggregateNode(childId)
            local child = out.nodesById[childId]
            if child then
                for slotId, items in pairs(child.aggBySlot) do
                    node.aggBySlot[slotId] = node.aggBySlot[slotId] or {}
                    MergeSet(node.aggBySlot[slotId], items)
                end
                        for slotId, byDiff in pairs(child.aggBySlotByDifficulty or {}) do
                            node.aggBySlotByDifficulty[slotId] = node.aggBySlotByDifficulty[slotId] or {}
                            for diffId, items in pairs(byDiff or {}) do
                                node.aggBySlotByDifficulty[slotId][diffId] = node.aggBySlotByDifficulty[slotId][diffId] or {}
                                MergeSet(node.aggBySlotByDifficulty[slotId][diffId], items)
                            end
                        end
            end
        end
    end

    for _, mod in ipairs(out.modules) do
        local roots = out.rootIdsByModule[mod.id] or {}
        table.sort(roots, function(a, b)
            local na, nb = out.nodesById[a], out.nodesById[b]
            local pa = na and na.priority or 0
            local pb = nb and nb.priority or 0
            if pa ~= pb then return pa < pb end
            local sa = na and na.name or tostring(a)
            local sb = nb and nb.name or tostring(b)
            return tostring(sa) < tostring(sb)
        end)
        for _, rootId in ipairs(roots) do
            aggregateNode(rootId)
        end
    end

    -- compatibility tables used by ItemData helpers/tooltips
    BiSPlanner_ItemDB = {}
    BisEquip_ItemDB = BiSPlanner_ItemDB -- Backward compatibility
    for slotId, byItem in pairs(itemRowBySlot) do
        BiSPlanner_ItemDB[slotId] = {}
        for _, row in pairs(byItem) do
            BiSPlanner_ItemDB[slotId][#BiSPlanner_ItemDB[slotId] + 1] = row
        end
        table.sort(BiSPlanner_ItemDB[slotId], function(a, b) return a[1] < b[1] end)
    end
    BiSPlanner_ItemSources = itemSources
    BisEquip_ItemSources = BiSPlanner_ItemSources -- Backward compatibility
    BiSPlanner_SourceBySlot = nil
    BisEquip_SourceBySlot = nil

    MODULE_CACHE = out
    return out
end

local function SlotsForLookup(slotId)
    local fn = BiSPlanner_ResolveSlotQueryList or BisEquip_ResolveSlotQueryList
    if fn then return fn(slotId) or { slotId } end
    return { (BiSPlanner_ResolveSlotQuery or BisEquip_ResolveSlotQuery)(slotId) or slotId }
end

local function BuildNodeForSlot(cache, nodeId, lookupSlots)
    local node = cache.nodesById[nodeId]
    if not node then return nil end
    local children = {}
    for _, childId in ipairs(node.children or {}) do
        local childNode = BuildNodeForSlot(cache, childId, lookupSlots)
        if childNode then
            children[#children + 1] = childNode
        end
    end
    local hasItems = false
    for _, sid in ipairs(lookupSlots or {}) do
        if node.aggBySlot[sid] and next(node.aggBySlot[sid]) ~= nil then hasItems = true break end
    end
    if (not hasItems) and #children == 0 then
        return nil
    end
    return {
        id = node.id,
        name = node.name,
        children = children,
        hasItems = hasItems,
        difficulties = node.difficulties,
    }
end

local HIERARCHY_CACHE = {}

local function GetHierarchyForSlotFromModules(slotId)
    local cached = HIERARCHY_CACHE[slotId]
    if cached then return cached end
    local c = BuildModuleCache()
    if not c then return {} end
    local lookupSlots = SlotsForLookup(slotId)
    local out = {}
    for _, mod in ipairs(c.modules) do
        local children = {}
        for _, rootId in ipairs(c.rootIdsByModule[mod.id] or {}) do
            local n = BuildNodeForSlot(c, rootId, lookupSlots)
            if n then
                children[#children + 1] = n
            end
        end
        if #children > 0 then
            out[#out + 1] = {
                id = "module|" .. mod.id,
                name = mod.name,
                children = children,
                hasItems = false,
            }
        end
    end
    HIERARCHY_CACHE[slotId] = out
    return out
end

local SOURCES_CACHE = {}

local function GetSourcesForSlotFromModules(slotId)
    local cached = SOURCES_CACHE[slotId]
    if cached then return cached end
    local tree = GetHierarchyForSlotFromModules(slotId)
    local out = {}
    local seen = {}
    local function walk(nodes)
        for _, n in ipairs(nodes or {}) do
            if n.id and n.hasItems and not seen[n.id] then
                seen[n.id] = true
                out[#out + 1] = { id = n.id, name = n.name }
            end
            walk(n.children)
        end
    end
    walk(tree)
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    SOURCES_CACHE[slotId] = out
    return out
end

local function GetItemsForSlotFromModules(slotId, sourceFilter, difficultyFilter)
    local c = BuildModuleCache()
    if not c then return {} end
    local lookupSlots = SlotsForLookup(slotId)
    local diffId = tostring(difficultyFilter or ""):lower()
    local hasDifficultyFilter = diffId ~= ""
    local isAllowed = (BiSPlanner_IsItemAllowedForSlot or BisEquip_IsItemAllowedForSlot) or function(_, _) return true end
    local function mergeAndFilter(slotSet)
        local out = {}
        for itemId, _ in pairs(slotSet or {}) do
            if isAllowed(slotId, itemId) then out[itemId] = true end
        end
        return out
    end
    local function mergeSlots(getSlotData)
        local merged = {}
        for _, sid in ipairs(lookupSlots) do
            local data = getSlotData(sid)
            for itemId, _ in pairs(data or {}) do merged[itemId] = true end
        end
        return merged
    end
    if sourceFilter and sourceFilter ~= "" then
        local node = c.nodesById[sourceFilter]
        if not node then return {} end
        local raw
        if hasDifficultyFilter then
            raw = mergeSlots(function(sid) return (node.aggBySlotByDifficulty[sid] or {})[diffId] end)
        else
            raw = mergeSlots(function(sid) return node.aggBySlot[sid] end)
        end
        return FlattenSet(mergeAndFilter(raw))
    end
    local raw
    if hasDifficultyFilter then
        raw = mergeSlots(function(sid) return (c.itemsBySlotByDifficulty[sid] or {})[diffId] end)
    else
        raw = mergeSlots(function(sid) return c.itemsBySlot[sid] end)
    end
    return FlattenSet(mergeAndFilter(raw))
end

local function GetSourceDifficultiesFromModules(sourceFilter)
    local c = BuildModuleCache()
    if not c then return {} end
    local node = c.nodesById[sourceFilter]
    while node do
        if node.difficulties and #node.difficulties > 0 then
            return node.difficulties
        end
        node = node.parentId and c.nodesById[node.parentId] or nil
    end
    return {}
end

function BiSPlanner_ModuleDataWarmCaches()
    BisEquip_ModuleDataWarmCaches = BiSPlanner_ModuleDataWarmCaches -- Backward compatibility
    BuildModuleCache()
end

function BiSPlanner_ModuleGetSourcesForSlot(slotId)
    BisEquip_ModuleGetSourcesForSlot = BiSPlanner_ModuleGetSourcesForSlot -- Backward compatibility
    return GetSourcesForSlotFromModules(slotId)
end

function BiSPlanner_ModuleGetItemsForSlot(slotId, sourceFilter, difficultyFilter)
    BisEquip_ModuleGetItemsForSlot = BiSPlanner_ModuleGetItemsForSlot -- Backward compatibility
    return GetItemsForSlotFromModules(slotId, sourceFilter, difficultyFilter)
end

function BiSPlanner_ModuleGetHierarchyForSlot(slotId)
    BisEquip_ModuleGetHierarchyForSlot = BiSPlanner_ModuleGetHierarchyForSlot -- Backward compatibility
    return GetHierarchyForSlotFromModules(slotId)
end

function BiSPlanner_GetSourcesForSlot(slotId)
    BisEquip_GetSourcesForSlot = BiSPlanner_GetSourcesForSlot -- Backward compatibility
    return GetSourcesForSlotFromModules(slotId)
end

function BiSPlanner_GetSourceDifficulties(sourceFilter)
    BisEquip_GetSourceDifficulties = BiSPlanner_GetSourceDifficulties -- Backward compatibility
    return GetSourceDifficultiesFromModules(sourceFilter)
end

-- Supported signatures:
-- (slotId, sourceFilter)
-- (slotId, difficultyFilter, sourceFilter)
function BiSPlanner_GetItemsForSlot(slotId, arg2, arg3)
    BisEquip_GetItemsForSlot = BiSPlanner_GetItemsForSlot -- Backward compatibility
    local sourceFilter = nil
    local difficultyFilter = nil
    if arg3 ~= nil then
        difficultyFilter = arg2
        sourceFilter = arg3
    else
        local s = tostring(arg2 or "")
        if s:find("|", 1, true) then
            sourceFilter = arg2
        else
            difficultyFilter = arg2
        end
    end
    return GetItemsForSlotFromModules(slotId, sourceFilter, difficultyFilter)
end

function BiSPlanner_GetSourceHierarchy(slotId)
    BisEquip_GetSourceHierarchy = BiSPlanner_GetSourceHierarchy -- Backward compatibility
    return GetHierarchyForSlotFromModules(slotId)
end

function BiSPlanner_GetPvpSeasonGroupsForSlot(_slotId)
    BisEquip_GetPvpSeasonGroupsForSlot = BiSPlanner_GetPvpSeasonGroupsForSlot -- Backward compatibility
    return {}
end

function BiSPlanner_WarmItemDataCaches()
    BisEquip_WarmItemDataCaches = BiSPlanner_WarmItemDataCaches -- Backward compatibility
    BiSPlanner_ModuleDataWarmCaches()
end

