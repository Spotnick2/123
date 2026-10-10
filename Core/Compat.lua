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

-- One unit's events only (UNIT_AURA would otherwise arrive for every raid
-- member and nameplate).
function API.RegisterUnitEvent(frame, event, unit)
    local ok, result = pcall(frame.RegisterUnitEvent, frame, event, unit)
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

-- The NPC id in a creature's or pet's GUID ("Pet-0-...-1860-..."), or nil.
function API.UnitGUID(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and API.Readable(guid) and type(guid) == "string" then return guid end
    return nil
end

function API.UnitNpcID(unit)
    local guid = API.UnitGUID(unit)
    return guid and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
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
    if ok and API.Readable(icon) and icon then return icon end
    return nil
end

-- C_SpellBook.IsSpellKnown and IsPlayerSpell agreed on every Warlock ID (run 2).
function API.IsKnown(spellID)
    if not spellID then return false end
    local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
    if ok and API.Readable(known) and known == true then return true end
    local okP, has = pcall(IsPlayerSpell, spellID)
    return okP and API.Readable(has) and has == true
end

-- The first known spell of a list ordered best first.
function API.FirstKnown(spellIDs)
    for _, spellID in ipairs(spellIDs) do
        if API.IsKnown(spellID) then return spellID end
    end
    return nil
end

------------------------------------------------------------
-- Auras. Measured (PORTING-TBC-TO-FOREVER.md "Auras go dark"): in combat an
-- index read THROWS, the by-name lookup quietly returns nil, and comparing a
-- secret field throws. So: an index walk with every touch inside one pcall,
-- and a third answer, nil, for "can't tell".
------------------------------------------------------------

-- A secret anywhere raises, so the pcall below answers "can't tell" instead
-- of a lookup silently missing and reporting the aura absent.
local function walkAuras(unit, ids, names)
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not API.Readable(aura) then error("secret aura") end
        if not aura then return false end
        local spellId, name = aura.spellId, aura.name
        if not API.Readable(spellId) or not API.Readable(name) then error("secret aura field") end
        if ids[spellId] or names[name] then return true end
    end
    return false
end

-- true / false, or nil when the auras can't be read (combat).
function API.HasAura(unit, ids, names)
    local ok, found = pcall(walkAuras, unit, ids, names)
    if ok then return found end
    return nil
end

function API.SpellDescription(spellID)
    local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
    if ok and API.Readable(text) and type(text) == "string" and text ~= "" then return text end
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
    if ok and API.Readable(icon) and icon then return icon end
    return nil
end

function API.ItemName(itemID)
    local ok, name = pcall(C_Item.GetItemNameByID, itemID)
    if ok and type(name) == "string" and API.Readable(name) then return name end
    return nil
end

function API.RequestItemData(itemID)
    pcall(C_Item.RequestLoadItemDataByID, itemID)
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
