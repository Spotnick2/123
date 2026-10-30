-- ============================================================
-- Announce (#11): group chat lines when a Ritual of Summoning starts.
--
--   "Summoning {name}, please click the portal"   (on by default)
--   "Need 2 clickers for the summon"              (off by default; sent
--       only when fewer than two others are near the Warlock)
--
-- Both texts are the player's to change ({name} is who is summoned; an
-- empty text is the default, in the client's language). They go to the
-- group's chat (instance, then raid, then party; nothing solo), each at
-- most once per THROTTLE. Whether a line sent from an event reaches the
-- others is unmeasured (FOREVER-PROBE.md row 7).
-- ============================================================

local _, ns = ...
if ns.skip then return end

local API = ns.API
local L = ns.L

local Announce = {
    last = {},
}
ns.Announce = Announce

Announce.THROTTLE = 10
-- The ritual takes the Warlock and two others; a clicker must reach the
-- portal beside the Warlock.
local CLICKERS, CLICK_RANGE = 2, 30

Announce.DEFAULT = {
    summon = L["Summoning {name}, please click the portal"],
    clickers = L["Need 2 clickers for the summon"],
}

-- The saved text of a line, or its default when blank.
function Announce.Template(kind)
    local text = ns.db.announce[kind .. "Text"]
    if type(text) ~= "string" or not text:find("%S") then return Announce.DEFAULT[kind] end
    return text
end

function Announce.Text(kind, name)
    return (Announce.Template(kind):gsub("{name}", function() return name or "" end))
end

-- Sends one kind of line, throttled. Returns true when it went out.
function Announce:Send(kind, text)
    if not ns.db.announce[kind] then return false end
    local channel = API.GroupChannel()
    if not channel then return false end
    local now = GetTime()
    if self.last[kind] and now - self.last[kind] < Announce.THROTTLE then return false end
    self.last[kind] = now
    return API.SendGroup(text, channel)
end

-- How many group members other than the summoned one are near enough to
-- click, or nil when someone's distance can't be read.
function Announce.ClickersNear(target)
    local units, near = {}, 0
    local n = API.Number(GetNumGroupMembers()) or 0
    if IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    else
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    local me = API.UnitGUID("player")
    for _, unit in ipairs(units) do
        if unit ~= target and API.UnitGUID(unit) ~= me then
            local yes = API.Near(unit, CLICK_RANGE)
            if yes == nil then return nil end
            if yes then near = near + 1 end
        end
    end
    return near
end

-- ns.Summon: a ritual started on `name` (nil when unknown), at `target`
-- (their unit, or nil).
function Announce:RitualStarted(name, target)
    if name then self:Send("summon", Announce.Text("summon", name)) end
    if ns.db.announce.clickers then
        local near = Announce.ClickersNear(target)
        if near and near < CLICKERS then self:Send("clickers", Announce.Text("clickers", name)) end
    end
end
