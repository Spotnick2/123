-- ============================================================
-- The soulstone target picker (#5): a glass list above the Soulstone
-- button, opened by its right click. You first, then the group, in class
-- colours; the one picked is marked. Clicking a name picks them, "Clear"
-- forgets the pick. A list, not a dropdown (UIDropDownMenu is gone).
--
-- Nothing here is secure: it hangs from UIParent at coordinates read off
-- the button (Bar:TopOf), so it opens in combat too. A pick made in combat
-- arms the button once combat ends.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local L = ns.L

local SoulPicker = {}
ns.SoulPicker = SoulPicker

local COLUMN, ROW, PAD, HEADER = 150, 18, 8, 18
local PER_COLUMN = 10

local function classColor(class)
    local c = class and RAID_CLASS_COLORS[class]
    if type(c) == "table" then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- You, then the group: { guid, name, class }.
function SoulPicker.Candidates()
    local list = {}
    local function add(unit)
        local guid = API.UnitGUID(unit)
        if not guid then return end
        local name = GetUnitName(unit, false)
        local _, class = UnitClass(unit)
        list[#list + 1] = {
            guid = guid,
            name = API.Readable(name) and name or "?",
            class = API.Readable(class) and class or nil,
        }
    end
    add("player")
    for _, unit in ipairs(ns.Queue.GroupUnits()) do add(unit) end
    return list
end

function SoulPicker:Row(i)
    local row = self.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, self.frame)
    row:SetSize(COLUMN - PAD, ROW)
    row:SetFrameLevel((self.glass.top or self.frame):GetFrameLevel() + 1)
    row.text = ns.Skin:Font(row, 12, "LEFT")
    row.text:SetPoint("LEFT", 2, 0)
    row.text:SetWidth(COLUMN - PAD - 4)
    row:SetScript("OnEnter", function() row.text:SetAlpha(0.7) end)
    row:SetScript("OnLeave", function() row.text:SetAlpha(1) end)
    row:SetScript("OnClick", function()
        if row.pick then
            ns.SoulTarget:Set(row.pick.guid, row.pick.name, row.pick.class)
        else
            ns.SoulTarget:Clear()
        end
        self:Hide()
    end)
    self.rows[i] = row
    return row
end

function SoulPicker:Create()
    local frame = CreateFrame("Frame", "OneTwoThreeSoulPicker", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    self.frame = frame
    self.glass = ns.Skin:Pill(frame)
    local top = self.glass.top or frame
    self.title = ns.Skin:Font(top, 12, "LEFT")
    self.title:SetPoint("TOPLEFT", PAD, -PAD)
    self.title:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    self.title:SetText(L["Soulstone target"])
    self.rows = {}
    -- Escape closes it, as Blizzard's panels.
    UISpecialFrames[#UISpecialFrames + 1] = "OneTwoThreeSoulPicker"
end

-- Fills the list: every candidate, then "Clear" when someone is picked.
function SoulPicker:Refresh()
    local picked = ns.SoulTarget:Get()
    local entries = SoulPicker.Candidates()
    if picked then entries[#entries + 1] = { clear = true } end
    local columns = math.ceil(#entries / PER_COLUMN)
    local perColumn = math.min(#entries, PER_COLUMN)
    for i, e in ipairs(entries) do
        local row = self:Row(i)
        local col, line = math.floor((i - 1) / PER_COLUMN), (i - 1) % PER_COLUMN
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD + col * COLUMN, -(PAD + HEADER + line * ROW))
        if e.clear then
            row.pick = nil
            row.text:SetText(L["Clear"])
            row.text:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
        else
            row.pick = e
            local mark = picked and picked.guid == e.guid and "> " or ""
            row.text:SetText(mark .. e.name)
            row.text:SetTextColor(classColor(e.class))
        end
        row:Show()
    end
    for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
    self.frame:SetSize(PAD + columns * COLUMN, PAD * 2 + HEADER + perColumn * ROW)
end

function SoulPicker:Show()
    if not self.frame then self:Create() end
    self:Refresh()
    local x, top = ns.Bar:TopOf("soulstone")
    if not (x and top) then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, top + 14)
    self.frame:Show()
end

function SoulPicker:Hide()
    if self.frame then self.frame:Hide() end
end

function SoulPicker:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

function SoulPicker:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

function SoulPicker:Initialize()
    -- The group changed while it is open: list who is there now.
    ns.Events:Register("GROUP_ROSTER_UPDATE", function()
        if self:IsShown() then self:Refresh() end
    end)
end
