-- The probe module on the ForeverProbe host (#35): every command runs
-- against the stubs without a Lua error, its lines go to the console and the
-- saved log, never to chat, and chat payloads are logged by shape only.
-- ForeverProbe is private and local: CI skips this (FOREVERPROBE_OPTIONAL).

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- A file from before ForeverProbe: its runs are left alone.
local ns = H.loadProbe({ runs = { { results = { stale = "old session" } } } })
local DB = OneTwoThreeProbeDB
eq(DB.runs[1].results.stale, "old session", "earlier sessions are kept")
check(type(DB.log) == "table", "the log is bound at ADDON_LOADED")
eq(DB.loads, 1, "loads counted")

local function fp(msg) SlashCmdList.FOREVERPROBE(msg) end
local function logged(pattern)
    for _, line in ipairs(DB.log) do if line:find(pattern) then return true end end
    return false
end

-- The host's dispatcher catches a handler's throw: it logs "ERROR /fp ..."
-- and hands the error to geterrorhandler(). Both are watched, so a command
-- that throws fails here (an API refusal the probe measures is logged by
-- Probe:Call as ABSENT / ERROR: and is not a command failure).
local thrown = {}
rawset(_G, "geterrorhandler", function() return function(err) thrown[#thrown + 1] = tostring(err) end end)
local function failures()
    local n = 0
    for _, line in ipairs(DB.log) do if line:find("ERROR|r /fp 123", 1, true) then n = n + 1 end end
    return n
end

-- The check catches a failing command.
ns._test.Probe:Command("boom", function() error("boom") end, "test only")
fp("123 boom")
eq(failures(), 1, "a throwing command is logged as an ERROR")
eq(#thrown, 1, "and reaches the error handler")
thrown = {}

local chatBefore = #WoW.chat
local cmds = { "", "book", "pet", "stones", "watch on", "secure target", "trade target",
    "tradeitem 5512", "range", "auras", "locale", "watch off" }
for _, cmd in ipairs(cmds) do
    local before = failures()
    local ok, err = pcall(fp, "123 " .. cmd)
    check(ok, "/fp 123 " .. cmd .. " runs: " .. tostring(err))
    eq(failures(), before, "/fp 123 " .. cmd .. " logs no ERROR")
end
eq(#thrown, 0, "no command reached the error handler: " .. table.concat(thrown, "; "))
WoW.advance(5)
check(logged("pet exists"), "results land in the saved log")
check(logged("item 6265 Soul Shard count"), "stones are logged")
eq(#WoW.chat, chatBefore, "nothing printed to chat")

-- Chat payloads: shapes, never the text.
fp("123 watch on")
WoW.fire("CHAT_MSG_PARTY", "123 please", "Some One", "", "", "", "", 0, 0, "", 0, 42, "Player-1-ABC")
check(logged("CHAT_MSG_PARTY: text=str10"), "the text by length")
check(not logged("123 please"), "never the text itself")
fp("123 watch off")

-- `say` writes to group chat on purpose (a stimulus), typed then by timer.
WoW.sent = {}
fp("123 say PARTY hello")
WoW.advance(2)
eq(#WoW.sent, 2, "the typed and the timer send")

-- #39's procedure, walked with the host's own controls, by the player's
-- GUID (WoW.playerGUID in the stubs).
local S = ForeverProbe.Steps
fp("123 disable")
check(S.IsShown(), "/fp 123 disable starts the procedure")
local rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/disable"]
check(rec.results[1] and rec.results[1].status == "done", "step 1 read the names on arrival")
S.Run()   -- step 2 (step 1 ran on arrival and moved on); Run completes it
eq(rec.results[2].check, "PASS", "disabled for this character only: PASS")
eq(C_AddOns.GetAddOnEnableState("123", nil), 1, "still on for the others")
S.Answer(true)
S.Run()
eq(rec.results[4].check, "PASS", "enabled again: PASS")
eq(C_AddOns.GetAddOnEnableState("123", nil), 2, "on for everyone")
S.Stop("test")

-- The danger: a client that ignores the character disables 123 everywhere;
-- the step puts it back at once and the check fails.
local real = C_AddOns.DisableAddOn
C_AddOns.DisableAddOn = function() WoW.addonOffAll = true end
fp("123 disable")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/disable"]
S.Run()
eq(rec.results[2].check, "FAIL", "disabled everywhere: FAIL")
eq(C_AddOns.GetAddOnEnableState("123", nil), 2, "and re-enabled for every character at once")
check(logged("disabled for EVERY character"), "and says so")
S.Stop("test")
C_AddOns.DisableAddOn = real

-- #9's procedure, walked to the end: each chat step completes from the
-- event its text asks for (a party leader's line and instance chat are their
-- own events, Codex on #38), and logs the payload by shape only.
local function chat(event, sender)
    WoW.fire(event, "123", sender, "", "", "", "", 0, 0, "", 0, 9, "Player-1-AAA")
end
-- A step's screenshot holds the next step until the host's OnUpdate driver
-- has settled and taken it (here it fails: no Screenshot() in the stubs).
local function settle() for _ = 1, 12 do WoW.tick(0.5) end end
fp("123 queue")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/queue"]
check(S.IsShown() and rec ~= nil, "/fp 123 queue starts the procedure")
S.Next()                                             -- 1 ready
chat("CHAT_MSG_PARTY_LEADER", "Wrong Step")          -- 2 waits for a member's PARTY line
check(rec.results[2] == nil or rec.results[2].status ~= "event", "a leader's line doesn't complete the member step")
chat("CHAT_MSG_PARTY", "Ashka Vale")                 -- 2
S.Answer(true); settle(); S.Answer(true)    -- 3 (its screenshot), 4
S.Skip()                                             -- 5 the /reload
chat("CHAT_MSG_PARTY", "Ashka Vale")                 -- 6 in combat
S.Answer(true); settle()                     -- 7 (its screenshot)
S.Answer(true); settle()                     -- 8 (its screenshot)
chat("CHAT_MSG_PARTY_LEADER", "Ashka Vale")          -- 9 them as leader
S.Answer(true)                                       -- 10
chat("CHAT_MSG_RAID", "Ashka Vale")                  -- 11
S.Answer(true)                                       -- 12
chat("CHAT_MSG_PARTY", "Ashka Vale")                 -- 13 dungeon
S.Answer(true)                                       -- 14
chat("CHAT_MSG_INSTANCE_CHAT", "Ashka Vale")         -- 15 dungeon finder
S.Answer(true)                                       -- 16
for _, i in ipairs({ 2, 6, 9, 11, 13, 15 }) do
    eq(rec.results[i] and rec.results[i].status, "event", "chat step " .. i .. " completes from its event")
end
check(not logged("Ashka Vale"), "never the sender's name")
S.Stop("test")

-- #10, #11: the summon procedure turns watch on; a ritual's SENT logs its
-- target's name by shape only.
fp("123 summon")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/summon"]
check(S.IsShown() and rec ~= nil, "/fp 123 summon starts the procedure")
check(logged("watch on"), "and turns watch on")
WoW.fire("UNIT_SPELLCAST_SENT", "player", "Ashka Vale", "Cast-3-0-0-698-1", 698)
check(logged("UNIT_SPELLCAST_SENT player, target="), "SENT is logged")
check(not logged("Ashka Vale"), "never the target's name")
S.Stop("test")
fp("123 watch off")

fp("123 soulstone")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/soulstone"]
check(S.IsShown() and rec ~= nil, "/fp 123 soulstone starts the procedure (#5)")
S.Stop("test")
fp("123 watch off")

fp("123 healthstone")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/healthstone"]
check(S.IsShown() and rec ~= nil, "/fp 123 healthstone starts the procedure (#8)")
S.Stop("test")
fp("123 control")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/control"]
check(S.IsShown() and rec ~= nil, "/fp 123 control starts the procedure (#29)")
S.Next()
WoW.fire("CHAT_MSG_PARTY", "hs", "Ashka Vale", "", "", "", "", 0, 0, "", 0, 9, "Player-1-AAA")
check(not logged("Ashka Vale"), "the request is logged by shape: never the name")
S.Stop("test")
fp("123 watch off")

fp("123 sacrifice")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/sacrifice"]
check(S.IsShown() and rec ~= nil, "/fp 123 sacrifice starts the procedure (#20)")
S.Stop("test")
fp("123 watch off")

-- #59: a vendor selling two grimoires, an Imp that knows Firebolt rank 2.
-- The merchant API isn't in the stub world: stubbed here, then removed.
local merchantStubs = {
    GetMerchantNumItems = function() return 3 end,
    GetMerchantItemID = function(i) return ({ 16302, 16316, 6265 })[i] end,
}
for k, v in pairs(merchantStubs) do rawset(_G, k, v) end
rawset(_G, "C_MerchantFrame", { GetItemInfo = function(i)
    return { name = ({ "Grimoire of Firebolt (Rank 2)", "Grimoire of Firebolt (Rank 3)", "Soul Shard" })[i], price = 100 }
end })
local realKnown, realInBook = C_SpellBook.IsSpellKnown, C_SpellBook.IsSpellInSpellBook
C_SpellBook.IsSpellKnown = function(id, bank) return bank == Enum.SpellBookSpellBank.Pet and (id == 7799 or id == 3110) end
C_SpellBook.IsSpellInSpellBook = function() return false end
local before = failures()
fp("123 petbook")
eq(failures(), before, "/fp 123 petbook logs no ERROR")
check(logged("rank Firebolt 2 %(spell 7799, item 16302%): IsSpellKnown=true"), "a known rank, with its grimoire")
check(logged("rank Firebolt 3 %(spell 7800, item 16316%): IsSpellKnown=false"), "the next rank, not known")
check(logged("no rank known: .*Torment"), "abilities with nothing known on one line")
check(logged("merchant 1 item 16302 .*%-> Firebolt 2 %(spell 7799%).*IsSpellKnown=true"), "the vendor's grimoire, known")
check(logged("2 of 3 items are grimoires in the table"), "a Soul Shard isn't a grimoire")
fp("123 grimoires")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/grimoires"]
check(S.IsShown() and rec ~= nil, "/fp 123 grimoires starts the procedure (#59)")
check(logged("grimoire watch on"), "and turns its watch on")
S.Stop("test")
C_SpellBook.IsSpellKnown, C_SpellBook.IsSpellInSpellBook = realKnown, realInBook
for k in pairs(merchantStubs) do rawset(_G, k, nil) end
rawset(_G, "C_MerchantFrame", nil)
eq(#thrown, 0, "no #59 command reached the error handler: " .. table.concat(thrown, "; "))

fp("123 clear")
eq(#DB.log, 1, "clear empties the log in place (then says so)")
check(ns._test.Probe ~= nil, "the test seam")

done("test_probe")
