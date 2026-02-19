--[[
BiSPlanner - Main frame, ElvUI × WotLK style (design.txt).
Structure: HeaderFrame, TopBarFrame, ContentFrame (GearPanel + StatsPanel), BottomBarFrame.
]]

local S = BiSPlanner_Styles or {}
local PAD = (S and S.PADDING_OUTER) or 12
local PAD_BLOCK = (S and S.PADDING_BLOCK) or 8
local MAIN_W = (S and S.MAIN_WIDTH) or 900
local MAIN_H = (S and S.MAIN_HEIGHT) or 560
local HEADER_H = (S and S.HEADER_HEIGHT) or 32
local TOPBAR_H = (S and S.TOPBAR_HEIGHT) or 36
local BOTTOMBAR_H = (S and S.BOTTOMBAR_HEIGHT) or 40
local SLOT_SIZE = (S and S.SLOT_SIZE) or 40
local SLOT_GAP = (S and S.SLOT_GAP) or 8
local SLOT_CELL = (S and S.SLOT_CELL) or (SLOT_SIZE + SLOT_GAP)
local SLOT_COLUMN_GAP = (S and S.SLOT_COLUMN_GAP) or 20
local GEAR_W = (S and S.GEAR_PANEL_WIDTH) or 260
local GEAR_H = (S and S.GEAR_PANEL_HEIGHT) or 420
-- Inset for stats scroll: must fit scrollbar (14px) + padding so it stays inside main window
local STATS_SCROLL_INSET = 18
local STATS_SCROLLBAR_RESERVED = 16  -- scrollbar width (14) + padding to stats edge (2)

local function SyncDBs(db, set, name)
    if BiSPlannerDB then BiSPlannerDB.currentSet = set; BiSPlannerDB.currentSetName = name end
    if BisEquipDB then BisEquipDB.currentSet = set; BisEquipDB.currentSetName = name end
end

local function SyncDBsSaveSet(db, name)
    if BiSPlannerDB then BiSPlannerDB.sets[name] = db.sets[name]; BiSPlannerDB.currentSetName = name end
    if BisEquipDB then BisEquipDB.sets[name] = db.sets[name]; BisEquipDB.currentSetName = name end
end

-- Main frame
local main = CreateFrame("Frame", "BiSPlanner_MainFrame", UIParent)
BisEquip_MainFrame = main
main:SetSize(MAIN_W, MAIN_H)
-- TOPLEFT anchor avoids jump when dragging from header (CENTER anchor would jerk frame up)
main:SetPoint("TOPLEFT", UIParent, "CENTER", -MAIN_W / 2, MAIN_H / 2)
main:SetMovable(true)
main:SetClampedToScreen(true)
main:SetFrameStrata("DIALOG")
main:EnableMouse(true)
main:Hide()
if BiSPlanner_UI_EnableEscapeClose then
    BiSPlanner_UI_EnableEscapeClose(main)
elseif BisEquip_UI_EnableEscapeClose then
    BisEquip_UI_EnableEscapeClose(main)
end
if BiSPlanner_ApplyMainBackdrop then
    BiSPlanner_ApplyMainBackdrop(main)
elseif BisEquip_ApplyMainBackdrop then
    BisEquip_ApplyMainBackdrop(main)
else
    BiSPlanner_ApplyMainBackdropWithFallback(main)
end
main:RegisterForDrag("LeftButton")
main:SetScript("OnDragStart", main.StartMoving)
main:SetScript("OnDragStop", main.StopMovingOrSizing)
main:SetScript("OnHide", function()
    local picker = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    if picker and picker:IsShown() then picker:Hide() end
end)

-- HeaderFrame (32px): title + close only
local headerFrame = CreateFrame("Frame", "BiSPlanner_HeaderFrame", main)
headerFrame:SetPoint("TOPLEFT", PAD, -PAD)
headerFrame:SetPoint("TOPRIGHT", -PAD, -PAD)
headerFrame:SetHeight(HEADER_H)
headerFrame:EnableMouse(true)
headerFrame:RegisterForDrag("LeftButton")
headerFrame:SetScript("OnDragStart", function() main:StartMoving() end)
headerFrame:SetScript("OnDragStop", function() main:StopMovingOrSizing() end)

local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("LEFT", 0, 0)
local addonVersion = (GetAddOnMetadata and (GetAddOnMetadata("BiSPlanner", "Version") or GetAddOnMetadata("BisEquip", "Version"))) or "1.0"
title:SetText("BiS Planner " .. tostring(addonVersion or "1.0"))
local tc = S.TEXT_VALUE or { 0.9, 0.9, 0.9, 1 }
title:SetTextColor(tc[1], tc[2], tc[3])

-- ElvUI-style close: large gray cross, no background
local closeBtn = CreateFrame("Button", "BiSPlanner_MainFrameClose", headerFrame)
closeBtn:SetSize(36, 36)
closeBtn:SetPoint("TOPRIGHT", 0, 0)
local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeX:SetPoint("CENTER", 0, 0)
closeX:SetText("×")
closeX:SetTextColor(0.55, 0.55, 0.58, 1)
closeX:SetFont(closeX:GetFont(), 26, "OUTLINE")
closeBtn:SetScript("OnClick", function() BiSPlanner_MainFrame:Hide() end)
closeBtn:SetScript("OnEnter", function(self)
    closeX:SetTextColor(0.75, 0.75, 0.78, 1)
end)
closeBtn:SetScript("OnLeave", function(self)
    closeX:SetTextColor(0.55, 0.55, 0.58, 1)
end)
if BiSPlanner_UI_ApplyClickable then BiSPlanner_UI_ApplyClickable(closeBtn, 4)
elseif BisEquip_UI_ApplyClickable then BisEquip_UI_ApplyClickable(closeBtn, 4) end

-- TopBarFrame (36px): class dropdown left, profile dropdown right, same row
local topBarFrame = CreateFrame("Frame", "BiSPlanner_TopBarFrame", main)
topBarFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -PAD_BLOCK)
topBarFrame:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, -PAD_BLOCK)
topBarFrame:SetHeight(TOPBAR_H)

-- Class dropdown (left, aligned with BiSPlanner title - compensate for dropdown's 20px internal offset)
local classDropdown = CreateFrame("Frame", "BiSPlanner_ClassDropdown", topBarFrame, "UIDropDownMenuTemplate")
BisEquip_ClassDropdown = classDropdown
classDropdown:SetPoint("LEFT", -20, 0)
UIDropDownMenu_SetWidth(classDropdown, 140)
if BiSPlanner_ApplyDropDownStyle then BiSPlanner_ApplyDropDownStyle(classDropdown) end

-- Profile dropdown (right)
local profileDropdown = CreateFrame("Frame", "BiSPlanner_ProfileDropdown", topBarFrame, "UIDropDownMenuTemplate")
-- Align dropdown right edge with stats content (scroll child ends at scroll right - reserved)
profileDropdown:SetPoint("RIGHT", -(STATS_SCROLL_INSET + STATS_SCROLLBAR_RESERVED), 0)
UIDropDownMenu_SetWidth(profileDropdown, 160)
if BiSPlanner_ApplyDropDownStyle then BiSPlanner_ApplyDropDownStyle(profileDropdown) end
local profileLabel = topBarFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
profileLabel:SetPoint("RIGHT", profileDropdown, "LEFT", 8, 0)
profileLabel:SetText("Профиль:")
profileLabel:SetTextColor((S.TEXT_NORMAL or { 0.75, 0.75, 0.78, 1 })[1], (S.TEXT_NORMAL or {})[2] or 0.75, (S.TEXT_NORMAL or {})[3] or 0.78)

-- ContentFrame (padding between content and buttons)
local CONTENT_BOTTOM_PAD = 16
local contentFrame = CreateFrame("Frame", "BiSPlanner_ContentFrame", main)
contentFrame:SetPoint("TOPLEFT", topBarFrame, "BOTTOMLEFT", 0, -PAD_BLOCK)
contentFrame:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -PAD, BOTTOMBAR_H + PAD + CONTENT_BOTTOM_PAD)

-- GearPanel: same height as stats/scroll, aligned top and bottom
local gearPanel = CreateFrame("Frame", "BiSPlanner_GearPanel", contentFrame)
BisEquip_SlotsLeft = gearPanel
BisEquip_SlotsRight = gearPanel
BisEquip_SlotsBottom = gearPanel
gearPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
gearPanel:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", 0, 0)
gearPanel:SetWidth(GEAR_W)
if BiSPlanner_ApplyPanelBackdrop then
    BiSPlanner_ApplyPanelBackdrop(gearPanel)
elseif BisEquip_ApplyPanelBackdrop then
    BisEquip_ApplyPanelBackdrop(gearPanel)
end

local gearTitle = gearPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gearTitle:SetPoint("TOP", 0, -10)
gearTitle:SetText("Экипировка")
gearTitle:SetTextColor((S.TEXT_NORMAL or { 0.75, 0.75, 0.78, 1 })[1], (S.TEXT_NORMAL or {})[2] or 0.75, (S.TEXT_NORMAL or {})[3] or 0.78)

-- Stats panel (right of gear): same height as gear, inset so scrollbar stays inside
local statsScroll = CreateFrame("ScrollFrame", "BiSPlanner_StatsScroll", contentFrame, "UIPanelScrollFrameTemplate")
BisEquip_StatsScroll = statsScroll
statsScroll:SetPoint("TOPLEFT", gearPanel, "TOPRIGHT", PAD_BLOCK, 0)
statsScroll:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -STATS_SCROLL_INSET, 0)
statsScroll:EnableMouseWheel(true)
statsScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll() or 0
    local step = 24
    local maxScroll = self:GetVerticalScrollRange() or 0
    local nextScroll = cur - (delta * step)
    if nextScroll < 0 then nextScroll = 0 end
    if nextScroll > maxScroll then nextScroll = maxScroll end
    self:SetVerticalScroll(nextScroll)
end)
if BiSPlanner_ApplyScrollBarStyle then BiSPlanner_ApplyScrollBarStyle(statsScroll) end

local statsContainer = CreateFrame("Frame", "BiSPlanner_StatsContainer", statsScroll)
BisEquip_StatsContainer = statsContainer
statsContainer:SetPoint("TOPLEFT", statsScroll, "TOPLEFT", 0, 0)
statsContainer:SetHeight(1)
statsScroll:SetScrollChild(statsContainer)

-- BottomBarFrame (40px)
local bottomBarFrame = CreateFrame("Frame", "BiSPlanner_BottomBarFrame", main)
bottomBarFrame:SetPoint("BOTTOMLEFT", PAD, PAD)
bottomBarFrame:SetPoint("BOTTOMRIGHT", -PAD, PAD)
bottomBarFrame:SetHeight(BOTTOMBAR_H)

local saveBtn, loadBtn, deleteBtn
if BiSPlanner_CreateFlatButton then
    saveBtn = BiSPlanner_CreateFlatButton(bottomBarFrame, 140, 22, "Сохранить")
    loadBtn = BiSPlanner_CreateFlatButton(bottomBarFrame, 100, 22, "Загрузить")
    deleteBtn = BiSPlanner_CreateFlatButton(bottomBarFrame, 80, 22, "Удалить")
else
    saveBtn = CreateFrame("Button", "BiSPlanner_SaveSetBtn", bottomBarFrame, "UIPanelButtonTemplate")
    loadBtn = CreateFrame("Button", "BiSPlanner_LoadSetBtn", bottomBarFrame, "UIPanelButtonTemplate")
    deleteBtn = CreateFrame("Button", "BiSPlanner_DeleteSetBtn", bottomBarFrame, "UIPanelButtonTemplate")
    saveBtn:SetText("Сохранить"); loadBtn:SetText("Загрузить"); deleteBtn:SetText("Удалить")
end
saveBtn:SetSize(140, 22)
saveBtn:SetPoint("LEFT", 0, 0)
loadBtn:SetSize(100, 22)
loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
deleteBtn:SetSize(80, 22)
deleteBtn:SetPoint("LEFT", loadBtn, "RIGHT", 8, 0)

-- Slot textures
local SLOT_TO_WOW_NAME = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [4] = "ShirtSlot", [5] = "ChestSlot",
    [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot", [9] = "WristSlot", [10] = "HandsSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [15] = "BackSlot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot", [19] = "TabardSlot",
}
BiSPlanner_SlotPlaceholderTextures = {}
BisEquip_SlotPlaceholderTextures = BiSPlanner_SlotPlaceholderTextures
local defaultEmptyTex = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
for slotId, wowName in pairs(SLOT_TO_WOW_NAME) do
    local id, tex = GetInventorySlotInfo(wowName)
    BiSPlanner_SlotPlaceholderTextures[slotId] = (tex and tex ~= "") and tex or defaultEmptyTex
end

-- Slot order: paper doll 7+7+3 (left col, right col, bottom weapons)
BiSPlanner_SlotOrder = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
BisEquip_SlotOrder = BiSPlanner_SlotOrder
BiSPlanner_SlotNames = {
    [1] = "Голова", [2] = "Шея", [3] = "Плечо", [4] = "Рубашка", [5] = "Грудь",
    [6] = "Пояс", [7] = "Ноги", [8] = "Ступни", [9] = "Запястья", [10] = "Кисти",
    [11] = "Кольцо 1", [12] = "Кольцо 2", [13] = "Аксессуар 1", [14] = "Аксессуар 2",
    [15] = "Плащ", [16] = "Правая рука", [17] = "Левая рука", [18] = "Дальний бой", [19] = "Гербовая накидка",
}
BisEquip_SlotNames = BiSPlanner_SlotNames

local NON_CLICKABLE_SLOTS = { [4] = true, [19] = true }

-- Frame helpers
local function FrameSetSelectedClass(classId)
    if BiSPlanner_SetSelectedClass then BiSPlanner_SetSelectedClass(classId)
    elseif BisEquip_SetSelectedClass then BisEquip_SetSelectedClass(classId)
    else
        if BiSPlannerDB then BiSPlannerDB.selectedClass = classId end
        if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() end
    end
end
local function FrameGetSelectedClass()
    if BiSPlanner_GetSelectedClass then return BiSPlanner_GetSelectedClass() end
    if BisEquip_GetSelectedClass then return BisEquip_GetSelectedClass() end
    if BiSPlannerDB and BiSPlannerDB.selectedClass then return BiSPlannerDB.selectedClass end
    if BisEquipDB and BisEquipDB.selectedClass then return BisEquipDB.selectedClass end
    return nil
end

local CLASS_IDS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT" }
local CLASS_NAMES_RU = {
    WARRIOR = "Воин", PALADIN = "Паладин", HUNTER = "Охотник", ROGUE = "Разбойник",
    PRIEST = "Жрец", SHAMAN = "Шаман", MAGE = "Маг", WARLOCK = "Чернокнижник",
    DRUID = "Друид", DEATHKNIGHT = "Рыцарь смерти",
}

local function BiSPlanner_InitClassDropdown()
    BisEquip_InitClassDropdown = BiSPlanner_InitClassDropdown
    local dd = BiSPlanner_ClassDropdown or BisEquip_ClassDropdown
    if not dd then return end
    UIDropDownMenu_Initialize(dd, function(self, level)
        if BiSPlanner_ScheduleDropDownListStyle then BiSPlanner_ScheduleDropDownListStyle()
        elseif BisEquip_ScheduleDropDownListStyle then BisEquip_ScheduleDropDownListStyle() end
        local cur = FrameGetSelectedClass()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Текущий класс"
        info.checked = (not cur or cur == "")
        info.isNotRadio = false
        info.func = function()
            FrameSetSelectedClass(nil)
            UIDropDownMenu_SetText(dd, "Текущий класс")
            if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() end
        end
        UIDropDownMenu_AddButton(info, level)
        for _, cid in ipairs(CLASS_IDS) do
            local info2 = UIDropDownMenu_CreateInfo()
            info2.text = CLASS_NAMES_RU[cid] or cid
            info2.checked = (cur == cid)
            info2.isNotRadio = false
            info2.func = function()
                FrameSetSelectedClass(cid)
                UIDropDownMenu_SetText(dd, CLASS_NAMES_RU[cid] or cid)
                if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() end
            end
            UIDropDownMenu_AddButton(info2, level)
        end
    end)
    local cur = FrameGetSelectedClass()
    UIDropDownMenu_SetText(dd, cur and (CLASS_NAMES_RU[cur] or cur) or "Текущий класс")
end

local function GetEffectiveClassId()
    local fn = BiSPlanner_GetEffectiveClassId or BisEquip_GetEffectiveClassId
    return fn and fn() or nil
end

-- Profile dropdown (load set)
local function InitProfileDropdown()
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.sets then return end
    local list = {}
    for name, _ in pairs(db.sets) do list[#list + 1] = name end
    table.sort(list)
    UIDropDownMenu_Initialize(profileDropdown, function(self, level)
        if BiSPlanner_ScheduleDropDownListStyle then BiSPlanner_ScheduleDropDownListStyle()
        elseif BisEquip_ScheduleDropDownListStyle then BisEquip_ScheduleDropDownListStyle() end
        for _, name in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = (db.currentSetName == name)
            info.isNotRadio = false
            info.func = function()
                db.currentSet = {}
                for k, v in pairs(db.sets[name] or {}) do db.currentSet[k] = v end
                db.currentSetName = name
                SyncDBs(db, db.currentSet, name)
                BiSPlanner_RefreshAllSlots()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(profileDropdown, db.currentSetName or "—")
end

function BiSPlanner_RefreshCurrentSetNameLabel()
    BisEquip_RefreshCurrentSetNameLabel = BiSPlanner_RefreshCurrentSetNameLabel
    if profileDropdown then
        local name = (BiSPlannerDB and BiSPlannerDB.currentSetName) or (BisEquipDB and BisEquipDB.currentSetName) or ""
        UIDropDownMenu_SetText(profileDropdown, name ~= "" and name or "—")
    end
end

local function SlotButton_OnClick(self)
    if not self or not self.slotId then return end
    if BiSPlanner_ShowItemPicker then BiSPlanner_ShowItemPicker(self.slotId, self)
    elseif BisEquip_ShowItemPicker then BisEquip_ShowItemPicker(self.slotId, self) end
end

local function SlotButton_OnEnter(self)
    if self.bgTex then
        self.bgTex:SetVertexColor(0.16, 0.16, 0.16, 1)
    end
    if self.slotId then
        local itemId = (BiSPlanner and BiSPlanner:GetSlot(self.slotId)) or (BisEquip and BisEquip:GetSlot(self.slotId))
        if itemId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. itemId .. ":0:0:0:0:0:0:0")
            GameTooltip:Show()
        end
    end
end

local function SlotButton_OnLeave(self)
    if self.bgTex then
        self.bgTex:SetVertexColor(0.12, 0.12, 0.12, 1)
    end
    GameTooltip:Hide()
end

local function UpdateStatsChildWidth()
    local w = (statsScroll:GetWidth() or 0) - STATS_SCROLLBAR_RESERVED
    if w < 120 then w = 120 end
    statsContainer:SetWidth(w)
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() end
end
statsScroll:SetScript("OnSizeChanged", UpdateStatsChildWidth)
main:HookScript("OnShow", UpdateStatsChildWidth)

function BiSPlanner_InitUI()
    BisEquip_InitUI = BiSPlanner_InitUI
    if BiSPlanner_InitClassDropdown then BiSPlanner_InitClassDropdown()
    elseif BisEquip_InitClassDropdown then BisEquip_InitClassDropdown() end
    InitProfileDropdown()
    if BiSPlanner_RefreshCurrentSetNameLabel then BiSPlanner_RefreshCurrentSetNameLabel() end
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() elseif BisEquip_RefreshStats then BisEquip_RefreshStats() end

    -- Paper doll: left col LEFT of weapon block, right col RIGHT of weapon block, symmetric offset
    local leftCol = { 1, 3, 5, 9, 7, 11, 13 }
    local rightCol = { 2, 15, 10, 6, 8, 12, 14 }
    local bottomRow = { 16, 17, 18 }
    local bottomTotalW = 3 * SLOT_SIZE + 2 * SLOT_GAP
    local bottomStartX = (GEAR_W - bottomTotalW) / 2
    local COLUMN_OFFSET = 12
    local leftX = bottomStartX - SLOT_SIZE - COLUMN_OFFSET
    local rightX = bottomStartX + bottomTotalW + COLUMN_OFFSET
    local GEAR_BOTTOM_PAD = 12
    local bottomY = -7 * SLOT_CELL - 24 - GEAR_BOTTOM_PAD

    local function CreateSlotBtn(slotId, x, y)
        local btn = CreateFrame("Button", "BiSPlanner_Slot" .. slotId, gearPanel)
        _G["BisEquip_Slot" .. slotId] = btn
        btn:SetSize(SLOT_SIZE, SLOT_SIZE)
        btn:SetPoint("TOPLEFT", gearPanel, "TOPLEFT", x, y)
        btn.slotId = slotId
        local isNonClickable = NON_CLICKABLE_SLOTS[slotId]
        if isNonClickable then
            btn:EnableMouse(false)
        elseif BiSPlanner_UI_ApplyClickable then BiSPlanner_UI_ApplyClickable(btn, 4)
        elseif BisEquip_UI_ApplyClickable then BisEquip_UI_ApplyClickable(btn, 4)
        else
            btn:EnableMouse(true)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetHitRectInsets(-4, -4, -4, -4)
        end
        if not isNonClickable then
            btn:SetScript("OnClick", SlotButton_OnClick)
            btn:SetScript("OnEnter", SlotButton_OnEnter)
            btn:SetScript("OnLeave", SlotButton_OnLeave)
        end
        local bgTex = btn:CreateTexture(nil, "BACKGROUND")
        bgTex:SetAllPoints()
        bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
        bgTex:SetVertexColor(0.12, 0.12, 0.12, 1)
        btn.bgTex = bgTex
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.texture = tex
        if not isNonClickable then
            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        end
        BiSPlanner_UpdateSlot(slotId)
    end

    for row, slotId in ipairs(leftCol) do
        CreateSlotBtn(slotId, leftX, -(row - 1) * SLOT_CELL - 24)
    end
    for row, slotId in ipairs(rightCol) do
        CreateSlotBtn(slotId, rightX, -(row - 1) * SLOT_CELL - 24)
    end
    for col, slotId in ipairs(bottomRow) do
        CreateSlotBtn(slotId, bottomStartX + (col - 1) * SLOT_CELL, bottomY)
    end

    closeBtn:SetScript("OnClick", function() BiSPlanner_MainFrame:Hide() end)
    saveBtn:SetScript("OnClick", function()
        if BiSPlanner_SaveSet then BiSPlanner_SaveSet() elseif BisEquip_SaveSet then BisEquip_SaveSet() end
    end)
    loadBtn:SetScript("OnClick", function()
        if BiSPlanner_LoadSet then BiSPlanner_LoadSet() elseif BisEquip_LoadSet then BisEquip_LoadSet() end
    end)
    deleteBtn:SetScript("OnClick", function()
        if BiSPlanner_DeleteSet then BiSPlanner_DeleteSet() elseif BisEquip_DeleteSet then BisEquip_DeleteSet() end
    end)
end

function BiSPlanner_UpdateSlot(slotId)
    BisEquip_UpdateSlot = BiSPlanner_UpdateSlot
    local btn = _G["BiSPlanner_Slot" .. slotId] or _G["BisEquip_Slot" .. slotId]
    if not btn or not btn.texture then return end
    local itemId = (BiSPlanner and BiSPlanner:GetSlot(slotId)) or (BisEquip and BisEquip:GetSlot(slotId))
    if itemId then
        local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
        if texture then
            btn.texture:SetTexture(texture)
            btn.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            btn.texture:SetTexture(0.3, 0.3, 0.3, 0.9)
        end
    else
        local placeholder = (BiSPlanner_SlotPlaceholderTextures and BiSPlanner_SlotPlaceholderTextures[slotId]) or (BisEquip_SlotPlaceholderTextures and BisEquip_SlotPlaceholderTextures[slotId])
        if placeholder then
            btn.texture:SetTexture(placeholder)
            btn.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            btn.texture:SetTexture(0.12, 0.12, 0.12, 1)
        end
    end
    -- RefreshStats called once by RefreshAllSlots; avoid N redundant calls from UpdateSlot
end

function BiSPlanner_RefreshAllSlots()
    BisEquip_RefreshAllSlots = BiSPlanner_RefreshAllSlots
    if BiSPlanner_ClearArmorScanFailed then BiSPlanner_ClearArmorScanFailed()
    elseif BisEquip_ClearArmorScanFailed then BisEquip_ClearArmorScanFailed() end
    for _, slotId in ipairs(BiSPlanner_SlotOrder or BisEquip_SlotOrder or {}) do
        BiSPlanner_UpdateSlot(slotId)
    end
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() elseif BisEquip_RefreshStats then BisEquip_RefreshStats() end
end

main:SetScript("OnShow", function()
    -- Ensure UI is initialized (fallback if OnEnable ran before frames were ready)
    if BiSPlanner_InitUI and not _G["BiSPlanner_Slot1"] then
        BiSPlanner_InitUI()
    end
    BiSPlanner_RefreshAllSlots()
    if InitProfileDropdown then InitProfileDropdown() end
end)

function BiSPlanner_ShowItemPicker(slotId, anchor)
    BisEquip_ShowItemPicker = BiSPlanner_ShowItemPicker
    if BiSPlanner_ShowItemPickerImpl then BiSPlanner_ShowItemPickerImpl(slotId, anchor)
    elseif BisEquip_ShowItemPickerImpl then BisEquip_ShowItemPickerImpl(slotId, anchor) end
end

function BiSPlanner_RefreshStats()
    BisEquip_RefreshStats = BiSPlanner_RefreshStats
    if BiSPlanner_RefreshStatsImpl then BiSPlanner_RefreshStatsImpl()
    elseif BisEquip_RefreshStatsImpl then BisEquip_RefreshStatsImpl() end
end

local function CopySet(src)
    local dst = {}
    if src then for k, v in pairs(src) do dst[k] = v end end
    return dst
end

function BiSPlanner_SaveSet()
    BisEquip_SaveSet = BiSPlanner_SaveSet
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.sets then return end
    StaticPopup_Show("BISPLANNERSIRUS_SAVE_SET")
end

function BiSPlanner_LoadSet()
    BisEquip_LoadSet = BiSPlanner_LoadSet
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.sets then return end
    local list = {}
    for name, _ in pairs(db.sets) do list[#list + 1] = name end
    table.sort(list)
    if #list == 0 then return end
    if not BiSPlanner_LoadSetDropDown then
        BiSPlanner_LoadSetDropDown = CreateFrame("Frame", "BiSPlanner_LoadSetDropDown", UIParent, "UIDropDownMenuTemplate")
        BisEquip_LoadSetDropDown = BiSPlanner_LoadSetDropDown
        if BiSPlanner_ApplyDropDownStyle then BiSPlanner_ApplyDropDownStyle(BiSPlanner_LoadSetDropDown) end
    end
    if BiSPlanner_UI_BringToFront then BiSPlanner_UI_BringToFront(BiSPlanner_LoadSetDropDown, "FULLSCREEN_DIALOG", 22)
    elseif BisEquip_UI_BringToFront then BisEquip_UI_BringToFront(BiSPlanner_LoadSetDropDown, "FULLSCREEN_DIALOG", 22) end
    UIDropDownMenu_Initialize(BiSPlanner_LoadSetDropDown, function(self, level)
        if BiSPlanner_ScheduleDropDownListStyle then BiSPlanner_ScheduleDropDownListStyle()
        elseif BisEquip_ScheduleDropDownListStyle then BisEquip_ScheduleDropDownListStyle() end
        for _, name in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = (db.currentSetName == name)
            info.isNotRadio = false
            info.func = function()
                db.currentSet = CopySet(db.sets[name])
                db.currentSetName = name
                SyncDBs(db, db.currentSet, name)
                BiSPlanner_RefreshAllSlots()
                BiSPlanner_RefreshCurrentSetNameLabel()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, BiSPlanner_LoadSetDropDown, "cursor", 0, 0)
end

function BiSPlanner_DeleteSet()
    BisEquip_DeleteSet = BiSPlanner_DeleteSet
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.sets then return end
    local list = {}
    for name, _ in pairs(db.sets) do list[#list + 1] = name end
    table.sort(list)
    if #list == 0 then return end
    if not BiSPlanner_DeleteSetDropDown then
        BiSPlanner_DeleteSetDropDown = CreateFrame("Frame", "BiSPlanner_DeleteSetDropDown", UIParent, "UIDropDownMenuTemplate")
        BisEquip_DeleteSetDropDown = BiSPlanner_DeleteSetDropDown
        if BiSPlanner_ApplyDropDownStyle then BiSPlanner_ApplyDropDownStyle(BiSPlanner_DeleteSetDropDown) end
    end
    if BiSPlanner_UI_BringToFront then BiSPlanner_UI_BringToFront(BiSPlanner_DeleteSetDropDown, "FULLSCREEN_DIALOG", 22)
    elseif BisEquip_UI_BringToFront then BisEquip_UI_BringToFront(BiSPlanner_DeleteSetDropDown, "FULLSCREEN_DIALOG", 22) end
    UIDropDownMenu_Initialize(BiSPlanner_DeleteSetDropDown, function(self, level)
        if BiSPlanner_ScheduleDropDownListStyle then BiSPlanner_ScheduleDropDownListStyle()
        elseif BisEquip_ScheduleDropDownListStyle then BisEquip_ScheduleDropDownListStyle() end
        for _, name in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                db.sets[name] = nil
                if db.currentSetName == name then
                    db.currentSetName = nil
                    SyncDBs(db, db.currentSet, nil)
                    BiSPlanner_RefreshCurrentSetNameLabel()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, BiSPlanner_DeleteSetDropDown, "cursor", 0, 0)
end

local function trim(s)
    if not s then return "" end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

StaticPopupDialogs["BISPLANNERSIRUS_SAVE_SET"] = {
    text = "Имя комплекта:",
    button1 = "Сохранить",
    button2 = "Отмена",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local name = trim(self.editBox:GetText())
        local db = BiSPlannerDB or BisEquipDB
        if name ~= "" and db and db.sets then
            db.sets[name] = CopySet(db.currentSet)
            db.currentSetName = name
            SyncDBsSaveSet(db, name)
            BiSPlanner_RefreshCurrentSetNameLabel()
            InitProfileDropdown()
        end
    end,
    OnShow = function(self)
        if BiSPlanner_ApplyStaticPopupStyle then BiSPlanner_ApplyStaticPopupStyle(self)
        elseif BisEquip_ApplyStaticPopupStyle then BisEquip_ApplyStaticPopupStyle(self) end
        local db = BiSPlannerDB or BisEquipDB
        self.editBox:SetText((db and db.currentSetName) or "")
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        local name = trim(self:GetText())
        local db = BiSPlannerDB or BisEquipDB
        if name ~= "" and db and db.sets then
            db.sets[name] = CopySet(db.currentSet)
            db.currentSetName = name
            SyncDBsSaveSet(db, name)
            BiSPlanner_RefreshCurrentSetNameLabel()
            InitProfileDropdown()
        end
        self:GetParent():Hide()
    end,
}
StaticPopupDialogs["BISEQUIP_SAVE_SET"] = StaticPopupDialogs["BISPLANNERSIRUS_SAVE_SET"]
