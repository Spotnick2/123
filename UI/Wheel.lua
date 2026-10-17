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
--   * Each bead is the demon's live, idling face (ns.Portrait.Head: the
--     creature's portrait camera, GlassUnitFrames' recipe), else the icon.
--   * It opens two thirds of the way across the screen (owner), not centred.
--   * /123 preview (Portal Roulette's /pr preview): every demon lit, nothing
--     cast; a click puts that demon in the centre, for screenshots.
--   * Fel art and animation live in WheelEffects (#13). Secure buttons
--     stay fixed; a normal close disarms mouse input before its short fade.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local SA = ns.SecureAction
local Data = ns.Data
local Skin = ns.Skin
local FX = ns.WheelEffects

local Wheel = { nodes = {}, open = false }
ns.Wheel = Wheel

local FEL = ns.Colors.FEL
local ROOT_W, ROOT_H = 480, 600
local DISC = 440
local BEAD = 76
-- The portrait model's square: inscribed in the bead, its edges under the
-- metal node (Media/Wheel_Node_256.tga, Tools/make_wheel_art.py), whose
-- opaque band starts at this square's inscribed circle. A 3D model can't
-- be masked.
local MODEL = math.floor(BEAD * 0.695)
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
Wheel.DemonName = demonName

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
    -- Sized before construction so texture extents are independent of
    -- whether the root's anchors have resolved yet.
    local visual = CreateFrame("Frame", nil, button)
    visual:SetSize(BEAD, BEAD)
    visual:SetPoint("CENTER")
    visual:EnableMouse(false)
    local top = visual
    local face = Skin:RoundTexture(visual, "BACKGROUND")
    face:SetTexture(ns.Media.WHITE)
    face:SetVertexColor(0.025, 0.035, 0.025, 0.95)
    local halo = FX.Texture(visual, "WHEEL_GLOW", BEAD * 1.45, BEAD * 1.45, "BACKGROUND", true)
    local iconHost = CreateFrame("Frame", nil, top)
    iconHost:EnableMouse(false)
    iconHost:SetSize(MODEL, MODEL)
    iconHost:SetPoint("CENTER")
    local icon = Skin:RoundTexture(iconHost, "ARTWORK")
    icon:Hide()
    local portrait = ns.Portrait.Head(iconHost, MODEL)

    -- The ring above the model: an opaque dark band over its square edges,
    -- fel lines on both its edges (brighter on hover and when active).
    local ringFrame = CreateFrame("Frame", nil, top)
    ringFrame:SetAllPoints(visual)
    ringFrame:SetFrameLevel(iconHost:GetFrameLevel() + 5)
    ringFrame:EnableMouse(false)
    local ring = ringFrame:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints()
    ring:SetTexture(ns.Media.WHEEL_NODE)
    local edge = ringFrame:CreateTexture(nil, "OVERLAY")
    edge:SetAllPoints()
    edge:SetTexture(ns.Media.WHEEL_NODE_LIGHT)
    edge:SetBlendMode("ADD")
    edge:SetVertexColor(FEL[1], FEL[2], FEL[3], 0.5)
    local count = Skin:Font(ringFrame, 12, "RIGHT")
    count:SetPoint("BOTTOMRIGHT", -6, 5)

    -- The name plate under the bead, as in the mockup, above the ring.
    local plate = CreateFrame("Frame", nil, top)
    plate:EnableMouse(false)
    plate:SetFrameLevel(ringFrame:GetFrameLevel() + 1)
    plate:SetSize(BEAD + 30, 20)
    plate:SetPoint("TOP", visual, "BOTTOM", 0, 6)
    FX.Plate(plate)
    local label = Skin:Font(plate, 12, "CENTER")
    label:SetPoint("CENTER")
    local sub = Skin:Font(top, 10, "CENTER")
    sub:SetPoint("TOP", plate, "BOTTOM", 0, -1)
    sub:SetTextColor(0.78, 0.80, 0.74, 1)
    local subPlate = FX.Texture(top, "WHEEL_PLATE", BEAD + 24, 15, "BACKGROUND")
    subPlate:ClearAllPoints()
    subPlate:SetPoint("TOP", plate, "BOTTOM", 0, 1)
    subPlate:SetAlpha(0.90)

    local node = { index = index, entry = entry, spellID = entry.spell, major = entry.major,
        button = button, visual = visual, icon = icon, portrait = portrait, label = label, sub = sub,
        count = count, edge = edge, ring = ring, halo = halo, subPlate = subPlate }
    button:SetScript("OnEnter", function()
        if not Wheel.open then return end
        node.hovered = true -- the effects clock eases the light in
        Wheel:Hint(Wheel:NodeHint(node))
        Wheel:Voice(node.spellID)
    end)
    button:SetScript("OnLeave", function()
        node.hovered = false
        Wheel:Hint()
    end)
    -- Insecure PostClick, after the secure action: the active demon's bead
    -- asks first; any other cast closes the wheel. Only a click that cast
    -- something counts: a bead arms the left button, and shift only with
    -- Fel Domination (a secure button never falls back from shift-type1 to
    -- type1), so a right click or a bare shift-click does nothing.
    -- No "is the wheel open" guard: a click that reached a secure button
    -- has cast, and its bookkeeping (voice, the remembered demon) follows;
    -- Close itself does nothing when the wheel is not open.
    button:SetScript("PostClick", function(_, mouseButton, down)
        if down then return end
        -- Preview: nothing was armed; the demon goes to the centre.
        if Wheel.preview then
            if Wheel.open and mouseButton == "LeftButton" then Wheel:PreviewSelect(node) end
            return
        end
        if not node.known or mouseButton ~= "LeftButton" then return end
        if IsShiftKeyDown() and not node.shiftArmed and not node.held then return end
        Wheel:Voice(node.spellID)
        -- A demon picked here is the Demon button's from now on (a major
        -- demon never is).
        if not node.major then ns.char.demon = node.spellID end
        if node.held then
            ns.Resummon:Show(button, node.spellID, function() Wheel:Close(node.index) end, Wheel.root)
        else
            Wheel:Close(node.index)
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
    center:SetSize(CENTER, CENTER)
    center:SetPoint("CENTER")
    center:EnableMouse(false)
    local top = center
    self.centerVisual = center
    -- The model in the upper part of the centre, the three lines under it
    -- (in game the name sat on the model's feet).
    local modelHost = CreateFrame("Frame", nil, top)
    modelHost:SetSize(104, 104)
    modelHost:SetPoint("CENTER", 0, 26)
    modelHost:EnableMouse(false)
    local iconHost = CreateFrame("Frame", nil, modelHost)
    iconHost:EnableMouse(false)
    iconHost:SetSize(72, 72)
    iconHost:SetPoint("CENTER")
    self.centerIcon = Skin:RoundTexture(iconHost, "ARTWORK")
    self.portrait = ns.Portrait.Create(modelHost, 104)
    self.centerName = Skin:Font(top, 14, "CENTER")
    self.centerName:SetPoint("TOP", modelHost, "BOTTOM", 0, -2)
    self.centerSub = Skin:Font(top, 11, "CENTER")
    self.centerSub:SetPoint("TOP", self.centerName, "BOTTOM", 0, -1)
    self.centerSub:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    self.centerState = Skin:Font(top, 11, "CENTER")
    self.centerState:SetPoint("TOP", self.centerSub, "BOTTOM", 0, -1)

    button:SetScript("OnEnter", function() Wheel:Hint(Wheel:SacrificeHint()) end)
    button:SetScript("OnLeave", function() Wheel:Hint() end)
    button:SetScript("PostClick", function(_, mouseButton, down)
        if down or Wheel.preview or mouseButton ~= "RightButton" or not Wheel.sacrifice.action then return end
        if IsShiftKeyDown() then return end -- no shift- attributes: nothing cast
        Wheel:Close()
    end)
    self.center = button
    self.sacrifice = {}
end

function Wheel:CreateHeader()
    local header = CreateFrame("Frame", nil, self.stage)
    header:SetSize(220, 56)
    header:SetPoint("BOTTOM", self.disc, "TOP", 0, 2)
    header:EnableMouse(false)
    local backing = FX.Texture(header, "WHEEL_GLOW", 238, 90, "BACKGROUND")
    backing:SetVertexColor(0.02, 0.025, 0.02, 0.95)
    local crest = FX.Texture(header, "WHEEL_CREST", 244, 122, "ARTWORK")
    crest:SetPoint("CENTER", header, "CENTER", 0, 10)
    -- The client's serif face, already used by Blizzard headings, on a plain
    -- font string: a Skin:Font one is restyled by LibGlass's font changes.
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 38, "")
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 0.8)
    title:SetPoint("TOP", 0, 0)
    title:SetText("123")
    title:SetTextColor(0.92, 0.95, 0.88)
    local subtitle = Skin:Font(header, 12, "CENTER")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("DEMON SUMMONING")
    local mark = Skin:Font(header, 11, "CENTER")
    mark:SetPoint("TOP", subtitle, "BOTTOM", 0, -2)
    mark:SetText("PREVIEW")
    mark:SetTextColor(1, 0.82, 0.2)
    mark:Hide()
    self.previewMark = mark
    subtitle:SetTextColor(0.80, 0.82, 0.75)
    self.header = header

    -- A plain (insecure) close button, right of the title.
    local close = CreateFrame("Button", nil, self.root)
    close:SetSize(30, 30)
    close:SetPoint("LEFT", header, "RIGHT", 20, -6)
    close:SetFrameLevel(self.root:GetFrameLevel() + 20)
    local visual = CreateFrame("Frame", nil, close)
    visual:SetAllPoints()
    visual:EnableMouse(false)
    local face = Skin:RoundTexture(visual, "BACKGROUND")
    face:SetTexture(ns.Media.WHITE)
    face:SetVertexColor(0.03, 0.04, 0.025, 0.95)
    FX.Texture(visual, "WHEEL_NODE", 30, 30)
    local x = Skin:Font(visual, 15, "CENTER")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("x")
    close:SetScript("OnClick", function() Wheel:Close() end)
    close:SetScript("OnEnter", function() x:SetTextColor(0.65, 1, 0.25) end)
    close:SetScript("OnLeave", function() x:SetTextColor(1, 1, 1) end)
    self.closeButton = close
    self.closeVisual = visual
end

-- The strip under the ring: soul shards | what the hovered bead does.
function Wheel:CreateStrip()
    local strip = CreateFrame("Frame", nil, self.stage)
    strip:SetSize(380, 44)
    strip:SetPoint("TOP", self.disc, "BOTTOM", 0, -6)
    strip:EnableMouse(false)
    FX.Plate(strip)
    local top = strip
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
    root:SetFrameStrata("HIGH")
    root:SetClampedToScreen(true)
    root:EnableMouse(false)
    root:Hide()
    self.root = root
    self:ApplyPosition()

    local stage = CreateFrame("Frame", nil, root)
    stage:SetAllPoints()
    stage:EnableMouse(false)
    self.stage = stage

    local disc = CreateFrame("Frame", nil, stage)
    disc:SetSize(DISC, DISC)
    disc:SetPoint("CENTER", root, "CENTER", 0, 4)
    disc:EnableMouse(false)
    self.disc = disc

    self:CreateHeader()
    self:CreateStrip()
    self:CreateCenter()
    for index, entry in ipairs(Data.WHEEL) do
        self.nodes[index] = self:CreateNode(index, entry)
    end
    self.effects = FX.Create(self)

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
    -- "Imp: ..." or "Succubus/Incubus: ...": the names before the colon,
    -- matched whole, so "Imp" never matches "Improved".
    for line in text:gmatch("[^\r\n]+") do
        local head = line:match("^%s*([^:]+):")
        if head then
            for name in head:gmatch("[^/]+") do
                if name:match("^%s*(.-)%s*$") == demon then return line end
            end
        end
    end
    return nil
end
Wheel.SacrificeEffect = sacrificeEffect

-- What every bead and the centre do, from the current state.
function Wheel:Resolve()
    if self.preview then return self:ResolvePreview() end
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

------------------------------------------------------------
-- Preview (/123 preview): every demon lit, nothing armed, and the centre
-- shows whichever demon was last clicked (for screenshots on any level).
------------------------------------------------------------

local function entryOf(spellID)
    for _, entry in ipairs(Data.WHEEL) do
        if entry.spell == spellID then return entry end
    end
    return nil
end

function Wheel:ResolvePreview()
    self.petOut = true
    self.active = self.previewDemon
    for _, node in ipairs(self.nodes) do
        node.known, node.held = true, false
        node.isActive = node.spellID == self.previewDemon
    end
    local sac = self.sacrifice
    sac.action, sac.text, sac.effectText = nil, nil, nil
end

-- The centre's name in preview: a bead's label (the Doomguard) or demon name.
function Wheel:ActiveName()
    local entry = self.active and entryOf(self.active)
    return entry and (entry.label or demonName(entry.spell)) or self:PetFamily()
end

function Wheel:SetPreview(on)
    if InCombatLockdown() then
        ns.Print("preview can't change in combat.")
        return
    end
    self.preview = on and true or false
    if self.preview then
        -- Start from the demon that is out, else the Voidwalker.
        self.previewDemon = ns.Bar.PetSummon() or Data.VOIDWALKER
    end
    if self.preview and not self.open then
        self:Open() -- resolves and syncs before anything shows
    elseif self.open then
        -- Disarm (or re-arm) every cast path NOW, not on the coalesced
        -- tick: the re-summon question's own Summon button too (Codex, #26).
        ns.Resummon:Hide()
        self:Resolve()
        SA.RunSyncs()
        self:Paint()
        self:PaintPortraits()
        self:Hint()
    end
    ns.Print(self.preview and "preview on: every demon is shown, nothing is cast. "
        .. "Click a demon to put it in the centre; /123 preview again to stop."
        or "preview off.")
end

-- A click on a bead in preview: that demon goes to the centre.
function Wheel:PreviewSelect(node)
    self.previewDemon = node.spellID
    self:Voice(node.spellID)
    self:Resolve()
    self:Paint()
    self:PaintPortraits()
end

-- The pet's family name ("Infernal"), for a demon not in Data.DEMON_NPC.
function Wheel:PetFamily()
    local ok, family = pcall(UnitCreatureFamily, "pet")
    if ok and API.Readable(family) and type(family) == "string" then return family end
    return ""
end

-- The coalesced secure rebuild (registered with SecureAction).
-- Closed, there is nothing to arm: Open resolves and syncs before the first
-- click (the buttons are hidden with the root meanwhile).
function Wheel:SyncSecure()
    if not (self.root and self.open) then return end
    -- The current state, never the last Resolve's: /123 confirm only marks
    -- the sync dirty, and the active bead must follow it (Codex, #19).
    self:Resolve()
    local felDom = API.IsKnown(Data.FEL_DOMINATION) and API.SpellName(Data.FEL_DOMINATION)
    for _, node in ipairs(self.nodes) do
        local actions = {}
        node.shiftArmed = false
        if node.known and not node.held and not self.preview then
            actions[1] = { type = "spell", spell = node.spellID }
            local name = API.SpellName(node.spellID)
            if felDom and name and not node.major then
                actions.shift = { { type = "macro", macrotext = "/cast " .. felDom .. "\n/cast " .. name } }
                node.shiftArmed = true
            end
        end
        SA.Apply(node.button, actions)
    end
    -- The centre: right button only.
    SA.Apply(self.center, { nil, self.sacrifice.action })
end

-- Two thirds of the way across the screen (owner), placed on each opening
-- (out of combat: the root is protected) so a resized window is followed.
function Wheel:ApplyPosition()
    local w = tonumber(UIParent:GetWidth()) or 0
    self.root:ClearAllPoints()
    self.root:SetPoint("CENTER", UIParent, "CENTER", w / 6, 20)
end

-- The beads' live portraits: on opening and on a new state only (a model
-- load is not a per-bag-update job). The icon shows if no portrait can.
function Wheel:PaintPortraits()
    for _, node in ipairs(self.nodes) do
        node.icon:SetTexture(API.SpellIcon(node.spellID))
        node.icon:SetDesaturated(not node.known)
        node.icon:SetAlpha(node.known and 1 or 0.45)
        node.icon:Hide()
        node.portrait:Show(node.entry.npc, function() node.icon:Show() end)
        node.portrait:SetDesaturated(not node.known)
    end
    self.centerIcon:Hide()
    if self.petOut then
        self.centerIcon:SetTexture(self.active and API.SpellIcon(self.active) or nil)
        local entry = self.preview and entryOf(self.active)
        local npcID = entry and entry.npc or API.UnitNpcID("pet")
        self.portrait:Show(npcID, function() self.centerIcon:Show() end)
    else
        self.portrait:Hide()
    end
end

-- Repaint everything non-secure. Safe in combat.
function Wheel:Paint()
    if not self.root then return end
    for _, node in ipairs(self.nodes) do
        node.label:SetText(node.entry.label or demonName(node.spellID))
        self:PaintReagent(node)
        self:PaintEdge(node)
    end
    self.previewMark:SetShown(self.preview == true)
    if self.preview then
        self.centerName:SetText(self:ActiveName())
        self.centerSub:SetText("")
        self.centerState:SetText(hex(FEL) .. "\226\151\143 Active|r")
    elseif self.petOut then
        self.centerName:SetText(self.active and demonName(self.active) or self:PetFamily())
        local petName = UnitName("pet")
        self.centerSub:SetText(API.Readable(petName) and petName or "")
        self.centerState:SetText(hex(FEL) .. "\226\151\143 Active|r")
    else
        self.centerName:SetText("No demon")
        self.centerSub:SetText("")
        self.centerState:SetText("")
    end
    self.strip.shards:SetText(API.ItemCount(Data.SOUL_SHARD) or "")
end

-- Frame states and eased hover light are painted by the effects layer.
function Wheel:PaintEdge(node)
    FX.PaintNode(node, self.effects and self.effects.time or 0)
end

-- The reagent a summon consumes, or nil: vendor reagents are free with the
-- Reagent Economy perk.
local function reagentOf(spellID)
    local itemID = Data.REAGENT[spellID]
    if itemID and Data.VENDOR_REAGENTS[itemID] and API.FirstKnown(Data.REAGENT_ECONOMY_SPELLS) then
        return nil
    end
    return itemID
end

-- The reagent a summon consumes: "No <reagent>" under a learned bead that
-- can't be cast for want of it, and how many are carried on the major
-- demons' beads (their reagents are rare; shards are in the strip).
function Wheel:PaintReagent(node)
    if self.preview then
        node.missingReagent = false
        node.count:SetText("")
        node.sub:SetText(node.isActive and (hex(FEL) .. "Active|r") or "")
        node.subPlate:SetShown(node.isActive)
        return
    end
    local itemID = reagentOf(node.spellID)
    local have = itemID and API.ItemCount(itemID)
    node.missingReagent = node.known and itemID ~= nil and have == 0
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
    node.subPlate:SetShown(node.sub:GetText() ~= "")
end

function Wheel:ItemName(itemID)
    local name = API.ItemName(itemID)
    if not name then API.RequestItemData(itemID) end
    return name or "reagent"
end

------------------------------------------------------------
-- Voices: a demon's line on hover and on click (owner), a different one
-- each time, on the Dialog channel (TimeIsMoney's Director: the player's
-- dialog volume and mute apply). A new line cuts the one still playing, so
-- sweeping over the ring never stacks voices.
------------------------------------------------------------

function Wheel:Voice(spellID)
    local lines = Data.VOICE[spellID]
    if not (lines and ns.db.sounds) then return end
    local i = math.random(#lines)
    if #lines > 1 and i == self.lastLine then i = i % #lines + 1 end
    self.lastLine = i
    if self.voiceHandle then pcall(StopSound, self.voiceHandle, 200) end
    local ok, willPlay, handle = pcall(PlaySoundFile, lines[i], "Dialog")
    self.voiceHandle = ok and willPlay and handle or nil
end

------------------------------------------------------------
-- The strip's hint line
------------------------------------------------------------

function Wheel:Hint(text)
    if self.strip then
        self.strip.hint:SetText(text or (self.preview and "Preview: click a demon to put it in the centre" or HINT))
    end
end

function Wheel:NodeHint(node)
    if self.preview then
        return "Preview: put the " .. (node.entry.label or demonName(node.spellID)) .. " in the centre"
    end
    if not node.known then
        return (node.entry.label or demonName(node.spellID)) .. ": not learned yet"
    end
    local name = API.SpellName(node.spellID) or ""
    if node.isActive then
        return name .. " again (already out)"
    end
    local itemID = reagentOf(node.spellID)
    if itemID and API.ItemCount(itemID) == 0 then
        return name .. ": needs " .. self:ItemName(itemID)
    end
    if not node.major and API.IsKnown(Data.FEL_DOMINATION) then
        return "Click: " .. name .. "    Shift: Fel Domination first"
    end
    return "Click: " .. name
end

function Wheel:SacrificeHint()
    if self.preview then return "Preview: nothing is cast" end
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
    self:PaintPortraits()
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
    if self:IsClosing() then self:FinishClose() end
    self.pendingHide = false
    self.open = true
    self:Resolve()
    SA.RunSyncs() -- out of combat: attributes are current before the first click
    self:Paint()
    self:PaintPortraits()
    self:Hint()
    self:ApplyPosition()
    self:SetMouseEnabled(false) -- on once the beads have faded in (OnOpened)
    self.root:Show()
    FX.Start(self.effects)
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

function Wheel:SetMouseEnabled(enabled)
    for _, node in ipairs(self.nodes) do node.button:EnableMouse(enabled) end
    self.center:EnableMouse(enabled)
    self.closeButton:EnableMouse(enabled)
end

-- The opening has finished: every bead is visible, so it takes clicks.
function Wheel:OnOpened()
    if self.open and not InCombatLockdown() then self:SetMouseEnabled(true) end
end

-- The closing animation runs (one source of truth: the effects' phase).
function Wheel:IsClosing()
    return self.effects ~= nil and self.effects.phase == "closing"
end

-- Stop accepting input immediately. Visual children can finish a normal
-- close, but combat/forced cleanup always bypasses that animation.
function Wheel:BeginClose()
    self.open = false
    self:StopTicker()
    self.syncingEscape = true
    self.escape:Hide()
    self.syncingEscape = false
    ns.Resummon:Hide()
    if not InCombatLockdown() then self:SetMouseEnabled(false) end
end

function Wheel:FinishClose()
    FX.Stop(self.effects, InCombatLockdown())
    if InCombatLockdown() then
        -- Its buttons still cast until combat ends: shown with their
        -- portraits (hidden at OnCombatEnd), and said so.
        self.pendingHide = true
        ns.Print("the demon wheel closes when combat ends.")
    else
        self.pendingHide = false
        self:HidePortraits()
        self.root:Hide()
    end
end

function Wheel:HidePortraits()
    self.portrait:Hide()
    for _, node in ipairs(self.nodes) do node.portrait:Hide() end
end

function Wheel:Teardown()
    self:BeginClose()
    self:FinishClose()
end

function Wheel:Close(selected)
    if not self.open or InCombatLockdown() then return end
    self:BeginClose()
    FX.Close(self.effects, selected)
    ns.Presentation:Exit("close")
end

function Wheel:Toggle()
    if self.open then self:Close() else self:Open() end
end

-- Combat entry: still unlocked inside PLAYER_REGEN_DISABLED (measured), so
-- the wheel closes at once and no invisible targets are left in combat.
function Wheel:OnCombatStart()
    if not self.open and not self:IsClosing() then return end
    self:Teardown()
    ns.Presentation:ForceExit("combat")
end

function Wheel:OnCombatEnd()
    if self.pendingHide and not self.open then
        self.pendingHide = false
        self:HidePortraits()
        self.root:Hide()
        self:SetMouseEnabled(false) -- FX.Start restores every alpha on the next open
    end
end

-- Escape or Alt+Z through LibShowcase, or another forced restore.
function Wheel:OnForcedExit(reason)
    ns.Presentation:MarkClosed()
    if reason == "ui-shown" and self.open and not InCombatLockdown() then
        self:Close()
    elseif self.open or self:IsClosing() then
        self:Teardown()
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
    ns.Events:Register("PLAYER_REGEN_ENABLED", function() Wheel:OnCombatEnd() end)
end
