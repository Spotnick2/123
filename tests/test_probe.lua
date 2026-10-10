-- Every probe command runs against the stubs without a Lua error, and each
-- session's results are appended to what the client saves.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- A file from before runs existed: its one session becomes the first run,
-- and this session is appended after it (results were lost after /reload).
H.loadProbe({ build = "70334", results = { stale = "old session" }, log = {} })
local runs = OneTwoThreeProbeDB.runs
H.eq(#runs, 2, "the old session is kept and this one appended")
H.eq(runs[1].results.stale, "old session", "the old session's results survive")
local run = runs[2]
H.eq(next(run.results), nil, "this session starts empty")

local cmds = { "", "book", "pet", "stones", "watch on", "secure target", "trade target",
    "tradeitem 5512", "say PARTY hello", "range", "auras", "report", "watch off" }
for _, cmd in ipairs(cmds) do
    local before = H.messagesMatching("failed:")
    local ok, err = pcall(H.slash, "ONETWOTHREEPROBE", cmd)
    H.check(ok, "/123probe " .. cmd .. " runs: " .. tostring(err))
    H.eq(H.messagesMatching("failed:"), before, "/123probe " .. cmd .. " reports no failure")
end
WoW.runTimers(5)
H.check(run.results["pet exists"] ~= nil, "results land in the saved table")
H.check(run.book ~= nil, "the spellbook dump lands in this run")
H.slash("ONETWOTHREEPROBE", "reset")
H.eq(next(run.results), nil, "reset clears this session's run")
H.eq(runs[1].results.stale, "old session", "reset leaves earlier runs alone")
H.eq(H.messagesMatching("will not be saved"), 0, "ADDON_LOADED registered")

H.done("test_probe")
