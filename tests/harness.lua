------------------------------------------------------------
-- harness.lua: assertions and addon loading for the tests
-- (adapted from Portal Roulette's tests/harness.lua).
--
--     dofile("tests/wow_stubs.lua")
--     local H = dofile("tests/harness.lua")
--     local ns = H.loadAddon()
--     H.check(cond, "message")
--     H.done("test_name")
------------------------------------------------------------

local H = {}
local passed, failed = 0, 0

function H.check(cond, msg)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

function H.eq(actual, expected, msg)
    H.check(actual == expected, (msg or "") .. " (expected " .. tostring(expected)
            .. ", got " .. tostring(actual) .. ")")
end

function H.done(name)
    if failed > 0 then
        io.stderr:write(name .. ": " .. failed .. " failed, " .. passed .. " passed\n")
        os.exit(1)
    end
    io.write(name .. ": " .. passed .. " tests passed\n")
end

-- The files a TOC lists, in load order, with forward slashes.
function H.tocFiles(toc)
    local files = {}
    local dir = toc:match("^(.*)/[^/]+$")
    for line in io.lines(toc) do
        line = line:gsub("\r", ""):gsub("\\", "/")
        if line ~= "" and not line:match("^#") then
            files[#files + 1] = dir and (dir .. "/" .. line) or line
        end
    end
    return files
end

local function login(addonName)
    WoW.fire("ADDON_LOADED", addonName)
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD")
    WoW.runTimers(0)
end

-- The dev-only probe addon, then the client's login sequence.
function H.loadProbe(savedDB)
    for _, f in ipairs(H.tocFiles("Tools/OneTwoThreeProbe/OneTwoThreeProbe.toc")) do
        local chunk, err = loadfile(f)
        if not chunk then error(err) end
        chunk("OneTwoThreeProbe", {})
    end
    if savedDB then rawset(_G, "OneTwoThreeProbeDB", savedDB) end
    login("OneTwoThreeProbe")
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
    login("123")
    return ns
end

-- Run a slash command by its SlashCmdList key.
function H.slash(key, msg)
    local fn = SlashCmdList[key]
    if not fn then error("no slash command " .. key) end
    fn(msg or "")
end

function H.messagesMatching(pattern)
    local n = 0
    for _, m in ipairs(WoW.messages) do if m:find(pattern) then n = n + 1 end end
    return n
end

return H
