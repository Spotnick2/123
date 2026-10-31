-- Summon queue (#9): exact keyword matching in group chat, GUID-keyed and
-- in order, roster and timeout pruning, the list above the Summoning button.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.group = {
    { guid = "Player-1-AAA", name = "Ashka Vale", class = "MAGE" },
    { guid = "Player-1-BBB", name = "Brom Hollow", class = "WARRIOR" },
}
local ns = H.loadAddon()
local Q, L = ns.Queue, ns.QueueList

-- A group chat line as the client fires it: text, sender, ..., GUID (12th).
local function say(event, text, guid)
    WoW.fire(event, text, "Sender", "", "", "", "", 0, 0, "", 0, 7, guid)
end
local function names()
    local t = {}
    for i, e in ipairs(Q.entries) do t[i] = e.name end
    return table.concat(t, ",")
end

-- Exact matching: the whole message, case, spaces and trailing ! ? . aside.
for _, text in ipairs({ "123", " 123 ", "123!", "123?!", "123." }) do
    H.check(Q:Matches(text), "matches '" .. text .. "'")
end
for _, text in ipairs({ "1234", "123 dps", "o123", "12 3", "" }) do
    H.check(not Q:Matches(text), "doesn't match '" .. text .. "'")
end

-- Party chat from a member joins, with name and class from the roster.
WoW.kits = {}
say("CHAT_MSG_PARTY", "123", "Player-1-AAA")
H.eq(names(), "Ashka Vale", "a member who says 123 joins")
H.eq(Q.entries[1].class, "MAGE", "with their class")
H.eq(#WoW.kits, 1, "the summon request sound plays")
H.check(L.frame:IsShown(), "the list shows")
H.eq(L.title:GetText(), "Summons (1)", "with a count")
H.eq(L.rows[1].name:GetText(), "Ashka Vale", "and the name")
local p = L.frame._points[1]
H.check(p and p[1] == "BOTTOM" and p[2] == UIParent and p[4] == 960 and p[5] == 540 + 18 + 22,
    "above the Summoning button, under UIParent")

-- Raid and instance chat count too; order is kept; asking again keeps
-- the place.
say("CHAT_MSG_RAID_LEADER", "123!", "Player-1-BBB")
H.eq(names(), "Ashka Vale,Brom Hollow", "in order")
WoW.time = WoW.time + 30
say("CHAT_MSG_INSTANCE_CHAT", "123", "Player-1-AAA")
H.eq(names(), "Ashka Vale,Brom Hollow", "asking again keeps the place")
H.eq(Q.entries[1].at, WoW.time, "and refreshes the time")

-- What doesn't join: no match, not in the group, the player, an
-- unreadable GUID, the queue turned off.
say("CHAT_MSG_PARTY", "1234", "Player-1-AAA")
say("CHAT_MSG_PARTY", "123", "Player-1-ZZZ")
say("CHAT_MSG_PARTY", "123", WoW.playerGUID)
say("CHAT_MSG_PARTY", "123", nil)
ns.db.queue.enabled = false
WoW.group[3] = { guid = "Player-1-CCC", name = "Cyra Dusk", class = "PRIEST" }
say("CHAT_MSG_PARTY", "123", "Player-1-CCC")
ns.db.queue.enabled = true
H.eq(#Q.entries, 2, "none of those join")

-- Keywords: the player's list, normalized; empty falls back to 123.
H.eq(table.concat(Q.ParseKeywords(" Summ, 123!, summ ,, "), "|"), "summ|123", "keywords parsed")
H.eq(table.concat(Q.ParseKeywords(""), "|"), "123", "an empty list is 123")
ns.db.queue.keywords = Q.ParseKeywords("summ pls")
say("CHAT_MSG_PARTY", "Summ pls!", "Player-1-CCC")
H.eq(names(), "Ashka Vale,Brom Hollow,Cyra Dusk", "a custom keyword joins")
say("CHAT_MSG_PARTY", "123", "Player-1-CCC")
ns.db.queue.keywords = { "123" }

-- The x drops someone.
L.rows[2].remove:GetScript("OnClick")(L.rows[2].remove)
H.eq(names(), "Ashka Vale,Cyra Dusk", "the x removes that row's member")

-- Leaving the group drops them.
table.remove(WoW.group, 3)
WoW.fire("GROUP_ROSTER_UPDATE")
H.eq(names(), "Ashka Vale", "a member who left drops off")

-- The timeout drops them; the ticker runs only while someone waits.
H.check(Q.ticker ~= nil, "a ticker while someone waits")
WoW.time = WoW.time + 10 * 60
WoW.runTimers(10)
H.eq(#Q.entries, 0, "dropped after the timeout")
H.check(not L.frame:IsShown(), "the list hides when empty")
H.eq(Q.ticker, nil, "no ticker when nobody waits")

-- In combat, people still join and the list still shows (nothing secure).
WoW.enterCombat()
say("CHAT_MSG_PARTY", "123", "Player-1-BBB")
H.check(L.frame:IsShown(), "the list shows in combat")
H.eq(#WoW.blocked, 0, "nothing blocked")
WoW.leaveCombat()
Q:Clear()

-- /123 queue test: two made-up requests join, "1234" doesn't.
H.slash("ONETWOTHREE", "queue test")
H.eq(#Q.entries, 2, "two test requests")
H.check(H.messagesMatching("2 test requests joined") > 0, "and says so")
WoW.fire("GROUP_ROSTER_UPDATE")
H.eq(#Q.entries, 2, "test requests aren't dropped by the roster check")
H.slash("ONETWOTHREE", "queue clear")
H.eq(#Q.entries, 0, "/123 queue clear")

-- More than fits: eight rows and "and N more".
for i = 1, 10 do Q:Add("Test-" .. i, "Name " .. i, "MAGE", true) end
H.check(L.rows[8]:IsShown() and L.rows[9] == nil, "eight rows")
H.eq(L.more:GetText(), "and 2 more", "the rest counted")
Q:Clear()

-- The options page edits the keywords.
ns.Options.panel:GetScript("OnShow")(ns.Options.panel)
local box
for _, c in ipairs(ns.Options.panel._children) do
    -- The queue's box shows "123" (the page has others: #8, #11).
    if c._kind == "EditBox" and c:GetText() == "123" then box = c end
end
H.eq(box:GetText(), "123", "the box shows the keywords")
box:SetText("123, summ")
box:GetScript("OnEnterPressed")(box)
H.eq(table.concat(ns.db.queue.keywords, "|"), "123|summ", "Enter saves them")

-- The first list after a /reload arrives in combat, and the client refuses
-- the button's position: the spot remembered when the bar was set up is
-- used (Codex on #38).
WoW.reset()
local ns2 = H.loadAddon()
local button = ns2.Bar:Button("summoning")
button.GetCenter = function() error("refused in combat") end
WoW.enterCombat()
ns2.Queue:Add("Test-9", "Late Comer", "MAGE", true)
local p2 = ns2.QueueList.frame._points[1]
H.check(p2 and p2[1] == "BOTTOM" and p2[4] == 960 and p2[5] == 540 + 18 + 22,
    "the first list in combat still goes above Summoning")
H.check(ns2.QueueList.frame:IsShown(), "and shows")
WoW.leaveCombat()

H.done("test_queue")
