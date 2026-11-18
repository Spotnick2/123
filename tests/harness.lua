------------------------------------------------------------
-- harness.lua: addon loading for the tests (adapted from Portal Roulette's
-- tests/harness.lua). The assertions are WowTestKit's globals (check, eq,
-- done), loaded by tests/wow_stubs.lua.
--
--     dofile("tests/wow_stubs.lua")
--     local H = dofile("tests/harness.lua")
--     local ns = H.loadAddon()
--     check(cond, "message")
--     done("test_name")
------------------------------------------------------------

local H = {}

-- The files a TOC lists (every line, .xml too), in load order, with forward
-- slashes, under the TOC's folder: Kit.tocLines as paths.
function H.tocFiles(toc)
    local files = {}
    local dir = toc:match("^(.*)/[^/]+$")
    for _, line in ipairs(Kit.tocLines(toc)) do
        line = line:gsub("\\", "/")
        files[#files + 1] = dir and (dir .. "/" .. line) or line
    end
    return files
end

local function login(addonName)
    WoW.fire("ADDON_LOADED", addonName)
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD")
    WoW.advance(0)
end

-- The ForeverProbe host from the sibling checkout ($FOREVERPROBE, else
-- ../ForeverProbe), as GlassChat's harness loads it. It is private, so CI
-- can't fetch it: with FOREVERPROBE_OPTIONAL=1 a missing checkout skips the
-- probe's test; locally it is an error.
function H.loadForeverProbe()
    local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
    local toc = io.open(root .. "/ForeverProbe.toc", "rb")
    if not toc then
        if os.getenv("FOREVERPROBE_OPTIONAL") == "1" then
            io.write("SKIPPED: ForeverProbe isn't here (private, local only); the probe tests run locally\n")
            os.exit(0)
        end
        error("ForeverProbe checkout not found at " .. root .. ": clone it there or set FOREVERPROBE", 0)
    end
    for line in toc:read("*a"):gmatch("[^\r\n]+") do
        if line:match("%.lua$") and not line:match("^#") then
            assert(loadfile(root .. "/" .. line:gsub("\\", "/")))("ForeverProbe", {})
        end
    end
    toc:close()
    WoW.fire("ADDON_LOADED", "ForeverProbe")
    return rawget(_G, "ForeverProbe")
end

-- The dev-only probe module on the ForeverProbe host, then the client's
-- login sequence. Returns the module's namespace (its _test seam).
function H.loadProbe(savedDB)
    H.loadForeverProbe()
    local ns = {}
    for _, f in ipairs(H.tocFiles("Tools/OneTwoThreeProbe/OneTwoThreeProbe.toc")) do
        local chunk, err = loadfile(f)
        if not chunk then error(err) end
        chunk("OneTwoThreeProbe", ns)
    end
    if savedDB then rawset(_G, "OneTwoThreeProbeDB", savedDB) end
    login("OneTwoThreeProbe")
    return ns
end

-- 123 itself. Libs\ lines load only LibStub: LibGlass comes from a sibling
-- checkout (opts.libs = paths), so by default the no-LibGlass fallback runs.
function H.loadAddon(opts)
    opts = opts or {}
    local ns = {}
    for _, f in ipairs(H.tocFiles("123.toc")) do
        local isLib = f:find("^Libs/")
        if not isLib or f == "Libs/LibStub/LibStub.lua" then
            local chunk, err = loadfile(f)
            if not chunk then error(err) end
            chunk("123", ns)
        end
    end
    for _, lib in ipairs(opts.libs or {}) do
        local chunk, err = loadfile(lib)
        if not chunk then error(err) end
        chunk("123")
    end
    if opts.savedDB then rawset(_G, "OneTwoThreeDB", opts.savedDB) end
    if opts.beforeLogin then opts.beforeLogin() end
    login("123")
    return ns
end

-- Run a slash command by its SlashCmdList key.
function H.slash(key, msg)
    local fn = SlashCmdList[key]
    if not fn then error("no slash command " .. key) end
    fn(msg or "")
end

-- Printed lines (the chat frame's included) matching a pattern.
function H.messagesMatching(pattern)
    local n = 0
    for _, m in ipairs(WoW.chat) do if m:find(pattern) then n = n + 1 end end
    return n
end

-- FINDING #61: /123 queue, /123 hs and the help line print a bare "|",
-- which done() fails on (the kit's print checks every printed line). Until
-- it is fixed, a test that runs those commands calls this before done(): it
-- takes exactly those lines out of WoW.strays, so any other stray still
-- fails, and checks one was printed, so the exception can't outlive the fix.
local KNOWN_STRAYS = {
    "/123 queue test | clear",
    "/123 hs test | clear",
    "/123 | options | queue (test, clear)",
}
function H.acceptKnownStrays()
    local keep, known = {}, 0
    for _, line in ipairs(WoW.strays) do
        local isKnown = false
        for _, s in ipairs(KNOWN_STRAYS) do
            if line:find(s, 1, true) then isKnown = true break end
        end
        if isKnown then known = known + 1 else keep[#keep + 1] = line end
    end
    WoW.strays = keep
    check(known > 0, "a known stray-| line (FINDING #61) was printed")
    return known
end

return H
