-- The TOC, .pkgmeta and .gitignore.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- WowTestKit's checks every TOC must pass: the interface, the packager's
-- version token, every listed .lua file exists, every entry listed once.
-- (Not the probe's TOC: its "## Version: dev" is deliberate, WowTestKit #84.)
Kit.checkToc("123.toc")

local toc = assert(io.open("123.toc")):read("*a"):gsub("\r", "")
check(toc:find("## SavedVariables: OneTwoThreeDB\n"), "OneTwoThreeDB is the saved table")
check(toc:find("## X%-Curse%-Project%-ID: 1735903\n"), "the CurseForge project ID")
-- The `wago` job uploads to the project the packaged TOC names (#42).
check(toc:find("## X%-Wago%-ID: qGYBAONg\n"), "the Wago project ID")

-- Kit.checkToc covers the .lua lines; the libraries' XML lines are fetched
-- by the packager, so only the other (none today) are checked here.
local files = H.tocFiles("123.toc")
for _, f in ipairs(files) do
    if not f:find("%.lua$") and not f:find("^Libs/LibGlass") and not f:find("^Libs/LibShowcase") then
        check(io.open(f) ~= nil, "TOC file exists: " .. f)
    end
end
eq(files[1], "Libs/LibStub/LibStub.lua", "LibStub loads first")
local order = {}
for i, f in ipairs(files) do order[f] = i end
check(order["Libs/LibGlass-1.0/LibGlass-1.0.xml"] < order["Core/Constants.lua"], "libraries before the addon")
check(order["Libs/LibShowcase-1.0/LibShowcase-1.0.xml"] < order["Core/Constants.lua"], "LibShowcase before the addon")
check(order["Core/Constants.lua"] < order["Core/Compat.lua"], "Constants before Compat")
check(order["Core/Compat.lua"] < order["Core/Events.lua"], "Compat before Events")
eq(files[#files], "Core/Init.lua", "Init loads last")
check(not order["Tools/OneTwoThreeProbe/OneTwoThreeProbe.lua"], "the probe is not shipped")

-- #39: every 123 file stops on its first line on another class.
for _, f in ipairs(files) do
    if f:find("%.lua$") and not f:find("^Libs/") then
        local src = assert(io.open(f)):read("*a")
        local head = src:match("^.-ns = %.%.%.\r?\n([^\n]*)")
        check(head and head:find("if ns.skip then return end", 1, true) or f == "Core/Constants.lua",
            f .. " stops at once on another class")
    end
end
local constants = assert(io.open("Core/Constants.lua")):read("*a")
check(constants:find("if ns.skip then return end", 1, true), "Constants decides, then stops too")

local pkg = assert(io.open(".pkgmeta")):read("*a"):gsub("\r", "")
check(pkg:find("package%-as: 123\n"), ".pkgmeta packages as 123")
for _, ignored in ipairs({ "tests", "Tools", "docs", "AGENTS.md", "CLAUDE.md", ".claude", ".github" }) do
    check(pkg:find("\n%s*%- " .. ignored:gsub("%p", "%%%0") .. "\n"), ".pkgmeta ignores " .. ignored)
end
for _, lib in ipairs({ "LibGlass-1.0", "LibShowcase-1.0" }) do
    for _, sub in ipairs({ "tests", "docs", "Tools" }) do
        check(pkg:find("- Libs/" .. lib .. "/" .. sub .. "\n", 1, true), ".pkgmeta ignores Libs/" .. lib .. "/" .. sub)
    end
end
local ignore = assert(io.open(".gitignore")):read("*a")
check(ignore:find("Libs/LibGlass%-1.0/"), "LibGlass is never committed")
check(ignore:find("Libs/LibShowcase%-1.0/"), "LibShowcase is never committed")

-- The .pkgmeta pin matches the minimum library version the code requires.
local skin = assert(io.open("UI/Skin.lua")):read("*a")
local needs = tonumber(skin:match("local NEEDS_MINOR = (%d+)"))
local pin = tonumber(pkg:match("Libs/LibGlass%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
check(pin and needs and pin >= needs, "LibGlass pin covers what Skin.lua needs")
local pres = assert(io.open("UI/Presentation.lua")):read("*a")
local scNeeds = tonumber(pres:match("local NEEDS_MINOR = (%d+)"))
local scPin = tonumber(pkg:match("Libs/LibShowcase%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
check(scPin and scNeeds and scPin >= scNeeds, "LibShowcase pin covers what Presentation.lua needs")

done("test_manifest")
