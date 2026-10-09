-- Every probe command runs against the stubs without a Lua error.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- Last session's saved table is replaced by this session's, and results
-- land in the table the client will save (they were lost after /reload).
H.loadProbe({ results = { stale = "old session" }, log = {} })
H.eq(OneTwoThreeProbeDB.results.stale, nil, "last session's results are not kept")
local cmds = { "", "book", "pet", "stones", "watch on", "secure target", "trade target",
    "tradeitem 5512", "say PARTY hello", "range", "report", "watch off" }
for _, cmd in ipairs(cmds) do
    local before = H.messagesMatching("failed:")
    local ok, err = pcall(H.slash, "ONETWOTHREEPROBE", cmd)
    H.check(ok, "/123probe " .. cmd .. " runs: " .. tostring(err))
    H.eq(H.messagesMatching("failed:"), before, "/123probe " .. cmd .. " reports no failure")
end
WoW.runTimers(5)
H.check(OneTwoThreeProbeDB.results["pet exists"] ~= nil, "results land in the saved table")
H.slash("ONETWOTHREEPROBE", "reset")
H.eq(next(OneTwoThreeProbeDB.results), nil, "reset clears the saved table")

H.done("test_probe")
