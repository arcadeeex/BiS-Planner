--[[
BiSPlanner - Item picker: AtlasLoot Sirus style.
Dropdown for loot source selection, 2-column loot list (icon + name + slot).
]]

local PICKER_WIDTH = 480
local PICKER_HEIGHT = 460
local LOOT_COLS = 2
local LOOT_ROW_HEIGHT = 36
local DROPDOWN_BUTTON_HEIGHT = 20  -- prevent list items overlapping
local ITEM_BUTTONS = {}
local PickerFilters = { sourceSectionId = nil, difficultyId = nil, searchText = "" }

-- Fix overlapping dropdown list buttons (WoW 3.3.5 UIDropDownMenu can draw with too small height)
local function FixDropdownListButtonHeights()
    if BiSPlanner_UI_FixDropDownLists then
        BiSPlanner_UI_FixDropDownLists(DROPDOWN_BUTTON_HEIGHT)
    elseif BisEquip_UI_FixDropDownLists then
        BisEquip_UI_FixDropDownLists(DROPDOWN_BUTTON_HEIGHT)
        return
    end
    local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 3
    local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 20
    for level = 1, maxLevels do
        for i = 1, maxButtons do
            local btn = _G["DropDownList" .. level .. "Button" .. i]
            if btn then btn:SetHeight(DROPDOWN_BUTTON_HEIGHT) end
        end
    end
end

local function OnItemClick(self)
    local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
    if not slotId then return end
    if self.itemId then
        if BiSPlanner then BiSPlanner:SetSlot(slotId, self.itemId) elseif BisEquip then BisEquip:SetSlot(slotId, self.itemId) end
    else
        if BiSPlanner then BiSPlanner:SetSlot(slotId, nil) elseif BisEquip then BisEquip:SetSlot(slotId, nil) end
    end
    if BiSPlanner_UpdateSlot then BiSPlanner_UpdateSlot(slotId) elseif BisEquip_UpdateSlot then BisEquip_UpdateSlot(slotId) end
    if BiSPlanner_RefreshAllSlots then BiSPlanner_RefreshAllSlots() elseif BisEquip_RefreshAllSlots then BisEquip_RefreshAllSlots() end
    if BiSPlanner_ItemPickerFrame then BiSPlanner_ItemPickerFrame:Hide() elseif BisEquip_ItemPickerFrame then BisEquip_ItemPickerFrame:Hide() end
end

local function OnItemEnter(self)
    if self.itemId then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemId .. ":0:0:0:0:0:0:0")
        if BiSPlanner_GetItemSource then
            local src = BiSPlanner_GetItemSource(self.itemId)
        elseif BisEquip_GetItemSource then
            local src = BisEquip_GetItemSource(self.itemId)
            if src and src.source then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(("Источник: %s"):format(src.source), 0.5, 0.5, 0.5)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Клик - добавить в слот", 0.4, 0.8, 0.4)
        GameTooltip:Show()
    end
end

local function OnItemLeave(self)
    GameTooltip:Hide()
end

local function CreatePickerFrame()
    if BiSPlanner_ItemPickerFrame then return BiSPlanner_ItemPickerFrame end
    if BisEquip_ItemPickerFrame then BiSPlanner_ItemPickerFrame = BisEquip_ItemPickerFrame; return BisEquip_ItemPickerFrame end

    local f = CreateFrame("Frame", "BiSPlanner_ItemPickerFrame", UIParent)
    BisEquip_ItemPickerFrame = f -- Backward compatibility
    f:SetSize(PICKER_WIDTH, PICKER_HEIGHT)
    f:SetPoint("CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, edgeSize = 32, tileSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 4, 4)
    if BiSPlanner_UI_ApplyClickable then
        BiSPlanner_UI_ApplyClickable(close, 2)
    elseif BisEquip_UI_ApplyClickable then
        BisEquip_UI_ApplyClickable(close, 2)
    else
        close:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    -- Выпадающий список источников лута (категории → рейд/подземелье → боссы)
    local srcDropdown = CreateFrame("Frame", "BiSPlanner_PickerSrcDropdown", f, "UIDropDownMenuTemplate")
    BisEquip_PickerSrcDropdown = srcDropdown -- Backward compatibility
    srcDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -52)
    local srcLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    srcLabel:SetPoint("BOTTOMLEFT", srcDropdown, "TOPLEFT", 16, 4)
    srcLabel:SetText("Источник лута:")

    -- Message when no source selected
    local msgLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    msgLabel:SetPoint("CENTER", 0, -60)
    msgLabel:SetText("Выберите источник лута из списка выше")
    f.msgLabel = msgLabel

    -- Сложность: в нижнем правом углу, список выпадает вверх (показывается только при выборе источника с difficulties)
    local diffDropdown = CreateFrame("Frame", "BiSPlanner_PickerDiffDropdown", f, "UIDropDownMenuTemplate")
    BisEquip_PickerDiffDropdown = diffDropdown -- Backward compatibility
    diffDropdown:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    local diffLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    diffLabel:SetPoint("BOTTOMLEFT", diffDropdown, "TOPLEFT", 16, 4)
    diffLabel:SetText("Сложность:")

    local searchEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    searchEdit:SetSize(180, 20)
    searchEdit:SetPoint("TOPLEFT", srcDropdown, "TOPRIGHT", 8, 0)
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("BOTTOMLEFT", searchEdit, "TOPLEFT", 0, 4)
    searchLabel:SetText("Поиск:")
    searchEdit:SetAutoFocus(false)
    searchEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    f.srcDropdown = srcDropdown
    f.diffDropdown = diffDropdown
    f.diffLabel = diffLabel
    diffDropdown:Hide()
    diffLabel:Hide()
    f.searchEdit = searchEdit

    -- Loot area (2-column list); снизу отступ под кнопку «Очистить» и опциональный блок сложности
    local lootScroll = CreateFrame("ScrollFrame", "BiSPlanner_PickerLootScroll", f, "UIPanelScrollFrameTemplate")
    BisEquip_PickerLootScroll = lootScroll -- Backward compatibility
    lootScroll:SetPoint("TOPLEFT", 12, -90)
    lootScroll:SetPoint("BOTTOMRIGHT", -30, 44)
    f.lootScroll = lootScroll
    
    local lootChild = CreateFrame("Frame", nil, lootScroll)
    lootChild:SetSize(PICKER_WIDTH - 60, 100)
    lootScroll:SetScrollChild(lootChild)
    f.lootChild = lootChild

    for i = 1, 60 do
        local col = ((i - 1) % LOOT_COLS)
        local row = math.floor((i - 1) / LOOT_COLS)
        local btn = CreateFrame("Button", nil, lootChild)
        btn:SetSize((PICKER_WIDTH - 80) / LOOT_COLS - 4, LOOT_ROW_HEIGHT - 2)
        btn:SetPoint("TOPLEFT", col * ((PICKER_WIDTH - 80) / LOOT_COLS), -row * LOOT_ROW_HEIGHT)
        if BiSPlanner_UI_ApplyClickable then
            BiSPlanner_UI_ApplyClickable(btn, 4)
        elseif BisEquip_UI_ApplyClickable then
            BisEquip_UI_ApplyClickable(btn, 4)
        else
            btn:EnableMouse(true)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetHitRectInsets(-4, -4, -4, -4)
        end
        btn:SetScript("OnClick", OnItemClick)
        btn:SetScript("OnEnter", OnItemEnter)
        btn:SetScript("OnLeave", OnItemLeave)
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        local icon = btn:CreateTexture(nil, "BACKGROUND")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(0.2, 0.2, 0.2, 0.8)
        btn.icon = icon

        local nameLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLabel:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetWidth((PICKER_WIDTH - 80) / LOOT_COLS - 50)
        nameLabel:SetWordWrap(false)
        btn.nameLabel = nameLabel

        local slotLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slotLabel:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 34, 0)
        slotLabel:SetJustifyH("LEFT")
        slotLabel:SetTextColor(0.7, 0.7, 0.7)
        btn.slotLabel = slotLabel

        ITEM_BUTTONS[i] = btn
    end

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("BOTTOMLEFT", 12, 12)
    if BisEquip_UI_ApplyClickable then
        BisEquip_UI_ApplyClickable(clearBtn, 2)
    else
        clearBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    clearBtn:SetText("Очистить слот")
    clearBtn:SetScript("OnClick", function()
        local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
        if slotId then
            if BiSPlanner then BiSPlanner:SetSlot(slotId, nil) elseif BisEquip then BisEquip:SetSlot(slotId, nil) end
            if BiSPlanner_UpdateSlot then BiSPlanner_UpdateSlot(slotId) elseif BisEquip_UpdateSlot then BisEquip_UpdateSlot(slotId) end
            if BiSPlanner_RefreshAllSlots then BiSPlanner_RefreshAllSlots() elseif BisEquip_RefreshAllSlots then BisEquip_RefreshAllSlots() end
        end
        f:Hide()
    end)

    if BiSPlanner_UI_EnableEscapeClose then
        BiSPlanner_UI_EnableEscapeClose(f)
    elseif BisEquip_UI_EnableEscapeClose then
        BisEquip_UI_EnableEscapeClose(f)
    end
    return f
end

-- Pre-create picker once so first slot click is instant.
function BiSPlanner_PreWarmItemPicker()
    BisEquip_PreWarmItemPicker = BiSPlanner_PreWarmItemPicker -- Backward compatibility
    local f = CreatePickerFrame()
    if f then
        f:Hide()
    end
end

local ITEM_QUALITY_COLORS = { [0] = {1,1,1}, [1] = {1,1,0}, [2] = {0,1,0}, [3] = {0,0.5,1}, [4] = {0.5,0,1}, [5] = {1,0.5,0} }
local EQUIP_SLOT_NAMES = {
    INVTYPE_HEAD = "Голова", INVTYPE_NECK = "Шея", INVTYPE_SHOULDER = "Плечо", INVTYPE_CHEST = "Грудь", INVTYPE_ROBE = "Грудь",
    INVTYPE_WAIST = "Пояс", INVTYPE_LEGS = "Ноги", INVTYPE_FEET = "Ступни", INVTYPE_WRIST = "Запястья", INVTYPE_HAND = "Кисти",
    INVTYPE_FINGER = "Палец", INVTYPE_TRINKET = "Аксессуар", INVTYPE_CLOAK = "Спина", INVTYPE_2HWEAPON = "Двуручное",
    INVTYPE_WEAPONMAINHAND = "Правая рука", INVTYPE_WEAPON = "Оружие", INVTYPE_WEAPONOFFHAND = "Левая рука",
    INVTYPE_SHIELD = "Щит", INVTYPE_HOLDABLE = "Левая рука", INVTYPE_RANGED = "Дальний бой", INVTYPE_RANGEDRIGHT = "Дальний бой",
}

local function RefreshPickerContent()
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
    if not f or not slotId then 
        return 
    end

    -- Проверяем наличие необходимых элементов
    if not f.lootScroll or not f.lootChild then
        return
    end

    local src = PickerFilters.sourceSectionId
    local diff = PickerFilters.difficultyId
    local search = (f.searchEdit and f.searchEdit:GetText()) or ""
    search = tostring(search):gsub("^%s+", ""):gsub("%s+$", "")
    PickerFilters.searchText = search
    if f.msgLabel then
        f.msgLabel:SetShown((not src) and search == "")
    end

    if not src and search == "" then
        for i = 1, 60 do ITEM_BUTTONS[i]:Hide() end
        f.lootChild:SetHeight(1)
        return
    end

    local list = {}
    if BiSPlanner_GetItemsForSlot then
        if src then
            list = BiSPlanner_GetItemsForSlot(slotId, diff, src) or {}
        else
            -- Без источника — показываем все предметы слота, без фильтра по сложности
            list = BiSPlanner_GetItemsForSlot(slotId, nil, nil) or {}
        end
    elseif BisEquip_GetItemsForSlot then
        if src then
            list = BisEquip_GetItemsForSlot(slotId, diff, src) or {}
        else
            list = BisEquip_GetItemsForSlot(slotId, nil, nil) or {}
        end
    end

    local filtered = {}
    if search ~= "" then
        local s = string.lower(search)
        for _, itemId in ipairs(list) do
            local name = GetItemInfo(itemId)
            if name and string.find(string.lower(name), s) then
                filtered[#filtered + 1] = itemId
            end
        end
    else
        filtered = list
    end

    local rows = math.ceil(#filtered / LOOT_COLS)
    f.lootChild:SetSize((PICKER_WIDTH - 80) / LOOT_COLS * LOOT_COLS, math.max(rows * LOOT_ROW_HEIGHT, 1))

    for i = 1, 60 do
        local btn = ITEM_BUTTONS[i]
        if i <= #filtered then
            local itemId = filtered[i]
            btn.itemId = itemId
            btn:Show()
            local name, link, quality, _, _, itemType, itemSubType, _, equipSlot, texture = GetItemInfo(itemId)
            if texture then
                btn.icon:SetTexture(texture)
                btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                btn.icon:SetTexture(0.3, 0.3, 0.3, 0.9)
            end
            local color = ITEM_QUALITY_COLORS[quality] or {1,1,1}
            btn.nameLabel:SetText(name or ("Item " .. itemId))
            btn.nameLabel:SetTextColor(color[1], color[2], color[3])
            -- Показываем только понятное название слота, без INVTYPE и технических данных
            local slotText = EQUIP_SLOT_NAMES[equipSlot] or "Реликвия"
            -- Не добавляем itemSubType если он содержит техническую информацию (INVTYPE и т.д.)
            btn.slotLabel:SetText(slotText)
        else
            btn.itemId = nil
            btn:Hide()
        end
    end

    f.lootScroll:SetVerticalScroll(0)
end

local InitDifficultyDropdown

local function SelectSource(sectionId, displayName)
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    if not f then return end
    
    PickerFilters.sourceSectionId = sectionId
    PickerFilters.difficultyId = nil
    if f.srcDropdown then
        UIDropDownMenu_SetSelectedValue(f.srcDropdown, sectionId)
        UIDropDownMenu_SetText(f.srcDropdown, displayName or "Выберите источник...")
    end

    if f.diffDropdown then
        InitDifficultyDropdown()
    end

    RefreshPickerContent()
end

local function SelectDifficulty(diffId, displayName)
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    if not f then return end
    PickerFilters.difficultyId = diffId
    if f.diffDropdown then
        UIDropDownMenu_SetSelectedValue(f.diffDropdown, diffId)
        UIDropDownMenu_SetText(f.diffDropdown, displayName or "Все")
    end
    RefreshPickerContent()
end

InitDifficultyDropdown = function()
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
    if not f or not slotId or not f.diffDropdown then return end

    local sourceId = PickerFilters.sourceSectionId
    local diffs = {}
    if sourceId and BiSPlanner_GetSourceDifficulties then
        diffs = BiSPlanner_GetSourceDifficulties(sourceId) or {}
    elseif sourceId and BisEquip_GetSourceDifficulties then
        diffs = BisEquip_GetSourceDifficulties(sourceId) or {}
    end

    local hasDiffs = diffs and #diffs > 0
    if f.diffDropdown then f.diffDropdown:SetShown(hasDiffs) end
    if f.diffLabel then f.diffLabel:SetShown(hasDiffs) end
    if not hasDiffs then
        PickerFilters.difficultyId = nil
        return
    end

    UIDropDownMenu_Initialize(f.diffDropdown, function(self, level)
        if (level or 1) ~= 1 then return end
        local anyInfo = UIDropDownMenu_CreateInfo()
        anyInfo.text = "Все"
        anyInfo.notCheckable = true
        anyInfo.value = ""
        anyInfo.func = function()
            SelectDifficulty(nil, "Все")
        end
        UIDropDownMenu_AddButton(anyInfo, 1)

        for _, d in ipairs(diffs) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = d.name or d.id
            info.notCheckable = true
            info.value = d.id
            info.func = function()
                SelectDifficulty(d.id, d.name or d.id)
            end
            UIDropDownMenu_AddButton(info, 1)
        end
    end)
    UIDropDownMenu_SetWidth(f.diffDropdown, 90)
    UIDropDownMenu_SetSelectedValue(f.diffDropdown, PickerFilters.difficultyId or "")
    if PickerFilters.difficultyId then
        local label = PickerFilters.difficultyId
        for _, d in ipairs(diffs) do
            if d.id == PickerFilters.difficultyId then
                label = d.name or d.id
                break
            end
        end
        UIDropDownMenu_SetText(f.diffDropdown, label)
    else
        UIDropDownMenu_SetText(f.diffDropdown, "Все")
    end
end

local function InitSourceDropdown()
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
    if not f or not slotId then return end

    local hierarchy = (BiSPlanner_GetSourceHierarchy and BiSPlanner_GetSourceHierarchy(slotId)) or (BisEquip_GetSourceHierarchy and BisEquip_GetSourceHierarchy(slotId)) or {}

    UIDropDownMenu_Initialize(f.srcDropdown, function(self, level)
        level = level or 1
        local currentNodes = nil
        if level == 1 then
            currentNodes = hierarchy
        else
            local val = UIDROPDOWNMENU_MENU_VALUE
            if val and val.children then
                currentNodes = val.children
            end
        end
        if not currentNodes then return end

        for _, node in ipairs(currentNodes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = node.name or node.id
            info.notCheckable = true
            local hasChildren = node.children and #node.children > 0
            info.func = function()
                SelectSource(node.id, node.name)
            end
            if hasChildren then
                info.hasArrow = true
                info.value = node
            else
                info.value = node.id
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(f.srcDropdown, 168)
    UIDropDownMenu_SetSelectedValue(f.srcDropdown, PickerFilters.sourceSectionId)
    do
        local txt = "Выберите источник..."
        if PickerFilters.sourceSectionId then
            local flatSources = (BiSPlanner_GetSourcesForSlot and BiSPlanner_GetSourcesForSlot(slotId)) or (BisEquip_GetSourcesForSlot and BisEquip_GetSourcesForSlot(slotId)) or {}
            for _, s in ipairs(flatSources) do
                if s.id == PickerFilters.sourceSectionId then txt = s.name break end
            end
        end
        UIDropDownMenu_SetText(f.srcDropdown, txt)
    end
end

function BiSPlanner_ShowItemPickerImpl(slotId, anchor)
    BisEquip_ShowItemPickerImpl = BiSPlanner_ShowItemPickerImpl -- Backward compatibility
    if not BiSPlanner_GetItemsForSlot and not BisEquip_GetItemsForSlot then return end
    if not slotId then return end
    
    BiSPlanner_PickerSlotId = slotId
    BisEquip_PickerSlotId = slotId -- Backward compatibility
    PickerFilters.sourceSectionId = nil
    PickerFilters.difficultyId = nil
    PickerFilters.searchText = ""

    local f = CreatePickerFrame()
    if not f then return end
    
    local slotName = (BiSPlanner_SlotNames and BiSPlanner_SlotNames[slotId]) or (BisEquip_SlotNames and BisEquip_SlotNames[slotId]) or ("Slot " .. slotId)
    if f.title then
        f.title:SetText("Выбор предмета: " .. slotName)
    end

    -- Инициализируем выпадающий список источников
    if f.srcDropdown then
        InitSourceDropdown()
    end
    if f.diffDropdown then
        InitDifficultyDropdown()
    end

    -- Инициализируем поле поиска
    if f.searchEdit then
        f.searchEdit:SetText("")
        f.searchEdit:SetScript("OnTextChanged", function(self)
            RefreshPickerContent()
        end)
    end

    -- Обновляем содержимое (показываем сообщение о выборе источника)
    RefreshPickerContent()

    -- Позиционируем фрейм справа от главного окна
    f:ClearAllPoints()
    local main = BiSPlanner_MainFrame or BisEquip_MainFrame
    if main and main:IsShown() and main:GetRight() then
        local mr = main:GetRight()
        local my = main:GetBottom() + main:GetHeight() / 2
        f:SetPoint("LEFT", UIParent, "BOTTOMLEFT", mr + 8, my - f:GetHeight() / 2)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
    end
    
    -- Убеждаемся что фрейм всегда показывается и поднимается наверх
    if BiSPlanner_UI_BringToFront then
        BiSPlanner_UI_BringToFront(f, "DIALOG", 10)
    elseif BisEquip_UI_BringToFront then
        BisEquip_UI_BringToFront(f, "DIALOG", 10)
    else
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 10)
        f:Raise()
    end
    f:Show()
end

-- Apply dropdown list button height fix; для сложности — список выпадает вверх
do
    if hooksecurefunc then
        hooksecurefunc("ToggleDropDownMenu", function(level, value, dropdown)
            local name = dropdown and dropdown.GetName and dropdown:GetName()
            if level == 1 and (name == "BiSPlanner_PickerSrcDropdown" or name == "BiSPlanner_PickerDiffDropdown" or name == "BisEquip_PickerSrcDropdown" or name == "BisEquip_PickerDiffDropdown") then
                FixDropdownListButtonHeights()
                for i = 1, (UIDROPDOWNMENU_MAXLEVELS or 3) do
                    local list = _G["DropDownList" .. i]
                    if list then
                        list:SetFrameStrata("FULLSCREEN_DIALOG")
                        list:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 20 + i)
                        -- Сложность внизу справа: список раскрывать вверх
                        -- Список сложности раскрывать вверх (окно внизу справа)
                        if (name == "BiSPlanner_PickerDiffDropdown" or name == "BisEquip_PickerDiffDropdown") and list == _G.DropDownList1 and dropdown then
                            local function repositionUp()
                                if list:IsShown() then
                                    list:ClearAllPoints()
                                    list:SetPoint("BOTTOM", dropdown, "TOP", 0, 2)
                                end
                            end
                            if C_Timer and C_Timer.After then
                                C_Timer.After(0, repositionUp)
                            else
                                local updater = dropdown._diffListUpdater
                                if not updater then
                                    updater = CreateFrame("Frame", nil, dropdown)
                                    updater:SetScript("OnUpdate", function(self)
                                        self:SetScript("OnUpdate", nil)
                                        local l = _G.DropDownList1
                                        if l and l:IsShown() then
                                            l:ClearAllPoints()
                                            l:SetPoint("BOTTOM", dropdown, "TOP", 0, 2)
                                        end
                                    end)
                                    dropdown._diffListUpdater = updater
                                end
                                updater:SetScript("OnUpdate", updater:GetScript("OnUpdate"))
                            end
                        end
                    end
                end
            end
        end)
    end
end
