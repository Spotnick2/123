dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- The Addon Compartment entry, called the way the client's menu calls it:
-- func(data, menuInputData, menu), the button in menuInputData.buttonName
-- (Blizzard_Minimap/Mainline/AddonCompartment.lua; Codex on #32).
local entry
rawset(_G, "AddonCompartmentFrame", { RegisterAddon = function(_, data) entry = data end })
local ns = H.loadAddon()
H.check(entry ~= nil, "registered in the Addon Compartment")
local opened, wheel, bar = 0, 0, 0
ns.Options.Open = function() opened = opened + 1 end
ns.Wheel.Toggle = function() wheel = wheel + 1 end
ns.Bar.Toggle = function() bar = bar + 1 end
entry.func({}, { buttonName = "RightButton" }, {})
H.eq(opened, 1, "right-click: options")
entry.func({}, { buttonName = "LeftButton" }, {})
H.eq(wheel, 1, "click: the demon wheel")
WoW.shiftDown = true
entry.func({}, { buttonName = "LeftButton" }, {})
WoW.shiftDown = false
H.eq(bar, 1, "shift-click: the bar")
H.eq(opened + wheel, 2, "and nothing else")

H.done("test_compartment")
