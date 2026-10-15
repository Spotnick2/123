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

local chatBefore = #WoW.messages
local cmds = { "", "book", "pet", "stones", "watch on", "secure target", "trade target",
    "tradeitem 5512", "range", "auras", "watch off" }
for _, cmd in ipairs(cmds) do
    local ok, err = pcall(fp, "123 " .. cmd)
    H.check(ok, "/fp 123 " .. cmd .. " runs: " .. tostring(err))
end
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

fp("123 clear")
H.eq(#DB.log, 1, "clear empties the log in place (then says so)")
H.check(ns._test.Probe ~= nil, "the test seam")

H.done("test_probe")
