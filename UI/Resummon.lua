-- ============================================================
-- Resummon: "You already have that demon summoned, are you sure?"
--
-- Shown by the Demon button's PostClick when the demon it would summon is
-- already out (the button is unarmed then, see Bar:HoldsDemon). Our own glass
-- prompt, never a Blizzard StaticPopup (they taint). "Summon" is a secure
-- button armed with the spell when the prompt opens, so one click casts.
-- Holding a secure button makes the prompt protected: it opens out of combat
-- only and closes at PLAYER_REGEN_DISABLED, while that is still allowed.
-- "Don't ask again" turns the question off (/123 confirm turns it back on).
-- ============================================================

local _, ns = ...
if ns.skip then return end

local Resummon = {}
ns.Resummon = Resummon

local SA = ns.SecureAction
local L = ns.L

local WIDTH, HEIGHT = 300, 96

local function choice(parent, label, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 22)
    button.glass = ns.Skin:Pill(button)
    local text = ns.Skin:Font(button.glass.top or button, 12, "CENTER")
    text:SetPoint("CENTER")
    text:SetText(label)
    button.text = text
    button:SetScript("OnEnter", function() text:SetTextColor(0.7, 0.85, 1) end)
    button:SetScript("OnLeave", function() text:SetTextColor(1, 1, 1) end)
    return button
end

function Resummon:Create()
    local frame = CreateFrame("Frame", "OneTwoThreeResummon", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame.glass = ns.Skin:Pill(frame)
    local top = frame.glass.top or frame
    self.frame = frame

    local text = ns.Skin:Font(top, 13, "CENTER")
    text:SetPoint("TOP", 0, -12)
    text:SetWidth(WIDTH - 24)
    text:SetWordWrap(true)
    self.text = text

    -- The secure Summon button and the plain Cancel one, above the glass.
    local summon = SA.Create(frame, "OneTwoThreeResummonYes")
    summon:SetSize(90, 22)
    summon:SetFrameLevel(top:GetFrameLevel() + 1)
    summon:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -6, 10)
    summon.glass = ns.Skin:Pill(summon)
    local summonText = ns.Skin:Font(summon.glass.top or summon, 12, "CENTER")
    summonText:SetPoint("CENTER")
    summonText:SetText(L["Summon"])
    summon:SetScript("PostClick", function(_, _, down)
        if down then return end
        if self.dontAsk:GetChecked() then
            ns.db.confirmResummon = false
            ns.Print(L["won't ask again before re-summoning (/123 confirm to ask again)."])
            SA.MarkDirty()
        end
        local done = self.onSummon
        self:Hide()
        if done then done() end
    end)
    self.summon = summon

    local cancel = choice(frame, L["Cancel"], 90)
    cancel:SetFrameLevel(top:GetFrameLevel() + 1)
    cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 6, 10)
    cancel:SetScript("OnClick", function() self:Hide() end)
    self.cancel = cancel

    local dontAsk = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    dontAsk:SetSize(22, 22)
    dontAsk:SetFrameLevel(top:GetFrameLevel() + 1)
    dontAsk:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 40, -4)
    local dontAskText = ns.Skin:Font(top, 12, "LEFT")
    dontAskText:SetPoint("LEFT", dontAsk, "RIGHT", 2, 0)
    dontAskText:SetText(L["Don't ask again"])
    self.dontAsk = dontAsk

    frame:Hide()
end

-- Ask about re-summoning `spellID`, above `anchor` (the Demon button, or
-- the wheel's bead). `onSummon` runs after Summon was clicked. `parent`:
-- the wheel's root, which LibShowcase keeps on screen while it hides
-- UIParent (a prompt under UIParent would be hidden with it).
function Resummon:Show(anchor, spellID, onSummon, parent)
    if InCombatLockdown() then return end
    if not self.frame then self:Create() end
    self.frame:SetParent(parent or UIParent)
    self.frame:SetFrameStrata("DIALOG")
    self.onSummon = onSummon
    -- The demon's name in the client's language (#22).
    local demon = ns.Wheel.DemonName(spellID)
    if demon == "" then demon = L["that demon"] end
    self.text:SetText(L["You already have your %s summoned. Summon it again?"]:format(demon))
    self.dontAsk:SetChecked(false)
    SA.Apply(self.summon, { { type = "spell", spell = spellID } })
    -- Tall enough for the question however it wraps (it overflowed in game):
    -- top pad, the text, the checkbox row, the buttons row, bottom pad.
    local textH = tonumber(self.text:GetStringHeight()) or 16
    self.frame:SetHeight(math.max(HEIGHT, 12 + textH + 6 + 24 + 6 + 22 + 10))
    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOM", anchor, "TOP", 0, 14)
    self.frame:Show()
end

function Resummon:Hide()
    if not self.frame or InCombatLockdown() then return end
    self.onSummon = nil
    self.frame:Hide()
    SA.Clear(self.summon)
end

function Resummon:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end
