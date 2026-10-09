-- ============================================================
-- Bar: the compact bar. For now only its glass pill and the "123" label,
-- so a deploy visibly loads; the buttons arrive with the bar issue. It
-- holds no secure buttons yet, so it may move at any time; once it does,
-- moving it in combat is refused (see AGENTS.md).
-- ============================================================

local _, ns = ...

local Bar = {}
ns.Bar = Bar

local WIDTH, HEIGHT = 96, 40

function Bar:ApplyPosition()
    local pos = ns.db.bar
    self.frame:ClearAllPoints()
    self.frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Bar:Initialize()
    local frame = CreateFrame("Frame", "OneTwoThreeBar", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    -- Shift-drag moves it, so a stray click never does.
    frame:SetScript("OnDragStart", function(f)
        if IsShiftKeyDown() then f:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        ns.db.bar = { point = point, x = x, y = y }
    end)
    self.frame = frame

    self.glass = ns.Skin:Pill(frame)
    local label = ns.Skin:Font(self.glass.top or frame, 16, "CENTER")
    label:SetPoint("CENTER")
    label:SetText("123")
    label:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    self.label = label

    self:ApplyPosition()
    frame:Show()
end

function Bar:Toggle()
    if not self.frame then return end
    self.frame:SetShown(not self.frame:IsShown())
end
