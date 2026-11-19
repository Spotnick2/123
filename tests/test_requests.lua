-- Healthstone requests (#8): a keyword in group chat or a whisper opens a
-- glass prompt; the player opens the trade and places the stone, two
-- clicks; nothing is delivered on its own. Whispers from outside the group
-- follow an option.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[6201] = { name = "Create Healthstone (Minor)", known = true }
WoW.counts[6265] = 3
WoW.inGroup = true
local ASHKA, BROM, STRANGER = "Player-1-AAA", "Player-1-BBB", "Player-1-ZZZ"
WoW.group = {
    { guid = ASHKA, name = "Ashka Vale", class = "MAGE" },
    { guid = BROM, name = "Brom Hollow", class = "WARRIOR" },
}
local ns = H.loadAddon()
local R, P = ns.Requests, ns.StonePrompt

local function say(event, text, guid, sender)
    WoW.fire(event, text, sender or "Sender", "", "", "", "", 0, 0, "", 0, 7, guid)
    WoW.advance(0)
end
local function names()
    local t = {}
    for i, e in ipairs(R.entries) do t[i] = e.name end
    return table.concat(t, ",")
end
local function click(b) b:GetScript("OnClick")(b) end
local function carry(itemID, name)
    WoW.AddItem(0, 1, itemID, 1, name)
    WoW.counts[itemID] = 1
    WoW.fire("BAG_UPDATE_DELAYED")
    WoW.advance(0)
end

-- Matching: the whole message, as the summon queue's.
for _, text in ipairs({ "hs", "HS!", " healthstone ", "hs?" }) do
    check(R:Matches(text), "matches '" .. text .. "'")
end
for _, text in ipairs({ "hs pls", "123", "this", "" }) do
    check(not R:Matches(text), "doesn't match '" .. text .. "'")
end

-- A member asks in party chat: the prompt opens above the Healthstone
-- button, with a sound; no stone carried yet.
WoW.kits = {}
say("CHAT_MSG_PARTY", "hs", ASHKA)
eq(names(), "Ashka Vale", "Ashka asks")
eq(#WoW.kits, 1, "the healthstone request sound plays")
check(P.frame:IsShown(), "the prompt shows")
eq(P.text:GetText(), "Ashka Vale asks for a healthstone.", "who asks")
local p = P.frame._points[1]
check(p and p[1] == "BOTTOM" and p[2] == UIParent, "above the Healthstone button, under UIParent")
eq(P.hint:GetText(), "No healthstone: create one first (the Healthstone button).", "no stone: says so")
click(P.primary)
eq(#WoW.trades, 0, "no stone: no trade opened")

-- A stone carried: the hint goes, the first click opens the trade with her.
carry(5512, "Minor Healthstone")
eq(P.hint:GetText(), "", "a stone carried: nothing in the way")
eq(P.primary.text:GetText(), "Open trade", "the first button opens the trade")
click(P.primary)
eq(WoW.trades[1], "party1", "InitiateTrade on Ashka's token, from the click")
eq(next(WoW.tradeSlots), nil, "nothing placed by opening it")

-- The trade opens with her: the second click places the stone.
WoW.tradeWith = ASHKA
WoW.fire("TRADE_SHOW")
eq(P.primary.text:GetText(), "Place the healthstone", "the trade with her is open: place it")
eq(P.hint:GetText(), "Put your best healthstone in the trade.", "says what the click does")
click(P.primary)
eq(WoW.tradeSlots[1], 5512, "the stone is in the first trade slot")
eq(WoW.cursor, nil, "nothing left on the cursor")
eq(P.hint:GetText(), "Accept the trade to give it.", "the player accepts")
-- Codex on #53: a failed repeat click (something on the cursor) keeps the
-- placement, and leaves the trade as it is.
WoW.items[2589] = "Linen Cloth"
WoW.cursor = 2589
click(P.primary)
eq(WoW.cursor, 2589, "a repeat click doesn't touch the cursor")
eq(WoW.tradeSlots[1], 5512, "the stone stays in the trade")
eq(next(WoW.tradeSlots, 1), nil, "and nothing else goes in")
eq(P.hint:GetText(), "Accept the trade to give it.", "still placed")
WoW.cursor = nil
WoW.tradeWith = nil
WoW.fire("TRADE_CLOSED")
WoW.advance(0)
eq(names(), "", "the trade closed after the stone was placed: her request is done")
check(not P.frame:IsShown(), "and the prompt goes")

-- A stone placed, then taken back out by hand: not placed any more.
WoW.tradeSlots = {}
say("CHAT_MSG_PARTY", "hs", ASHKA)
click(P.primary)
WoW.tradeWith = ASHKA
WoW.fire("TRADE_SHOW")
click(P.primary)
eq(WoW.tradeSlots[1], 5512, "placed")
WoW.tradeSlots[1] = nil
WoW.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
eq(P.hint:GetText(), "Put your best healthstone in the trade.", "taken back out: place it again")
WoW.tradeWith = nil
WoW.fire("TRADE_CLOSED")
WoW.advance(0)
eq(names(), "Ashka Vale", "closed without the stone: she still asks")
R:Clear()

-- A trade closed before the stone was placed keeps the request.
say("CHAT_MSG_RAID", "healthstone", BROM)
click(P.primary)
WoW.tradeWith = BROM
WoW.fire("TRADE_SHOW")
WoW.tradeWith = nil
WoW.fire("TRADE_CLOSED")
WoW.advance(0)
eq(names(), "Brom Hollow", "closed before placing: Brom still asks")

-- A trade the requester opens counts too.
WoW.tradeSlots = {}
WoW.tradeWith = BROM
WoW.fire("TRADE_SHOW")
eq(P.primary.text:GetText(), "Place the healthstone", "Brom opened it: place it")
-- Codex on #53: something already on the cursor is never touched, and
-- never traded in place of the stone.
WoW.items[2589] = "Linen Cloth"
WoW.cursor = 2589
click(P.primary)
eq(WoW.cursor, 2589, "the cloth on the cursor stays there")
eq(next(WoW.tradeSlots), nil, "nothing goes in the trade")
eq(P.hint:GetText(), "Your cursor holds something: put it down first.", "the hint says so")
WoW.cursor = nil
-- A refused pickup (a locked stone): the slot isn't clicked, nothing is placed.
WoW.pickupFails = true
click(P.primary)
eq(next(WoW.tradeSlots), nil, "a refused pickup places nothing")
eq(P.hint:GetText(), "No healthstone, or no free trade slot.", "and says so")
WoW.pickupFails = false
-- The slot refuses: nothing stays on the cursor, and the hint says so.
WoW.tradeRefuses = true
click(P.primary)
eq(WoW.cursor, nil, "a refused stone goes back to the bags")
eq(P.hint:GetText(), "No healthstone, or no free trade slot.", "and the hint says so")
WoW.tradeRefuses = false
WoW.tradeWith = nil
WoW.fire("TRADE_CLOSED")
WoW.advance(0)
eq(names(), "Brom Hollow", "nothing placed: still asks")

-- Skip drops it; asking again keeps one place; several show "and N more".
click(P.skip)
eq(names(), "", "Skip drops the request")
say("CHAT_MSG_PARTY", "hs", ASHKA)
say("CHAT_MSG_PARTY", "hs", BROM)
say("CHAT_MSG_PARTY", "hs", ASHKA)
eq(names(), "Ashka Vale,Brom Hollow", "asking again keeps one place")
eq(P.more:GetText(), "and 1 more", "the prompt counts the others")
eq(P.text:GetText(), "Ashka Vale asks for a healthstone.", "the oldest first")

-- Leaving the group or waiting too long drops them.
table.remove(WoW.group, 1)
WoW.fire("GROUP_ROSTER_UPDATE")
WoW.advance(0)
eq(names(), "Brom Hollow", "Ashka left the group: dropped")
WoW.advance(R.TIMEOUT + 15)
eq(names(), "", "five minutes later: dropped")
table.insert(WoW.group, 1, { guid = ASHKA, name = "Ashka Vale", class = "MAGE" })

-- Whispers: a member's counts; a stranger's only with the option on.
say("CHAT_MSG_WHISPER", "hs", ASHKA, "Ashka Vale")
eq(names(), "Ashka Vale", "a member's whisper asks")
R:Clear()
say("CHAT_MSG_WHISPER", "hs", STRANGER, "Zed Far")
eq(names(), "", "a stranger's whisper: ignored by default")
say("CHAT_MSG_PARTY", "hs", STRANGER, "Zed Far")
eq(names(), "", "a stranger can't ask in group chat")
ns.db.stones.strangers = true
say("CHAT_MSG_WHISPER", "hs", STRANGER, "Zed Far")
eq(names(), "Zed Far", "with the option on: Zed asks")
eq(P.hint:GetText(), "Not in your group: target them first.", "trading him needs him targeted")
WoW.trades = {}
click(P.primary)
eq(#WoW.trades, 0, "not targeted: no trade")
WoW.targetGUID = STRANGER
WoW.fire("PLAYER_TARGET_CHANGED")
eq(P.hint:GetText(), "", "targeted: nothing in the way")
click(P.primary)
eq(WoW.trades[1], "target", "the trade opens on the target")
WoW.targetGUID = nil
R:Clear()
ns.db.stones.strangers = false

-- Turned off, the player, an unreadable GUID: nothing.
ns.db.stones.enabled = false
say("CHAT_MSG_PARTY", "hs", ASHKA)
ns.db.stones.enabled = true
say("CHAT_MSG_PARTY", "hs", WoW.playerGUID)
say("CHAT_MSG_PARTY", "hs", WoW.Secret("guid"))
eq(names(), "", "off, yourself, or an unreadable sender: nothing")

-- The player's own keywords; /123 hs test and clear.
ns.db.stones.keywords = ns.Queue.ParseKeywords("pds, hs", "hs")
say("CHAT_MSG_PARTY", "pds", ASHKA)
eq(names(), "Ashka Vale", "a keyword of the player's own")
eq(table.concat(ns.Queue.ParseKeywords("", "hs"), "|"), "hs", "an empty list is hs")
R:Clear()
H.slash("ONETWOTHREE", "hs test")
eq(names(), "Ashka Vale", "/123 hs test: a made-up request")
WoW.trades = {}
click(P.primary)
eq(#WoW.trades, 0, "a test request trades nothing")
eq(P.hint:GetText(), "A test request: nothing to trade.", "and says so")
H.slash("ONETWOTHREE", "hs clear")
eq(names(), "", "/123 hs clear")

done("test_requests")
