-- ============================================================
-- Control (#29): how long a Banish lasts, and the subjugated demon.
--
-- Banish: from the cast's success (UNIT_SPELLCAST_SUCCEEDED, on the target
-- read at SENT) for the rank's duration (Data.LASTS); a recast restarts it
-- (one banish at a time), the target's death (UNIT_DIED) ends it. It is an
-- estimate: an early break can't be seen in combat (the combat log is
-- forbidden, auras are secret), and the tooltip says so.
--
-- Subjugate Demon (Forever's Enslave Demon): the pet that comes out right
-- after a successful cast, and isn't one of the Warlock's own demons, is
-- the subjugated one. Its countdown is the most the spell lasts. When it
-- stops being the pet, it was dismissed (PET_DISMISS_START), died
-- (UNIT_DIED), or broke free: then a chat line, a sound and a red glow,
-- since the demon is hostile again. The pet events are unmeasured
-- (FOREVER-PROBE.md row 11), so the verdict waits JUDGE seconds for them.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local Data = ns.Data
local L = ns.L

local Control = {
    listeners = {},
}
ns.Control = Control

local CAST_WINDOW = 5     -- a pet this soon after Subjugate's success is it
local JUDGE = 0.5         -- wait for UNIT_DIED / PET_DISMISS_START
Control.BROKEN_GLOW = 10  -- how long the button glows red after a break
Control.ENDING = 5        -- Banish glows its last seconds, to re-banish on time
local TICK = 0.2

local KIND = {}
for _, id in ipairs(Data.BANISH) do KIND[id] = "banish" end
for _, id in ipairs(Data.SUBJUGATE) do KIND[id] = "subjugate" end

function Control:OnChanged(fn)
    self.listeners[#self.listeners + 1] = fn
end

function Control:Changed()
    for _, fn in ipairs(self.listeners) do fn() end
    local running = self.banish or self.subjugate or self.brokenAt
    if running and not self.ticker then
        self.ticker = C_Timer.NewTicker(TICK, function() self:Tick() end)
    elseif not running and self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

-- Seconds left on a timer { start, duration }, or nil once it ran out.
function Control.Left(timer)
    if not timer then return nil end
    local left = timer.start + timer.duration - GetTime()
    return left > 0 and left or nil
end

-- Ends what ran out; the listeners redraw the countdowns.
function Control:Tick()
    if self.banish and not Control.Left(self.banish) then self.banish = nil end
    if self.subjugate and not Control.Left(self.subjugate) then self.subjugate = nil end
    if self.brokenAt and GetTime() - self.brokenAt >= Control.BROKEN_GLOW then self.brokenAt = nil end
    self:Changed()
end

function Control:Sent(castGUID, spellID)
    self.sent = { castGUID = castGUID, spellID = spellID, guid = API.UnitGUID("target"), at = GetTime() }
end

-- A Banish or a Subjugate went off.
function Control:Succeeded(castGUID, spellID)
    local sent = self.sent
    local same = sent and sent.spellID == spellID
        and ((castGUID and sent.castGUID and castGUID == sent.castGUID) or GetTime() - sent.at < 5)
    local guid = same and sent.guid or API.UnitGUID("target")
    self.sent = nil
    local timer = { guid = guid, start = GetTime(), duration = Data.LASTS[spellID] or 0, spellID = spellID }
    if KIND[spellID] == "banish" then
        self.banish = timer
    else
        self.subjugate, self.brokenAt = timer, nil
        self:PetChanged()
    end
    self:Changed()
end

local function ownDemon(guid)
    local npc = guid and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    return npc and Data.DEMON_NPC[npc] ~= nil
end

-- UNIT_PET for the player: the subjugated demon came out, or went.
function Control:PetChanged()
    local pet = API.UnitGUID("pet")
    local s = self.subjugate
    if s and not self.enslaved and pet and not ownDemon(pet) and GetTime() - s.start <= CAST_WINDOW then
        local name = UnitName("pet")
        self.enslaved = { guid = pet, name = API.Readable(name) and name or nil, at = GetTime() }
        self:Changed()
        return
    end
    local enslaved = self.enslaved
    if enslaved and pet ~= enslaved.guid then
        self.enslaved = nil
        C_Timer.After(JUDGE, function() self:Judge(enslaved) end)
    end
end

-- The subjugated demon is no longer the pet: dismissed, dead, or broken free.
function Control:Judge(enslaved)
    local now = GetTime()
    local dismissed = self.dismissedAt and now - self.dismissedAt <= JUDGE + 2
    -- A death since it became the pet (not a GUID that died before).
    local died = self.died and self.died[enslaved.guid]
    died = died and died >= enslaved.at
    self.subjugate = nil
    if not dismissed and not died then
        self.brokenAt = now
        ns.Print(L["%s broke free: it's hostile again!"]:format(enslaved.name or L["the subjugated demon"]))
        ns.Sound:Play("breakFree")
    end
    self.dismissedAt = nil
    self:Changed()
end

-- Deaths are kept a minute: long enough to judge a pet that just went.
function Control:Died(guid)
    local now = GetTime()
    self.died = self.died or {}
    for g, at in pairs(self.died) do
        if now - at > 60 then self.died[g] = nil end
    end
    self.died[guid] = now
    if self.banish and self.banish.guid == guid then
        self.banish = nil
        self:Changed()
    end
end

local function readable(v)
    return API.Readable(v) and v or nil
end

function Control:Initialize()
    local Events = ns.Events
    Events:Register("UNIT_SPELLCAST_SENT", function(_, unit, _, castGUID, spellID)
        spellID = API.Number(spellID)
        if unit == "player" and KIND[spellID] then self:Sent(readable(castGUID), spellID) end
    end)
    Events:Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, castGUID, spellID)
        spellID = API.Number(spellID)
        if unit == "player" and KIND[spellID] then self:Succeeded(readable(castGUID), spellID) end
    end)
    Events:Register("UNIT_PET", function(_, unit)
        if unit == "player" then self:PetChanged() end
    end)
    Events:Register("PET_DISMISS_START", function() self.dismissedAt = GetTime() end)
    Events:Register("UNIT_DIED", function(_, guid)
        if type(guid) == "string" and API.Readable(guid) then self:Died(guid) end
    end)
end
