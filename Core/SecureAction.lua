-- ============================================================
-- SecureAction: the single writer of secure attributes.
--
-- Portal Roulette's Core/SecureAction.lua, with `unitN` added (a click aimed
-- at a group member: soulstone target #5, summon queue #10). Rules
-- (measured, AGENTS.md):
--   * SecureActionButtonTemplate, RegisterForClicks("AnyUp", "AnyDown"):
--     one cast per click whichever edge the player casts on.
--   * Numbered families only: typeN + spellN / itemN, plus unitN. Unnumbered
--     `type` is never set, so an unbound button does nothing.
--   * NEVER typerelease (any variant): it casts twice and spends two
--     reagents.
--   * SetAttribute silently does nothing in combat: writes happen out of
--     combat only, through a coalesced rebuild (MarkDirty -> sync) that
--     resolves the CURRENT state when it runs, never a replay of old writes.
-- ============================================================

local _, ns = ...

local SA = {
    syncs = {},
    dirty = false,
}
ns.SecureAction = SA

local API = ns.API

-- Every attribute family a rebuild clears, numbered and not.
SA.FAMILIES = { "type", "spell", "item", "macro", "macrotext", "unit", "typerelease" }
SA.SUFFIXES = { "", "1", "2" }

function SA.Create(parent, name)
    local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    button:RegisterForClicks(API.ClickEdges())
    return button
end

-- Clear every family. Returns false (and changes nothing) in combat.
function SA.Clear(button)
    if InCombatLockdown() then
        return false
    end
    for _, family in ipairs(SA.FAMILIES) do
        for _, suffix in ipairs(SA.SUFFIXES) do
            if button:GetAttribute(family .. suffix) ~= nil then
                button:SetAttribute(family .. suffix, nil)
            end
        end
    end
    return true
end

-- actions = { [1] = { type = "spell", spell = 688 }, [2] = { type = "item", item = "item:5512", unit = "party1" } }
-- Index 1 is the left mouse button, 2 the right. Everything is cleared
-- first, so a family set by an earlier state never lingers (a stale unit
-- token must never retarget someone else).
function SA.Apply(button, actions)
    if not SA.Clear(button) then
        return false
    end
    for index = 1, 2 do
        local action = actions and actions[index]
        if action and action.type then
            local suffix = tostring(index)
            button:SetAttribute("type" .. suffix, action.type)
            local payload = action[action.type]
            if payload ~= nil then
                button:SetAttribute(action.type .. suffix, payload)
            end
            if action.unit then
                button:SetAttribute("unit" .. suffix, action.unit)
            end
        end
    end
    return true
end

-- True when the button would do something on a click.
function SA.HasAction(button)
    for _, suffix in ipairs(SA.SUFFIXES) do
        if button:GetAttribute("type" .. suffix) ~= nil then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- Coalesced sync
------------------------------------------------------------

-- Register a function that rebuilds attributes from the current state.
function SA.RegisterSync(fn)
    SA.syncs[#SA.syncs + 1] = fn
end

function SA.RunSyncs()
    if InCombatLockdown() then
        SA.dirty = true
        return false
    end
    SA.dirty = false
    for _, fn in ipairs(SA.syncs) do
        fn()
    end
    return true
end

-- Ask for a rebuild: now when possible, otherwise once combat ends. Many
-- requests in one frame collapse into one rebuild.
function SA.MarkDirty()
    SA.dirty = true
    if SA.pending then
        return
    end
    SA.pending = true
    C_Timer.After(0, function()
        SA.pending = false
        if SA.dirty then
            SA.RunSyncs()
        end
    end)
end

-- SA owns the combat flag, so every sync sees one consistent answer. Its
-- handlers are registered before any module's, so the flag is set before
-- they run. Leaving combat always runs one sync: what a button does can
-- depend on being in combat (Bar:HoldsDemon), and auras are readable again.
function SA.Initialize()
    ns.Events:Register("PLAYER_REGEN_DISABLED", function()
        SA.inCombat = true
    end)
    ns.Events:Register("PLAYER_REGEN_ENABLED", function()
        SA.inCombat = false
        SA.RunSyncs()
    end)
end

------------------------------------------------------------
-- Cooldowns: values may be secret in combat. They go to the widget
-- untouched; only their presence is checked, through type() on a
-- non-secret value.
------------------------------------------------------------

function SA.ApplyItemCooldown(cooldown, itemID)
    local ok, start, duration = pcall(API.ItemCooldown, itemID)
    if not ok then
        return
    end
    if not API.Readable(start) or not API.Readable(duration) then
        pcall(cooldown.SetCooldown, cooldown, start, duration)
        return
    end
    if type(start) ~= "number" or type(duration) ~= "number" then
        cooldown:Clear()
        return
    end
    cooldown:SetCooldown(start, duration)
end

function SA.ApplySpellCooldown(cooldown, spellID)
    local duration = API.SpellCooldownDuration(spellID)
    if not API.Readable(duration) then
        pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
        return
    end
    if duration == nil then
        cooldown:Clear()
        return
    end
    pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
end
