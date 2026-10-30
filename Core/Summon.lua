-- ============================================================
-- Summon (#10): follows Ritual of Summoning and each queued member's
-- summon, and sets their place in it (Queue:SetState).
--
--   ritual starts on them        -> "summoning"
--   their prompt is up           -> "pending"    (IncomingSummonStatus)
--   they accept / decline        -> "accepted" / "declined"
--   prompt gone, never accepted  -> waiting again (timed out, cancelled)
--   ritual ends with no prompt   -> waiting again, a few seconds later
--
-- An accepted member leaves the queue once they are near (Queue:Prune).
-- A status that can't be read changes nothing.
--
-- The ritual counts from START or CHANNEL_START, never from SENT: a cast
-- refused at once (no target, too far) announces nothing. Who it is on: the
-- member the Summoning button was clicked for, else the cast's target name
-- (UNIT_SPELLCAST_SENT, just before), else the target. The
-- ritual's events and the status transitions are unmeasured on Forever
-- (FOREVER-PROBE.md row 4).
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local Data = ns.Data

local Summon = {}
ns.Summon = Summon

-- A click on the Summoning button counts for a cast this soon after it.
local CLICK_WINDOW = 2
-- How long a ritual that ended with no prompt keeps "summoning".
local SETTLE = 3

-- PostClick on the Summoning button: what it was armed with.
function Summon:Clicked(action)
    self.clicked = action and action.guid and { guid = action.guid, at = GetTime() } or nil
end

local function readable(v)
    return API.Readable(v) and v or nil
end

-- The queued member a ritual is on, or nil.
function Summon:EntryFor(targetName)
    local Queue = ns.Queue
    local c = self.clicked
    if c and GetTime() - c.at <= CLICK_WINDOW and Queue:Find(c.guid) then
        return Queue:Find(c.guid)
    end
    if type(targetName) == "string" and targetName ~= "" then
        local short = targetName:match("^([^%-]+)") or targetName
        for _, e in ipairs(Queue.entries) do
            if e.name == targetName or e.name == short then return e end
        end
    end
    local guid = API.UnitGUID("target")
    return guid and Queue:Find(guid) or nil
end

-- UNIT_SPELLCAST_SENT: the cast's target name, for the start that follows.
function Summon:Sent(castGUID, targetName)
    self.sent = { castGUID = castGUID, name = targetName, at = GetTime() }
end

-- The SENT target name of this cast (same GUID, or a second ago when
-- either GUID is unreadable).
function Summon:SentName(castGUID, now)
    local sent = self.sent
    if not sent then return nil end
    if (castGUID and sent.castGUID) and castGUID ~= sent.castGUID then return nil end
    if now - sent.at > 1 then return nil end
    return sent.name
end

-- START or CHANNEL_START: the first one of a cast counts. An unreadable
-- cast GUID falls back to "a second start within a second is the same".
function Summon:Started(castGUID)
    local now = GetTime()
    local last = self.cast
    if last and ((castGUID and castGUID == last.castGUID) or (not castGUID and now - last.at < 1)) then
        return false
    end
    local targetName = self:SentName(castGUID, now)
    self.sent = nil
    local entry = self:EntryFor(targetName)
    self.clicked = nil
    self.cast = { castGUID = castGUID, at = now, guid = entry and entry.guid }
    if entry then ns.Queue:SetState(entry.guid, "summoning") end
    local name = entry and entry.name or targetName
    ns.Announce:RitualStarted(name ~= "" and name or nil, entry and ns.Queue.UnitOf(entry.guid))
    return true
end

-- The channel stopped, failed or was interrupted. If no prompt came, the
-- member waits again.
function Summon:Ended(castGUID)
    local cast = self.cast
    if not cast or (castGUID and cast.castGUID and castGUID ~= cast.castGUID) then return end
    local guid = cast.guid
    C_Timer.After(SETTLE, function()
        local e = guid and ns.Queue:Find(guid)
        if e and e.state == "summoning" then ns.Queue:SetState(guid, nil) end
    end)
end

local NEXT = {
    [API.SUMMON.Pending] = "pending",
    [API.SUMMON.Accepted] = "accepted",
    [API.SUMMON.Declined] = "declined",
}

-- INCOMING_SUMMON_CHANGED for a unit.
function Summon:StatusChanged(unit)
    local guid = API.UnitGUID(unit)
    local e = guid and ns.Queue:Find(guid)
    if not e then return end
    local status = API.SummonStatus(unit)
    if status == nil then return end
    local state = NEXT[status]
    if status == API.SUMMON.None then
        -- Accepted stays until they are near; a prompt that went away
        -- unanswered puts them back in line.
        state = e.state == "accepted" and "accepted" or (e.state == "declined" and "declined" or nil)
    end
    ns.Queue:SetState(guid, state)
    if state == "accepted" then ns.Queue:Prune() end
end

local function isRitual(unit, spellID)
    return unit == "player" and API.Number(spellID) == Data.RITUAL_OF_SUMMONING
end

function Summon:Initialize()
    local Events = ns.Events
    Events:Register("UNIT_SPELLCAST_SENT", function(_, unit, target, castGUID, spellID)
        if isRitual(unit, spellID) then self:Sent(readable(castGUID), readable(target)) end
    end)
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START" }) do
        Events:Register(event, function(_, unit, castGUID, spellID)
            if isRitual(unit, spellID) then self:Started(readable(castGUID)) end
        end)
    end
    for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        Events:Register(event, function(_, unit, castGUID, spellID)
            if isRitual(unit, spellID) then self:Ended(readable(castGUID)) end
        end)
    end
    Events:Register("INCOMING_SUMMON_CHANGED", function(_, unit)
        if type(unit) == "string" and API.Readable(unit) then self:StatusChanged(unit) end
    end)
end
