-- The TOC, .pkgmeta and .gitignore.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local toc = assert(io.open("123.toc")):read("*a"):gsub("\r", "")
H.check(toc:find("## Interface: 16001\n"), "Interface is 16001")
H.check(toc:find("## Version: @project%-version@\n"), "Version stays the packager token")
H.check(toc:find("## SavedVariables: OneTwoThreeDB\n"), "OneTwoThreeDB is the saved table")
H.check(toc:find("## X%-Curse%-Project%-ID: 1735903\n"), "the CurseForge project ID")

local files = H.tocFiles("123.toc")
for _, f in ipairs(files) do
    if not f:find("^Libs/LibGlass") and not f:find("^Libs/LibShowcase") then
        H.check(io.open(f) ~= nil, "TOC file exists: " .. f)
    end
end
H.eq(files[1], "Libs/LibStub/LibStub.lua", "LibStub loads first")
local order = {}
for i, f in ipairs(files) do order[f] = i end
H.check(order["Libs/LibGlass-1.0/LibGlass-1.0.xml"] < order["Core/Constants.lua"], "libraries before the addon")
H.check(order["Libs/LibShowcase-1.0/LibShowcase-1.0.xml"] < order["Core/Constants.lua"], "LibShowcase before the addon")
H.check(order["Core/Constants.lua"] < order["Core/Compat.lua"], "Constants before Compat")
H.check(order["Core/Compat.lua"] < order["Core/Events.lua"], "Compat before Events")
H.eq(files[#files], "Core/Init.lua", "Init loads last")
H.check(not order["Tools/OneTwoThreeProbe/OneTwoThreeProbe.lua"], "the probe is not shipped")

-- #39: every 123 file stops on its first line on another class.
for _, f in ipairs(files) do
    if f:find("%.lua$") and not f:find("^Libs/") then
        local src = assert(io.open(f)):read("*a")
        local head = src:match("^.-ns = %.%.%.\r?\n([^\n]*)")
        H.check(head and head:find("if ns.skip then return end", 1, true) or f == "Core/Constants.lua",
            f .. " stops at once on another class")
    end
end
local constants = assert(io.open("Core/Constants.lua")):read("*a")
H.check(constants:find("if ns.skip then return end", 1, true), "Constants decides, then stops too")

local pkg = assert(io.open(".pkgmeta")):read("*a"):gsub("\r", "")
H.check(pkg:find("package%-as: 123\n"), ".pkgmeta packages as 123")
for _, ignored in ipairs({ "tests", "Tools", "docs", "AGENTS.md", "CLAUDE.md", ".claude", ".github" }) do
    H.check(pkg:find("\n%s*%- " .. ignored:gsub("%p", "%%%0") .. "\n"), ".pkgmeta ignores " .. ignored)
end
for _, lib in ipairs({ "LibGlass-1.0", "LibShowcase-1.0" }) do
    for _, sub in ipairs({ "tests", "docs", "Tools" }) do
        H.check(pkg:find("- Libs/" .. lib .. "/" .. sub .. "\n", 1, true), ".pkgmeta ignores Libs/" .. lib .. "/" .. sub)
    end
end
local ignore = assert(io.open(".gitignore")):read("*a")
H.check(ignore:find("Libs/LibGlass%-1.0/"), "LibGlass is never committed")
H.check(ignore:find("Libs/LibShowcase%-1.0/"), "LibShowcase is never committed")

-- The .pkgmeta pin matches the minimum library version the code requires.
local skin = assert(io.open("UI/Skin.lua")):read("*a")
local needs = tonumber(skin:match("local NEEDS_MINOR = (%d+)"))
local pin = tonumber(pkg:match("Libs/LibGlass%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
H.check(pin and needs and pin >= needs, "LibGlass pin covers what Skin.lua needs")
local pres = assert(io.open("UI/Presentation.lua")):read("*a")
local scNeeds = tonumber(pres:match("local NEEDS_MINOR = (%d+)"))
local scPin = tonumber(pkg:match("Libs/LibShowcase%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
H.check(scPin and scNeeds and scPin >= scNeeds, "LibShowcase pin covers what Presentation.lua needs")

H.done("test_manifest")
