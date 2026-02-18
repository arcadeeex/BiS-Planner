--[[
BiSPlanner - Main frame and paper doll slots (created entirely in Lua, no XML)
]]

-- Create main frame immediately when this file loads
local FRAME_WIDTH = 480
local FRAME_HEIGHT = 520
local main = CreateFrame("Frame", "BiSPlanner_MainFrame", UIParent)
-- Backward compatibility alias
BisEquip_MainFrame = main
main:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
main:SetPoint("CENTER", 0, 0)
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

main:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

main:RegisterForDrag("LeftButton")
main:SetScript("OnDragStart", main.StartMoving)
main:SetScript("OnDragStop", main.StopMovingOrSizing)

-- Title (draggable area)
local title = main:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -14)
title:SetText("BiSPlanner")

-- Close button
local closeBtn = CreateFrame("Button", "BiSPlanner_MainFrameClose", main, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
if BiSPlanner_UI_ApplyClickable then
    BiSPlanner_UI_ApplyClickable(closeBtn, 2)
elseif BisEquip_UI_ApplyClickable then
    BisEquip_UI_ApplyClickable(closeBtn, 2)
end

-- WoW slot names for GetInventorySlotInfo (returns empty slot texture)
local SLOT_TO_WOW_NAME = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [4] = "ShirtSlot", [5] = "ChestSlot",
    [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot", [9] = "WristSlot", [10] = "HandsSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [15] = "BackSlot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot", [19] = "TabardSlot",
}
BiSPlanner_SlotPlaceholderTextures = {}
BisEquip_SlotPlaceholderTextures = BiSPlanner_SlotPlaceholderTextures -- Backward compatibility
local defaultEmptyTex = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
for slotId, wowName in pairs(SLOT_TO_WOW_NAME) do
    local id, tex = GetInventorySlotInfo(wowName)
    BiSPlanner_SlotPlaceholderTextures[slotId] = (tex and tex ~= "") and tex or defaultEmptyTex
end

local SLOT_HEIGHT = 400
-- Slots left column (Head, Neck, Shoulder, Back, Chest, Wrist, Hands, Waist, Legs, Feet)
local slotsLeft = CreateFrame("Frame", "BiSPlanner_SlotsLeft", main)
BisEquip_SlotsLeft = slotsLeft -- Backward compatibility
slotsLeft:SetSize(44, SLOT_HEIGHT)
-- Увеличиваем отступ сверху чтобы слот головы был ниже выпадающего меню класса (которое на y=-34)
slotsLeft:SetPoint("TOPLEFT", 16, -60)

-- Slots right column (Плащ, Кольцо 1, Кольцо 2, Аксессуар 1, Аксессуар 2)
local slotsRight = CreateFrame("Frame", "BiSPlanner_SlotsRight", main)
BisEquip_SlotsRight = slotsRight -- Backward compatibility
slotsRight:SetSize(44, SLOT_HEIGHT)
-- Выравниваем правую колонку с левой по вертикали
slotsRight:SetPoint("TOPRIGHT", -16, -60)

-- Slots bottom row (Main Hand, Off Hand, Ranged) - like standard character window
local slotsBottom = CreateFrame("Frame", "BiSPlanner_SlotsBottom", main)
BisEquip_SlotsBottom = slotsBottom -- Backward compatibility
slotsBottom:SetSize(140, 56)
slotsBottom:SetPoint("BOTTOM", main, "BOTTOM", 0, 56)

-- Class dropdown (for stat calculation). Use local helpers so we don't depend on Stats.lua load order.
local function FrameSetSelectedClass(classId)
    if BiSPlanner_SetSelectedClass then
        BiSPlanner_SetSelectedClass(classId)
    elseif BisEquip_SetSelectedClass then
        BisEquip_SetSelectedClass(classId)
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

local classDropdown = CreateFrame("Frame", "BiSPlanner_ClassDropdown", main, "UIDropDownMenuTemplate")
BisEquip_ClassDropdown = classDropdown -- Backward compatibility
classDropdown:SetPoint("TOP", main, "TOP", 0, -34)
UIDropDownMenu_SetWidth(classDropdown, 140)

-- Current set name label (under class dropdown, above stats panel)
local currentSetNameLabel = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
currentSetNameLabel:SetPoint("TOP", classDropdown, "BOTTOM", 0, -6)
currentSetNameLabel:SetTextColor(1, 0.82, 0)
currentSetNameLabel:SetText("Комплект: —")

local CLASS_IDS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT" }
local CLASS_NAMES_RU = {
    WARRIOR = "Воин", PALADIN = "Паладин", HUNTER = "Охотник", ROGUE = "Разбойник",
    PRIEST = "Жрец", SHAMAN = "Шаман", MAGE = "Маг", WARLOCK = "Чернокнижник",
    DRUID = "Друид", DEATHKNIGHT = "Рыцарь смерти",
}
local function BiSPlanner_InitClassDropdown()
    BisEquip_InitClassDropdown = BiSPlanner_InitClassDropdown -- Backward compatibility
    local dd = BiSPlanner_ClassDropdown or BisEquip_ClassDropdown
    if not dd then return end
    UIDropDownMenu_Initialize(dd, function(self, level)
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

function BiSPlanner_RefreshCurrentSetNameLabel()
    BisEquip_RefreshCurrentSetNameLabel = BiSPlanner_RefreshCurrentSetNameLabel -- Backward compatibility
    if not currentSetNameLabel then return end
    local name = (BiSPlannerDB and BiSPlannerDB.currentSetName) or (BisEquipDB and BisEquipDB.currentSetName) or ""
    if name == "" then
        currentSetNameLabel:SetText("Комплект: —")
    else
        currentSetNameLabel:SetText("Комплект: " .. name)
    end
end

-- Stats container (center) with vertical scroll
local STATS_AREA_PADDING = 24
local statsScroll = CreateFrame("ScrollFrame", "BiSPlanner_StatsScroll", main, "UIPanelScrollFrameTemplate")
BisEquip_StatsScroll = statsScroll -- Backward compatibility
statsScroll:SetPoint("TOPLEFT", slotsLeft, "TOPRIGHT", 12, -24)
statsScroll:SetPoint("TOPRIGHT", slotsRight, "TOPLEFT", -(12 + STATS_AREA_PADDING), -24)
-- End stats area above bottom weapon slots.
statsScroll:SetPoint("BOTTOM", slotsBottom, "TOP", 0, 8)
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

local statsContainer = CreateFrame("Frame", "BiSPlanner_StatsContainer", statsScroll)
BisEquip_StatsContainer = statsContainer -- Backward compatibility
statsContainer:SetPoint("TOPLEFT", statsScroll, "TOPLEFT", 0, 0)
statsContainer:SetHeight(1)
statsScroll:SetScrollChild(statsContainer)

local function UpdateStatsChildWidth()
    local w = (statsScroll:GetWidth() or 0) - 28
    if w < 120 then w = 120 end
    statsContainer:SetWidth(w)
    if BiSPlanner_RefreshStats then
        BiSPlanner_RefreshStats()
    end
end
statsScroll:SetScript("OnSizeChanged", UpdateStatsChildWidth)
main:HookScript("OnShow", UpdateStatsChildWidth)

-- Set management buttons
local saveBtn = CreateFrame("Button", "BiSPlanner_SaveSetBtn", main, "UIPanelButtonTemplate")
saveBtn:SetSize(140, 22)
saveBtn:SetPoint("BOTTOMLEFT", 24, 16)
saveBtn:SetText("Сохранить комплект")

local loadBtn = CreateFrame("Button", "BiSPlanner_LoadSetBtn", main, "UIPanelButtonTemplate")
loadBtn:SetSize(80, 22)
loadBtn:SetPoint("BOTTOMLEFT", saveBtn, "BOTTOMRIGHT", 8, 0)
loadBtn:SetText("Загрузить")

local deleteBtn = CreateFrame("Button", "BiSPlanner_DeleteSetBtn", main, "UIPanelButtonTemplate")
deleteBtn:SetSize(80, 22)
deleteBtn:SetPoint("BOTTOMLEFT", loadBtn, "BOTTOMRIGHT", 8, 0)
deleteBtn:SetText("Удалить")

-- Slot order and names
BiSPlanner_SlotOrder = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
BisEquip_SlotOrder = BiSPlanner_SlotOrder -- Backward compatibility
BiSPlanner_SlotNames = {
    [1] = "Голова", [2] = "Шея", [3] = "Плечо", [4] = "Рубашка", [5] = "Грудь",
    [6] = "Пояс", [7] = "Ноги", [8] = "Ступни", [9] = "Запястья", [10] = "Кисти",
    [11] = "Кольцо 1", [12] = "Кольцо 2", [13] = "Аксессуар 1", [14] = "Аксессуар 2",
    [15] = "Плащ", [16] = "Правая рука", [17] = "Левая рука", [18] = "Дальний бой", [19] = "Гербовая накидка",
}
BisEquip_SlotNames = BiSPlanner_SlotNames -- Backward compatibility

local SLOT_SIZE = 36
local SLOT_PADDING = 4
local NON_CLICKABLE_SLOTS = {
    [4] = true,  -- Рубашка
    [19] = true, -- Гербовая накидка
}

local SOURCE_LABEL_OVERRIDES = {
    GruulMaulgar = "Верховный король Маулгар",
    GruulsLairHighKingMaulgar = "Верховный король Маулгар",
    GruulGruul = "Груул",
    GruulsLairGruulTheDragonkiller = "Груул",
    TrialoftheCrusaderAnubarak_A = "Ануб'арак",
    TrialoftheCrusaderAnubarak_H = "Ануб'арак",
}

local function FormatSourceShort(src)
    if not src or not src.source then return "" end
    -- Используем русифицированное название источника
    local name = SOURCE_LABEL_OVERRIDES[src.source]
        or ((BiSPlanner_FormatSourceName and BiSPlanner_FormatSourceName(src.source)) or (BisEquip_FormatSourceName and BisEquip_FormatSourceName(src.source)) or src.source:gsub("_", " "):gsub("(%l)(%u)", "%1 %2"))
    name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
    -- Русифицируем сложность
    local diffText = ""
    if src.difficulty then
        local diffMap = { ["10N"] = "10об", ["25N"] = "25об", ["10H"] = "10хм", ["25H"] = "25хм" }
        diffText = " " .. (diffMap[src.difficulty] or src.difficulty)
    end
    local s = name .. diffText
    -- На слотах держим короткий формат, иначе текст перекрывает соседние элементы.
    return #s > 24 and s:sub(1, 22) .. "…" or s
end

local function SlotButton_OnClick(self)
    if not self or not self.slotId then return end
    if BiSPlanner_ShowItemPicker then
        BiSPlanner_ShowItemPicker(self.slotId, self)
    elseif BisEquip_ShowItemPicker then
        BisEquip_ShowItemPicker(self.slotId, self)
    end
end

local function SlotButton_OnEnter(self)
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
    GameTooltip:Hide()
end

function BiSPlanner_InitUI()
    BisEquip_InitUI = BiSPlanner_InitUI -- Backward compatibility
    local leftCol = BiSPlanner_SlotsLeft or BisEquip_SlotsLeft
    local rightCol = BiSPlanner_SlotsRight or BisEquip_SlotsRight
    local bottomRow = BiSPlanner_SlotsBottom or BisEquip_SlotsBottom
    if not leftCol or not rightCol or not bottomRow then return end

    if BiSPlanner_InitClassDropdown then BiSPlanner_InitClassDropdown() elseif BisEquip_InitClassDropdown then BisEquip_InitClassDropdown() end
    if BiSPlanner_RefreshCurrentSetNameLabel then BiSPlanner_RefreshCurrentSetNameLabel() elseif BisEquip_RefreshCurrentSetNameLabel then BisEquip_RefreshCurrentSetNameLabel() end
    
    -- Обновляем статы при инициализации
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() elseif BisEquip_RefreshStats then BisEquip_RefreshStats() end

    -- Распределение как в окне персонажа (C), по требуемому порядку:
    -- Слева: Голова, Шея, Плечи, Спина, Грудь, Рубашка, Гербовая, Запястья
    -- Справа: Руки, Пояс, Ноги, Ступни, Кольцо 1, Кольцо 2, Аксессуар 1, Аксессуар 2
    -- Внизу: Правая рука, Левая рука, Дальний бой (3)
    local colsLeft = { 1, 2, 3, 15, 5, 4, 19, 9 }
    local colsRight = { 10, 6, 7, 8, 11, 12, 13, 14 }
    local colsBottom = { 16, 17, 18 }

    local function CreateSlotBtn(parent, slotId, x, y, isLeftColumn, isRightColumn)
        local btn = CreateFrame("Button", "BiSPlanner_Slot" .. slotId, parent)
        _G["BisEquip_Slot" .. slotId] = btn -- Backward compatibility
        btn:SetSize(SLOT_SIZE, SLOT_SIZE)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        btn.slotId = slotId
        local isNonClickable = NON_CLICKABLE_SLOTS[slotId]
        if isNonClickable then
            btn:EnableMouse(false)
        elseif BiSPlanner_UI_ApplyClickable then
            BiSPlanner_UI_ApplyClickable(btn, 4)
        elseif BisEquip_UI_ApplyClickable then
            BisEquip_UI_ApplyClickable(btn, 4)
        else
            btn:EnableMouse(true)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetHitRectInsets(-4, -4, -4, -4)
        end
        if isNonClickable then
            btn:SetScript("OnClick", nil)
            btn:SetScript("OnMouseUp", nil)
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
        else
            btn:SetScript("OnClick", SlotButton_OnClick)
            btn:SetScript("OnMouseUp", SlotButton_OnClick)
            btn:SetScript("OnEnter", SlotButton_OnEnter)
            btn:SetScript("OnLeave", SlotButton_OnLeave)
        end
        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        tex:SetTexture(0.2, 0.2, 0.2, 0.8)
        btn.texture = tex
        if not isNonClickable then
            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        end
        local srcLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        -- Для левых слотов: источник справа от слота, текст влево (к центру)
        -- Для правых слотов: источник слева от слота, текст вправо (к центру)
        -- Для нижних слотов: источник под слотом по центру
        if isLeftColumn then
            srcLabel:SetPoint("LEFT", btn, "RIGHT", 6, 0)
            srcLabel:SetJustifyH("LEFT")
        elseif isRightColumn then
            srcLabel:SetPoint("RIGHT", btn, "LEFT", -6, 0)
            srcLabel:SetJustifyH("RIGHT")
        else
            -- Нижние слоты (оружие)
            srcLabel:SetPoint("TOP", btn, "BOTTOM", 0, -1)
            srcLabel:SetJustifyH("CENTER")
        end
        -- Увеличиваем ширину для длинных имен боссов
        srcLabel:SetWidth(180)
        srcLabel:SetFont(srcLabel:GetFont(), 9)
        srcLabel:SetTextColor(0.6, 0.6, 0.6)
        btn.sourceLabel = srcLabel
        BiSPlanner_UpdateSlot(slotId)
        return btn
    end

    for i, slotId in ipairs(colsLeft) do
        CreateSlotBtn(leftCol, slotId, 0, -(i - 1) * (SLOT_SIZE + SLOT_PADDING), true, false)
    end

    for i, slotId in ipairs(colsRight) do
        CreateSlotBtn(rightCol, slotId, 0, -(i - 1) * (SLOT_SIZE + SLOT_PADDING), false, true)
    end

    for i, slotId in ipairs(colsBottom) do
        CreateSlotBtn(bottomRow, slotId, (i - 1) * (SLOT_SIZE + SLOT_PADDING), 0, false, false)
    end

    closeBtn:SetScript("OnClick", function()
        BiSPlanner_MainFrame:Hide()
    end)

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
    BisEquip_UpdateSlot = BiSPlanner_UpdateSlot -- Backward compatibility
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
        if btn.sourceLabel then
            btn.sourceLabel:SetText("")
            btn.sourceLabel:Hide()
        end
    else
        local placeholder = (BiSPlanner_SlotPlaceholderTextures and BiSPlanner_SlotPlaceholderTextures[slotId]) or (BisEquip_SlotPlaceholderTextures and BisEquip_SlotPlaceholderTextures[slotId])
        if placeholder then
            btn.texture:SetTexture(placeholder)
            btn.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            btn.texture:SetTexture(0.2, 0.2, 0.2, 0.8)
        end
        if btn.sourceLabel then
            btn.sourceLabel:SetText("")
            btn.sourceLabel:Hide()
        end
    end
    -- Обновляем статы при каждом изменении слота
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() elseif BisEquip_RefreshStats then BisEquip_RefreshStats() end
end

function BiSPlanner_RefreshAllSlots()
    BisEquip_RefreshAllSlots = BiSPlanner_RefreshAllSlots -- Backward compatibility
    local order = BiSPlanner_SlotOrder or BisEquip_SlotOrder
    for _, slotId in ipairs(order) do
        BiSPlanner_UpdateSlot(slotId)
    end
    if BiSPlanner_RefreshStats then BiSPlanner_RefreshStats() elseif BisEquip_RefreshStats then BisEquip_RefreshStats() end
end

main:SetScript("OnShow", function()
    BiSPlanner_RefreshAllSlots()
end)

main:SetScript("OnHide", function()
    -- Picker stays open when main hides (user can move it independently)
end)

function BiSPlanner_ShowItemPicker(slotId, anchor)
    BisEquip_ShowItemPicker = BiSPlanner_ShowItemPicker -- Backward compatibility
    if BiSPlanner_ShowItemPickerImpl then BiSPlanner_ShowItemPickerImpl(slotId, anchor) elseif BisEquip_ShowItemPickerImpl then BisEquip_ShowItemPickerImpl(slotId, anchor) end
end

function BiSPlanner_RefreshStats()
    BisEquip_RefreshStats = BiSPlanner_RefreshStats -- Backward compatibility
    if BiSPlanner_RefreshStatsImpl then BiSPlanner_RefreshStatsImpl() elseif BisEquip_RefreshStatsImpl then BisEquip_RefreshStatsImpl() end
end

-- Save/Load/Delete sets
local function CopySet(src)
    local dst = {}
    if src then for k, v in pairs(src) do dst[k] = v end end
    return dst
end

function BiSPlanner_SaveSet()
    BisEquip_SaveSet = BiSPlanner_SaveSet -- Backward compatibility
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.sets then return end
    StaticPopup_Show("BISPLANNERSIRUS_SAVE_SET")
end

function BiSPlanner_LoadSet()
    BisEquip_LoadSet = BiSPlanner_LoadSet -- Backward compatibility
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.sets then return end
    local list = {}
    for name, _ in pairs(db.sets) do list[#list + 1] = name end
    table.sort(list)
    if #list == 0 then return end
    if not BiSPlanner_LoadSetDropDown then
        BiSPlanner_LoadSetDropDown = CreateFrame("Frame", "BiSPlanner_LoadSetDropDown", UIParent, "UIDropDownMenuTemplate")
        BisEquip_LoadSetDropDown = BiSPlanner_LoadSetDropDown -- Backward compatibility
    end
    if BiSPlanner_UI_BringToFront then
        BiSPlanner_UI_BringToFront(BiSPlanner_LoadSetDropDown, "FULLSCREEN_DIALOG", 22)
    elseif BisEquip_UI_BringToFront then
        BisEquip_UI_BringToFront(BiSPlanner_LoadSetDropDown, "FULLSCREEN_DIALOG", 22)
    end
    UIDropDownMenu_Initialize(BiSPlanner_LoadSetDropDown, function(self, level)
        for _, name in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            local isCurrent = ((db.currentSetName == name))
            info.text = name
            -- Standard WoW selected indicator: yellow filled radio circle.
            info.checked = isCurrent
            info.isNotRadio = false
            info.func = function()
                db.currentSet = CopySet(db.sets[name])
                db.currentSetName = name
                -- Sync to both DBs
                if BiSPlannerDB then BiSPlannerDB.currentSet = db.currentSet; BiSPlannerDB.currentSetName = name end
                if BisEquipDB then BisEquipDB.currentSet = db.currentSet; BisEquipDB.currentSetName = name end
                BiSPlanner_RefreshAllSlots()
                if BiSPlanner_RefreshCurrentSetNameLabel then BiSPlanner_RefreshCurrentSetNameLabel() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, BiSPlanner_LoadSetDropDown, "cursor", 0, 0)
end

function BiSPlanner_DeleteSet()
    BisEquip_DeleteSet = BiSPlanner_DeleteSet -- Backward compatibility
    local db = BiSPlannerDB or BisEquipDB
    if not db or not db.sets then return end
    local list = {}
    for name, _ in pairs(db.sets) do list[#list + 1] = name end
    table.sort(list)
    if #list == 0 then return end
    if not BiSPlanner_DeleteSetDropDown then
        BiSPlanner_DeleteSetDropDown = CreateFrame("Frame", "BiSPlanner_DeleteSetDropDown", UIParent, "UIDropDownMenuTemplate")
        BisEquip_DeleteSetDropDown = BiSPlanner_DeleteSetDropDown -- Backward compatibility
    end
    if BiSPlanner_UI_BringToFront then
        BiSPlanner_UI_BringToFront(BiSPlanner_DeleteSetDropDown, "FULLSCREEN_DIALOG", 22)
    elseif BisEquip_UI_BringToFront then
        BisEquip_UI_BringToFront(BiSPlanner_DeleteSetDropDown, "FULLSCREEN_DIALOG", 22)
    end
    UIDropDownMenu_Initialize(BiSPlanner_DeleteSetDropDown, function(self, level)
        for _, name in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                db.sets[name] = nil
                if db.currentSetName == name then
                    db.currentSetName = nil
                    -- Sync to both DBs
                    if BiSPlannerDB then BiSPlannerDB.currentSetName = nil end
                    if BisEquipDB then BisEquipDB.currentSetName = nil end
                    if BiSPlanner_RefreshCurrentSetNameLabel then BiSPlanner_RefreshCurrentSetNameLabel() end
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
            -- Sync to both DBs
            if BiSPlannerDB then BiSPlannerDB.sets[name] = db.sets[name]; BiSPlannerDB.currentSetName = name end
            if BisEquipDB then BisEquipDB.sets[name] = db.sets[name]; BisEquipDB.currentSetName = name end
            if BiSPlanner_RefreshCurrentSetNameLabel then BiSPlanner_RefreshCurrentSetNameLabel() end
        end
    end,
    OnShow = function(self)
        local db = BiSPlannerDB or BisEquipDB
        local cur = (db and db.currentSetName) or ""
        self.editBox:SetText(cur)
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        local name = trim(self:GetText())
        local db = BiSPlannerDB or BisEquipDB
        if name ~= "" and db and db.sets then
            db.sets[name] = CopySet(db.currentSet)
            db.currentSetName = name
            -- Sync to both DBs
            if BiSPlannerDB then BiSPlannerDB.sets[name] = db.sets[name]; BiSPlannerDB.currentSetName = name end
            if BisEquipDB then BisEquipDB.sets[name] = db.sets[name]; BisEquipDB.currentSetName = name end
            if BiSPlanner_RefreshCurrentSetNameLabel then BiSPlanner_RefreshCurrentSetNameLabel() end
        end
        self:GetParent():Hide()
    end,
}
-- Backward compatibility
StaticPopupDialogs["BISEQUIP_SAVE_SET"] = StaticPopupDialogs["BISPLANNERSIRUS_SAVE_SET"]
