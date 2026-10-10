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

-- Every attribute family a rebuild clears, numbered and not, plain and
-- shift-modified. `action` is the pet bar slot of type "pet".
SA.FAMILIES = { "type", "spell", "item", "macro", "macrotext", "action", "unit", "typerelease" }
SA.SUFFIXES = { "", "1", "2" }
SA.PREFIXES = { "", "shift-" }

-- Where each type keeps its payload (SecureTemplates.lua SECURE_ACTIONS).
local PAYLOAD = { macro = "macrotext", pet = "action" }

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
    for _, prefix in ipairs(SA.PREFIXES) do
        for _, family in ipairs(SA.FAMILIES) do
            for _, suffix in ipairs(SA.SUFFIXES) do
                local key = prefix .. family .. suffix
                if button:GetAttribute(key) ~= nil then
                    button:SetAttribute(key, nil)
                end
            end
        end
    end
    return true
end

local function write(button, prefix, index, action)
    if not (action and action.type) then return end
    local suffix = tostring(index)
    button:SetAttribute(prefix .. "type" .. suffix, action.type)
    local key = PAYLOAD[action.type] or action.type
    if action[key] ~= nil then
        button:SetAttribute(prefix .. key .. suffix, action[key])
    end
    if action.unit then
        button:SetAttribute(prefix .. "unit" .. suffix, action.unit)
    end
end

-- actions = {
--     [1] = { type = "spell", spell = 688 },                      -- left button
--     [2] = { type = "item", item = "item:5512", unit = "party1" }, -- right button
--     shift = { [1] = { type = "macro", macrotext = "/cast ..." } },
-- }
-- Types: spell, item, macro (macrotext), pet (action = pet bar slot).
-- Everything is cleared first, so a family set by an earlier state never
-- lingers (a stale unit token must never retarget someone else).
function SA.Apply(button, actions)
    if not SA.Clear(button) then
        return false
    end
    for index = 1, 2 do
        write(button, "", index, actions and actions[index])
        write(button, "shift-", index, actions and actions.shift and actions.shift[index])
    end
    return true
end

-- True when the button would do something on a click.
function SA.HasAction(button)
    for _, prefix in ipairs(SA.PREFIXES) do
        for _, suffix in ipairs(SA.SUFFIXES) do
            if button:GetAttribute(prefix .. "type" .. suffix) ~= nil then
                return true
            end
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
