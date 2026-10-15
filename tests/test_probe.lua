-- The probe module on the ForeverProbe host (#35): every command runs
-- against the stubs without a Lua error, its lines go to the console and the
-- saved log, never to chat, and chat payloads are logged by shape only.
-- ForeverProbe is private and local: CI skips this (FOREVERPROBE_OPTIONAL).

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- A file from before ForeverProbe: its runs are left alone.
local ns = H.loadProbe({ runs = { { results = { stale = "old session" } } } })
local DB = OneTwoThreeProbeDB
H.eq(DB.runs[1].results.stale, "old session", "earlier sessions are kept")
H.check(type(DB.log) == "table", "the log is bound at ADDON_LOADED")
H.eq(DB.loads, 1, "loads counted")

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
H.eq(failures(), 1, "a throwing command is logged as an ERROR")
H.eq(#thrown, 1, "and reaches the error handler")
thrown = {}

local chatBefore = #WoW.messages
local cmds = { "", "book", "pet", "stones", "watch on", "secure target", "trade target",
    "tradeitem 5512", "range", "auras", "watch off" }
for _, cmd in ipairs(cmds) do
    local before = failures()
    local ok, err = pcall(fp, "123 " .. cmd)
    H.check(ok, "/fp 123 " .. cmd .. " runs: " .. tostring(err))
    H.eq(failures(), before, "/fp 123 " .. cmd .. " logs no ERROR")
end
H.eq(#thrown, 0, "no command reached the error handler: " .. table.concat(thrown, "; "))
WoW.runTimers(5)
H.check(logged("pet exists"), "results land in the saved log")
H.check(logged("item 6265 Soul Shard count"), "stones are logged")
H.eq(#WoW.messages, chatBefore, "nothing printed to chat")

-- Chat payloads: shapes, never the text.
fp("123 watch on")
WoW.fire("CHAT_MSG_PARTY", "123 please", "Some One", "", "", "", "", 0, 0, "", 0, 42, "Player-1-ABC")
H.check(logged("CHAT_MSG_PARTY: text=str10"), "the text by length")
H.check(not logged("123 please"), "never the text itself")
fp("123 watch off")

-- `say` writes to group chat on purpose (a stimulus), typed then by timer.
WoW.chat = {}
fp("123 say PARTY hello")
WoW.runTimers(2)
H.eq(#WoW.chat, 2, "the typed and the timer send")

-- #39's procedure, walked with the host's own controls, by the player's
-- GUID (WoW.playerGUID in the stubs).
local S = ForeverProbe.Steps
fp("123 disable")
H.check(S.IsShown(), "/fp 123 disable starts the procedure")
local rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/disable"]
H.check(rec.results[1] and rec.results[1].status == "done", "step 1 read the names on arrival")
S.Run()   -- step 2 (step 1 ran on arrival and moved on); Run completes it
H.eq(rec.results[2].check, "PASS", "disabled for this character only: PASS")
H.eq(C_AddOns.GetAddOnEnableState("123", nil), 1, "still on for the others")
S.Answer(true)
S.Run()
H.eq(rec.results[4].check, "PASS", "enabled again: PASS")
H.eq(C_AddOns.GetAddOnEnableState("123", nil), 2, "on for everyone")
S.Stop("test")

-- The danger: a client that ignores the character disables 123 everywhere;
-- the step puts it back at once and the check fails.
local real = C_AddOns.DisableAddOn
C_AddOns.DisableAddOn = function() WoW.addonOffAll = true end
fp("123 disable")
rec = ForeverProbeDB.steps.records["OneTwoThreeProbe/disable"]
S.Run()
H.eq(rec.results[2].check, "FAIL", "disabled everywhere: FAIL")
H.eq(C_AddOns.GetAddOnEnableState("123", nil), 2, "and re-enabled for every character at once")
H.check(logged("disabled for EVERY character"), "and says so")
S.Stop("test")
C_AddOns.DisableAddOn = real

fp("123 clear")
H.eq(#DB.log, 1, "clear empties the log in place (then says so)")
H.check(ns._test.Probe ~= nil, "the test seam")

H.done("test_probe")
