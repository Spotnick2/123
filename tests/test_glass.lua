-- The bar built with the real LibGlass (from $LIBGLASS or ../LibGlass)
-- instead of the plain fallback.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local root = os.getenv("LIBGLASS") or "../LibGlass"
local libFile = root .. "/LibGlass.lua"
if not io.open(libFile) then
    io.write("test_glass: skipped (no LibGlass checkout at " .. root .. ")\n")
    os.exit(0)
end

local ns = H.loadAddon({ libs = { libFile } })
H.check(ns.Skin:Glass() ~= nil, "LibGlass r5+ is picked up")
H.check(ns.Bar.glass.top ~= nil, "the bar is glass")
H.eq(H.messagesMatching("not found"), 0, "no fallback warning")

H.done("test_glass")
