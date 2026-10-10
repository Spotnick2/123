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

-- The Warlock colour (the wheel: fel green) at 60%, at the surface's own opacity (AltStable #220).
local function near(x, y) return math.abs(x - y) < 1e-6 end
local function tinted(g, what, color)
    local want = color or { 0.53, 0.53, 0.93 }
    local c, built = g.tint and g.tint._color, g.tint and g.tint.glassColor
    H.check(c and near(c[1], want[1] * 0.6) and near(c[2], want[2] * 0.6) and near(c[3], want[3] * 0.6),
        what .. " wears its colour at 60%")
    H.check(c and built and c[4] == built[4], what .. " keeps its own opacity")
end
tinted(ns.Bar.glass, "the bar")
ns.Wheel:Open()
tinted(ns.Wheel.nodes[1].glass, "a wheel bead", ns.Colors.FEL)
ns.Wheel:Close()

H.done("test_glass")
