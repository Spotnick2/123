-- ============================================================
-- Compat: the one place the addon touches WoW: Forever's client API.
--
-- Adapted from Portal Roulette's Core/Compat.lua (measured on 70205). What
-- this addon measures itself goes in docs/FOREVER-PROBE.md.
--
-- Secret values: cooldowns and counts may be secret in combat; current
-- health and power are secret even out of combat. A secret may be held and
-- passed back to the client (a Cooldown widget, a FontString), but
-- comparing, truth-testing or doing arithmetic on one throws. Every such use
-- goes through API.Readable first.
-- ============================================================

local _, ns = ...

local API = {}
ns.API = API

-- True when `v` can be compared and used in arithmetic.
function API.Readable(v)
    if issecretvalue and issecretvalue(v) then return false end
    if canaccessvalue and not canaccessvalue(v) then return false end
    return true
end

-- A plain number, or nil when the value is missing or secret. The secret
-- check comes first: even `v == nil` throws on a secret.
function API.Number(v)
    if not API.Readable(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

function API.ClientBuild()
    local _, build = GetBuildInfo()
    return tonumber(build)
end

-- Both mouse edges: the secure click handler acts on the edge matching the
-- player's ActionButtonUseKeyDown, so a single edge leaves the button dead
-- for half the players. Measured by Portal Roulette: one cast per click.
function API.ClickEdges()
    return "AnyUp", "AnyDown"
end

------------------------------------------------------------
-- Events: RegisterEvent on an unknown event throws, and may return false.
------------------------------------------------------------

API.eventFailures = {}

function API.RegisterEvent(frame, event)
    local ok, result = pcall(frame.RegisterEvent, frame, event)
    if ok and result ~= false then return true end
    API.eventFailures[#API.eventFailures + 1] = event .. (ok and " (refused)" or (": " .. tostring(result)))
    return false
end

function API.RegisterEvents(frame, ...)
    local all = true
    for i = 1, select("#", ...) do
        if not API.RegisterEvent(frame, (select(i, ...))) then all = false end
    end
    return all
end

------------------------------------------------------------
-- Player
------------------------------------------------------------

function API.PlayerClass()
    local ok, _, token = pcall(UnitClass, "player")
    if ok and type(token) == "string" and API.Readable(token) then return token end
    return nil
end

------------------------------------------------------------
-- Spells (Portal Roulette's helpers; IDs measured in FOREVER-PROBE.md run 2)
------------------------------------------------------------

function API.SpellName(spellID)
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    if ok and type(name) == "string" and API.Readable(name) then return name end
    return nil
end

function API.SpellIcon(spellID)
    local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
    if ok and icon and API.Readable(icon) then return icon end
    return nil
end

-- C_SpellBook.IsSpellKnown and IsPlayerSpell agreed on every Warlock ID (run 2).
function API.IsKnown(spellID)
    if not spellID then return false end
    local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
    if ok and known == true then return true end
    local okP, has = pcall(IsPlayerSpell, spellID)
    return okP and has == true
end

-- The first known spell of a list ordered best first.
function API.FirstKnown(spellIDs)
    for _, spellID in ipairs(spellIDs) do
        if API.IsKnown(spellID) then return spellID end
    end
    return nil
end

-- A LuaDurationObject for a Cooldown widget, or nil. Safe with secrets.
function API.SpellCooldownDuration(spellID)
    local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    if ok then return duration end
    return nil
end

------------------------------------------------------------
-- Items
------------------------------------------------------------

-- Answers without the item cache.
function API.ItemIcon(itemID)
    local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
    if ok and icon and API.Readable(icon) then return icon end
    return nil
end

function API.ItemName(itemID)
    local ok, name = pcall(C_Item.GetItemNameByID, itemID)
    if ok and type(name) == "string" and API.Readable(name) then return name end
    return nil
end

-- Raw count: may be secret in combat. Pass it to a FontString as is.
function API.ItemCountRaw(itemID)
    local ok, count = pcall(C_Item.GetItemCount, itemID)
    if ok then return count end
    return nil
end

-- A plain count, or nil when unreadable.
function API.ItemCount(itemID)
    return API.Number(API.ItemCountRaw(itemID))
end

-- The first item of a list (best first) the player carries, and its count.
-- Out of combat only in practice: counts may be secret in combat.
function API.FirstCarried(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        local count = API.ItemCount(itemID)
        if count and count > 0 then return itemID, count end
    end
    return nil
end

-- (start, duration, enable) as C_Container.GetItemCooldown returns them;
-- possibly secret. Never compare them here.
function API.ItemCooldown(itemID)
    return C_Container.GetItemCooldown(itemID)
end
