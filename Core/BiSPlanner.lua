--[[
BiSPlanner - BiS list builder for WoW 3.3.5a (Sirus)
Uses Ace3 (AceAddon, AceConsole) for reliable slash commands and initialization.
]]

BiSPlanner = LibStub("AceAddon-3.0"):NewAddon("BiSPlanner", "AceConsole-3.0")

-- Backward compatibility: alias BisEquip and BisPlannerSirus to BiSPlanner
BisEquip = BiSPlanner
BisPlannerSirus = BiSPlanner

local function GetDefaults()
    return {
        sets = {},
        currentSetName = nil,
        currentSet = {},
        selectedClass = nil, -- e.g. "WARRIOR", "PALADIN"; nil = current player class
        minimap = {
            angle = 220,
            hide = false,
        },
    }
end

function BiSPlanner:InitDB()
    -- Migrate from old databases if exists
    if BisEquipDB and not BiSPlannerDB then
        BiSPlannerDB = BisEquipDB
    end
    if BisPlannerSirusDB and not BiSPlannerDB then
        BiSPlannerDB = BisPlannerSirusDB
    end
    if not BiSPlannerDB then
        BiSPlannerDB = GetDefaults()
    end
    if not BiSPlannerDB.sets then BiSPlannerDB.sets = {} end
    if not BiSPlannerDB.currentSet then BiSPlannerDB.currentSet = {} end
    if not BiSPlannerDB.minimap then
        BiSPlannerDB.minimap = { angle = 220, hide = false }
    end
    if BiSPlannerDB.minimap.angle == nil then
        BiSPlannerDB.minimap.angle = 220
    end
    if BiSPlannerDB.minimap.hide == nil then
        BiSPlannerDB.minimap.hide = false
    end
    -- Keep old DBs in sync for backward compatibility
    BisEquipDB = BiSPlannerDB
    BisPlannerSirusDB = BiSPlannerDB
end

function BiSPlanner:GetCurrentSet()
    return BiSPlannerDB.currentSet
end

function BiSPlanner:SetSlot(slotId, itemId)
    if not BiSPlannerDB.currentSet then BiSPlannerDB.currentSet = {} end
    if itemId and itemId > 0 then
        BiSPlannerDB.currentSet[slotId] = itemId
    else
        BiSPlannerDB.currentSet[slotId] = nil
    end
end

function BiSPlanner:GetSlot(slotId)
    return BiSPlannerDB.currentSet and BiSPlannerDB.currentSet[slotId] or nil
end

function BiSPlanner:Toggle()
    if BiSPlanner_MainFrame then
        if BiSPlanner_MainFrame:IsShown() then
            BiSPlanner_MainFrame:Hide()
        else
            BiSPlanner_MainFrame:Show()
        end
    else
        self:Print("BiSPlanner: Main frame not found. Try /reload")
    end
end

function BiSPlanner:Show()
    if BiSPlanner_MainFrame then
        BiSPlanner_MainFrame:Show()
    end
end

local function CalcAngle(dy, dx)
    if math.atan2 then
        return math.deg(math.atan2(dy, dx))
    end
    if dx == 0 then
        if dy > 0 then return 90 end
        if dy < 0 then return -90 end
        return 0
    end
    local a = math.deg(math.atan(dy / dx))
    if dx < 0 then a = a + 180 end
    return a
end

local function UpdateMinimapButtonPosition(btn, angle)
    if not btn or not Minimap then return end
    local radius = 78
    local rad = math.rad(angle or 220)
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function EnsureMinimapButton()
    if not Minimap then return end
    if _G["BiSPlanner_MinimapButton"] then
        local btn = _G["BiSPlanner_MinimapButton"]
        UpdateMinimapButtonPosition(btn, BiSPlannerDB and BiSPlannerDB.minimap and BiSPlannerDB.minimap.angle or 220)
        if BiSPlannerDB and BiSPlannerDB.minimap and BiSPlannerDB.minimap.hide then
            btn:Hide()
        else
            btn:Show()
        end
        return
    end

    local btn = CreateFrame("Button", "BiSPlanner_MinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    btn.bg = bg

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn.border = border

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            BiSPlanner:Toggle()
        elseif button == "RightButton" then
            ReloadUI()
        end
    end)

    btn:SetScript("OnDragStart", function(self)
        self.dragging = true
    end)
    btn:SetScript("OnDragStop", function(self)
        self.dragging = false
        if not BiSPlannerDB or not BiSPlannerDB.minimap then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale() or 1
        cx = cx / scale
        cy = cy / scale
        local dx = cx - mx
        local dy = cy - my
        local angle = CalcAngle(dy, dx)
        BiSPlannerDB.minimap.angle = angle
        UpdateMinimapButtonPosition(self, angle)
    end)
    btn:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if not BiSPlannerDB or not BiSPlannerDB.minimap then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale() or 1
        cx = cx / scale
        cy = cy / scale
        local dx = cx - mx
        local dy = cy - my
        local angle = CalcAngle(dy, dx)
        BiSPlannerDB.minimap.angle = angle
        UpdateMinimapButtonPosition(self, angle)
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("BiSPlanner", 1, 0.82, 0)
        GameTooltip:AddLine("ЛКМ: открыть/закрыть", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("ПКМ: /reload", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Зажмите ЛКМ и перетащите: переместить", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateMinimapButtonPosition(btn, BiSPlannerDB and BiSPlannerDB.minimap and BiSPlannerDB.minimap.angle or 220)
    if BiSPlannerDB and BiSPlannerDB.minimap and BiSPlannerDB.minimap.hide then
        btn:Hide()
    else
        btn:Show()
    end
end

function BiSPlanner:OnInitialize()
    self:InitDB()
    -- Keep /bis command for convenience
    self:RegisterChatCommand("bis", "Toggle")
end

function BiSPlanner:OnEnable()
    if BiSPlanner_InitUI then
        BiSPlanner_InitUI()
    end
    if BiSPlanner_WarmItemDataCaches then
        BiSPlanner_WarmItemDataCaches()
    end
    if BiSPlanner_PreWarmItemPicker then
        BiSPlanner_PreWarmItemPicker()
    end
    EnsureMinimapButton()
end
