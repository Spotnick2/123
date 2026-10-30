-- Summon execution (#10) and announcements (#11): the Summoning button aims
-- Ritual of Summoning at the next in the queue, out of combat only; each
-- member follows their summon's status and leaves only once they accepted
-- and arrived (or left the group); group chat lines when the ritual starts.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[698] = { name = "Ritual of Summoning", known = true }
WoW.counts[6265] = 3
WoW.inGroup = true
local ASHKA, BROM, CYRA = "Player-1-AAA", "Player-1-BBB", "Player-1-CCC"
WoW.group = {
    { guid = ASHKA, name = "Ashka Vale", class = "MAGE", distance = 900 },
    { guid = BROM, name = "Brom Hollow", class = "WARRIOR", distance = 5 },
    { guid = CYRA, name = "Cyra Dusk", class = "PRIEST", distance = 8 },
}
local ns = H.loadAddon()
local Q, Bar, Summon = ns.Queue, ns.Bar, ns.Summon
local button = Bar:Button("summoning")

local function say(text, guid)
    WoW.fire("CHAT_MSG_PARTY", text, "Sender", "", "", "", "", 0, 0, "", 0, 7, guid)
    WoW.runTimers(0)
end
local function aimed()
    return button:GetAttribute("type1"), button:GetAttribute("spell1"), button:GetAttribute("unit1")
end
local function stateOf(guid)
    local e = Q:Find(guid)
    return e and (e.state or (e.here and "here") or "waiting") or "gone"
end
local function memberAt(guid)
    for i, m in ipairs(WoW.group) do if m.guid == guid then return m, "party" .. i end end
end
-- The ritual as the client is expected to fire it (unmeasured, row 4).
local cast = 0
local function ritual(target, viaButton)
    cast = cast + 1
    local castGUID = "Cast-3-0-0-698-" .. cast
    if viaButton then button:GetScript("PostClick")(button, "LeftButton", false) end
    WoW.fire("UNIT_SPELLCAST_SENT", "player", target or "", castGUID, 698)
    WoW.fire("UNIT_SPELLCAST_CHANNEL_START", "player", castGUID, 698)
    WoW.runTimers(0)
    return castGUID
end
local function status(guid, value)
    local m, unit = memberAt(guid)
    m.summon = value
    WoW.fire("INCOMING_SUMMON_CHANGED", unit)
    WoW.runTimers(0)
end
local function lastChat() local c = WoW.chat[#WoW.chat]; return c and c[1], c and c[2] end

------------------------------------------------------------
-- #10: the button aims at the next who needs a summon
------------------------------------------------------------

local t, s, u = aimed()
H.eq(t, "spell", "Ritual known: the button casts it"); H.eq(s, 698, "Ritual of Summoning")
H.eq(u, nil, "nobody waiting: on the target, as before")

say("123", ASHKA)
t, s, u = aimed()
H.eq(u, "party1", "Ashka asks: the ritual is aimed at her")
H.eq(button.action.name, "Ashka Vale", "by name")
button:GetScript("OnEnter")(button)
H.eq(GameTooltip._lines[1], "Summoning", "the tooltip")
local seen = false
for _, line in ipairs(GameTooltip._lines or {}) do
    if line == "Click: Ritual of Summoning on Ashka Vale" then seen = true end
end
H.check(seen, "the tooltip says who the click summons")
H.eq(ns.QueueList.rows[1].age:GetText(), "next", "the list marks her next")

say("123", BROM)
H.eq(stateOf(BROM), "here", "Brom asks from 5 yards: already here")
H.eq(ns.QueueList.rows[2].age:GetText(), "here", "and the list says so")
H.eq(select(3, aimed()), "party1", "still Ashka: the one who needs it")

-- A reshuffle moves unit tokens: the button follows Ashka at once, with no
-- frame in between for a click to meet a stale token.
WoW.group = { WoW.group[3], WoW.group[2], WoW.group[1] }
WoW.fire("GROUP_ROSTER_UPDATE")
H.eq(select(3, aimed()), "party3", "a reshuffle: still Ashka, now party3, rewritten at once")

-- In combat the token can't be rewritten, so it comes off as combat starts.
WoW.enterCombat()
t, s, u = aimed()
H.eq(s, 698, "in combat: still the ritual"); H.eq(u, nil, "but on the target, never a token")
WoW.group = { WoW.group[3], WoW.group[2], WoW.group[1] }
WoW.fire("GROUP_ROSTER_UPDATE")
H.eq(select(3, aimed()), nil, "a reshuffle in combat changes nothing")
WoW.leaveCombat()
WoW.runTimers(0)
H.eq(select(3, aimed()), "party1", "out of combat: Ashka again, at her new token")

-- Test entries are no one to summon.
Q:Test()
WoW.runTimers(0)
H.eq(select(3, aimed()), "party1", "test entries are never aimed at")
for _, e in ipairs({ unpack(Q.entries) }) do if e.test then Q:Remove(e.guid) end end

------------------------------------------------------------
-- #10: the summon's lifecycle
------------------------------------------------------------

WoW.chat = {}
ritual("Ashka Vale", true)
H.eq(stateOf(ASHKA), "summoning", "the ritual starts on her")
H.eq(ns.QueueList.rows[1].age:GetText(), "summoning", "the list shows it")
H.eq(select(3, aimed()), nil, "and nobody else waits: the button aims at no one")
status(ASHKA, 1)
H.eq(stateOf(ASHKA), "pending", "her prompt is up")
status(ASHKA, 2)
H.eq(stateOf(ASHKA), "accepted", "she accepts")
H.eq(#Q.entries, 2, "accepting alone doesn't drop her")
status(ASHKA, 0)
H.eq(stateOf(ASHKA), "accepted", "the prompt goes: still accepted, until she is near")
WoW.runTimers(10)
H.eq(stateOf(ASHKA), "accepted", "far, after a tick: kept")
memberAt(ASHKA).distance = nil
WoW.runTimers(10)
H.eq(stateOf(ASHKA), "accepted", "distance unreadable: kept")
memberAt(ASHKA).distance = 3
WoW.runTimers(10)
H.eq(stateOf(ASHKA), "gone", "near after accepting: arrived, dropped")

-- Declined: kept, skipped, back in line on asking again.
memberAt(ASHKA).distance = 900
say("123", ASHKA)
ritual(nil, true)
status(ASHKA, 1)
status(ASHKA, 3)
H.eq(stateOf(ASHKA), "declined", "she declines: kept")
H.eq(select(3, aimed()), nil, "and not aimed at again")
status(ASHKA, 0)
H.eq(stateOf(ASHKA), "declined", "the prompt goes: still declined")
say("123", ASHKA)
H.eq(stateOf(ASHKA), "waiting", "she asks again: back in line")
H.eq(select(3, aimed()), "party1", "and aimed at")

-- A prompt that times out puts her back; so does a ritual with no prompt.
ritual(nil, true)
status(ASHKA, 1)
status(ASHKA, 0)
H.eq(stateOf(ASHKA), "waiting", "an unanswered prompt goes away: waiting again")
local castGUID = ritual(nil, true)
WoW.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", castGUID, 698)
WoW.runTimers(1)
H.eq(stateOf(ASHKA), "summoning", "the channel stops: summoning a moment longer")
WoW.runTimers(3)
H.eq(stateOf(ASHKA), "waiting", "no prompt came: waiting again")

-- What can't be read changes nothing.
ritual(nil, true)
status(ASHKA, 1)
status(ASHKA, "secret")
H.eq(stateOf(ASHKA), "pending", "a secret status keeps her where she was")

-- Who the ritual is on without a button click: the cast's target name.
Q:SetState(ASHKA, nil)
WoW.runTimers(11)
WoW.chat = {}
ritual("Ashka Vale")
H.eq(stateOf(ASHKA), "summoning", "cast on her by name (a macro, a keybind elsewhere)")
Q:SetState(ASHKA, nil)
WoW.runTimers(11)
ritual("Someone Else")
H.eq(stateOf(ASHKA), "waiting", "a ritual on someone not queued leaves her alone")

-- A refused cast (SENT, then FAILED, no start) is no ritual.
WoW.runTimers(11)
WoW.chat = {}
button:GetScript("PostClick")(button, "LeftButton", false)
WoW.fire("UNIT_SPELLCAST_SENT", "player", "Ashka Vale", "Cast-3-0-0-698-x", 698)
WoW.fire("UNIT_SPELLCAST_FAILED", "player", "Cast-3-0-0-698-x", 698)
WoW.runTimers(4)
H.eq(stateOf(ASHKA), "waiting", "a refused cast changes nothing")
H.eq(#WoW.chat, 0, "and announces nothing")

-- Leaving the group drops her.
local m = memberAt(ASHKA)
for i, g in ipairs(WoW.group) do if g == m then table.remove(WoW.group, i) end end
WoW.fire("GROUP_ROSTER_UPDATE")
WoW.runTimers(0)
H.eq(stateOf(ASHKA), "gone", "she leaves the group: dropped")
table.insert(WoW.group, 1, m)
WoW.fire("GROUP_ROSTER_UPDATE")

------------------------------------------------------------
-- #11: announcements
------------------------------------------------------------

Q:Clear()
WoW.runTimers(11)
WoW.chat = {}
say("123", ASHKA)
ritual("Ashka Vale", true)
local msg, chan = lastChat()
H.eq(msg, "Summoning Ashka Vale, please click the portal", "the summon line")
H.eq(chan, "PARTY", "to party chat")
H.eq(#WoW.chat, 1, "once per ritual (SENT and CHANNEL_START are one cast); no clicker line by default")

Q:SetState(ASHKA, nil)
ritual("Ashka Vale", true)
H.eq(#WoW.chat, 1, "a second ritual within 10 seconds: throttled")
WoW.runTimers(11)
Q:SetState(ASHKA, nil)
ritual("Ashka Vale", true)
H.eq(#WoW.chat, 2, "after 10 seconds: announced again")

-- The clickers line: only when fewer than two others are near.
ns.db.announce.clickers = true
WoW.runTimers(11)
WoW.chat = {}
Q:SetState(ASHKA, nil)
ritual("Ashka Vale", true)
H.eq(#WoW.chat, 1, "Brom and Cyra are near: no call for clickers")
memberAt(CYRA).distance = 200
WoW.runTimers(11)
WoW.chat = {}
Q:SetState(ASHKA, nil)
ritual("Ashka Vale", true)
H.eq(#WoW.chat, 2, "only Brom near: the summon line and a call for clickers")
H.eq(lastChat(), "Need 2 clickers for the summon", "the clickers line")
memberAt(CYRA).distance = nil
WoW.runTimers(11)
WoW.chat = {}
Q:SetState(ASHKA, nil)
ritual("Ashka Vale", true)
H.eq(#WoW.chat, 1, "Cyra's distance unreadable: no guess, no call")
memberAt(CYRA).distance = 8

-- The player's own texts; {name} is who is summoned; % is plain text.
ns.db.announce.summonText = "Portal up for {name}: 100% click it!"
WoW.runTimers(11)
WoW.chat = {}
Q:SetState(ASHKA, nil)
ritual("Ashka Vale", true)
H.eq(WoW.chat[1] and WoW.chat[1][1], "Portal up for Ashka Vale: 100% click it!", "a custom summon line")
ns.db.announce.summonText = "   "
H.eq(ns.Announce.Text("summon", "X"), "Summoning X, please click the portal", "a blank text is the default")

-- Channels: instance, then raid, then party; nothing solo; off is off.
WoW.groupCategory = LE_PARTY_CATEGORY_INSTANCE
H.eq(ns.API.GroupChannel(), "INSTANCE_CHAT", "a dungeon-finder group: instance chat")
WoW.groupCategory = nil
WoW.inRaid = true
H.eq(ns.API.GroupChannel(), "RAID", "a raid: raid chat")
WoW.inRaid = false
WoW.inGroup = false
H.eq(ns.API.GroupChannel(), nil, "solo: nowhere")
WoW.inGroup = true
ns.db.announce.summon, ns.db.announce.clickers = false, false
WoW.runTimers(11)
WoW.chat = {}
Q:SetState(ASHKA, nil)
ritual("Ashka Vale", true)
H.eq(#WoW.chat, 0, "both lines off: nothing sent")

H.done("test_summon")
