-- ============================================================
-- Bar: the compact bar (storyboard panel 01, issue #3).
--
--   [123] Demons · Demon · Armor · Soulstone · Healthstone · Summoning | shards
--
-- "Demons" opens the demon wheel (Retail's Summon Demon flyout, with Fel
-- Domination's icon: owner); it casts nothing, so it is a plain button.
--
-- Each button is a stationary secure button and the only mouse-enabled
-- frame in its footprint; the bar itself takes no mouse, and the "123"
-- handle beside the buttons is what shift-drags it. What a click does is
-- resolved by Bar:Sync, out of combat only (ns.SecureAction); icons, counts
-- and cooldowns refresh at any time and show what the click is armed with.
--
-- The buttons start simple; their own issues refine them: the demon wheel
-- (#4), the soulstone target (#5), smart stones (#6), the armor glow (#7)
-- and the summon queue (#10).
-- ============================================================

local _, ns = ...
if ns.skip then return end

local Bar = {}
ns.Bar = Bar

local API = ns.API
local SA = ns.SecureAction
local Data = ns.Data

local ICON = 36
local PITCH = 60            -- button centre to centre (room for "Healthstone")
local PAD = 8
local HANDLE_W = 34
local SHARD_W = 56
local LABEL_H = 12
local SLOTS = 6             -- the wheel's button, then the five secure ones
local WIDTH = PAD + HANDLE_W + PITCH * SLOTS + 1 + SHARD_W + PAD
-- The names under the icons are a setting, off by default (owner: the
-- tooltips are enough); without them the bar loses that row.
local HEIGHT = PAD + ICON + 2 + LABEL_H + PAD
local HEIGHT_BARE = PAD + ICON + PAD

------------------------------------------------------------
-- What each button does: an action for SecureAction.Apply (nil when nothing
-- is learned yet), the icon, and the tooltip line.
------------------------------------------------------------

local function spellAction(spellID)
    return { type = "spell", spell = spellID, spellID = spellID }
end

local function itemAction(itemID)
    return { type = "item", item = "item:" .. itemID, itemID = itemID }
end

-- A stone button (#6), from its tiers (strongest first): use the best stone
-- carried, else create the best rank known. Only stones the player can use
-- count (a traded higher-level stone doesn't). Returns the action, or KEEP
-- when a stone count can't be read (secret, as combat starts): the button
-- keeps what it is armed with rather than turn "use" into "create".
local KEEP = {}
Bar.KEEP = KEEP
local function stone(tiers)
    for _, tier in ipairs(tiers) do
        local id, _, unreadable = API.FirstCarried(tier.items, true)
        if unreadable then return KEEP end
        if id then return itemAction(id) end
    end
    for _, tier in ipairs(tiers) do
        if API.IsKnown(tier.create) then return spellAction(tier.create) end
    end
    return nil
end

local showTooltip

-- The spell IDs and names of an armor family: any of them on the player
-- counts as wearing it. Built once per rebuild, not per UNIT_AURA.
local function wornBy(family)
    local ids, names = {}, {}
    for _, spellID in ipairs(family) do
        ids[spellID] = true
        local name = API.SpellName(spellID)
        if name then names[name] = true end
    end
    return ids, names
end

local RESOLVE = {
    -- Out of Soul Shards, the Imp (the one demon that needs none) until
    -- shards come back; the remembered demon itself is kept (owner).
    demon = function()
        local last = ns.char.demon
        local spellID = (last and API.IsKnown(last)) and last or API.FirstKnown(Data.DEMONS)
        if spellID and Data.REAGENT[spellID] == Data.SOUL_SHARD
            and API.ItemCount(Data.SOUL_SHARD) == 0 and API.IsKnown(Data.IMP) then
            spellID = Data.IMP
        end
        return spellID and spellAction(spellID) or nil
    end,
    armor = function()
        for _, family in ipairs(Data.ARMOR) do
            local spellID = API.FirstKnown(family)
            if spellID then
                local action = spellAction(spellID)
                action.ids, action.names = wornBy(family)
                return action
            end
        end
        return nil
    end,
    soulstone = function()
        return stone(Data.SOULSTONE_TIERS)
    end,
    healthstone = function()
        return stone(Data.HEALTHSTONE_TIERS)
    end,
    summoning = function()
        local spellID = Data.RITUAL_OF_SUMMONING
        return API.IsKnown(spellID) and spellAction(spellID) or nil
    end,
}

-- The icon shown while nothing is armed (not learned yet).
local IDLE_ICON = {
    demon = { spell = 688 },
    armor = { spell = 687 },
    soulstone = { item = 5232 },
    healthstone = { item = 5512 },
    summoning = { spell = Data.RITUAL_OF_SUMMONING },
}

Bar.BUTTONS = {
    { key = "demon", label = "Demon" },
    { key = "armor", label = "Armor" },
    { key = "soulstone", label = "Soulstone" },
    { key = "healthstone", label = "Healthstone" },
    { key = "summoning", label = "Summoning" },
}

local function actionIcon(action, key)
    if action then
        if action.itemID then return API.ItemIcon(action.itemID) end
        return API.SpellIcon(action.spellID)
    end
    local idle = IDLE_ICON[key]
    if idle.item then return API.ItemIcon(idle.item) end
    return API.SpellIcon(idle.spell)
end

local function actionName(action)
    if action.itemID then
        return "Use " .. (API.ItemName(action.itemID) or ("item " .. action.itemID))
    end
    return API.SpellName(action.spellID) or ("spell " .. action.spellID)
end

------------------------------------------------------------
-- Visuals (safe in combat)
------------------------------------------------------------

-- A count may be secret in combat: the FontString takes it untouched.
-- The Readable check comes first: even `raw == nil` throws on a secret.
local function setCount(fontString, raw, showOne)
    if not API.Readable(raw) then
        fontString:SetText(raw)
    elseif raw == nil then
        fontString:SetText("")
    elseif type(raw) == "number" and (raw > 1 or (showOne and raw >= 0)) then
        fontString:SetText(raw)
    else
        fontString:SetText("")
    end
end

-- True when the armed spell needs a reagent the player has none of (a
-- Soul Shard to create a stone or for the Ritual). An unreadable count
-- (secret, in combat) is not "none".
local function short(action)
    local itemID = action and action.spellID and Data.REAGENT[action.spellID]
    return itemID ~= nil and API.ItemCount(itemID) == 0
end

function Bar:RefreshButton(button)
    local action = button.action
    local dim = action == nil or short(action)
    button.short = action ~= nil and dim
    button.icon:SetTexture(actionIcon(action, button.key))
    button.icon:SetDesaturated(dim)
    button.icon:SetAlpha(dim and 0.45 or 1)
    if action and action.itemID then
        setCount(button.count, API.ItemCountRaw(action.itemID))
        SA.ApplyItemCooldown(button.cooldown, action.itemID)
    elseif action then
        button.count:SetText("")
        SA.ApplySpellCooldown(button.cooldown, action.spellID)
    else
        button.count:SetText("")
        button.cooldown:Clear()
    end
end

------------------------------------------------------------
-- Armor reminder: a glow while the armor the button casts is not on.
-- "on" / "missing" / "unknown"; auras are secret in combat, so it is
-- "unknown" there and the glow goes out rather than guess.
------------------------------------------------------------

local ARMOR_RETRIES, ARMOR_RETRY_SECONDS = 5, 1

function Bar:ReadArmor(button)
    local action = button.action
    if not action or SA.inCombat then return "unknown" end
    local found = API.HasAura("player", action.ids, action.names)
    if found == nil then return "unknown" end
    return found and "on" or "missing"
end

function Bar:UpdateArmor()
    local button = self.armorButton
    if not button then return end
    local state = self:ReadArmor(button)
    button.armorState = state
    local missing = state == "missing"
    button.glow:SetShown(missing)
    if not missing then
        button.pulse:Stop()
    elseif not button.pulse:IsPlaying() then
        button.pulse:Play()
    end
    if GameTooltip:IsOwned(button) then showTooltip(button) end
    -- Unreadable out of combat (auras may stay secret a moment after it
    -- ends): look again shortly, since no UNIT_AURA may come.
    if state == "unknown" and button.action and not SA.inCombat then
        self:RetryArmor()
    else
        self.armorRetries = 0
    end
end

function Bar:RetryArmor()
    if self.armorRetryPending or (self.armorRetries or 0) >= ARMOR_RETRIES then return end
    self.armorRetries = (self.armorRetries or 0) + 1
    self.armorRetryPending = true
    C_Timer.After(ARMOR_RETRY_SECONDS, function()
        self.armorRetryPending = false
        self:UpdateArmor()
    end)
end

function Bar:Refresh()
    if not self.frame then return end
    for _, button in ipairs(self.buttons) do
        self:RefreshButton(button)
        -- An open tooltip follows what the button now does.
        if GameTooltip:IsOwned(button) then showTooltip(button) end
    end
    setCount(self.shardCount, API.ItemCountRaw(Data.SOUL_SHARD), true)
end

------------------------------------------------------------
-- Secure attributes (out of combat only, through SecureAction)
------------------------------------------------------------

-- The summon spell of the demon that is out, or nil.
local function petSummon()
    local npcID = API.UnitNpcID("pet")
    return npcID and Data.DEMON_NPC[npcID] or nil
end
Bar.PetSummon = petSummon

-- Remember the demon that is out (per character), so the Demon button
-- summons it again once it is gone.
-- The out-of-shards fallback (the Imp) is not a choice: while it stands in
-- for a remembered demon that needs a shard, the Imp it summoned is not
-- remembered, so that demon comes back with the shards (Codex, #19). An
-- Imp picked on the wheel is remembered there, explicitly.
-- Each pet is judged once, when it comes out (by its GUID): a later
-- rebuild, with shards back, must not turn the fallback Imp into a choice.
function Bar:RememberPet()
    local guid = API.UnitGUID("pet")
    if guid == self.seenPet then return end
    self.seenPet = guid
    local spellID = petSummon()
    if not spellID then return end
    local last = ns.char.demon
    if spellID == Data.IMP and last and Data.REAGENT[last] == Data.SOUL_SHARD
        and API.ItemCount(Data.SOUL_SHARD) == 0 then
        return
    end
    ns.char.demon = spellID
end

-- Out of combat, a right-click on the Demon button while that demon is out
-- asks first (ns.Resummon) instead of casting: the right button is left
-- unarmed.
function Bar:HoldsDemon(action)
    return action ~= nil and ns.db.confirmResummon and not SA.inCombat
        and petSummon() == action.spellID
end

-- Demonic Sacrifice, when it is known and a demon it takes is out (a
-- Demonology Warlock sacrifices from the bar, without reopening the wheel:
-- owner). 18788 measured on Forever (the wheel's centre, #19).
function Bar:SacrificeAction()
    if petSummon() and API.IsKnown(Data.DEMONIC_SACRIFICE) then
        return { type = "spell", spell = Data.DEMONIC_SACRIFICE, spellID = Data.DEMONIC_SACRIFICE }
    end
    return nil
end

-- The Demon button (the wheel has its own button):
--   * Left: summon the remembered demon, asking first when it is already
--     out (held: nothing armed, PostClick asks).
--   * Right: Demonic Sacrifice while a demon is out and the talent is known
--     (a Demonology Warlock sacrifices from the bar: owner); otherwise the
--     same summon as the left.
-- In combat there is no question: the summon is armed as combat starts (a
-- demon that dies mid-fight comes straight back).
local function demonActions(action, held, sacrifice)
    local summon = (SA.inCombat or not held) and action or nil
    return { summon, sacrifice or summon }
end

-- One armed slot, as written: type, payload and unit (a changed unit
-- token must rewrite the attributes, #5).
local function keyOf(action)
    return action and (action.type .. ":" .. tostring(action[action.type]) .. "@" .. tostring(action.unit))
        or "none"
end

-- What a button is armed with: both slots, their shift- variants, and, when
-- the Demon button holds (asks first, nothing armed), what it would summon.
-- Any change rewrites the attributes; nothing else does.
local function syncKey(actions, held, action)
    local shift = actions.shift or {}
    return keyOf(actions[1]) .. "|" .. keyOf(actions[2]) .. "|" .. keyOf(shift[1]) .. "|" .. keyOf(shift[2])
        .. (held and ("|held:" .. keyOf(action)) or "")
end

-- Rewrites a button's attributes only when what it does changed.
function Bar:Sync()
    self:RememberPet()
    for _, button in ipairs(self.buttons) do
        local action = RESOLVE[button.key]()
        if action == KEEP then
            -- Unreadable counts: keep what it is armed with.
            action = button.action
        end
        local isDemon = button.key == "demon"
        local sacrifice = isDemon and self:SacrificeAction() or nil
        -- Held whatever Sacrifice does: the left click (and its binding)
        -- still asks before re-summoning the demon that is out (Codex, #19).
        local held = isDemon and self:HoldsDemon(action)
        local actions = isDemon and demonActions(action, held, sacrifice) or { action }
        local key = syncKey(actions, held, action)
        if key == button.syncKey or SA.Apply(button, actions) then
            button.action, button.held, button.sacrifice, button.syncKey = action, held, sacrifice, key
        end
    end
    self:Refresh()
    self:UpdateArmor()
end

------------------------------------------------------------
-- Frames
------------------------------------------------------------

-- "Needs <reagent>" under a tooltip line whose spell lacks its reagent.
local function addNeeds(action)
    GameTooltip:AddLine("Needs " .. (API.ItemName(Data.REAGENT[action.spellID]) or "a reagent"), 1, 0.45, 0.45)
end

function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.label:GetText(), 1, 1, 1)
    if button.armorState == "missing" then
        GameTooltip:AddLine("Not on you", 1, 0.45, 0.45)
    end
    if button.key == "demon" and button.action then
        GameTooltip:AddLine("Click: " .. actionName(button.action)
            .. (button.held and " (already out: asks first)" or ""), 0.75, 0.8, 0.9)
        if button.sacrifice then
            local effect = ns.Wheel.SacrificeEffect(ns.Wheel.DemonName(petSummon()))
            GameTooltip:AddLine("Right-click: " .. actionName(button.sacrifice), 0.75, 0.8, 0.9)
            if effect then GameTooltip:AddLine(effect, 1, 1, 1, true) end
        end
    elseif button.action then
        GameTooltip:AddLine("Click: " .. actionName(button.action), 0.75, 0.8, 0.9)
        if button.short then addNeeds(button.action) end
        local waiting = button.key == "summoning" and #ns.Queue.entries or 0
        if waiting > 0 then
            GameTooltip:AddLine(waiting .. " waiting for a summon", 0.75, 0.8, 0.9)
        end
    else
        GameTooltip:AddLine("Nothing learned for this yet", 0.75, 0.8, 0.9)
    end
    GameTooltip:Show()
end

local function hideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

-- A pulsing accent edge around the button, on its mouse-disabled overlay
-- (placeholder until the Codex art, #13).
function Bar:CreateGlow(button, overlay)
    local glow = overlay:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    glow:Hide()
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.8)
    button.glow, button.pulse = glow, pulse
end

-- Above the glass's top layer, which draws over the host's children.
function Bar:ContentLevel()
    return (self.glass.top or self.frame):GetFrameLevel() + 1
end

function Bar:CreateButton(index, spec, parent)
    local button = SA.Create(parent, "OneTwoThreeBarButton" .. index)
    button:SetSize(ICON, ICON)
    button:SetFrameLevel(self:ContentLevel())
    local x = PAD + HANDLE_W + PITCH * index + (PITCH - ICON) / 2
    button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -PAD)
    button.key = spec.key

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture(ns.Media.WHITE)
    highlight:SetVertexColor(1, 1, 1, 0.15)

    -- Cooldown and text sit on mouse-disabled children of the button.
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:EnableMouse(false)
    button.cooldown = cooldown

    -- The count goes above the cooldown swipe, which draws over the
    -- button's own regions.
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    overlay:EnableMouse(false)
    local count = ns.Skin:Font(overlay, 13, "RIGHT")
    count:SetPoint("BOTTOMRIGHT", -1, 2)
    button.count = count

    local label = ns.Skin:Font(self.glass.top or self.frame, 10, "CENTER")
    label:SetPoint("TOP", button, "BOTTOM", 0, -2)
    label:SetText(spec.label)
    label:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    button.label = label

    if spec.key == "armor" then
        self:CreateGlow(button, overlay)
        self.armorButton = button
    end

    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", hideTooltip)
    -- Insecure PostClick, after the secure action: a click on the Demon
    -- button that armed nothing because the demon is out asks first.
    if spec.key == "demon" then
        button:SetScript("PostClick", function(b, mouseButton, down)
            if down or InCombatLockdown() or not b.held then return end
            if mouseButton == "RightButton" and b.sacrifice then return end
            ns.Resummon:Show(b, b.action.spellID)
        end)
    end
    return button
end

-- "Demons": opens the wheel. A plain button (it casts nothing), left of
-- the secure ones, with Fel Domination's icon (owner: Retail's Summon Demon
-- flyout shows it).
function Bar:CreateWheelButton()
    local button = CreateFrame("Button", "OneTwoThreeBarWheel", self.frame)
    button:SetSize(ICON, ICON)
    button:SetFrameLevel(self:ContentLevel())
    button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD + HANDLE_W + (PITCH - ICON) / 2, -PAD)
    button:RegisterForClicks("AnyUp")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(API.SpellIcon(Data.FEL_DOMINATION))
    button.icon = icon
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture(ns.Media.WHITE)
    highlight:SetVertexColor(1, 1, 1, 0.15)
    local label = ns.Skin:Font(self.glass.top or self.frame, 10, "CENTER")
    label:SetPoint("TOP", button, "BOTTOM", 0, -2)
    label:SetText("Demons")
    label:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    button.label = label
    button:SetScript("OnClick", function() ns.Wheel:Toggle() end)
    button:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText("Demons", 1, 1, 1)
        GameTooltip:AddLine(InCombatLockdown() and "The demon wheel can't open in combat"
            or "Click: the demon wheel", 0.75, 0.8, 0.9)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", hideTooltip)
    self.wheelButton = button
end

function Bar:CreateHandle()
    local handle = CreateFrame("Frame", nil, self.frame)
    handle:SetSize(HANDLE_W, HEIGHT)
    self.handle = handle
    handle:SetFrameLevel(self:ContentLevel())
    handle:SetPoint("LEFT", self.frame, "LEFT", PAD, 0)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    -- Shift-drag moves the bar, so a stray click never does. The bar holds
    -- secure buttons, so it cannot move in combat.
    handle:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not InCombatLockdown() then
            self.frame:StartMoving()
            self.moving = true
        end
    end)
    handle:SetScript("OnDragStop", function() self:StopMoving() end)
    handle:SetScript("OnEnter", function(f)
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:SetText("123", ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
        GameTooltip:AddLine("Shift-drag: move the bar", 0.75, 0.8, 0.9)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", hideTooltip)

    local label = ns.Skin:Font(self.glass.top or self.frame, 13, "CENTER")
    label:SetPoint("CENTER", handle, "CENTER", 0, 0)
    label:SetText("123")
    label:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    self.label = label
end

-- Also called as combat starts: InCombatLockdown() is still false inside
-- PLAYER_REGEN_DISABLED, the last moment a drag can be stopped.
function Bar:StopMoving()
    if not self.moving then return end
    self.moving = false
    self.frame:StopMovingOrSizing()
    local point, _, _, x, y = self.frame:GetPoint()
    ns.db.bar.point, ns.db.bar.x, ns.db.bar.y = point, x, y
    self:Moved()
end

-- The summon queue's list follows the Summoning button (#9).
function Bar:Moved()
    if ns.QueueList then
        ns.QueueList:Remember()
        ns.QueueList:Refresh()
    end
end

-- A bar button by key ("summoning"), or nil.
function Bar:Button(key)
    for _, button in ipairs(self.buttons or {}) do
        if button.key == key then return button end
    end
    return nil
end

function Bar:CreateShards()
    local left = PAD + HANDLE_W + PITCH * SLOTS
    local divider = (self.glass.top or self.frame):CreateTexture(nil, "ARTWORK")
    divider:SetTexture(ns.Media.WHITE)
    divider:SetVertexColor(1, 1, 1, 0.18)
    divider:SetSize(1, HEIGHT - PAD * 2)
    self.divider = divider
    divider:SetPoint("LEFT", self.frame, "LEFT", left, 0)

    local icon = (self.glass.top or self.frame):CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", self.frame, "LEFT", left + 8, 0)
    icon:SetTexture(API.ItemIcon(Data.SOUL_SHARD))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.shardIcon = icon

    local count = ns.Skin:Font(self.glass.top or self.frame, 15, "LEFT")
    count:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    self.shardCount = count
end

function Bar:ApplyPosition()
    local pos = ns.db.bar
    self.frame:ClearAllPoints()
    self.frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    self:Moved()
end

function Bar:Initialize()
    local frame = CreateFrame("Frame", "OneTwoThreeBar", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    self.frame = frame

    self.glass = ns.Skin:Pill(frame)
    self:CreateHandle()
    self:CreateWheelButton()
    self.buttons = {}
    for index, spec in ipairs(self.BUTTONS) do
        self.buttons[index] = self:CreateButton(index, spec, frame)
    end
    self:CreateShards()
    self:ApplyLabels()
    self:ApplyPosition()
    self:ApplyScale()
    self:ApplyShown()

    SA.RegisterSync(function() self:Sync() end)
    local function rebuild() SA.MarkDirty() end
    local function refresh() self:Refresh() end
    -- A rebuild ends in a refresh; in combat only the visuals can change.
    local function bagsChanged()
        if InCombatLockdown() then refresh() else rebuild() end
    end
    ns.Events:Register("SPELLS_CHANGED", rebuild)
    ns.Events:Register("BAG_UPDATE_DELAYED", bagsChanged)
    -- A carried stone skipped for its level becomes usable (#6).
    ns.Events:Register("PLAYER_LEVEL_UP", rebuild)
    ns.Events:Register("BAG_UPDATE_COOLDOWN", refresh)
    ns.Events:Register("SPELL_UPDATE_COOLDOWN", refresh)
    -- The Demon button follows the demon that is out, however it came.
    -- The player's auras only; the payload is secret in combat and unread.
    local auras = CreateFrame("Frame")
    API.RegisterUnitEvent(auras, "UNIT_AURA", "player")
    auras:SetScript("OnEvent", function() self:UpdateArmor() end)
    ns.Events:Register("UNIT_PET", function(_, unit)
        if unit == "player" then rebuild() end
    end)
    -- Last unlocked moment before combat (SA.inCombat is already set): stop
    -- a drag, close the prompt, arm the Demon button without asking and put
    -- the armor glow out. Leaving combat, SecureAction runs the sync.
    ns.Events:Register("PLAYER_REGEN_DISABLED", function()
        self:StopMoving()
        ns.Resummon:Hide()
        SA.RunSyncs()
    end)
    SA.MarkDirty()
end

-- The names under the icons, and the bar's height with or without them.
-- The bar holds secure buttons, so it can't be resized in combat.
function Bar:ApplyLabels()
    if not self.frame or InCombatLockdown() then return false end
    local on = ns.db.barLabels == true
    local h = on and HEIGHT or HEIGHT_BARE
    for _, button in ipairs(self.buttons) do button.label:SetShown(on) end
    self.wheelButton.label:SetShown(on)
    self.frame:SetHeight(h)
    self.handle:SetHeight(h)
    self.divider:SetHeight(h - PAD * 2)
    return true
end

-- Showing, hiding or scaling a frame that holds secure buttons is refused
-- in combat. Both are saved (#15).
function Bar:ApplyShown()
    if not self.frame or InCombatLockdown() then return false end
    self.frame:SetShown(ns.db.bar.shown ~= false)
    return true
end

function Bar:ApplyScale()
    if not self.frame or InCombatLockdown() then return false end
    self.frame:SetScale(tonumber(ns.db.bar.scale) or 1)
    self:Moved()
    return true
end

function Bar:Toggle()
    if not self.frame then return end
    if InCombatLockdown() then
        ns.Print("the bar can't be shown or hidden in combat.")
        return
    end
    ns.db.bar.shown = not self.frame:IsShown()
    self:ApplyShown()
end

-- Back to the default place (moving is refused in combat).
function Bar:ResetPosition()
    if not self.frame or InCombatLockdown() then return end
    local default = ns.Constants.DEFAULTS.bar
    ns.db.bar.point, ns.db.bar.x, ns.db.bar.y = default.point, default.x, default.y
    self:ApplyPosition()
end
