-- Any other class: nothing of 123 runs (#39). Every file stops on its first
-- line, so there's no UI, no command, no event handler and no saved data
-- touched. If the class can't be read yet at load, 123 loads and the login
-- gate stops it instead.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.class = "MAGE"
local ns = H.loadAddon()
H.eq(ns.skip, true, "a Mage skips 123")
H.eq(ns.Bar, nil, "no bar module")
H.eq(ns.Events, nil, "no event frame")
H.eq(SlashCmdList.ONETWOTHREE, nil, "no /123")
H.eq(rawget(_G, "OneTwoThree_Wheel"), nil, "no globals")
H.eq(rawget(_G, "OneTwoThreeDB"), nil, "the saved table is left alone")
H.eq(#WoW.messages, 0, "nothing said")

-- The class unreadable while the files load: 123 loads, and the login gate
-- (the class is known by then) gives a Mage no UI and no commands.
WoW.reset()
WoW.class = "MAGE"
local realUnitClass = UnitClass
UnitClass = function() return nil end
ns = H.loadAddon({ beforeLogin = function() UnitClass = realUnitClass end })
H.eq(ns.skip, false, "loaded when the class wasn't known yet")
H.check(not ns.isWarlock, "the login gate sees a Mage")
H.check(ns.Bar.frame == nil, "no bar")
H.eq(SlashCmdList.ONETWOTHREE, nil, "no /123")

H.done("test_class_gate")
