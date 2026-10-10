-- ============================================================
-- Bar: the compact bar (storyboard panel 01, issue #3).
--
--   [123] Demon · Armor · Soulstone · Healthstone · Summoning | shard count
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
local WIDTH = PAD + HANDLE_W + PITCH * 5 + 1 + SHARD_W + PAD
local HEIGHT = PAD + ICON + 2 + LABEL_H + PAD

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

-- Use the best stone carried, else create the best rank known.
local function stone(items, creates)
    local itemID = API.FirstCarried(items)
    if itemID then
        return itemAction(itemID)
    end
    local spellID = API.FirstKnown(creates)
    return spellID and spellAction(spellID) or nil
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
    demon = function()
        local last = ns.char.demon
        local spellID = (last and API.IsKnown(last)) and last or API.FirstKnown(Data.DEMONS)
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
        return stone(Data.SOULSTONES, Data.CREATE_SOULSTONE)
    end,
    healthstone = function()
        return stone(Data.HEALTHSTONES, Data.CREATE_HEALTHSTONE)
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

function Bar:RefreshButton(button)
    local action = button.action
    button.icon:SetTexture(actionIcon(action, button.key))
    button.icon:SetDesaturated(action == nil)
    button.icon:SetAlpha(action and 1 or 0.45)
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
function Bar:RememberPet()
    local spellID = petSummon()
    if spellID then
        ns.char.demon = spellID
    end
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

-- The Demon button:
--   * Left: the wheel (PostClick, nothing armed).
--   * Right: Demonic Sacrifice while a demon is out and the talent is known;
--     otherwise re-summon the remembered demon (asking first when it is
--     already out).
-- The wheel can't open in combat, so there the left button summons, armed
-- as combat starts (a demon that dies mid-fight comes straight back), and
-- the right one keeps Sacrifice, else summons too.
local function demonActions(action, held, sacrifice)
    if SA.inCombat then return { action, sacrifice or action } end
    return { nil, sacrifice or (not held and action or nil) }
end

-- What a button is armed with; the Demon button's also depends on combat
-- and on Sacrifice.
local function syncKey(key, action, held, sacrifice)
    if not action then return "none" end
    return action.type .. ":" .. tostring(action[action.type]) .. (held and ":held" or "")
        .. ((key == "demon" and SA.inCombat) and ":combat" or "")
        .. (sacrifice and ":sacrifice" or "")
end

-- Rewrites a button's attributes only when what it does changed.
function Bar:Sync()
    self:RememberPet()
    for _, button in ipairs(self.buttons) do
        local action = RESOLVE[button.key]()
        local isDemon = button.key == "demon"
        local sacrifice = isDemon and self:SacrificeAction() or nil
        local held = isDemon and not sacrifice and self:HoldsDemon(action)
        local actions = isDemon and demonActions(action, held, sacrifice) or { action }
        local key = syncKey(button.key, action, held, sacrifice)
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

function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.label:GetText(), 1, 1, 1)
    if button.armorState == "missing" then
        GameTooltip:AddLine("Not on you", 1, 0.45, 0.45)
    end
    if button.key == "demon" and not SA.inCombat then
        GameTooltip:AddLine("Click: demon wheel", 0.75, 0.8, 0.9)
        if button.sacrifice then
            local effect = ns.Wheel.SacrificeEffect(ns.Wheel.DemonName(petSummon()))
            GameTooltip:AddLine("Right-click: " .. actionName(button.sacrifice), 0.75, 0.8, 0.9)
            if effect then GameTooltip:AddLine(effect, 1, 1, 1, true) end
        elseif button.action then
            GameTooltip:AddLine("Right-click: " .. actionName(button.action)
                .. (button.held and " (already out: asks first)" or ""), 0.75, 0.8, 0.9)
        end
    elseif button.action then
        GameTooltip:AddLine("Click: " .. actionName(button.action), 0.75, 0.8, 0.9)
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
    local x = PAD + HANDLE_W + PITCH * (index - 1) + (PITCH - ICON) / 2
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
    -- Insecure PostClick, after the secure action: the Demon button's left
    -- click opens the wheel, and its right click asks before re-summoning.
    if spec.key == "demon" then
        button:SetScript("PostClick", function(b, mouseButton, down)
            if down or InCombatLockdown() then return end
            if mouseButton == "RightButton" then
                if b.held and not b.sacrifice then ns.Resummon:Show(b, b.action.spellID) end
            else
                ns.Wheel:Toggle()
            end
        end)
    end
    return button
end

function Bar:CreateHandle()
    local handle = CreateFrame("Frame", nil, self.frame)
    handle:SetSize(HANDLE_W, HEIGHT)
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
end

function Bar:CreateShards()
    local left = PAD + HANDLE_W + PITCH * 5
    local divider = (self.glass.top or self.frame):CreateTexture(nil, "ARTWORK")
    divider:SetTexture(ns.Media.WHITE)
    divider:SetVertexColor(1, 1, 1, 0.18)
    divider:SetSize(1, HEIGHT - PAD * 2)
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
    self.buttons = {}
    for index, spec in ipairs(self.BUTTONS) do
        self.buttons[index] = self:CreateButton(index, spec, frame)
    end
    self:CreateShards()
    self:ApplyPosition()
    frame:Show()

    SA.RegisterSync(function() self:Sync() end)
    local function rebuild() SA.MarkDirty() end
    local function refresh() self:Refresh() end
    -- A rebuild ends in a refresh; in combat only the visuals can change.
    local function bagsChanged()
        if InCombatLockdown() then refresh() else rebuild() end
    end
    ns.Events:Register("SPELLS_CHANGED", rebuild)
    ns.Events:Register("BAG_UPDATE_DELAYED", bagsChanged)
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

-- Showing or hiding a frame that holds secure buttons is refused in combat.
function Bar:Toggle()
    if not self.frame then return end
    if InCombatLockdown() then
        ns.Print("the bar can't be shown or hidden in combat.")
        return
    end
    self.frame:SetShown(not self.frame:IsShown())
end
