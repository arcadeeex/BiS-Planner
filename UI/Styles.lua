--[[
BiSPlanner - ElvUI × WotLK style palette and layout constants.
Design: design.txt wireframes.
]]

-- Palette (RGBA 0-1)
BiSPlanner_Styles = BiSPlanner_Styles or {}
local S = BiSPlanner_Styles

S.BG_MAIN      = { 0.08, 0.08, 0.09, 0.95 }
S.BG_PANEL     = { 0.12, 0.12, 0.13, 1 }
S.BORDER       = { 0.20, 0.20, 0.22, 1 }
S.TEXT_NORMAL  = { 0.75, 0.75, 0.78, 1 }
S.TEXT_VALUE   = { 0.90, 0.90, 0.90, 1 }
S.GREEN        = { 0.20, 0.80, 0.20, 1 }
S.RED          = { 0.85, 0.20, 0.20, 1 }
S.YELLOW       = { 1.00, 0.82, 0.00, 1 }
S.BLUE         = { 0.20, 0.60, 1.00, 1 }
S.PALADIN_GOLD = { 1.00, 0.85, 0.30, 1 }

-- Layout
S.PADDING_OUTER   = 12
S.PADDING_BLOCK   = 8
S.ROW_HEIGHT      = 18
S.CARD_HEADER     = 24
S.SLOT_SIZE       = 40
S.SLOT_GAP        = 8
S.SLOT_CELL       = S.SLOT_SIZE + S.SLOT_GAP  -- 48
S.SLOT_COLUMN_GAP = 28  -- space between left and right columns (ElvUI-like)

-- Main window (reduced width, height fits equipment + stats)
S.MAIN_WIDTH      = 560
S.MAIN_HEIGHT     = 600
S.HEADER_HEIGHT   = 32
S.TOPBAR_HEIGHT   = 36
S.BOTTOMBAR_HEIGHT = 40

-- Gear panel (height includes bottom padding)
S.GEAR_PANEL_WIDTH  = 260
S.GEAR_PANEL_HEIGHT = 420

-- Item picker (width -200 from original, height matches main window)
S.PICKER_WIDTH   = 420
S.PICKER_HEIGHT  = S.MAIN_HEIGHT or 600
S.ITEM_ROW_HEIGHT = 42

-- Solid texture for custom backdrops (WoW 3.3.5)
local SOLID_TEX = "Interface\\Buttons\\WHITE8x8"
-- ElvUI-style highlight (gradient, same as ElvUI Dropdown.lua / HandleButtonHighlight)
local HIGHLIGHT_TEX = [[Interface\QuestFrame\UI-QuestTitleHighlight]]

function BiSPlanner_ApplyPanelBackdropWithFallback(frame)
    BisEquip_ApplyPanelBackdropWithFallback = BiSPlanner_ApplyPanelBackdropWithFallback
    if not frame then return end
    frame:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true,
        tileSize = 8,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(0.12, 0.12, 0.13, 1)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.22, 1)
end

function BiSPlanner_ApplyPanelBackdrop(frame, r, g, b, a)
    if not frame then return end
    local c = BiSPlanner_Styles or S
    r = r or (c.BG_PANEL and c.BG_PANEL[1]) or 0.12
    g = g or (c.BG_PANEL and c.BG_PANEL[2]) or 0.12
    b = b or (c.BG_PANEL and c.BG_PANEL[3]) or 0.13
    a = a or (c.BG_PANEL and c.BG_PANEL[4]) or 1
    frame:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true,
        tileSize = 8,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(c.BORDER[1], c.BORDER[2], c.BORDER[3], c.BORDER[4])
end

function BiSPlanner_ApplyMainBackdropWithFallback(frame)
    BisEquip_ApplyMainBackdropWithFallback = BiSPlanner_ApplyMainBackdropWithFallback
    if not frame then return end
    frame:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true,
        tileSize = 8,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(0.08, 0.08, 0.09, 0.95)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.22, 1)
end

function BiSPlanner_ApplyMainBackdrop(frame)
    if not frame then return end
    local c = BiSPlanner_Styles or S
    frame:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true,
        tileSize = 8,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(c.BG_MAIN[1], c.BG_MAIN[2], c.BG_MAIN[3], c.BG_MAIN[4])
    frame:SetBackdropBorderColor(c.BORDER[1], c.BORDER[2], c.BORDER[3], c.BORDER[4])
end

-- Create flat-style button (ElvUI-like dark flat)
function BiSPlanner_CreateFlatButton(parent, w, h, text)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 100, h or 22)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(SOLID_TEX)
    bg:SetVertexColor(0.18, 0.18, 0.2, 1)
    btn.bgTex = bg
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text or "")
    label:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
    btn:SetScript("OnEnter", function()
        if btn.bgTex then btn.bgTex:SetVertexColor(0.25, 0.25, 0.27, 1) end
        if label then label:SetTextColor(1, 1, 1) end
    end)
    btn:SetScript("OnLeave", function()
        if btn.bgTex then btn.bgTex:SetVertexColor(0.18, 0.18, 0.2, 1) end
        if label then label:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3]) end
    end)
    btn.SetText = function(self, t) if label then label:SetText(t or "") end end
    btn.GetText = function(self) return label and label:GetText() or "" end
    return btn
end

-- ElvUI-style flat dropdown (for UIDropDownMenuTemplate)
function BiSPlanner_ApplyDropDownStyle(frame)
    if not frame or frame.BiSPlanner_DropDownStyled then return end
    local name = frame:GetName()
    if not name then return end
    local btn = _G[name .. "Button"]
    local text = _G[name .. "Text"]
    local left = _G[name .. "Left"]
    local middle = _G[name .. "Middle"]
    local right = _G[name .. "Right"]
    if left then left:SetAlpha(0) end
    if middle then middle:SetAlpha(0) end
    if right then right:SetAlpha(0) end
    local backdrop = CreateFrame("Frame", nil, frame)
    backdrop:SetFrameLevel(frame:GetFrameLevel())
    backdrop:SetPoint("TOPLEFT", 20, -3)
    backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    backdrop:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    backdrop:SetBackdropColor(S.BG_PANEL[1], S.BG_PANEL[2], S.BG_PANEL[3], S.BG_PANEL[4])
    backdrop:SetBackdropBorderColor(S.BORDER[1], S.BORDER[2], S.BORDER[3], S.BORDER[4])
    frame.BiSPlanner_DropDownBackdrop = backdrop
    if text then
        text:ClearAllPoints()
        text:SetPoint("RIGHT", backdrop, "RIGHT", -24, 0)
        text:SetPoint("LEFT", backdrop, "LEFT", 6, 0)
        text:SetJustifyH("LEFT")
        text:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
    end
    if btn then
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -2, -2)
        btn:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -2, 2)
        btn:SetSize(20, 20)
        if btn.Left then btn.Left:SetAlpha(0) end
        if btn.Middle then btn.Middle:SetAlpha(0) end
        if btn.Right then btn.Right:SetAlpha(0) end
        if btn.SetNormalTexture then btn:SetNormalTexture("") end
        if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
        if btn.SetPushedTexture then btn:SetPushedTexture("") end
        if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
        local arrowBg = btn:CreateTexture(nil, "BACKGROUND")
        arrowBg:SetAllPoints()
        arrowBg:SetTexture(SOLID_TEX)
        arrowBg:SetVertexColor(0.18, 0.18, 0.2, 1)
        btn.BiSPlanner_ArrowBg = arrowBg
        local arrowText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrowText:SetPoint("CENTER", 0, 0)
        arrowText:SetText("▼")
        arrowText:SetTextColor(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3])
        arrowText:SetFont(arrowText:GetFont(), 10, "OUTLINE")
        btn.BiSPlanner_ArrowText = arrowText
        local origOnEnter = btn:GetScript("OnEnter")
        local origOnLeave = btn:GetScript("OnLeave")
        btn:SetScript("OnEnter", function()
            if arrowBg then arrowBg:SetVertexColor(0.25, 0.25, 0.27, 1) end
            if arrowText then arrowText:SetTextColor(1, 0.9, 0.5, 1) end
            if origOnEnter then origOnEnter(btn) end
        end)
        btn:SetScript("OnLeave", function()
            if arrowBg then arrowBg:SetVertexColor(0.18, 0.18, 0.2, 1) end
            if arrowText then arrowText:SetTextColor(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3]) end
            if origOnLeave then origOnLeave(btn) end
        end)
    end
    frame.BiSPlanner_DropDownStyled = true
end

-- ElvUI-style flat dropdown list (DropDownList1, 2, 3 - shared by UIDropDownMenu)
local function styleDropDownList(list)
    if not list then return end
    local name = list:GetName()
    if not name then return end
    -- Hide default ornate textures/regions on list
    for i = 1, list:GetNumRegions() do
        local r = select(i, list:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") then
            r:SetAlpha(0)
        end
    end
    -- MenuBackdrop / backdrop frames - hide ornate border
    local backdrop = _G[name .. "MenuBackdrop"]
    if backdrop then
        backdrop:SetAlpha(0)
        for i = 1, backdrop:GetNumRegions() do
            local r = select(i, backdrop:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
        end
    end
    -- Hide any backdrop-like child frames (e.g. Blizzard NineSlice)
    for i = 1, list:GetNumChildren() do
        local child = select(i, list:GetChildren())
        if child and child.GetName then
            local cname = child:GetName() or ""
            if cname:find("Backdrop") or cname:find("Border") or cname:find("Edge") or cname:find("Corner") then
                child:SetAlpha(0)
            end
        end
    end
    -- Clear list's own backdrop if any, we use overlay
    if list.SetBackdrop then list:SetBackdrop(nil) end
    -- Flat backdrop overlay (create once, behind buttons) - ElvUI Transparent style
    -- ElvUI uses backdropfadecolor ~(0.05-0.06, 0.05-0.06, 0.05-0.06, 0.8)
    if not list.BiSPlanner_ListOverlay then
        local overlay = CreateFrame("Frame", nil, list)
        overlay:SetFrameLevel(0)
        overlay:SetAllPoints()
        overlay:SetBackdrop({
            bgFile = SOLID_TEX,
            edgeFile = SOLID_TEX,
            tile = true, tileSize = 8, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        overlay:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        overlay:SetBackdropBorderColor(S.BORDER[1], S.BORDER[2], S.BORDER[3], S.BORDER[4])
        list.BiSPlanner_ListOverlay = overlay
    end
    list.BiSPlanner_ListOverlay:Show()
    -- Style buttons
    local maxBtns = UIDROPDOWNMENU_MAXBUTTONS or 20
    for i = 1, maxBtns do
        local btn = _G[name .. "Button" .. i]
        if btn then
            local l, m, r = _G[name .. "Button" .. i .. "Left"], _G[name .. "Button" .. i .. "Middle"], _G[name .. "Button" .. i .. "Right"]
            if l then l:SetAlpha(0) end
            if m then m:SetAlpha(0) end
            if r then r:SetAlpha(0) end
            -- Style Check/UnCheck (radio icons) - ElvUI colors
            local check = _G[name .. "Button" .. i .. "Check"]
            local uncheck = _G[name .. "Button" .. i .. "UnCheck"]
            if check then
                check:SetVertexColor(S.YELLOW[1], S.YELLOW[2], S.YELLOW[3])
            end
            if uncheck then
                uncheck:SetVertexColor(0.40, 0.40, 0.43, 1)
            end
            if not btn.BiSPlanner_ListBtnStyled then
                -- ElvUI HandleButtonHighlight: use gradient + light color (0.9, 0.9, 0.9, 0.35)
                local hl = _G[name .. "Button" .. i .. "Highlight"]
                if hl and hl.SetTexture then
                    hl:SetTexture(HIGHLIGHT_TEX)
                    hl:SetBlendMode("ADD")
                    hl:SetVertexColor(0.9, 0.9, 0.9, 0.35)
                else
                    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
                    hl = btn:CreateTexture(nil, "OVERLAY")
                    hl:SetAllPoints()
                    hl:SetTexture(HIGHLIGHT_TEX)
                    hl:SetBlendMode("ADD")
                    hl:SetVertexColor(0.9, 0.9, 0.9, 0.35)
                    btn:SetHighlightTexture(hl)
                end
                btn.BiSPlanner_ListBtnStyled = true
            end
            -- Ensure text color
            local normalText = _G[name .. "Button" .. i .. "NormalText"]
            if normalText then
                normalText:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
            end
        end
    end
end

-- Offset for sub-menus: 0 = submenu directly adjacent to parent (level 2, 3)
local DROPDOWN_SUBMENU_OFFSET_X = 0

local subMenuRepositionFrame
local function repositionSubMenuDeferred(list)
    if not list or not list:IsShown() then return end
    local point, relTo, relPoint, x, y = list:GetPoint(1)
    if point and relTo then
        list:ClearAllPoints()
        list:SetPoint(point, relTo, relPoint or point, (x or 0) + DROPDOWN_SUBMENU_OFFSET_X, y or 0)
    end
end

local function hookSubMenuSetPoint()
    for lvl = 2, (UIDROPDOWNMENU_MAXLEVELS or 3) do
        local list = _G["DropDownList" .. lvl]
        if list and list.SetPoint and not list.BiSPlanner_SetPointHooked then
            list.BiSPlanner_SetPointHooked = true
            local orig = list.SetPoint
            list.SetPoint = function(self, a1, a2, a3, a4, a5)
                if type(a3) == "string" then
                    orig(self, a1, a2, a3, (a4 or 0) + DROPDOWN_SUBMENU_OFFSET_X, a5)
                elseif type(a2) == "number" then
                    orig(self, a1, (a2 or 0) + DROPDOWN_SUBMENU_OFFSET_X, a3)
                else
                    orig(self, a1, a2, a3, a4, a5)
                end
            end
        end
    end
end

local installDropDownListStyleHook_done = false
local function installDropDownListStyleHook()
    if installDropDownListStyleHook_done then return end
    installDropDownListStyleHook_done = true
    -- Hook SetPoint on sub-menus so we add offset at the source
    local function tryHook()
        if _G.DropDownList2 then
            hookSubMenuSetPoint()
            return true
        end
        return false
    end
    if not tryHook() then
        local f = CreateFrame("Frame")
        f:SetScript("OnUpdate", function(self)
            if tryHook() then self:SetScript("OnUpdate", nil) end
        end)
    end
    -- Method 1: Hook ToggleDropDownMenu - runs when any dropdown opens
    hooksecurefunc("ToggleDropDownMenu", function(level, value, dropdown)
        if level and level > 0 then
            local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 3
            local needsReposition = false
            for lvl = 1, maxLevels do
                local list = _G["DropDownList" .. lvl]
                if list and list:IsShown() then
                    styleDropDownList(list)
                    if lvl >= 2 then needsReposition = true end
                end
            end
            if needsReposition then
                if not subMenuRepositionFrame then
                    subMenuRepositionFrame = CreateFrame("Frame")
                end
                subMenuRepositionFrame:SetScript("OnUpdate", function(self)
                    self:SetScript("OnUpdate", nil)
                    for lvl = 2, (UIDROPDOWNMENU_MAXLEVELS or 3) do
                        local list = _G["DropDownList" .. lvl]
                        if list then repositionSubMenuDeferred(list) end
                    end
                end)
            end
        end
    end)
    -- Method 2: Hook OnShow on each list (backup) - skip if frame doesn't support it
    local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 3
    for lvl = 1, maxLevels do
        local list = _G["DropDownList" .. lvl]
        if list and list.HookScript then
            local ok = pcall(function()
                list:HookScript("OnShow", function()
                    styleDropDownList(list)
                end)
            end)
            if not ok then
                -- DropDownList frames may not support HookScript; Method 1 (ToggleDropDownMenu hook) handles styling
            end
        end
    end
end

-- Style visible dropdown lists (call when list is shown)
function BiSPlanner_StyleDropDownList()
    for lvl = 1, (UIDROPDOWNMENU_MAXLEVELS or 3) do
        local list = _G["DropDownList" .. lvl]
        if list and list:IsShown() then
            styleDropDownList(list)
        end
    end
end
BisEquip_StyleDropDownList = BiSPlanner_StyleDropDownList

-- Call at start of UIDropDownMenu_Initialize callback to style list on next frame
function BiSPlanner_ScheduleDropDownListStyle()
    local fn = BiSPlanner_StyleDropDownList or BisEquip_StyleDropDownList
    if fn then
        local f = CreateFrame("Frame")
        local count = 0
        f:SetScript("OnUpdate", function(self)
            count = count + 1
            fn()
            if count >= 2 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end
BisEquip_ScheduleDropDownListStyle = BiSPlanner_ScheduleDropDownListStyle
-- Install as soon as ToggleDropDownMenu exists; retry until DropDownList1 exists
local function tryInstall()
    if not _G.ToggleDropDownMenu then return false end
    if _G.DropDownList1 then
        installDropDownListStyleHook()
        return true
    end
    return false
end
local defer = CreateFrame("Frame")
defer:SetScript("OnUpdate", function(self)
    if tryInstall() then
        self:SetScript("OnUpdate", nil)
    end
end)

-- ElvUI-style StaticPopup (save set dialog etc.)
function BiSPlanner_ApplyStaticPopupStyle(popup)
    if not popup or popup.BiSPlanner_PopupStyled then return end
    local name = popup:GetName()
    if not name then return end
    -- Main frame: hide ornate textures, apply flat backdrop
    for i = 1, popup:GetNumRegions() do
        local r = select(i, popup:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") then
            r:SetAlpha(0)
        end
    end
    if popup.SetBackdrop then popup:SetBackdrop(nil) end
    local overlay = CreateFrame("Frame", nil, popup)
    overlay:SetFrameLevel(popup:GetFrameLevel() - 1)
    overlay:SetAllPoints()
    overlay:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    overlay:SetBackdropColor(S.BG_MAIN[1], S.BG_MAIN[2], S.BG_MAIN[3], S.BG_MAIN[4])
    overlay:SetBackdropBorderColor(S.BORDER[1], S.BORDER[2], S.BORDER[3], S.BORDER[4])
    popup.BiSPlanner_PopupOverlay = overlay
    -- Text label
    local text = _G[name .. "Text"]
    if text then
        text:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
    end
    -- EditBox
    local editBox = _G[name .. "EditBox"] or popup.editBox
    if editBox then
        local ebName = editBox:GetName()
        for _, key in ipairs({"Left", "Middle", "Right", "Mid"}) do
            local tex = (ebName and _G[ebName .. key]) or editBox[key]
            if tex then tex:SetAlpha(0) end
        end
        for i = 1, editBox:GetNumRegions() do
            local r = select(i, editBox:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
        end
        if not editBox.BiSPlanner_EditBoxStyled then
            local ebBg = CreateFrame("Frame", nil, editBox)
            ebBg:SetFrameLevel(editBox:GetFrameLevel() - 1)
            ebBg:SetPoint("TOPLEFT", -2, -4)
            ebBg:SetPoint("BOTTOMRIGHT", 2, 4)
            ebBg:SetBackdrop({
                bgFile = SOLID_TEX,
                edgeFile = SOLID_TEX,
                tile = true, tileSize = 8, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            ebBg:SetBackdropColor(S.BG_PANEL[1], S.BG_PANEL[2], S.BG_PANEL[3], S.BG_PANEL[4])
            ebBg:SetBackdropBorderColor(S.BORDER[1], S.BORDER[2], S.BORDER[3], S.BORDER[4])
            editBox.BiSPlanner_EditBoxBackdrop = ebBg
            editBox:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
            editBox.BiSPlanner_EditBoxStyled = true
        end
    end
    -- Buttons (Button1, Button2)
    for j = 1, 4 do
        local btn = _G[name .. "Button" .. j]
        if btn and not btn.BiSPlanner_PopupBtnStyled then
            local btnName = btn:GetName()
            for _, key in ipairs({"Left", "Middle", "Right"}) do
                local tex = (btnName and _G[btnName .. key]) or btn[key]
                if tex then tex:SetAlpha(0) end
            end
            if btn.SetNormalTexture then btn:SetNormalTexture("") end
            if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
            if btn.SetPushedTexture then btn:SetPushedTexture("") end
            if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(SOLID_TEX)
            bg:SetVertexColor(0.18, 0.18, 0.2, 1)
            btn.BiSPlanner_Bg = bg
            local label = btn:GetFontString()
            if label then
                label:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
            end
            btn:SetScript("OnEnter", function()
                if btn.BiSPlanner_Bg then btn.BiSPlanner_Bg:SetVertexColor(0.25, 0.25, 0.27, 1) end
                local l = btn:GetFontString()
                if l then l:SetTextColor(1, 1, 1) end
            end)
            btn:SetScript("OnLeave", function()
                if btn.BiSPlanner_Bg then btn.BiSPlanner_Bg:SetVertexColor(0.18, 0.18, 0.2, 1) end
                local l = btn:GetFontString()
                if l then l:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3]) end
            end)
            btn.BiSPlanner_PopupBtnStyled = true
        end
    end
    popup.BiSPlanner_PopupStyled = true
end
BisEquip_ApplyStaticPopupStyle = BiSPlanner_ApplyStaticPopupStyle

-- ElvUI-style EditBox (search, input fields) - integrated with frame, no "default box" look
function BiSPlanner_ApplyEditBoxStyle(editBox)
    if not editBox or editBox.BiSPlanner_EditBoxStyled then return end
    local name = editBox:GetName()
    for _, key in ipairs({"Left", "Middle", "Right", "Mid"}) do
        local tex = (name and _G[name .. key]) or editBox[key]
        if tex then tex:SetAlpha(0) end
    end
    local ebBg = CreateFrame("Frame", nil, editBox)
    ebBg:SetFrameLevel(editBox:GetFrameLevel() - 1)
    ebBg:SetPoint("TOPLEFT", -1, -2)
    ebBg:SetPoint("BOTTOMRIGHT", 1, 2)
    ebBg:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    ebBg:SetBackdropColor(S.BG_MAIN[1], S.BG_MAIN[2], S.BG_MAIN[3], S.BG_MAIN[4])
    ebBg:SetBackdropBorderColor(S.BORDER[1], S.BORDER[2], S.BORDER[3], S.BORDER[4])
    editBox.BiSPlanner_EditBoxBackdrop = ebBg
    editBox:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetTextInsets(6, 0, 6, 0)
    editBox.BiSPlanner_EditBoxStyled = true
end
BisEquip_ApplyEditBoxStyle = BiSPlanner_ApplyEditBoxStyle

-- Flat search box: only flat backdrop, no default InputBox 3D styling; keep cursor visible
function BiSPlanner_ApplySearchBoxStyle(editBox)
    if not editBox or editBox.BiSPlanner_SearchBoxStyled then return end
    local name = editBox:GetName()
    -- Hide border textures (Left, Middle, Right, Mid) - removes 3D look, keeps cursor visible
    for _, key in ipairs({"Left", "Middle", "Right", "Mid"}) do
        local tex = (name and _G[name .. key]) or editBox[key]
        if tex then tex:SetAlpha(0) end
    end
    -- Single flat backdrop
    local ebBg = CreateFrame("Frame", nil, editBox)
    ebBg:SetFrameLevel(editBox:GetFrameLevel() - 1)
    ebBg:SetPoint("TOPLEFT", editBox, "TOPLEFT", -2, -3)
    ebBg:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 2, 3)
    ebBg:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    ebBg:SetBackdropColor(S.BG_PANEL[1], S.BG_PANEL[2], S.BG_PANEL[3], S.BG_PANEL[4])
    ebBg:SetBackdropBorderColor(S.BORDER[1], S.BORDER[2], S.BORDER[3], S.BORDER[4])
    editBox.BiSPlanner_EditBoxBackdrop = ebBg
    editBox:SetTextColor(S.TEXT_VALUE[1], S.TEXT_VALUE[2], S.TEXT_VALUE[3])
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetTextInsets(8, 10, 6, 6)
    -- Focus indication: brighter border when focused
    editBox:SetScript("OnEditFocusGained", function(self)
        if ebBg and ebBg.SetBackdropBorderColor then
            ebBg:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
        end
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        if ebBg and ebBg.SetBackdropBorderColor then
            ebBg:SetBackdropBorderColor(S.BORDER[1], S.BORDER[2], S.BORDER[3], S.BORDER[4])
        end
    end)
    editBox.BiSPlanner_SearchBoxStyled = true
end
BisEquip_ApplySearchBoxStyle = BiSPlanner_ApplySearchBoxStyle

-- ElvUI-style flat scrollbar (for UIPanelScrollFrameTemplate)
function BiSPlanner_ApplyScrollBarStyle(scrollFrame)
    if not scrollFrame or scrollFrame.BiSPlanner_ScrollBarStyled then return end
    local name = scrollFrame:GetName()
    if not name then return end
    local scrollBar = _G[name .. "ScrollBar"]
    if not scrollBar then return end
    local sbName = scrollBar:GetName()
    if not sbName then return end
    local upBtn = _G[sbName .. "ScrollUpButton"]
    local downBtn = _G[sbName .. "ScrollDownButton"]
    local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture() or _G[sbName .. "ThumbTexture"]
    -- Hide default textures
    for i = 1, scrollBar:GetNumRegions() do
        local r = select(i, scrollBar:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") then
            r:SetAlpha(0)
        end
    end
    if thumb then thumb:SetAlpha(0) end
    -- Flat dark track
    local track = CreateFrame("Frame", nil, scrollBar)
    track:SetPoint("TOP", upBtn and upBtn or scrollBar, "BOTTOM", 0, 0)
    track:SetPoint("BOTTOM", downBtn and downBtn or scrollBar, "TOP", 0, 0)
    track:SetPoint("LEFT", scrollBar, "LEFT", 0, 0)
    track:SetPoint("RIGHT", scrollBar, "RIGHT", 0, 0)
    track:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    track:SetBackdropColor(0.08, 0.08, 0.09, 1)
    track:SetBackdropBorderColor(0.15, 0.15, 0.16, 1)
    scrollBar.BiSPlanner_Track = track
    -- Flat thumb (light grey draggable part)
    local thumbBg = CreateFrame("Frame", nil, scrollBar)
    thumbBg:SetFrameLevel(scrollBar:GetFrameLevel() + 2)
    thumbBg:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    thumbBg:SetBackdropColor(0.45, 0.45, 0.48, 1)
    thumbBg:SetBackdropBorderColor(0.25, 0.25, 0.27, 1)
    scrollBar.BiSPlanner_ThumbBg = thumbBg
    local function updateThumb()
        if not thumb or not thumbBg then return end
        thumbBg:ClearAllPoints()
        thumbBg:SetPoint("TOPLEFT", thumb, "TOPLEFT", 1, -1)
        thumbBg:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -1, 1)
        thumbBg:SetShown(thumb.IsShown and thumb:IsShown())
    end
    if scrollBar.HookScript then
        scrollBar:HookScript("OnValueChanged", updateThumb)
        scrollBar:HookScript("OnShow", updateThumb)
    end
    if scrollFrame.HookScript then
        scrollFrame:HookScript("OnShow", updateThumb)
    end
    updateThumb()
    -- Flat up/down buttons with chevrons
    local function styleScrollBtn(btn, arrow)
        if not btn or btn.BiSPlanner_Styled then return end
        if btn.SetNormalTexture then btn:SetNormalTexture("") end
        if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
        if btn.SetPushedTexture then btn:SetPushedTexture("") end
        if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
        for i = 1, btn:GetNumRegions() do
            local r = select(i, btn:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
        end
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(SOLID_TEX)
        bg:SetVertexColor(0.12, 0.12, 0.13, 1)
        btn.BiSPlanner_Bg = bg
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("CENTER", 0, 0)
        txt:SetText(arrow)
        txt:SetTextColor(0.75, 0.75, 0.78, 1)
        txt:SetFont(txt:GetFont(), 10, "OUTLINE")
        btn.BiSPlanner_Arrow = txt
        btn:SetScript("OnEnter", function()
            if bg then bg:SetVertexColor(0.2, 0.2, 0.22, 1) end
            if txt then txt:SetTextColor(0.95, 0.95, 0.95, 1) end
        end)
        btn:SetScript("OnLeave", function()
            if bg then bg:SetVertexColor(0.12, 0.12, 0.13, 1) end
            if txt then txt:SetTextColor(0.75, 0.75, 0.78, 1) end
        end)
        btn.BiSPlanner_Styled = true
    end
    styleScrollBtn(upBtn, "▲")
    styleScrollBtn(downBtn, "▼")
    scrollBar:SetWidth(14)
    scrollFrame.BiSPlanner_ScrollBarStyled = true
end

-- Backward compatibility
BisEquip_Styles = BiSPlanner_Styles
BisEquip_ApplyPanelBackdrop = BiSPlanner_ApplyPanelBackdrop
BisEquip_ApplyMainBackdrop = BiSPlanner_ApplyMainBackdrop
BisEquip_ApplyDropDownStyle = BiSPlanner_ApplyDropDownStyle
BisEquip_ApplyScrollBarStyle = BiSPlanner_ApplyScrollBarStyle
BisEquip_ApplyStaticPopupStyle = BiSPlanner_ApplyStaticPopupStyle
BisEquip_ApplyEditBoxStyle = BiSPlanner_ApplyEditBoxStyle
