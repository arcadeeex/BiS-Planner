--[[
BiSPlanner - Item picker: ElvUI × WotLK style (design.txt).
Single-column ItemRow (Icon, Name, ilvl, Boss), Preview panel with delta stats.
]]

local S = BiSPlanner_Styles or {}
local PICKER_WIDTH = S.PICKER_WIDTH or 760
local PICKER_HEIGHT = S.PICKER_HEIGHT or 500
local PICKER_SCROLL_INSET = 10  -- right inset so scrollbar has padding from window edge
local DROPDOWN_ROW_OFFSET = 16  -- offset so dropdown content aligns with item row icon (dropdown has ~20px internal offset, icon at 4px)
local ITEM_ROW_HEIGHT = S.ITEM_ROW_HEIGHT or 42
local DROPDOWN_BUTTON_HEIGHT = 20
local ITEM_BUTTONS = {}
local PickerFilters = { sourceSectionId = nil, difficultyId = nil, searchText = "" }
local HOVERED_ITEM_ID = nil

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

local function GetSourceDisplayName(itemId)
    local getSrc = BiSPlanner_GetItemSource or BisEquip_GetItemSource
    if not getSrc then return "" end
    local src = getSrc(itemId)
    if not src or not src.source then return "" end
    local fmt = BiSPlanner_FormatSourceName or BisEquip_FormatSourceName
    if fmt then return fmt(src.source) end
    return tostring(src.source):gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
end

-- Dedicated tooltip for picker (avoids conflicts with global GameTooltip)
local PickerTooltip
local function GetPickerTooltip()
    if not PickerTooltip then
        PickerTooltip = CreateFrame("GameTooltip", "BiSPlanner_PickerTooltip", UIParent, "GameTooltipTemplate")
        PickerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        PickerTooltip:SetFrameStrata("TOOLTIP")
    end
    return PickerTooltip
end

local function OnItemEnter(self)
    HOVERED_ITEM_ID = self.itemId
    if self.bgTex then self.bgTex:SetVertexColor(0.16, 0.16, 0.16, 1) end
    if self.itemId then
        local tt = GetPickerTooltip()
        local picker = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
        tt:SetOwner(picker or UIParent, "ANCHOR_RIGHT", 10, 0)
        tt:ClearLines()
        local _, link = GetItemInfo(self.itemId)
        tt:SetHyperlink(link or ("item:" .. self.itemId .. ":0:0:0:0:0:0:0"))
        tt:AddLine(" ")
        tt:AddLine("Клик - добавить в слот", 0.4, 0.8, 0.4)
        tt:Show()
    end
    if BiSPlanner_RefreshPickerPreview then BiSPlanner_RefreshPickerPreview(self.itemId) end
end

local function OnItemLeave(self)
    HOVERED_ITEM_ID = nil
    if self.bgTex then self.bgTex:SetVertexColor(0.12, 0.12, 0.12, 1) end
    if PickerTooltip then PickerTooltip:Hide() end
    GameTooltip:Hide()
    if BiSPlanner_RefreshPickerPreview then BiSPlanner_RefreshPickerPreview(nil) end
end

local function CreatePickerFrame()
    if BiSPlanner_ItemPickerFrame then return BiSPlanner_ItemPickerFrame end
    if BisEquip_ItemPickerFrame then BiSPlanner_ItemPickerFrame = BisEquip_ItemPickerFrame; return BisEquip_ItemPickerFrame end

    local f = CreateFrame("Frame", "BiSPlanner_ItemPickerFrame", UIParent)
    BisEquip_ItemPickerFrame = f
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
    f:SetScript("OnHide", function()
        if PickerTooltip then PickerTooltip:Hide() end
        GameTooltip:Hide()
        HOVERED_ITEM_ID = nil
    end)
    if BiSPlanner_ApplyMainBackdrop then BiSPlanner_ApplyMainBackdrop(f)
    elseif BisEquip_ApplyMainBackdrop then BisEquip_ApplyMainBackdrop(f)
    else BiSPlanner_ApplyMainBackdropWithFallback(f) end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    f.title = title

    local close = CreateFrame("Button", nil, f)
    close:SetSize(36, 36)
    close:SetPoint("TOPRIGHT", 0, 0)
    local closeX = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeX:SetPoint("CENTER", 0, 0)
    closeX:SetText("×")
    closeX:SetTextColor(0.55, 0.55, 0.58, 1)
    closeX:SetFont(closeX:GetFont(), 26, "OUTLINE")
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function()
        closeX:SetTextColor(0.75, 0.75, 0.78, 1)
    end)
    close:SetScript("OnLeave", function()
        closeX:SetTextColor(0.55, 0.55, 0.58, 1)
    end)
    if BiSPlanner_UI_ApplyClickable then BiSPlanner_UI_ApplyClickable(close, 2)
    elseif BisEquip_UI_ApplyClickable then BisEquip_UI_ApplyClickable(close, 2)
    else close:RegisterForClicks("LeftButtonUp", "RightButtonUp") end

    -- Top bar: Источник [▼] | Поиск [____] — align dropdown left with item rows (dropdown has ~20px internal offset)
    local srcDropdown = CreateFrame("Frame", "BiSPlanner_PickerSrcDropdown", f, "UIDropDownMenuTemplate")
    BisEquip_PickerSrcDropdown = srcDropdown
    srcDropdown:SetPoint("TOPLEFT", 4, -44)
    if BiSPlanner_ApplyDropDownStyle then BiSPlanner_ApplyDropDownStyle(srcDropdown) end
    local srcLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    srcLabel:SetPoint("BOTTOMLEFT", srcDropdown, "TOPLEFT", 16, 4)
    srcLabel:SetText("Источник:")

    local searchEdit = CreateFrame("EditBox", nil, f)
    searchEdit:SetHeight(28)
    searchEdit:SetPoint("LEFT", srcDropdown, "RIGHT", 12, 0)
    searchEdit:SetPoint("RIGHT", f, "RIGHT", -(PICKER_SCROLL_INSET + 18), 0)
    searchEdit:SetHitRectInsets(-4, -4, -4, -4)
    searchEdit:SetFontObject(GameFontHighlight)
    searchEdit:SetAutoFocus(false)
    searchEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if BiSPlanner_ApplySearchBoxStyle then BiSPlanner_ApplySearchBoxStyle(searchEdit)
    elseif BisEquip_ApplySearchBoxStyle then BisEquip_ApplySearchBoxStyle(searchEdit)
    elseif BiSPlanner_ApplyEditBoxStyle then BiSPlanner_ApplyEditBoxStyle(searchEdit)
    elseif BisEquip_ApplyEditBoxStyle then BisEquip_ApplyEditBoxStyle(searchEdit) end
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("BOTTOMLEFT", searchEdit, "TOPLEFT", 0, 4)
    searchLabel:SetText("Поиск:")
    if S.TEXT_VALUE then searchLabel:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3]) end

    -- Сложность row
    local diffDropdown = CreateFrame("Frame", "BiSPlanner_PickerDiffDropdown", f, "UIDropDownMenuTemplate")
    BisEquip_PickerDiffDropdown = diffDropdown
    diffDropdown:SetPoint("TOPLEFT", srcDropdown, "BOTTOMLEFT", 0, -28)
    if BiSPlanner_ApplyDropDownStyle then BiSPlanner_ApplyDropDownStyle(diffDropdown) end
    local diffLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    diffLabel:SetPoint("BOTTOMLEFT", diffDropdown, "TOPLEFT", 16, 4)
    diffLabel:SetText("Сложность:")

    f.msgLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.msgLabel:SetText("Выберите источник лута из списка выше")

    f.srcDropdown = srcDropdown
    f.diffDropdown = diffDropdown
    f.diffLabel = diffLabel
    diffDropdown:Hide()
    diffLabel:Hide()
    f.searchEdit = searchEdit

    -- Loot list (single column, ItemRow 42px) - offset so rows align with dropdown content
    local lootScroll = CreateFrame("ScrollFrame", "BiSPlanner_PickerLootScroll", f, "UIPanelScrollFrameTemplate")
    BisEquip_PickerLootScroll = lootScroll
    lootScroll:SetPoint("TOPLEFT", srcDropdown, "BOTTOMLEFT", DROPDOWN_ROW_OFFSET, -8)
    lootScroll:SetPoint("BOTTOMRIGHT", -(PICKER_SCROLL_INSET + 18), 176)
    if BiSPlanner_ApplyScrollBarStyle then BiSPlanner_ApplyScrollBarStyle(lootScroll) end
    f.lootScroll = lootScroll

    local lootChild = CreateFrame("Frame", nil, lootScroll)
    lootChild:SetSize(PICKER_WIDTH - 60, 100)
    lootScroll:SetScrollChild(lootChild)
    f.lootChild = lootChild

    f.msgLabel:SetPoint("CENTER", lootScroll, "CENTER", 0, 0)

    for i = 1, 80 do
        local row = CreateFrame("Button", nil, lootChild)
        row:SetSize(PICKER_WIDTH - 60, ITEM_ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ITEM_ROW_HEIGHT)
        if BiSPlanner_UI_ApplyClickable then BiSPlanner_UI_ApplyClickable(row, 4)
        elseif BisEquip_UI_ApplyClickable then BisEquip_UI_ApplyClickable(row, 4)
        else row:EnableMouse(true); row:RegisterForClicks("LeftButtonUp", "RightButtonUp"); row:SetHitRectInsets(-4, -4, -4, -4) end
        row:SetScript("OnClick", OnItemClick)
        row:SetScript("OnEnter", OnItemEnter)
        row:SetScript("OnLeave", OnItemLeave)
        row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        local bgTex = row:CreateTexture(nil, "BACKGROUND")
        bgTex:SetAllPoints()
        bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
        bgTex:SetVertexColor(0.12, 0.12, 0.12, 1)
        row.bgTex = bgTex

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(0.2, 0.2, 0.2, 0.8)
        row.icon = icon
        -- Icon overlay: texture doesn't receive mouse, button ensures tooltip on icon hover
        local iconBtn = CreateFrame("Button", nil, row)
        iconBtn:SetSize(36, 36)
        iconBtn:SetPoint("LEFT", 4, 0)
        iconBtn:SetScript("OnEnter", function()
            OnItemEnter(row)
        end)
        iconBtn:SetScript("OnLeave", function() end)

        local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLabel:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        nameLabel:SetPoint("RIGHT", row, "RIGHT", -52, 0)  -- leave space for ilvl at right
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetWordWrap(false)
        row.nameLabel = nameLabel

        local ilvlLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ilvlLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        ilvlLabel:SetJustifyH("RIGHT")
        ilvlLabel:SetWidth(40)
        row.ilvlLabel = ilvlLabel

        ITEM_BUTTONS[i] = row
    end

    -- Preview panel (comparison, expanded height)
    local previewPanel = CreateFrame("Frame", nil, f)
    previewPanel:SetPoint("BOTTOMLEFT", 12, 44)
    previewPanel:SetPoint("BOTTOMRIGHT", -36, 44)
    previewPanel:SetHeight(130)
    if BiSPlanner_ApplyPanelBackdrop then BiSPlanner_ApplyPanelBackdrop(previewPanel)
    elseif BisEquip_ApplyPanelBackdrop then BisEquip_ApplyPanelBackdrop(previewPanel)
    else BiSPlanner_ApplyPanelBackdropWithFallback(previewPanel) end
    f.previewPanel = previewPanel
    local previewTitle = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewTitle:SetPoint("TOPLEFT", 8, -6)
    previewTitle:SetText("Изменение статов при замене")
    f.previewTitle = previewTitle
    -- Preview: multi-column layout when stats overflow
    local previewCols = {}
    for i = 1, 4 do
        local col = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col:SetJustifyH("LEFT")
        col:SetJustifyV("TOP")
        col:SetWordWrap(true)
        col:SetNonSpaceWrap(false)
        if i == 1 then
            col:SetPoint("TOPLEFT", 8, -24)
        else
            col:SetPoint("TOPLEFT", previewCols[i - 1], "TOPRIGHT", 6, 0)
        end
        previewCols[i] = col
    end
    f.previewCols = previewCols
    f.previewText = previewCols[1]

    local clearBtn
    if BiSPlanner_CreateFlatButton then
        clearBtn = BiSPlanner_CreateFlatButton(f, 120, 22, "Очистить слот")
    else
        clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetText("Очистить слот")
    end
    clearBtn:SetSize(120, 22)
    clearBtn:SetPoint("BOTTOMLEFT", 12, 12)
    if BiSPlanner_UI_ApplyClickable then BiSPlanner_UI_ApplyClickable(clearBtn, 2)
    elseif BisEquip_UI_ApplyClickable then BisEquip_UI_ApplyClickable(clearBtn, 2)
    elseif not BiSPlanner_CreateFlatButton then clearBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    clearBtn:SetScript("OnClick", function()
        local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
        if slotId then
            if BiSPlanner then BiSPlanner:SetSlot(slotId, nil) elseif BisEquip then BisEquip:SetSlot(slotId, nil) end
            if BiSPlanner_UpdateSlot then BiSPlanner_UpdateSlot(slotId) elseif BisEquip_UpdateSlot then BisEquip_UpdateSlot(slotId) end
            if BiSPlanner_RefreshAllSlots then BiSPlanner_RefreshAllSlots() elseif BisEquip_RefreshAllSlots then BisEquip_RefreshAllSlots() end
        end
        f:Hide()
    end)

    if BiSPlanner_UI_EnableEscapeClose then BiSPlanner_UI_EnableEscapeClose(f)
    elseif BisEquip_UI_EnableEscapeClose then BisEquip_UI_EnableEscapeClose(f) end
    return f
end

function BiSPlanner_PreWarmItemPicker()
    BisEquip_PreWarmItemPicker = BiSPlanner_PreWarmItemPicker
    local f = CreatePickerFrame()
    if f then f:Hide() end
end

local ITEM_QUALITY_COLORS = { [0] = {1,1,1}, [1] = {1,1,0}, [2] = {0,1,0}, [3] = {0,0.5,1}, [4] = {0.5,0,1}, [5] = {1,0.5,0} }
local SL = BiSPlanner_StatLabels or BisEquip_StatLabels or {}
local DISPLAY_NAMES = SL.DISPLAY_NAMES or {}
local DISPLAY_NAMES_DATIVE = SL.DISPLAY_NAMES_DATIVE or {}

local COLOR_LOSS = "|cffff3333"
local COLOR_GAIN = "|cff33cc33"
local COLOR_END = "|r"

-- Stat output priority: 1=primary, 2=secondary, 3=sockets
local STAT_PRIORITY_ORDER = {
    ["ITEM_MOD_STAMINA_SHORT"] = 1, ["ITEM_MOD_STRENGTH_SHORT"] = 1,
    ["ITEM_MOD_AGILITY_SHORT"] = 1, ["ITEM_MOD_INTELLECT_SHORT"] = 1,
}
local PRIMARY_ORDER = { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT" }
local SOCKET_ORDER = { ["EMPTY_SOCKET_YELLOW"] = 1, ["EMPTY_SOCKET_RED"] = 2, ["EMPTY_SOCKET_BLUE"] = 3, ["EMPTY_SOCKET_META"] = 4 }
local function statSortKey(k)
    if k:find("EMPTY_SOCKET") then return 3, SOCKET_ORDER[k] or 5, k end
    local p = STAT_PRIORITY_ORDER[k] or 2
    local sub = 0
    for i, pk in ipairs(PRIMARY_ORDER) do if pk == k then sub = i break end end
    return p, sub, k
end

function BiSPlanner_RefreshPickerPreview(itemId)
    BisEquip_RefreshPickerPreview = BiSPlanner_RefreshPickerPreview
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    if not f or not f.previewText then return end
    if not itemId then
        f.previewText:SetText("Наведите на предмет для сравнения")
        if f.previewCols then
            for i = 2, 4 do f.previewCols[i]:Hide() end
        end
        return
    end
    local set = (BiSPlanner and BiSPlanner:GetCurrentSet()) or (BisEquip and BisEquip:GetCurrentSet())
    local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
    if not set or not slotId or not BiSPlanner_GetTotalStatsWithDelta then
        f.previewText:SetText("Наведите на предмет для сравнения")
        if f.previewCols then
            for i = 2, 4 do f.previewCols[i]:Hide() end
        end
        return
    end
    local currentItemId = (BiSPlanner and BiSPlanner:GetSlot(slotId)) or (BisEquip and BisEquip:GetSlot(slotId))
    local baseTotal = BiSPlanner_GetTotalStatsWithDelta(set, slotId, currentItemId)
    local newTotal = BiSPlanner_GetTotalStatsWithDelta(set, slotId, itemId)
    local getRatingDiv = BiSPlanner_GetRatingPercentDivisor or BisEquip_GetRatingPercentDivisor

    local lines = {}

    -- Only stats that exist on at least one of the two items (exclude stats that are 0 on both)
    local getStats = BiSPlanner_GetItemStats or BisEquip_GetItemStats
    local baseSlot = getStats and (currentItemId and getStats(currentItemId) or {}) or {}
    local newSlot = getStats and getStats(itemId) or {}
    local allKeys = {}
    for k, v in pairs(baseSlot) do
        if type(v) == "number" and v ~= 0 then allKeys[k] = true end
    end
    for k, v in pairs(newSlot) do
        if type(v) == "number" and v ~= 0 then allKeys[k] = true end
    end

    local entries = {}
    local hasArmorKey = allKeys["ARMOR"] or allKeys["ITEM_MOD_ARMOR_SHORT"]
    for k in pairs(allKeys) do
        if not (k == "RESISTANCE0_NAME" and hasArmorKey) then
            local baseVal = baseTotal[k] or 0
            local newVal = newTotal[k] or 0
            local delta = newVal - baseVal
            if delta ~= 0 then
                local name = DISPLAY_NAMES[k] or _G[k] or k
                local nameDative = DISPLAY_NAMES_DATIVE[k] or name:lower()
                local div = getRatingDiv and getRatingDiv(k)
                local suffix = ""
                if div and div > 0 then
                    local pct = delta / div
                    suffix = (" (%.2f%%)"):format(pct)
                end
                local text
                if k:find("EMPTY_SOCKET") then
                    text = ("%s%d %s%s"):format(delta > 0 and "+" or "", delta, name, suffix)
                else
                    text = ("%s%d к %s%s"):format(delta > 0 and "+" or "", delta, nameDative, suffix)
                end
                local line = (delta < 0 and COLOR_LOSS or COLOR_GAIN) .. text .. COLOR_END
                entries[#entries + 1] = { key = k, delta = delta, line = line }
            end
        end
    end

    table.sort(entries, function(a, b)
        local pa, sa, ka = statSortKey(a.key)
        local pb, sb, kb = statSortKey(b.key)
        if pa ~= pb then return pa < pb end
        if sa ~= sb then return sa < sb end
        return (a.delta < 0 and 0 or 1) < (b.delta < 0 and 0 or 1)  -- losses before gains
    end)
    for _, e in ipairs(entries) do lines[#lines + 1] = e.line end

    if #lines == 0 then
        lines[#lines + 1] = "Нет изменений статов."
    end

    -- Multi-column: flow to next column when height overflows
    local cols = f.previewCols
    local panel = f.previewPanel
    if cols and panel then
        local LINE_H = 10  -- GameFontHighlightSmall actual line height
        local padH, padV = 8, 22
        local padBottom = 2
        local gap = 6
        local panelW = math.max(100, panel:GetWidth() or 200)
        local panelH = math.max(60, panel:GetHeight() or 100)
        local availH = math.max(20, panelH - padV - padBottom)
        local linesPerCol = math.max(1, math.floor(availH / LINE_H))
        local numCols = math.min(4, math.max(1, math.ceil(#lines / linesPerCol)))
        local colW = math.max(120, math.floor((panelW - padH * 2 - gap * (numCols - 1)) / numCols))

        for i = 1, 4 do
            local col = cols[i]
            if i <= numCols then
                col:SetWidth(colW)
                col:Show()
                local startIdx = (i - 1) * linesPerCol + 1
                local endIdx = math.min(i * linesPerCol, #lines)
                local colLines = {}
                for j = startIdx, endIdx do colLines[#colLines + 1] = lines[j] end
                col:SetText(#colLines > 0 and table.concat(colLines, "\n") or "")
            else
                col:SetText("")
                col:Hide()
            end
        end
    else
        f.previewText:SetText(table.concat(lines, "\n"))
    end
end

local function RefreshPickerContent()
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    local slotId = BiSPlanner_PickerSlotId or BisEquip_PickerSlotId
    if not f or not slotId or not f.lootScroll or not f.lootChild then return end

    local src = PickerFilters.sourceSectionId
    local diff = PickerFilters.difficultyId
    local search = (f.searchEdit and f.searchEdit:GetText()) or ""
    search = tostring(search):gsub("^%s+", ""):gsub("%s+$", "")
    PickerFilters.searchText = search
    if f.msgLabel then f.msgLabel:SetShown((not src) and search == "") end

    if not src and search == "" then
        for i = 1, 80 do ITEM_BUTTONS[i]:Hide() end
        f.lootChild:SetHeight(1)
        return
    end

    local list = {}
    if BiSPlanner_GetItemsForSlot then
        list = src and (BiSPlanner_GetItemsForSlot(slotId, diff, src) or {}) or (BiSPlanner_GetItemsForSlot(slotId, nil, nil) or {})
    elseif BisEquip_GetItemsForSlot then
        list = src and (BisEquip_GetItemsForSlot(slotId, diff, src) or {}) or (BisEquip_GetItemsForSlot(slotId, nil, nil) or {})
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

    f.lootChild:SetSize(PICKER_WIDTH - 60, math.max(#filtered * ITEM_ROW_HEIGHT, 1))

    for i = 1, 80 do
        local row = ITEM_BUTTONS[i]
        if i <= #filtered then
            local itemId = filtered[i]
            row.itemId = itemId
            row:Show()
            local name, link, quality, itemLevel, _, _, _, _, equipSlot, texture = GetItemInfo(itemId)
            if texture then
                row.icon:SetTexture(texture)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                row.icon:SetTexture(0.3, 0.3, 0.3, 0.9)
            end
            local color = ITEM_QUALITY_COLORS[quality] or {1,1,1}
            row.nameLabel:SetText(name or ("Item " .. itemId))
            row.nameLabel:SetTextColor(color[1], color[2], color[3])
            row.ilvlLabel:SetText(itemLevel and tostring(itemLevel) or "—")
        else
            row.itemId = nil
            row:Hide()
        end
    end

    f.lootScroll:SetVerticalScroll(0)
end

local InitDifficultyDropdown

local function SelectSource(sectionId, displayName)
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    if not f then return end
    CloseDropDownMenus()
    PickerFilters.sourceSectionId = sectionId
    PickerFilters.difficultyId = nil
    if f.srcDropdown then
        UIDropDownMenu_SetSelectedValue(f.srcDropdown, sectionId)
        UIDropDownMenu_SetText(f.srcDropdown, displayName or "Выберите источник...")
    end
    if f.diffDropdown then InitDifficultyDropdown() end
    RefreshPickerContent()
end

local function SelectDifficulty(diffId, displayName)
    local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
    if not f then return end
    CloseDropDownMenus()
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
    if sourceId and BiSPlanner_GetSourceDifficulties then diffs = BiSPlanner_GetSourceDifficulties(sourceId) or {}
    elseif sourceId and BisEquip_GetSourceDifficulties then diffs = BisEquip_GetSourceDifficulties(sourceId) or {} end
    local hasDiffs = diffs and #diffs > 0
    if f.diffDropdown then f.diffDropdown:SetShown(hasDiffs) end
    if f.diffLabel then f.diffLabel:SetShown(hasDiffs) end
    -- Reposition loot list: below diff when shown, below src when hidden
    if f.lootScroll then
        f.lootScroll:ClearAllPoints()
        f.lootScroll:SetPoint("TOPLEFT", hasDiffs and f.diffDropdown or f.srcDropdown, "BOTTOMLEFT", DROPDOWN_ROW_OFFSET, -8)
        f.lootScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PICKER_SCROLL_INSET + 18), 176)
    end
    if not hasDiffs then PickerFilters.difficultyId = nil; return end
    UIDropDownMenu_Initialize(f.diffDropdown, function(self, level)
        if BiSPlanner_ScheduleDropDownListStyle then BiSPlanner_ScheduleDropDownListStyle()
        elseif BisEquip_ScheduleDropDownListStyle then BisEquip_ScheduleDropDownListStyle() end
        if (level or 1) ~= 1 then return end
        local anyInfo = UIDropDownMenu_CreateInfo()
        anyInfo.text = "Все"
        anyInfo.notCheckable = true
        anyInfo.value = ""
        anyInfo.func = function() SelectDifficulty(nil, "Все") end
        UIDropDownMenu_AddButton(anyInfo, 1)
        for _, d in ipairs(diffs) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = d.name or d.id
            info.notCheckable = true
            info.value = d.id
            info.func = function() SelectDifficulty(d.id, d.name or d.id) end
            UIDropDownMenu_AddButton(info, 1)
        end
    end)
    UIDropDownMenu_SetWidth(f.diffDropdown, 90)
    UIDropDownMenu_SetSelectedValue(f.diffDropdown, PickerFilters.difficultyId or "")
    if PickerFilters.difficultyId then
        local label = PickerFilters.difficultyId
        for _, d in ipairs(diffs) do
            if d.id == PickerFilters.difficultyId then label = d.name or d.id break end
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
        if BiSPlanner_ScheduleDropDownListStyle then BiSPlanner_ScheduleDropDownListStyle()
        elseif BisEquip_ScheduleDropDownListStyle then BisEquip_ScheduleDropDownListStyle() end
        level = level or 1
        local currentNodes = level == 1 and hierarchy or (UIDROPDOWNMENU_MENU_VALUE and UIDROPDOWNMENU_MENU_VALUE.children)
        if not currentNodes then return end
        for _, node in ipairs(currentNodes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = node.name or node.id
            info.notCheckable = true
            local hasChildren = node.children and #node.children > 0
            info.func = function() SelectSource(node.id, node.name) end
            if hasChildren then info.hasArrow = true; info.value = node
            else info.value = node.id end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(f.srcDropdown, 150)
    UIDropDownMenu_SetSelectedValue(f.srcDropdown, PickerFilters.sourceSectionId)
    local txt = "Выберите источник..."
    if PickerFilters.sourceSectionId then
        local flatSources = (BiSPlanner_GetSourcesForSlot and BiSPlanner_GetSourcesForSlot(slotId)) or (BisEquip_GetSourcesForSlot and BisEquip_GetSourcesForSlot(slotId)) or {}
        for _, s in ipairs(flatSources) do
            if s.id == PickerFilters.sourceSectionId then txt = s.name break end
        end
    end
    UIDropDownMenu_SetText(f.srcDropdown, txt)
end

function BiSPlanner_ShowItemPickerImpl(slotId, anchor)
    BisEquip_ShowItemPickerImpl = BiSPlanner_ShowItemPickerImpl
    if not BiSPlanner_GetItemsForSlot and not BisEquip_GetItemsForSlot then return end
    if not slotId then return end
    BiSPlanner_PickerSlotId = slotId
    BisEquip_PickerSlotId = slotId
    PickerFilters.sourceSectionId = nil
    PickerFilters.difficultyId = nil
    PickerFilters.searchText = ""

    local f = CreatePickerFrame()
    if not f then return end

    local slotName = (BiSPlanner_SlotNames and BiSPlanner_SlotNames[slotId]) or (BisEquip_SlotNames and BisEquip_SlotNames[slotId]) or ("Slot " .. slotId)
    if f.title then f.title:SetText("Выбор предмета: " .. slotName) end

    if f.searchEdit then
        f.searchEdit:SetText("")
        f.searchEdit:SetScript("OnTextChanged", function() RefreshPickerContent() end)
    end
    if f.previewText then f.previewText:SetText("Наведите на предмет для превью") end

    f:ClearAllPoints()
    local mainFrame = BiSPlanner_MainFrame or BisEquip_MainFrame
    if mainFrame and mainFrame:IsShown() and mainFrame:GetRight() then
        f:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 8, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
    end

    if BiSPlanner_UI_BringToFront then BiSPlanner_UI_BringToFront(f, "DIALOG", 10)
    elseif BisEquip_UI_BringToFront then BisEquip_UI_BringToFront(f, "DIALOG", 10)
    else
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 10)
        f:Raise()
    end
    f:Show()

    -- Defer heavy init to next frame so window appears instantly
    local defer = f._pickerDeferFrame
    if not defer then
        defer = CreateFrame("Frame", nil, f)
        local function doInit(self)
            self:SetScript("OnUpdate", nil)
            if f.srcDropdown then InitSourceDropdown() end
            if f.diffDropdown then InitDifficultyDropdown() end
            RefreshPickerContent()
        end
        defer._doInit = doInit
        f._pickerDeferFrame = defer
    end
    defer:SetScript("OnUpdate", defer._doInit)
end

-- Hook DropDownList1 SetPoint to override position when it's our picker's source dropdown
local function hookDropDownList1SetPoint()
    local list = _G.DropDownList1
    if not list or list.BiSPlanner_SetPointHooked then return end
    list.BiSPlanner_SetPointHooked = true
    local origSetPoint = list.SetPoint
    list.SetPoint = function(self, ...)
        origSetPoint(self, ...)
        local openMenu = _G.UIDROPDOWNMENU_OPEN_MENU
        if openMenu and openMenu.GetName then
            local n = openMenu:GetName()
            if (n == "BiSPlanner_PickerSrcDropdown" or n == "BisEquip_PickerSrcDropdown") and self:IsShown() then
                self:ClearAllPoints()
                origSetPoint(self, "TOPLEFT", openMenu, "BOTTOMLEFT", 20, 0)
            end
        end
    end
end
local hookDefer = CreateFrame("Frame")
hookDefer:SetScript("OnUpdate", function(self)
    if _G.DropDownList1 then
        self:SetScript("OnUpdate", nil)
        hookDropDownList1SetPoint()
    end
end)

do
    if hooksecurefunc then
        hooksecurefunc("ToggleDropDownMenu", function(level, value, dropdown)
            local name = dropdown and dropdown.GetName and dropdown:GetName()
            local isPickerDropdown = (name == "BiSPlanner_PickerSrcDropdown" or name == "BiSPlanner_PickerDiffDropdown" or name == "BisEquip_PickerSrcDropdown" or name == "BisEquip_PickerDiffDropdown")
            -- Hide msgLabel when picker dropdown is open so it doesn't overlap submenus
            local f = BiSPlanner_ItemPickerFrame or BisEquip_ItemPickerFrame
            if f and f.msgLabel then
                if level and level > 0 and isPickerDropdown and f:IsShown() then
                    f.msgLabel:Hide()
                elseif level == 0 and isPickerDropdown then
                    if RefreshPickerContent then RefreshPickerContent() end
                end
            end
            if level and level >= 1 and isPickerDropdown then
                FixDropdownListButtonHeights()
                for i = 1, (UIDROPDOWNMENU_MAXLEVELS or 3) do
                    local list = _G["DropDownList" .. i]
                    if list then
                        list:SetFrameStrata("FULLSCREEN_DIALOG")
                        list:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 20 + i)
                        if list == _G.DropDownList1 and dropdown then
                            local function repositionList()
                                if list and list:IsShown() then
                                    list:ClearAllPoints()
                                    if name == "BiSPlanner_PickerDiffDropdown" or name == "BisEquip_PickerDiffDropdown" then
                                        list:SetPoint("BOTTOM", dropdown, "TOP", 0, 2)
                                    else
                                        -- Align list left edge with "Выберите источник..." field
                                        list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, 0)
                                    end
                                end
                            end
                            -- Run on multiple frames to override Blizzard's position (they set it after our hook)
                            repositionList()
                            local updater = dropdown._listRepositionUpdater
                            if not updater then
                                updater = CreateFrame("Frame", nil, dropdown)
                                updater._count = 0
                                updater:SetScript("OnUpdate", function(self)
                                    repositionList()
                                    self._count = (self._count or 0) + 1
                                    if self._count >= 4 then self:SetScript("OnUpdate", nil) end
                                end)
                                dropdown._listRepositionUpdater = updater
                            end
                            updater._count = 0
                            updater:SetScript("OnUpdate", updater:GetScript("OnUpdate"))
                        end
                    end
                end
            end
        end)
    end
end
