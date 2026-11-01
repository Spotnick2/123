-- ============================================================
-- Bar: the compact bar (storyboard panel 01, issue #3).
--
--   [123] Demons · Demon · Armor · Soulstone · Healthstone · Summoning
--         · Banish · Subjugate (once learned, #29) | shards
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
local L = ns.L

local ICON = 36
local PITCH = 60            -- button centre to centre (room for "Healthstone")
local PAD = 8
local HANDLE_W = 34
local SHARD_W = 56
local LABEL_H = 12
local LABEL_W = PITCH - 4     -- a name's room under its icon, clear of the next one
-- The wheel's button, then the secure ones shown (Bar:Layout).
local function widthFor(slots)
    return PAD + HANDLE_W + PITCH * slots + 1 + SHARD_W + PAD
end
local WIDTH = widthFor(6)
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
    -- A carried soulstone goes to the picked target (#5), out of combat
    -- only, as Summoning: from combat's start, on your target.
    soulstone = function()
        local action = stone(Data.SOULSTONE_TIERS)
        if action and action ~= KEEP and action.itemID and not SA.inCombat then
            local unit = ns.SoulTarget:Unit()
            if unit then action.unit, action.name = unit, ns.SoulTarget:Get().name end
        end
        return action
    end,
    healthstone = function()
        return stone(Data.HEALTHSTONE_TIERS)
    end,
    -- Ritual of Summoning on the next in the summon queue (#10), out of
    -- combat only: a roster change in combat can't rewrite the unit token,
    -- so from combat's start the button casts on the target instead and a
    -- stale token never hits someone else. Unaimed with no one waiting.
    summoning = function()
        local spellID = Data.RITUAL_OF_SUMMONING
        if not API.IsKnown(spellID) then return nil end
        local action = spellAction(spellID)
        local entry, unit
        if not SA.inCombat then entry, unit = ns.Queue:Next() end
        if entry then action.unit, action.guid, action.name = unit, entry.guid, entry.name end
        return action
    end,
    -- The best rank known, on the target (#29).
    banish = function()
        local spellID = API.FirstKnown(Data.BANISH)
        return spellID and spellAction(spellID) or nil
    end,
    subjugate = function()
        local spellID = API.FirstKnown(Data.SUBJUGATE)
        return spellID and spellAction(spellID) or nil
    end,
}

-- The Subjugate button's right click (#29): dismiss the pet, unless it is
-- one of the Warlock's own demons. /petdismiss ignores conditionals
-- (FrameXML SlashCommands.lua), so a /stopmacro guards it; families by
-- the client's names, English when it gives none. A Doomguard isn't one of
-- them: Ritual of Doom's is subjugated like any demon.
local OWN_FAMILIES = {
    { 23, "Imp" }, { 16, "Voidwalker" }, { 17, "Succubus" }, { 302, "Incubus" }, { 15, "Felhunter" },
}
function Bar.DismissMacro()
    local names = {}
    for i, f in ipairs(OWN_FAMILIES) do names[i] = API.FamilyName(f[1]) or f[2] end
    return "/stopmacro [nopet][pet:" .. table.concat(names, "/") .. "]\n/petdismiss"
end

-- The icon shown while nothing is armed (not learned yet).
local IDLE_ICON = {
    demon = { spell = 688 },
    armor = { spell = 687 },
    soulstone = { item = 5232 },
    healthstone = { item = 5512 },
    summoning = { spell = Data.RITUAL_OF_SUMMONING },
    banish = { spell = 710 },
    subjugate = { spell = 1098 },
}

Bar.BUTTONS = {
    { key = "demon", label = L["Demon"] },
    { key = "armor", label = L["Armor"] },
    { key = "soulstone", label = L["Soulstone"] },
    { key = "healthstone", label = L["Healthstone"] },
    { key = "summoning", label = L["Summoning"] },
    -- Shown only once learned (#29): Banish at 28, Subjugate Demon at 30.
    { key = "banish", label = L["Banish"], optional = true },
    { key = "subjugate", label = L["Subjugate"], optional = true },
}

-- A name wider than its room (#22: "Gesundheitsstein", "Pierre de soins")
-- gets a smaller font, so neighbours never run into each other.
function Bar.FitLabel(label, text)
    label:SetText(text)
    local font, size, flags = label:GetFont()
    local width = label:GetUnboundedStringWidth()
    if font and size and width and width > LABEL_W then
        label:SetFont(font, math.floor(size * LABEL_W / width * 10) / 10, flags)
    end
end

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
        return L["Use %s"]:format(API.ItemName(action.itemID) or L["item %d"]:format(action.itemID))
    end
    return API.SpellName(action.spellID) or L["spell %d"]:format(action.spellID)
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
    ns.BarEffects.Update(button)
    if button.target then self:RefreshTarget(button) end
    if button.timer and self:RefreshTimer(button) then return end
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

-- The soulstone target's first name on the Soulstone icon (#5): in class
-- colour while the stone goes to them, grey while it doesn't (in combat,
-- or creating a stone).
local function classColor(class)
    local c = class and RAID_CLASS_COLORS[class]
    if type(c) == "table" then return c.r, c.g, c.b end
    return 1, 1, 1
end

function Bar:RefreshTarget(button)
    local picked = ns.SoulTarget:Get()
    if not picked then
        button.target:SetText("")
        return
    end
    button.target:SetText((picked.name or "?"):match("^(%S+)") or picked.name)
    if button.action and button.action.name then
        button.target:SetTextColor(classColor(picked.class))
    else
        button.target:SetTextColor(0.6, 0.6, 0.6)
    end
end

-- A Banish or a subjugation running (#29): the swipe and the time left
-- replace the spell's cooldown. Returns true while one runs.
local function timeLeft(left)
    if left >= 60 then return L["%dm"]:format(math.ceil(left / 60)) end
    return tostring(math.ceil(left))
end
Bar.TimeLeft = timeLeft

function Bar:RefreshTimer(button)
    local timer = ns.Control[button.key]
    local left = ns.Control.Left(timer)
    if not left then
        button.timer:SetText("")
        button.timerStart = nil
        return false
    end
    button.timer:SetText(timeLeft(left))
    if button.timerStart ~= timer.start then
        button.timerStart = timer.start
        button.cooldown:SetCooldown(timer.start, timer.duration)
    end
    button.count:SetText("")
    return true
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
    ns.BarEffects.Update(button)
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

-- Which buttons the bar shows and where (out of combat only: they are
-- secure). The optional ones (#29) only once learned; the bar is as wide
-- as what it shows, and the shards follow.
function Bar:Layout()
    if InCombatLockdown() then return false end
    local slot = 1
    for _, button in ipairs(self.buttons) do
        local shown = not button.optional or RESOLVE[button.key]() ~= nil
        button:SetShown(shown)
        if shown then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD + HANDLE_W + PITCH * slot + (PITCH - ICON) / 2, -PAD)
            slot = slot + 1
        end
    end
    if slot ~= self.slots then
        self.slots = slot
        local left = PAD + HANDLE_W + PITCH * slot
        self.frame:SetWidth(widthFor(slot))
        self.divider:ClearAllPoints()
        self.divider:SetPoint("LEFT", self.frame, "LEFT", left, 0)
        self.shardIcon:ClearAllPoints()
        self.shardIcon:SetPoint("LEFT", self.frame, "LEFT", left + 8, 0)
        self:Moved()
    end
    return true
end

-- Rewrites a button's attributes only when what it does changed.
function Bar:Sync()
    self:RememberPet()
    self:Layout()
    for _, button in ipairs(self.buttons) do
        local action = RESOLVE[button.key]()
        if action == KEEP then
            -- Unreadable counts: keep what it is armed with, but never a
            -- unit token into combat (#5): it can't be rewritten there.
            action = button.action
            if action and action.unit and SA.inCombat then
                action = itemAction(action.itemID)
            end
        end
        local isDemon = button.key == "demon"
        local sacrifice = isDemon and self:SacrificeAction() or nil
        -- Held whatever Sacrifice does: the left click (and its binding)
        -- still asks before re-summoning the demon that is out (Codex, #19).
        local held = isDemon and self:HoldsDemon(action)
        local actions = isDemon and demonActions(action, held, sacrifice) or { action }
        if button.key == "subjugate" and action then
            actions[2] = { type = "macro", macrotext = Bar.DismissMacro() }
        end
        local key = syncKey(actions, held, action)
        if key == button.syncKey or SA.Apply(button, actions) then
            button.action, button.held, button.sacrifice, button.syncKey = action, held, sacrifice, key
        end
    end
    self:Refresh()
    self:UpdateArmor()
    -- The list marks whom the Summoning button is now aimed at (#10).
    ns.QueueList:Refresh()
end

------------------------------------------------------------
-- Frames
------------------------------------------------------------

-- "Needs <reagent>" under a tooltip line whose spell lacks its reagent.
local function addNeeds(action)
    GameTooltip:AddLine(L["Needs %s"]:format(API.ItemName(Data.REAGENT[action.spellID]) or L["a reagent"]), 1, 0.45, 0.45)
end

function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.label:GetText(), 1, 1, 1)
    if button.armorState == "missing" then
        GameTooltip:AddLine(L["Not on you"], 1, 0.45, 0.45)
    end
    if button.key == "demon" and button.action then
        GameTooltip:AddLine(L["Click: %s"]:format(actionName(button.action))
            .. (button.held and (" " .. L["(already out: asks first)"]) or ""), 0.75, 0.8, 0.9)
        if button.sacrifice then
            local effect = ns.Wheel.SacrificeEffect(ns.Wheel.DemonName(petSummon()))
            GameTooltip:AddLine(L["Right-click: %s"]:format(actionName(button.sacrifice)), 0.75, 0.8, 0.9)
            if effect then GameTooltip:AddLine(effect, 1, 1, 1, true) end
        end
    elseif button.action then
        local click = button.action.name and L["Click: %s on %s"]:format(actionName(button.action), button.action.name)
            or L["Click: %s"]:format(actionName(button.action))
        GameTooltip:AddLine(click, 0.75, 0.8, 0.9)
        if button.short then addNeeds(button.action) end
        if button.key == "banish" or button.key == "subjugate" then
            local left = ns.Control.Left(ns.Control[button.key])
            if left and button.key == "banish" then
                GameTooltip:AddLine(L["Banished: %s left"]:format(timeLeft(left)), 1, 1, 1)
                GameTooltip:AddLine(L["From the cast: a break before that can't be seen."], 0.75, 0.8, 0.9, true)
            elseif left then
                GameTooltip:AddLine(L["Subjugated: %s left at most"]:format(timeLeft(left)), 1, 1, 1)
            end
            if button.key == "subjugate" then
                GameTooltip:AddLine(L["Right-click: dismiss the subjugated demon"], 0.75, 0.8, 0.9)
            end
        end
        if button.key == "soulstone" then
            local picked = ns.SoulTarget:Get()
            if picked and not button.action.name and button.action.itemID then
                GameTooltip:AddLine(L["%s: in combat, on your target"]:format(picked.name), 0.75, 0.8, 0.9)
            end
            GameTooltip:AddLine(L["Right-click: choose who gets it"], 0.75, 0.8, 0.9)
        end
        local waiting = button.key == "summoning" and #ns.Queue.entries or 0
        if waiting > 0 then
            GameTooltip:AddLine(L["%d waiting for a summon"]:format(waiting), 0.75, 0.8, 0.9)
        end
    else
        GameTooltip:AddLine(L["Nothing learned for this yet"], 0.75, 0.8, 0.9)
    end
    GameTooltip:Show()
end

local function hideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
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
    button.key, button.optional = spec.key, spec.optional

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

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
    Bar.FitLabel(label, spec.label)
    label:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    button.label = label

    if spec.key == "armor" then
        self.armorButton = button
    end

    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", hideTooltip)
    -- After the scripts: the hover rim hooks them (SetScript drops hooks).
    ns.BarEffects.Attach(button, overlay)
    -- Insecure PostClick, after the secure action: a click on the Demon
    -- button that armed nothing because the demon is out asks first.
    if spec.key == "demon" then
        button:SetScript("PostClick", function(b, mouseButton, down)
            if down or InCombatLockdown() or not b.held then return end
            if mouseButton == "RightButton" and b.sacrifice then return end
            ns.Resummon:Show(b, b.action.spellID)
        end)
    elseif spec.key == "summoning" then
        -- Who the click aimed the ritual at, for the summon's tracking (#10).
        button:SetScript("PostClick", function(b) ns.Summon:Clicked(b.action) end)
    elseif spec.key == "banish" or spec.key == "subjugate" then
        -- How long the Banish or the subjugation has left (#29).
        local timer = ns.Skin:Font(overlay, 14, "CENTER")
        timer:SetPoint("CENTER", 0, 0)
        button.timer = timer
    elseif spec.key == "soulstone" then
        -- The right click is unarmed (no type2): it opens the target picker
        -- (#5). Its first name sits on the icon, in class colour.
        button:SetScript("PostClick", function(_, mouseButton, down)
            if mouseButton == "RightButton" and not down then ns.SoulPicker:Toggle() end
        end)
        local target = ns.Skin:Font(overlay, 10, "CENTER")
        target:SetPoint("TOP", 0, -2)
        button.target = target
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
    local label = ns.Skin:Font(self.glass.top or self.frame, 10, "CENTER")
    label:SetPoint("TOP", button, "BOTTOM", 0, -2)
    Bar.FitLabel(label, L["Demons"])
    label:SetTextColor(ns.Colors.MUTED[1], ns.Colors.MUTED[2], ns.Colors.MUTED[3], ns.Colors.MUTED[4])
    button.label = label
    button:SetScript("OnClick", function() ns.Wheel:Toggle() end)
    button:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText(L["Demons"], 1, 1, 1)
        GameTooltip:AddLine(InCombatLockdown() and L["The demon wheel can't open in combat"]
            or L["Click: the demon wheel"], 0.75, 0.8, 0.9)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", hideTooltip)
    ns.BarEffects.Attach(button, button, true)
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
        GameTooltip:AddLine(L["Shift-drag: move the bar"], 0.75, 0.8, 0.9)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", hideTooltip)

    local label = ns.Skin:Font(self.glass.top or self.frame, 13, "CENTER")
    label:SetPoint("CENTER", handle, "CENTER", 0, 0)
    label:SetText("123")
    label:SetTextColor(ns.Colors.ACCENT[1], ns.Colors.ACCENT[2], ns.Colors.ACCENT[3])
    ns.BarEffects.Grip(handle)
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

-- The top centre of a bar button, in UIParent's coordinates (x, top), or
-- nil when it can't be read: where the lists above the bar hang (#9, #5).
function Bar:TopOf(key)
    local button = self:Button(key)
    if not button then return nil end
    local ok, x, top, scale = pcall(function()
        local cx = button:GetCenter()
        return cx, button:GetTop(), button:GetEffectiveScale() / UIParent:GetEffectiveScale()
    end)
    x, top, scale = ok and API.Number(x), ok and API.Number(top), ok and API.Number(scale)
    if not (x and top and scale) then return nil end
    return x * scale, top * scale
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
    local left = PAD + HANDLE_W + PITCH * 6  -- until Bar:Layout places them
    local divider = (self.glass.top or self.frame):CreateTexture(nil, "ARTWORK")
    divider:SetTexture(ns.Media.BAR_DIVIDER)
    divider:SetVertexColor(1, 1, 1, 0.18)
    divider:SetSize(8, HEIGHT - PAD * 2)
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

    -- The countdowns and the break glow (#29), in combat too: visuals only.
    ns.Control:OnChanged(function()
        for _, key in ipairs({ "banish", "subjugate" }) do
            local b = self:Button(key)
            if b then
                self:RefreshButton(b)
                if GameTooltip:IsOwned(b) then showTooltip(b) end
            end
        end
    end)
    -- The queue's order and states decide whom the ritual aims at (#10).
    ns.Queue:OnChanged(function()
        ns.BarEffects.Update(self:Button("summoning"))
        SA.MarkDirty()
    end)
    -- A roster change moves unit tokens ("party2" becomes someone else):
    -- rebuild now, not a frame later, so a click never meets a stale one.
    ns.Events:Register("GROUP_ROSTER_UPDATE", function() SA.RunSyncs() end)
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
        ns.Print(L["the bar can't be shown or hidden in combat."])
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
