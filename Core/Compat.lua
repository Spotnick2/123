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
