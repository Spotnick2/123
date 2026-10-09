-- Any other class gets no UI and no commands.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.class = "MAGE"
local ns = H.loadAddon()
H.check(not ns.isWarlock, "a Mage is not a Warlock")
H.check(ns.Bar.frame == nil, "no bar for a Mage")
H.check(SlashCmdList.ONETWOTHREE == nil, "no /123 for a Mage")
H.check(type(OneTwoThreeDB) == "table", "the saved table still initialises")

H.done("test_class_gate")
