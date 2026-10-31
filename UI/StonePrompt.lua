-- ============================================================
-- The healthstone prompt (#8): a glass prompt above the Healthstone button
-- while someone has asked. Two clicks, both the player's: "Open trade",
-- then, once the trade with them is open, "Place the healthstone". The
-- player accepts in the game's own trade window. "Skip" drops the request.
-- Our own prompt, never a Blizzard StaticPopup (they taint).
--
-- Nothing here is secure (trading isn't a protected action: run 2 opened
-- one from a plain click), so it hangs from UIParent at coordinates read
-- off the button (Bar:TopOf) and works in combat as far as trading does.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local L = ns.L

local StonePrompt = {}
ns.StonePrompt = StonePrompt

local WIDTH, HEIGHT = 280, 96

-- Why the trade can't open, as the hint says it.
local WHY = {
    stone = L["No healthstone: create one first (the Healthstone button)."],
    target = L["Not in your group: target them first."],
    test = L["A test request: nothing to trade."],
    place = L["No healthstone, or no free trade slot."],
}

local function choice(parent, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 22)
    button.glass = ns.Skin:Pill(button)
    local text = ns.Skin:Font(button.glass.top or button, 12, "CENTER")
    text:SetPoint("CENTER")
    button.text = text
    button:SetScript("OnEnter", function() text:SetTextColor(0.7, 0.85, 1) end)
    button:SetScript("OnLeave", function() text:SetTextColor(1, 1, 1) end)
    return button
end

function StonePrompt:Create()
    local frame = CreateFrame("Frame", "OneTwoThreeStonePrompt", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame.glass = ns.Skin:Pill(frame)
    local top = frame.glass.top or frame
    self.frame = frame

    local text = ns.Skin:Font(top, 13, "CENTER")
    text:SetPoint("TOP", 0, -12)
    text:SetWidth(WIDTH - 24)
    self.text = text

    local hint = ns.Skin:Font(top, 11, "CENTER")
    hint:SetPoint("TOP", text, "BOTTOM", 0, -6)
    hint:SetWidth(WIDTH - 24)
    hint:SetWordWrap(true)
    hint:SetMaxLines(2)
    hint:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    self.hint = hint

    local primary = choice(frame, 150)
    primary:SetFrameLevel(top:GetFrameLevel() + 1)
    primary:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    primary:SetScript("OnClick", function() self:Primary() end)
    self.primary = primary

    local skip = choice(frame, 90)
    skip:SetFrameLevel(top:GetFrameLevel() + 1)
    skip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
    skip.text:SetText(L["Skip"])
    skip:SetScript("OnClick", function()
        if self.entry then ns.Requests:Remove(self.entry.guid) end
    end)
    self.skip = skip

    local more = ns.Skin:Font(top, 11, "RIGHT")
    more:SetPoint("TOPRIGHT", -10, -6)
    more:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    self.more = more
end

-- "Open trade", or "Place the healthstone" once the trade with them is open.
function StonePrompt:Primary()
    local Requests, entry = ns.Requests, self.entry
    if not entry then return end
    if self.placing then
        self.why = not Requests:PlaceStone() and "place" or nil
    else
        local ok, why = Requests:OpenTrade(entry)
        self.why = not ok and why or nil
    end
    self:Refresh(true)
end

-- Shows the request being traded, else the oldest; hidden when none. What
-- the last click ran into (`why`) shows until anything else refreshes it.
function StonePrompt:Refresh(keepWhy)
    local Requests = ns.Requests
    local trading = Requests:TradeEntry()
    local entry = trading or Requests.entries[1]
    if not entry then
        self.entry, self.why = nil, nil
        if self.frame then self.frame:Hide() end
        return
    end
    if not self.frame then self:Create() end
    if self.entry ~= entry or not keepWhy then self.why = nil end
    self.entry, self.placing = entry, trading ~= nil
    self.text:SetText(L["%s asks for a healthstone."]:format(entry.name or "?"))
    local hint
    if self.why then
        hint = WHY[self.why]
    elseif self.placing then
        hint = Requests.placed and L["Accept the trade to give it."] or L["Put your best healthstone in the trade."]
    elseif not Requests.Stone() then
        hint = WHY.stone
    elseif entry.stranger and not Requests.UnitFor(entry) then
        hint = WHY.target
    end
    self.hint:SetText(hint or "")
    self.primary.text:SetText(self.placing and L["Place the healthstone"] or L["Open trade"])
    local extra = #Requests.entries - 1
    self.more:SetText(extra > 0 and L["and %d more"]:format(extra) or "")
    -- Above the Healthstone button; the last spot read, or the screen's
    -- middle, if its position can't be read now.
    local x, top = ns.Bar:TopOf("healthstone")
    if x then self.spot = { x, top + 14 } end
    self.frame:ClearAllPoints()
    if self.spot then
        self.frame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", self.spot[1], self.spot[2])
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    self.frame:Show()
end

function StonePrompt:Initialize()
    ns.Requests:OnChanged(function() self:Refresh() end)
    -- A stranger targeted, or a stone created, changes what it says.
    local function refresh() if self.entry then self:Refresh() end end
    ns.Events:Register("PLAYER_TARGET_CHANGED", refresh)
    ns.Events:Register("BAG_UPDATE_DELAYED", refresh)
end
