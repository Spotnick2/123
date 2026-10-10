-- ============================================================
-- Wheel: the demon wheel (issue #4), on the owner's "Fel concept" mockup.
-- Opens from the Demon button.
--
--   * Seven beads on a fel ring, clockwise from 12 (Data.WHEEL): Voidwalker,
--     Felhunter, Inferno, Doomguard, Imp, Succubus, Incubus.
--   * The centre: the active demon in 3D (ns.Portrait), its name, the pet's
--     name and "Active". Its bead stays on the ring, marked active.
--   * Click a bead: summon. Shift-click: Fel Domination first, once known
--     (not for Inferno or Ritual of Doom). The active demon's bead asks first
--     (ns.Resummon), as the Demon button's right click does.
--   * Right-click the centre: Sacrifice. Demonic Sacrifice when the talent
--     is known, else the Voidwalker's own Sacrifice (a pet action). A left
--     click there does nothing, so it is never an accident.
--   * The strip under the ring: soul shards, and a line about what the
--     hovered bead does ("Select a demon to summon" otherwise).
--
-- Built on Portal Roulette's wheel (UI/Wheel/Roulette.lua), trimmed:
--   * The root parents secure buttons, so it is protected: it opens and
--     closes out of combat only. InCombatLockdown() is still false inside
--     PLAYER_REGEN_DISABLED, so the wheel closes synchronously there.
--   * Secure buttons sit at fixed positions and never move; which spell each
--     one casts is written by the coalesced sync.
--   * Escape: a plain proxy frame in UISpecialFrames (an insecure key handler
--     taints the Escape binding), armed only while the game UI is visible;
--     with the UI hidden, Escape goes through LibShowcase (onForcedExit).
--   * Art (title crest, rune ring, demon portraits) and animation are the
--     Codex handoff (#13); this is the structure and the fel colours.
-- ============================================================

local _, ns = ...

local API = ns.API
local SA = ns.SecureAction
local Data = ns.Data
local Skin = ns.Skin

local Wheel = { nodes = {}, open = false }
ns.Wheel = Wheel

local FEL = ns.Colors.FEL
local ROOT_W, ROOT_H = 480, 600
local DISC = 440
local BEAD = 70
local RADIUS = 162
local CENTER = 170
local HINT = "Select a demon to summon"

local function clockOffset(clock, radius)
    local angle = math.rad(90 - (clock % 12) * 30)
    return math.cos(angle) * radius, math.sin(angle) * radius
end

local function hex(c)
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

-- "Summon Imp" -> "Imp".
local function demonName(spellID)
    local name = API.SpellName(spellID) or ""
    return (name:gsub("^Summon ", ""))
end

------------------------------------------------------------
-- Construction (lazy, out of combat)
------------------------------------------------------------

function Wheel:CreateNode(index, entry)
    local root = self.root
    local button = SA.Create(root, "OneTwoThreeWheelNode" .. index)
    button:SetSize(BEAD, BEAD)
    button:SetFrameLevel(root:GetFrameLevel() + 20)
    local x, y = clockOffset((index - 1) * 12 / #Data.WHEEL, RADIUS)
    button:SetPoint("CENTER", self.disc, "CENTER", x, y)

    -- Everything visible on a mouse-disabled child of the button.
    local visual = CreateFrame("Frame", nil, button)
    visual:SetAllPoints()
    visual:EnableMouse(false)
    local glass = Skin:Disc(visual, "disc_small", FEL)
    local top = glass.top or visual
    local iconHost = CreateFrame("Frame", nil, top)
    iconHost:SetPoint("TOPLEFT", 5, -5)
    iconHost:SetPoint("BOTTOMRIGHT", -5, 5)
    local icon = Skin:RoundTexture(iconHost, "ARTWORK")
    local hover = Skin:RoundTexture(iconHost, "OVERLAY")
    hover:SetTexture(ns.Media.WHITE)
    hover:SetVertexColor(FEL[1], FEL[2], FEL[3], 0.18)
    hover:Hide()
    local count = Skin:Font(top, 12, "RIGHT")
    count:SetPoint("BOTTOMRIGHT", -4, 3)

    -- The name plate under the bead, as in the mockup.
    local plate = CreateFrame("Frame", nil, top)
    plate:SetSize(BEAD + 30, 20)
    plate:SetPoint("TOP", button, "BOTTOM", 0, 6)
    local plateGlass = Skin:Pill(plate, FEL)
    local label = Skin:Font(plateGlass.top or plate, 12, "CENTER")
    label:SetPoint("CENTER")
    local sub = Skin:Font(top, 10, "CENTER")
    sub:SetPoint("TOP", plate, "BOTTOM", 0, -1)
    sub:SetTextColor(1, 1, 1, 0.6)

    local node = { index = index, entry = entry, spellID = entry.spell, major = entry.major,
        button = button, glass = glass, icon = icon, label = label, sub = sub, count = count }
    button:SetScript("OnEnter", function()
        hover:Show()
        Wheel:Hint(Wheel:NodeHint(node))
    end)
    button:SetScript("OnLeave", function()
        hover:Hide()
        Wheel:Hint()
    end)
    -- Insecure PostClick, after the secure action: the active demon's bead
    -- asks first; any other cast closes the wheel.
    button:SetScript("PostClick", function(_, _, down)
        if down or not node.known then return end
        if node.held then
            ns.Resummon:Show(button, node.spellID, function() Wheel:Close() end)
        else
            Wheel:Close()
        end
    end)
    return node
end

function Wheel:CreateCenter()
    -- The centre is a secure button too (right-click: Sacrifice); what shows
    -- hangs off a mouse-disabled child.
    local button = SA.Create(self.root, "OneTwoThreeWheelCenter")
    button:SetSize(CENTER, CENTER)
    button:SetFrameLevel(self.root:GetFrameLevel() + 20)
    button:SetPoint("CENTER", self.disc, "CENTER")
    local center = CreateFrame("Frame", nil, button)
    center:SetAllPoints()
    center:EnableMouse(false)
    local glass = Skin:Disc(center, "disc", FEL)
    Skin:SetRimColor(glass, FEL[1], FEL[2], FEL[3], 0.9)
    local top = glass.top or center
    local iconHost = CreateFrame("Frame", nil, top)
    iconHost:SetSize(80, 80)
    iconHost:SetPoint("CENTER", 0, 20)
    self.centerIcon = Skin:RoundTexture(iconHost, "ARTWORK")
    self.portrait = ns.Portrait.Create(top, 120)
    if self.portrait.scene then
        self.portrait.scene:ClearAllPoints()
        self.portrait.scene:SetPoint("CENTER", 0, 18)
    end
    self.centerName = Skin:Font(top, 15, "CENTER")
    self.centerName:SetPoint("BOTTOM", center, "BOTTOM", 0, 46)
    self.centerSub = Skin:Font(top, 12, "CENTER")
    self.centerSub:SetPoint("TOP", self.centerName, "BOTTOM", 0, -1)
    self.centerSub:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    self.centerState = Skin:Font(top, 12, "CENTER")
    self.centerState:SetPoint("TOP", self.centerSub, "BOTTOM", 0, -1)

    button:SetScript("OnEnter", function() Wheel:Hint(Wheel:SacrificeHint()) end)
    button:SetScript("OnLeave", function() Wheel:Hint() end)
    button:SetScript("PostClick", function(_, mouseButton, down)
        if down or mouseButton ~= "RightButton" or not Wheel.sacrifice.action then return end
        Wheel:Close()
    end)
    self.center = button
    self.sacrifice = {}
end

function Wheel:CreateHeader()
    local header = CreateFrame("Frame", nil, self.stage)
    header:SetSize(220, 56)
    header:SetPoint("BOTTOM", self.disc, "TOP", 0, 2)
    local title = Skin:Font(header, 34, "CENTER")
    title:SetPoint("TOP", 0, 0)
    title:SetText("123")
    title:SetTextColor(0.92, 0.95, 0.88)
    local subtitle = Skin:Font(header, 12, "CENTER")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("DEMON SUMMONING")
    subtitle:SetTextColor(FEL[1], FEL[2], FEL[3])
    self.header = header

    -- A plain (insecure) close button, right of the title.
    local close = CreateFrame("Button", nil, self.root)
    close:SetSize(30, 30)
    close:SetPoint("LEFT", header, "RIGHT", 20, -6)
    close:SetFrameLevel(self.root:GetFrameLevel() + 20)
    local closeGlass = Skin:Disc(close, "disc_small", FEL)
    local x = Skin:Font(closeGlass.top or close, 15, "CENTER")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("x")
    close:SetScript("OnClick", function() Wheel:Close() end)
    self.closeButton = close
end

-- The strip under the ring: soul shards | what the hovered bead does.
function Wheel:CreateStrip()
    local strip = CreateFrame("Frame", nil, self.stage)
    strip:SetSize(380, 44)
    strip:SetPoint("TOP", self.disc, "BOTTOM", 0, -6)
    local glass = Skin:Pill(strip, FEL)
    local top = glass.top or strip
    local shard = top:CreateTexture(nil, "ARTWORK")
    shard:SetSize(22, 22)
    shard:SetPoint("LEFT", 16, 0)
    shard:SetTexture(API.ItemIcon(Data.SOUL_SHARD))
    shard:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local shards = Skin:Font(top, 16, "LEFT")
    shards:SetPoint("LEFT", shard, "RIGHT", 8, 0)
    local divider = top:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(ns.Media.WHITE)
    divider:SetVertexColor(1, 1, 1, 0.2)
    divider:SetSize(1, 24)
    divider:SetPoint("LEFT", 82, 0)
    -- Two lines at most, inside the strip (a long Sacrifice effect wraps).
    local hint = Skin:Font(top, 11, "CENTER")
    hint:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    hint:SetPoint("RIGHT", -12, 0)
    hint:SetWordWrap(true)
    hint:SetMaxLines(2)
    hint:SetText(HINT)
    self.strip = { frame = strip, shards = shards, hint = hint }
end

function Wheel:Create()
    if self.root then return self.root end
    local root = CreateFrame("Frame", "OneTwoThreeWheel", UIParent)
    root:SetSize(ROOT_W, ROOT_H)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
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
    disc:SetPoint("CENTER", root, "CENTER", 0, 4)
    disc:EnableMouse(false)
    local ring = Skin:Disc(disc, "disc", FEL)
    Skin:SetRimColor(ring, FEL[1], FEL[2], FEL[3], 0.85)
    self.disc = disc

    self:CreateHeader()
    self:CreateStrip()
    self:CreateCenter()
    for index, entry in ipairs(Data.WHEEL) do
        self.nodes[index] = self:CreateNode(index, entry)
    end

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

-- What every bead and the centre do, from the current state.
function Wheel:Resolve()
    local active = ns.Bar.PetSummon()
    -- A pet whose NPC id is not in Data.DEMON_NPC (an Infernal, a Doomguard,
    -- an unmeasured demon) is shown by its family; no bead is active then.
    self.petOut = API.UnitNpcID("pet") ~= nil
    self.active = active
    for _, node in ipairs(self.nodes) do
        node.known = API.IsKnown(node.spellID)
        node.isActive = node.spellID == active
        node.held = node.isActive and node.known and ns.db.confirmResummon
    end

    -- Sacrifice is for the demons Data.DEMON_NPC knows.
    local sac = self.sacrifice
    sac.action, sac.text, sac.effectText = nil, nil, nil
    if active then
        local demon = demonName(active)
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

-- The pet's family name ("Infernal"), for a demon not in Data.DEMON_NPC.
function Wheel:PetFamily()
    local ok, family = pcall(UnitCreatureFamily, "pet")
    if ok and API.Readable(family) and type(family) == "string" then return family end
    return ""
end

-- The coalesced secure rebuild (registered with SecureAction).
function Wheel:SyncSecure()
    if not self.root then return end
    local felDom = API.IsKnown(Data.FEL_DOMINATION) and API.SpellName(Data.FEL_DOMINATION)
    for _, node in ipairs(self.nodes) do
        local actions = {}
        if node.known and not node.held then
            actions[1] = { type = "spell", spell = node.spellID }
            local name = API.SpellName(node.spellID)
            if felDom and name and not node.major then
                actions.shift = { { type = "macro", macrotext = "/cast " .. felDom .. "\n/cast " .. name } }
            end
        end
        SA.Apply(node.button, actions)
    end
    -- The centre: right button only.
    SA.Apply(self.center, { nil, self.sacrifice.action })
end

-- Repaint everything non-secure. Safe in combat.
function Wheel:Paint()
    if not self.root then return end
    for _, node in ipairs(self.nodes) do
        node.icon:SetTexture(API.SpellIcon(node.spellID))
        node.icon:SetDesaturated(not node.known)
        node.icon:SetAlpha(node.known and 1 or 0.45)
        node.label:SetText(node.entry.label or demonName(node.spellID))
        Skin:SetRimColor(node.glass, FEL[1], FEL[2], FEL[3], node.isActive and 1 or 0.45)
        self:PaintReagent(node)
    end
    if self.petOut then
        self.centerName:SetText(self.active and demonName(self.active) or self:PetFamily())
        local petName = UnitName("pet")
        self.centerSub:SetText(API.Readable(petName) and petName or "")
        self.centerState:SetText(hex(FEL) .. "\226\151\143 Active|r")
        self.centerIcon:SetTexture(self.active and API.SpellIcon(self.active) or nil)
        self.centerIcon:Hide()
        local npcID = API.UnitNpcID("pet")
        self.portrait:Show(npcID, function() self.centerIcon:Show() end)
    else
        self.portrait:Hide()
        self.centerIcon:Hide()
        self.centerName:SetText("No demon")
        self.centerSub:SetText("")
        self.centerState:SetText("")
    end
    self.strip.shards:SetText(API.ItemCount(Data.SOUL_SHARD) or "")
end

-- The reagent a summon consumes: "No <reagent>" under a learned bead that
-- can't be cast for want of it, and how many are carried on the major
-- demons' beads (their reagents are rare; shards are in the strip).
function Wheel:PaintReagent(node)
    local itemID = Data.REAGENT[node.spellID]
    local have = itemID and API.ItemCount(itemID)
    node.count:SetText(node.major and itemID and have or "")
    if not node.known then
        node.sub:SetText("Not learned")
    elseif node.isActive then
        node.sub:SetText(hex(FEL) .. "Active|r")
    elseif itemID and have == 0 then
        node.sub:SetText("|cffff6060No " .. self:ItemName(itemID) .. "|r")
    else
        node.sub:SetText("")
    end
end

function Wheel:ItemName(itemID)
    local name = API.ItemName(itemID)
    if not name then API.RequestItemData(itemID) end
    return name or "reagent"
end

------------------------------------------------------------
-- The strip's hint line
------------------------------------------------------------

function Wheel:Hint(text)
    if self.strip then self.strip.hint:SetText(text or HINT) end
end

function Wheel:NodeHint(node)
    if not node.known then
        return (node.entry.label or demonName(node.spellID)) .. ": not learned yet"
    end
    local name = API.SpellName(node.spellID) or ""
    if node.isActive then
        return name .. " again (already out)"
    end
    local itemID = Data.REAGENT[node.spellID]
    if itemID and API.ItemCount(itemID) == 0 then
        return name .. ": needs " .. self:ItemName(itemID)
    end
    if not node.major and API.IsKnown(Data.FEL_DOMINATION) then
        return "Click: " .. name .. "    Shift: Fel Domination first"
    end
    return "Click: " .. name
end

function Wheel:SacrificeHint()
    local sac = self.sacrifice
    if not sac.action then return nil end
    return "Right-click: " .. sac.text .. (sac.effectText and (" - " .. sac.effectText) or "")
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
    self:Hint()
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
    ns.Resummon:Hide()
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
        ns.Resummon:Hide()
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
    ns.Events:Register("BAG_UPDATE_DELAYED", function()
        if Wheel.open then Wheel:Paint() end
    end)
    ns.Events:Register("GET_ITEM_INFO_RECEIVED", function()
        if Wheel.open then Wheel:Paint() end
    end)
    ns.Events:Register("PLAYER_REGEN_DISABLED", function() Wheel:OnCombatStart() end)
end
