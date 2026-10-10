-- ============================================================
-- Wheel: the demon wheel (storyboard top, issue #4). Opens from the Demon
-- button.
--
--   * The demons you can switch to spread evenly over the top arc, from 9
--     to 3, in Data.WHEEL_ORDER (the Sacrifice pill takes 6 o'clock); with
--     no demon out, all five spread from 8 to 4. The active demon is the
--     centre, a 3D portrait (ns.Portrait), and is never offered again here.
--   * Click a demon: summon it. Shift-click: Fel Domination first, once known.
--   * The pill under the centre: Demonic Sacrifice when the talent is known,
--     else the Voidwalker's own Sacrifice (a pet action). Hidden otherwise.
--
-- Built on Portal Roulette's wheel (UI/Wheel/Roulette.lua), trimmed:
--   * The root parents secure buttons, so it is protected: it opens and
--     closes out of combat only. InCombatLockdown() is still false inside
--     PLAYER_REGEN_DISABLED, so the wheel closes synchronously there.
--   * Secure buttons never move while the wheel is open: they are placed
--     when it resolves, out of combat, and the coalesced sync writes which
--     demon each one summons.
--   * Escape: a plain proxy frame in UISpecialFrames (an insecure key handler
--     taints the Escape binding), armed only while the game UI is visible;
--     with the UI hidden, Escape goes through LibShowcase (onForcedExit).
--   * Art and animation are placeholders until the Codex handoff (#13).
-- ============================================================

local _, ns = ...

local API = ns.API
local SA = ns.SecureAction
local Data = ns.Data
local Skin = ns.Skin

local Wheel = { nodes = {}, open = false }
ns.Wheel = Wheel

local ROOT_W, ROOT_H = 420, 470
local DISC = 380
local NODE = 64
local RADIUS = 132
local CENTER = 124
local SLOTS = 5

local function clockOffset(clock, radius)
    local angle = math.rad(90 - (clock % 12) * 30)
    return math.cos(angle) * radius, math.sin(angle) * radius
end

-- The clock position of node `i` of `n`, spread evenly from `from` to `to`
-- (clockwise): over the top arc (9 to 3) when the pill is under the centre,
-- 8 to 4 when it is not and all five demons are out there.
local function arcClock(i, n, from, to)
    if n == 1 then return 12 end
    local span = (to - from) % 12
    return from + span * (i - 1) / (n - 1)
end

-- "Summon Imp" -> "Imp".
local function demonName(spellID)
    local name = API.SpellName(spellID) or ""
    return (name:gsub("^Summon ", ""))
end

------------------------------------------------------------
-- Construction (lazy, out of combat)
------------------------------------------------------------

local function plate(parent, anchor, size)
    local label = Skin:Font(parent, size, "CENTER")
    label:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    return label
end

function Wheel:CreateNode(index)
    local root = self.root
    local button = SA.Create(root, "OneTwoThreeWheelNode" .. index)
    button:SetSize(NODE, NODE)
    button:SetFrameLevel(root:GetFrameLevel() + 20)

    -- Everything visible on a mouse-disabled child of the button.
    local visual = CreateFrame("Frame", nil, button)
    visual:SetAllPoints()
    visual:EnableMouse(false)
    local glass = Skin:Disc(visual, "disc_small")
    local top = glass.top or visual
    local iconHost = CreateFrame("Frame", nil, top)
    iconHost:SetPoint("TOPLEFT", 5, -5)
    iconHost:SetPoint("BOTTOMRIGHT", -5, 5)
    local icon = Skin:RoundTexture(iconHost, "ARTWORK")
    local hover = Skin:RoundTexture(iconHost, "OVERLAY")
    hover:SetTexture(ns.Media.WHITE)
    hover:SetVertexColor(1, 1, 1, 0.14)
    hover:Hide()
    local label = plate(top, button, 13)
    local sub = Skin:Font(top, 10, "CENTER")
    sub:SetPoint("TOP", label, "BOTTOM", 0, -1)
    sub:SetTextColor(1, 1, 1, 0.6)

    local node = { index = index, button = button, glass = glass, icon = icon, label = label, sub = sub }
    button:SetScript("OnEnter", function() hover:Show() end)
    button:SetScript("OnLeave", function() hover:Hide() end)
    -- Insecure PostClick, after the cast: the wheel's job is done.
    button:SetScript("PostClick", function(_, _, down)
        if down or not node.spellID or not node.known then return end
        Wheel:Close()
    end)
    return node
end

function Wheel:CreateCenter()
    local center = CreateFrame("Frame", nil, self.stage)
    center:SetSize(CENTER, CENTER)
    center:SetPoint("CENTER", self.disc, "CENTER")
    center:EnableMouse(false)
    local glass = Skin:Disc(center, "disc_small")
    Skin:SetRimColor(glass, ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3], 0.9)
    local top = glass.top or center
    local iconHost = CreateFrame("Frame", nil, top)
    iconHost:SetPoint("TOPLEFT", 14, -14)
    iconHost:SetPoint("BOTTOMRIGHT", -14, 14)
    self.centerIcon = Skin:RoundTexture(iconHost, "ARTWORK")
    self.portrait = ns.Portrait.Create(top, CENTER - 8)
    self.centerName = plate(top, center, 15)
    self.centerSub = Skin:Font(top, 11, "CENTER")
    self.centerSub:SetPoint("TOP", self.centerName, "BOTTOM", 0, -1)
    self.centerSub:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    self.center = center
end

function Wheel:CreateSacrifice()
    local button = SA.Create(self.root, "OneTwoThreeWheelSacrifice")
    button:SetSize(170, 26)
    button:SetFrameLevel(self.root:GetFrameLevel() + 20)
    button:SetPoint("TOP", self.center, "BOTTOM", 0, -40)
    local visual = CreateFrame("Frame", nil, button)
    visual:SetAllPoints()
    visual:EnableMouse(false)
    local glass = Skin:Pill(visual)
    local label = Skin:Font(glass.top or visual, 12, "CENTER")
    label:SetPoint("CENTER")
    local effect = Skin:Font(glass.top or visual, 10, "CENTER")
    effect:SetPoint("TOP", button, "BOTTOM", 0, -3)
    effect:SetWidth(220)
    effect:SetTextColor(1, 1, 1, 0.6)
    button:SetScript("PostClick", function(_, _, down)
        if not down then Wheel:Close() end
    end)
    self.sacrifice = { button = button, label = label, effect = effect }
end

function Wheel:CreateHeader()
    local header = CreateFrame("Frame", nil, self.stage)
    header:SetSize(150, 28)
    header:SetPoint("BOTTOM", self.disc, "TOP", 0, 6)
    local glass = Skin:Pill(header)
    local title = Skin:Font(glass.top or header, 14, "CENTER")
    title:SetPoint("CENTER")
    title:SetText("123")
    title:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])

    -- A plain (insecure) close button, beside the header.
    local close = CreateFrame("Button", nil, self.root)
    close:SetSize(26, 26)
    close:SetPoint("LEFT", header, "RIGHT", 8, 0)
    close:SetFrameLevel(self.root:GetFrameLevel() + 20)
    local closeGlass = Skin:Disc(close, "disc_small")
    local x = Skin:Font(closeGlass.top or close, 14, "CENTER")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("x")
    close:SetScript("OnClick", function() Wheel:Close() end)
    self.closeButton = close
end

function Wheel:Create()
    if self.root then return self.root end
    local root = CreateFrame("Frame", "OneTwoThreeWheel", UIParent)
    root:SetSize(ROOT_W, ROOT_H)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    root:SetFrameStrata("HIGH")
    root:SetClampedToScreen(true)
    root:EnableMouse(false)
    root:Hide()
    self.root = root

    local stage = CreateFrame("Frame", nil, root)
    stage:SetAllPoints()
    stage:EnableMouse(false)
    self.stage = stage

    local disc = CreateFrame("Frame", nil, stage)
    disc:SetSize(DISC, DISC)
    disc:SetPoint("CENTER", root, "CENTER", 0, -10)
    disc:EnableMouse(false)
    Skin:Disc(disc, "disc")
    self.disc = disc

    self:CreateHeader()
    self:CreateCenter()
    for index = 1, SLOTS do
        self.nodes[index] = self:CreateNode(index)
    end
    self:CreateSacrifice()

    -- Escape: a proxy in UISpecialFrames whose OnHide closes the wheel. No
    -- parent, so hiding the game UI does not hide it.
    local escape = CreateFrame("Frame", "OneTwoThreeWheelEscape")
    escape:Hide()
    escape:SetScript("OnHide", function()
        if Wheel.syncingEscape or not Wheel.open then return end
        Wheel:Close()
    end)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "OneTwoThreeWheelEscape")
    end
    self.escape = escape

    SA.RegisterSync(function() Wheel:SyncSecure() end)
    return root
end

------------------------------------------------------------
-- State
------------------------------------------------------------

-- The pet bar slot holding the Voidwalker's Sacrifice, or nil.
local function sacrificeSlot()
    local name = API.SpellName(Data.VOIDWALKER_SACRIFICE)
    for slot = 1, 10 do
        local ok, actionName, _, _, _, _, _, spellID = pcall(GetPetActionInfo, slot)
        if ok then
            spellID = API.Number(spellID)
            if spellID == Data.VOIDWALKER_SACRIFICE then return slot end
            if name and API.Readable(actionName) and actionName == name then return slot end
        end
    end
    return nil
end

-- The line of Demonic Sacrifice's description about `demon` ("Imp: ..."),
-- read from the client: Forever's effects differ from Vanilla's.
local function sacrificeEffect(demon)
    local text = API.SpellDescription(Data.DEMONIC_SACRIFICE)
    if not text or demon == "" then return nil end
    for line in text:gmatch("[^\r\n]+") do
        if line:find(demon, 1, true) and line:find(":", 1, true) then
            return line
        end
    end
    return nil
end

-- What every slot shows and does, from the current state.
function Wheel:Resolve()
    local active = ns.Bar.PetSummon()
    -- A pet whose NPC id is not in Data.DEMON_NPC (unmeasured): shown in the
    -- centre by its family, and every demon stays on offer.
    self.petOut = API.UnitNpcID("pet") ~= nil
    local list = {}
    for _, spellID in ipairs(Data.WHEEL_ORDER) do
        if spellID ~= active then list[#list + 1] = spellID end
    end
    local from, to = 9, 3
    if not self.petOut and #list > 4 then from, to = 8, 4 end
    for index, node in ipairs(self.nodes) do
        node.spellID = list[index]
        node.known = node.spellID ~= nil and API.IsKnown(node.spellID)
        node.clock = node.spellID and arcClock(index, #list, from, to) or nil
    end
    self.active = active

    local sac = self.sacrifice
    sac.action, sac.text, sac.effectText = nil, nil, nil
    if self.petOut then
        local demon = active and demonName(active) or self:PetFamily()
        if API.IsKnown(Data.DEMONIC_SACRIFICE) then
            sac.action = { type = "spell", spell = Data.DEMONIC_SACRIFICE }
            sac.text = API.SpellName(Data.DEMONIC_SACRIFICE) or "Demonic Sacrifice"
            sac.effectText = sacrificeEffect(demon)
        elseif active == Data.VOIDWALKER then
            local slot = sacrificeSlot()
            if slot then
                sac.action = { type = "pet", action = slot }
                sac.text = (API.SpellName(Data.VOIDWALKER_SACRIFICE) or "Sacrifice") .. " " .. demon
            end
        end
    end
end

-- The pet's family name ("Voidwalker"), for a demon not in Data.DEMON_NPC.
function Wheel:PetFamily()
    local ok, family = pcall(UnitCreatureFamily, "pet")
    if ok and API.Readable(family) and type(family) == "string" then return family end
    return ""
end

-- The coalesced secure rebuild (registered with SecureAction). Out of
-- combat only, so the buttons are placed here too.
function Wheel:SyncSecure()
    if not self.root then return end
    for _, node in ipairs(self.nodes) do
        if node.clock then
            local x, y = clockOffset(node.clock, RADIUS)
            node.button:ClearAllPoints()
            node.button:SetPoint("CENTER", self.disc, "CENTER", x, y)
        end
    end
    local felDom = API.IsKnown(Data.FEL_DOMINATION) and API.SpellName(Data.FEL_DOMINATION)
    for _, node in ipairs(self.nodes) do
        local actions = {}
        if node.known then
            actions[1] = { type = "spell", spell = node.spellID }
            local name = API.SpellName(node.spellID)
            if felDom and name then
                actions.shift = { { type = "macro", macrotext = "/cast " .. felDom .. "\n/cast " .. name } }
            end
        end
        SA.Apply(node.button, actions)
        node.button:SetShown(node.spellID ~= nil)
    end
    local sac = self.sacrifice
    SA.Apply(sac.button, { sac.action })
    sac.button:SetShown(sac.action ~= nil)
end

-- Repaint everything non-secure. Safe in combat.
function Wheel:Paint()
    if not self.root then return end
    for _, node in ipairs(self.nodes) do
        if node.spellID then
            node.icon:SetTexture(API.SpellIcon(node.spellID))
            node.icon:SetDesaturated(not node.known)
            node.icon:SetAlpha(node.known and 1 or 0.45)
            node.label:SetText(demonName(node.spellID))
            node.sub:SetText(node.known and "" or "Not learned")
        end
    end
    if self.petOut then
        self.centerName:SetText(self.active and demonName(self.active) or self:PetFamily())
        local petName = UnitName("pet")
        self.centerSub:SetText(API.Readable(petName) and petName or "Active demon")
        self.centerIcon:SetTexture(self.active and API.SpellIcon(self.active) or nil)
        self.centerIcon:Hide()
        local npcID = API.UnitNpcID("pet")
        self.portrait:Show(npcID, function() self.centerIcon:Show() end)
    else
        self.portrait:Hide()
        self.centerIcon:Hide()
        self.centerName:SetText("No demon")
        self.centerSub:SetText("Pick one to summon")
    end
    local sac = self.sacrifice
    sac.label:SetText(sac.text or "")
    sac.effect:SetText(sac.effectText or "")
end

-- New state (pet, spells): resolve, re-arm (deferred in combat), repaint.
function Wheel:Refresh()
    if not self.root or not self.open then return end
    self:Resolve()
    SA.MarkDirty()
    self:Paint()
end

------------------------------------------------------------
-- Open / close
------------------------------------------------------------

-- The Escape proxy is armed only while the game UI is visible.
function Wheel:SyncEscape()
    if not self.escape then return end
    local want = self.open and not ns.Presentation:IsGameUIHidden()
    if want ~= self.escape:IsShown() then
        self.syncingEscape = true
        self.escape:SetShown(want)
        self.syncingEscape = false
    end
end

function Wheel:OnGameUIShown()
    C_Timer.After(0, function() Wheel:SyncEscape() end)
end

function Wheel:Open()
    if InCombatLockdown() then
        ns.Print("the demon wheel can't open in combat.")
        return
    end
    self:Create()
    if self.open then return end
    self.open = true
    self:Resolve()
    SA.RunSyncs() -- out of combat: attributes are current before the first click
    self:Paint()
    self.root:Show()
    ns.Presentation:Enter(self.root)
    self:SyncEscape()
    -- Re-hide the game UI once a dialog that kept it up has cleared.
    self.ticker = C_Timer.NewTicker(1, function()
        if ns.Presentation:RetryHide(self.root) then self:SyncEscape() end
    end)
end

function Wheel:StopTicker()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

function Wheel:Close()
    if not self.open or InCombatLockdown() then return end
    self.open = false
    self:StopTicker()
    self.escape:Hide()
    self.portrait:Hide()
    self.root:Hide()
    ns.Presentation:Exit("close")
end

function Wheel:Toggle()
    if self.open then self:Close() else self:Open() end
end

-- Combat entry: still unlocked inside PLAYER_REGEN_DISABLED (measured), so
-- the wheel closes at once and no invisible targets are left in combat.
function Wheel:OnCombatStart()
    if not self.open then return end
    self.open = false
    self:StopTicker()
    self.escape:Hide()
    self.portrait:Hide()
    ns.Presentation:ForceExit("combat")
    if not InCombatLockdown() then self.root:Hide() end
end

-- Escape or Alt+Z through LibShowcase, or another forced restore.
function Wheel:OnForcedExit()
    ns.Presentation:MarkClosed()
    if self.open and not InCombatLockdown() then
        self.open = false
        self:StopTicker()
        self:SyncEscape()
        self.portrait:Hide()
        self.root:Hide()
    end
end

function Wheel:Initialize()
    local function refresh() Wheel:Refresh() end
    ns.Events:Register("UNIT_PET", function(_, unit)
        if unit == "player" then refresh() end
    end)
    ns.Events:Register("SPELLS_CHANGED", refresh)
    ns.Events:Register("PET_BAR_UPDATE", refresh)
    ns.Events:Register("PLAYER_REGEN_DISABLED", function() Wheel:OnCombatStart() end)
end
