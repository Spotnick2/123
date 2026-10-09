-- Every probe command runs against the stubs without a Lua error.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

H.loadProbe()
local cmds = { "", "book", "pet", "stones", "watch on", "secure target", "trade target",
    "tradeitem 5512", "say PARTY hello", "range", "report", "watch off", "reset" }
for _, cmd in ipairs(cmds) do
    local before = H.messagesMatching("failed:")
    local ok, err = pcall(H.slash, "ONETWOTHREEPROBE", cmd)
    H.check(ok, "/123probe " .. cmd .. " runs: " .. tostring(err))
    H.eq(H.messagesMatching("failed:"), before, "/123probe " .. cmd .. " reports no failure")
end
WoW.runTimers(5)
H.check(OneTwoThreeProbeDB.results ~= nil, "results are kept")

H.done("test_probe")
