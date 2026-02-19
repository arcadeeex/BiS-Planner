--[[
BisEquip UI compatibility helpers.
Provides reusable click/strata/dropdown behavior inspired by stable addon patterns.
]]

local function SafeGetLevel(frame)
    if frame and frame.GetFrameLevel then
        return frame:GetFrameLevel() or 0
    end
    return 0
end

function BisEquip_UI_ApplyClickable(frame, expandPx)
    if not frame then return end
    frame:EnableMouse(true)
    if frame.RegisterForClicks then
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    if expandPx and frame.SetHitRectInsets then
        frame:SetHitRectInsets(-expandPx, -expandPx, -expandPx, -expandPx)
    end
end
BiSPlanner_UI_ApplyClickable = BisEquip_UI_ApplyClickable

function BisEquip_UI_BringToFront(frame, strata, levelOffset)
    if not frame then return end
    frame:SetFrameStrata(strata or "DIALOG")
    local base = SafeGetLevel(UIParent)
    frame:SetFrameLevel(base + (levelOffset or 10))
    if frame.Raise then
        frame:Raise()
    end
end
BiSPlanner_UI_BringToFront = BisEquip_UI_BringToFront

function BisEquip_UI_EnableEscapeClose(frame)
    if not frame or not frame.GetName then return end
    local name = frame:GetName()
    if not name then return end
    UISpecialFrames = UISpecialFrames or {}
    local exists = false
    for _, n in ipairs(UISpecialFrames) do
        if n == name then
            exists = true
            break
        end
    end
    if not exists then
        table.insert(UISpecialFrames, name)
    end
end
BiSPlanner_UI_EnableEscapeClose = BisEquip_UI_EnableEscapeClose

function BisEquip_UI_FixDropDownLists(buttonHeight)
    local h = buttonHeight or 20
    local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 3
    local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 20
    for level = 1, maxLevels do
        local list = _G["DropDownList" .. level]
        if list then
            list:SetFrameStrata("FULLSCREEN_DIALOG")
            list:SetFrameLevel(SafeGetLevel(UIParent) + 20 + level)
        end
        for i = 1, maxButtons do
            local btn = _G["DropDownList" .. level .. "Button" .. i]
            if btn then
                btn:SetHeight(h)
            end
        end
    end
end
BiSPlanner_UI_FixDropDownLists = BisEquip_UI_FixDropDownLists

function BisEquip_UI_InitDropDown(dropdown, width, initializer, menuType)
    if not dropdown then return end
    if width and UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, width)
    end
    if UIDropDownMenu_Initialize and initializer then
        UIDropDownMenu_Initialize(dropdown, initializer, menuType)
    end
end

function BisEquip_UI_HasMSADropDown()
    return type(MSA_DropDownMenu_Initialize) == "function"
end

