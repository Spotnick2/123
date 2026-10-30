-- ============================================================
-- Summon queue (#9): who asked for a summon, in order.
--
-- A group member asks by typing "123" (or one of the player's keywords) in
-- party, raid or instance chat. The whole message must be the keyword
-- (case, spaces and trailing ! ? . aside), so "1234" or "123 dps" don't
-- count. People are keyed on GUID: asking again keeps their place. They
-- drop off when they leave the group, after the timeout, or by hand.
--
-- Execution (#10): the Summoning button aims Ritual of Summoning at
-- Queue:Next(). Each entry follows its summon (`state`, set by ns.Summon):
-- nil waiting, "summoning" (the ritual is on them), "pending" (their prompt
-- is up), "accepted", "declined". Someone is dropped only on a measured
-- signal: accepted and then near the player, or gone from the group. What
-- can't be read keeps them. `here` marks someone already near: shown,
-- never aimed at.
--
-- Chat payloads are plain in the open world, in and out of combat
-- (GlassChat's ChatProbe, PORTING-TBC-TO-FOREVER.md); a sender GUID that
-- can't be read (a dungeon is unmeasured) is skipped, never guessed.
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API

local Queue = {
    entries = {},      -- { guid, name, class, at, test, state, here }, oldest first
    listeners = {},
}
ns.Queue = Queue

Queue.CHAT_EVENTS = {
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

-- How often ages refresh and timeouts apply while someone is waiting.
local TICK = 10

-- Near enough to need no summon, or to have arrived from one: the portal
-- brings them beside the Warlock.
Queue.HERE = 30

-- A message or keyword, compared: lower case, trimmed, trailing ! ? . gone.
local function normalize(text)
    return (text:lower():gsub("^%s+", ""):gsub("[%s!%?%.]+$", ""))
end
Queue.Normalize = normalize

-- Keywords from the player's text ("123, summ"): normalized, no blanks or
-- repeats. Never empty: an empty list falls back to "123".
function Queue.ParseKeywords(text)
    local list, seen = {}, {}
    for word in tostring(text or ""):gmatch("[^,]+") do
        word = normalize(word)
        if word ~= "" and not seen[word] then
            seen[word] = true
            list[#list + 1] = word
        end
    end
    if #list == 0 then list[1] = "123" end
    return list
end

function Queue:Matches(text)
    if type(text) ~= "string" or not API.Readable(text) then return false end
    local said = normalize(text)
    for _, word in ipairs(ns.db.queue.keywords) do
        if said == word then return true end
    end
    return false
end

-- The group's units other than the player.
local function groupUnits()
    local units = {}
    local n = API.Number(GetNumGroupMembers()) or 0
    if IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    else
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- The unit token of a group member, by GUID, or nil.
function Queue.UnitOf(guid)
    for _, unit in ipairs(groupUnits()) do
        if API.UnitGUID(unit) == guid then return unit end
    end
    return nil
end

local function indexOf(guid)
    for i, e in ipairs(Queue.entries) do
        if e.guid == guid then return i end
    end
    return nil
end

function Queue:Find(guid)
    local i = indexOf(guid)
    return i and self.entries[i] or nil
end

-- Where someone's summon is (ns.Summon). Returns true when it changed.
function Queue:SetState(guid, state)
    local e = self:Find(guid)
    if not e or e.state == state then return false end
    e.state = state
    self:Changed()
    return true
end

-- The first who still needs a summon: waiting, in the group, not already
-- near. Returns the entry and their unit token, read now.
function Queue:Next()
    for _, e in ipairs(self.entries) do
        if not e.test and not e.state and not e.here then
            local unit = Queue.UnitOf(e.guid)
            if unit then return e, unit end
        end
    end
    return nil
end

function Queue:OnChanged(fn)
    self.listeners[#self.listeners + 1] = fn
end

function Queue:Changed()
    for _, fn in ipairs(self.listeners) do fn() end
    self:Schedule()
end

-- Adds someone (or refreshes their time, keeping their place). Returns
-- true when they are new.
function Queue:Add(guid, name, class, test)
    local i = indexOf(guid)
    if i then
        -- Asking again after declining puts them back in line.
        local e = self.entries[i]
        e.at = GetTime()
        if e.state == "declined" then e.state = nil end
        self:Changed()
        return false
    end
    self.entries[#self.entries + 1] = { guid = guid, name = name, class = class, at = GetTime(), test = test }
    ns.Sound:Play("summonRequest")
    self:Changed()
    return true
end

function Queue:Remove(guid)
    local i = indexOf(guid)
    if not i then return false end
    table.remove(self.entries, i)
    self:Changed()
    return true
end

function Queue:Clear()
    if #self.entries == 0 then return end
    self.entries = {}
    self:Changed()
end

-- Drops whoever left the group, waited past the timeout, or accepted and
-- is now near (arrived); marks who is already near. Test entries (/123
-- queue test) aren't group members and only time out. Distance the client
-- can't read changes nothing.
function Queue:Prune()
    local now, limit = GetTime(), (tonumber(ns.db.queue.timeout) or 10) * 60
    local kept, changed = {}, false
    for _, e in ipairs(self.entries) do
        local unit = not e.test and Queue.UnitOf(e.guid)
        local near = unit and API.Near(unit, Queue.HERE)
        if now - e.at >= limit or (not e.test and not unit) or (e.state == "accepted" and near == true) then
            changed = true
        else
            local here = (near and not e.state) or nil
            if near ~= nil and here ~= e.here then
                e.here = here
                changed = true
            end
            kept[#kept + 1] = e
        end
    end
    if changed then
        self.entries = kept
        self:Changed()
    end
end

-- One timer while someone waits: ages tick and timeouts apply.
function Queue:Schedule()
    if #self.entries == 0 then
        if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    elseif not self.ticker then
        self.ticker = C_Timer.NewTicker(TICK, function()
            self:Prune()
            for _, fn in ipairs(self.listeners) do fn() end
        end)
    end
end

-- A group chat line: text, sender, ..., guid (12th).
function Queue:OnChat(text, guid)
    if not ns.db.queue.enabled or not self:Matches(text) then return false end
    if type(guid) ~= "string" or not API.Readable(guid) then return false end
    if guid == API.UnitGUID("player") then return false end
    local unit = Queue.UnitOf(guid)
    if not unit then return false end
    local _, class = UnitClass(unit)
    local new = self:Add(guid, GetUnitName(unit, false), API.Readable(class) and class or nil)
    self:Prune()
    return new
end

-- /123 queue test: three made-up members say "123", "123!" and "1234".
-- The first two join (as test entries, outside the roster check); the
-- third doesn't match.
local TEST = {
    { "Test-0-123-0001", "Ashka Vale", "MAGE", "123" },
    { "Test-0-123-0002", "Brom Hollow", "WARRIOR", "123!" },
    { "Test-0-123-0003", "Cyra Dusk", "PRIEST", "1234" },
}
function Queue:Test()
    local joined = 0
    for _, t in ipairs(TEST) do
        if self:Matches(t[4]) and self:Add(t[1], t[2], t[3], true) then joined = joined + 1 end
    end
    return joined
end

function Queue:Initialize()
    for _, event in ipairs(self.CHAT_EVENTS) do
        ns.Events:Register(event, function(_, ...)
            self:OnChat((...), (select(12, ...)))
        end)
    end
    ns.Events:Register("GROUP_ROSTER_UPDATE", function() self:Prune() end)
end
