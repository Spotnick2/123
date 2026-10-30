-- ============================================================
-- The summon queue on screen (#9): a small glass list above the bar's
-- Summoning button, shown while someone waits. Each row: the name in its
-- class colour, how long they've waited or where their summon is (#10),
-- and an x to drop them.
--
-- Nothing here is secure, and the list hangs from UIParent at coordinates
-- read off the Summoning button, never anchored to the bar (a frame
-- anchored to a protected one could be restricted in combat): rows can come
-- and go in combat, which is when people ask.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local L = ns.L

local QueueList = {}
ns.QueueList = QueueList

local WIDTH, ROW, PAD, HEADER = 220, 18, 8, 18
local MAX_ROWS = 8

local function age(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then return L["%ds"]:format(seconds) end
    return L["%dm"]:format(math.floor(seconds / 60))
end

-- Where a summon is, in place of the wait time (#10). "next" is whom the
-- Summoning button is aimed at now.
local STATE = {
    next = L["next"],
    summoning = L["summoning"],
    pending = L["pending"],
    accepted = L["accepted"],
    declined = L["declined"],
    here = L["here"],
}

local function classColor(class)
    local c = class and RAID_CLASS_COLORS[class]
    if type(c) == "table" then return c.r, c.g, c.b end
    return 1, 1, 1
end

function QueueList:CreateRow(i)
    local top = self.glass.top or self.frame
    local row = CreateFrame("Frame", nil, self.frame)
    row:SetSize(WIDTH - PAD * 2, ROW)
    row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -(PAD + HEADER + (i - 1) * ROW))
    row:SetFrameLevel(top:GetFrameLevel() + 1)
    row.name = ns.Skin:Font(row, 12, "LEFT")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(WIDTH - PAD * 2 - 90)  -- room for "angenommen" (#10)
    row.age = ns.Skin:Font(row, 11, "RIGHT")
    row.age:SetPoint("RIGHT", -20, 0)
    row.age:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    local remove = CreateFrame("Button", nil, row)
    remove:SetSize(16, 16)
    remove:SetPoint("RIGHT", 0, 0)
    remove.text = ns.Skin:Font(remove, 13, "CENTER")
    remove.text:SetPoint("CENTER")
    remove.text:SetText("x")
    remove:SetScript("OnEnter", function() remove.text:SetTextColor(1, 0.45, 0.45) end)
    remove:SetScript("OnLeave", function() remove.text:SetTextColor(1, 1, 1) end)
    remove:SetScript("OnClick", function() if row.guid then ns.Queue:Remove(row.guid) end end)
    row.remove = remove
    return row
end

function QueueList:Create()
    local frame = CreateFrame("Frame", "OneTwoThreeQueue", UIParent)
    frame:SetSize(WIDTH, PAD * 2 + HEADER)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:Hide()
    self.frame = frame
    self.glass = ns.Skin:Pill(frame)
    local top = self.glass.top or frame
    self.title = ns.Skin:Font(top, 12, "LEFT")
    self.title:SetPoint("TOPLEFT", PAD, -PAD)
    self.title:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    self.more = ns.Skin:Font(top, 11, "LEFT")
    self.more:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    self.rows = {}
end

-- Above the Summoning button, in UIParent's coordinates.
-- Where the list goes: above the Summoning button, in UIParent's
-- coordinates. Reading a protected button's position in combat is
-- unmeasured, so the spot is also remembered whenever the bar is set up or
-- moved (out of combat): a refused read, even for the first list after a
-- /reload, falls back to it (Codex on #38).
function QueueList:Remember()
    local button = ns.Bar:Button("summoning")
    if not button then return nil end
    local ok, x, top, scale = pcall(function()
        local cx = button:GetCenter()
        return cx, button:GetTop(), button:GetEffectiveScale() / UIParent:GetEffectiveScale()
    end)
    x, top, scale = ok and API.Number(x), ok and API.Number(top), ok and API.Number(scale)
    if x and top and scale then
        self.spot = { x * scale, top * scale + 22 }
    end
    return self.spot
end

function QueueList:Place()
    local spot = self:Remember()
    if not spot then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", spot[1], spot[2])
end

function QueueList:Refresh()
    local entries = ns.Queue.entries
    if #entries == 0 then
        if self.frame then self.frame:Hide() end
        return
    end
    if not self.frame then self:Create() end
    local now, shown = GetTime(), math.min(#entries, MAX_ROWS)
    local summoning = ns.Bar:Button("summoning")
    local aimed = summoning and summoning.action and summoning.action.guid
    self.title:SetText(L["Summons (%d)"]:format(#entries))
    for i = 1, shown do
        local e = entries[i]
        local row = self.rows[i] or self:CreateRow(i)
        self.rows[i] = row
        row.guid = e.guid
        row.name:SetText(e.name or "?")
        row.name:SetTextColor(classColor(e.class))
        local state = e.state or (e.guid == aimed and "next") or (e.here and "here")
        row.age:SetText(state and STATE[state] or age(now - e.at))
        if state then
            row.age:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
        else
            row.age:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
        end
        row:Show()
    end
    for i = shown + 1, #self.rows do self.rows[i]:Hide(); self.rows[i].guid = nil end
    local extra = #entries - shown
    self.more:SetShown(extra > 0)
    self.more:SetText(L["and %d more"]:format(extra))
    self.more:ClearAllPoints()
    self.more:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -(PAD + HEADER + shown * ROW))
    self.frame:SetHeight(PAD * 2 + HEADER + shown * ROW + (extra > 0 and ROW or 0))
    self:Place()
    self.frame:Show()
end

function QueueList:Initialize()
    ns.Queue:OnChanged(function() self:Refresh() end)
end
