-- The TOC, .pkgmeta and .gitignore.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local toc = assert(io.open("123.toc")):read("*a"):gsub("\r", "")
H.check(toc:find("## Interface: 16001\n"), "Interface is 16001")
H.check(toc:find("## Version: @project%-version@\n"), "Version stays the packager token")
H.check(toc:find("## SavedVariables: OneTwoThreeDB\n"), "OneTwoThreeDB is the saved table")

local files = H.tocFiles("123.toc")
for _, f in ipairs(files) do
    if not f:find("^Libs/LibGlass") then
        H.check(io.open(f) ~= nil, "TOC file exists: " .. f)
    end
end
H.eq(files[1], "Libs/LibStub/LibStub.lua", "LibStub loads first")
local order = {}
for i, f in ipairs(files) do order[f] = i end
H.check(order["Libs/LibGlass-1.0/LibGlass-1.0.xml"] < order["Core/Constants.lua"], "libraries before the addon")
H.check(order["Core/Constants.lua"] < order["Core/Compat.lua"], "Constants before Compat")
H.check(order["Core/Compat.lua"] < order["Core/Events.lua"], "Compat before Events")
H.eq(files[#files], "Core/Init.lua", "Init loads last")
H.check(not order["Tools/OneTwoThreeProbe/OneTwoThreeProbe.lua"], "the probe is not shipped")

local pkg = assert(io.open(".pkgmeta")):read("*a"):gsub("\r", "")
H.check(pkg:find("package%-as: 123\n"), ".pkgmeta packages as 123")
for _, ignored in ipairs({ "tests", "Tools", "docs", "AGENTS.md", "CLAUDE.md", ".claude", ".github" }) do
    H.check(pkg:find("\n%s*%- " .. ignored:gsub("%p", "%%%0") .. "\n"), ".pkgmeta ignores " .. ignored)
end
for _, sub in ipairs({ "tests", "docs", "Tools" }) do
    H.check(pkg:find("- Libs/LibGlass-1.0/" .. sub .. "\n", 1, true), ".pkgmeta ignores Libs/LibGlass-1.0/" .. sub)
end
local ignore = assert(io.open(".gitignore")):read("*a")
H.check(ignore:find("Libs/LibGlass%-1.0/"), "LibGlass is never committed")

-- The .pkgmeta pin matches the minimum library version the code requires.
local skin = assert(io.open("UI/Skin.lua")):read("*a")
local needs = tonumber(skin:match("local NEEDS_MINOR = (%d+)"))
local pin = tonumber(pkg:match("Libs/LibGlass%-1%.0:%s*url: [^\n]+\n%s*tag: r(%d+)"))
H.check(pin and needs and pin >= needs, "LibGlass pin covers what Skin.lua needs")

H.done("test_manifest")
