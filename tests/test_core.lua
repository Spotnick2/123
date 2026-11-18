-- Loading: the Warlock gate, the saved table, the slash commands.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- A Warlock gets the bar and the commands.
local ns = H.loadAddon({ savedDB = { loadCount = 2, bar = { point = "TOP", x = 5, y = -40 } } })
check(ns.isWarlock, "a Warlock is recognised")
check(ns.Bar.frame and ns.Bar.frame:IsShown(), "the bar shows")
eq(ns.Bar.label:GetText(), "123", "the bar reads 123")
eq(OneTwoThreeDB.version, ns.Constants.VERSION, "the saved table is stamped")
eq(OneTwoThreeDB.loadCount, 3, "loadCount counts loads")
eq(OneTwoThreeDB.bar.point, "TOP", "a saved position survives the defaults merge")
eq(SLASH_ONETWOTHREE1, "/123", "/123 is registered")
eq(SLASH_ONETWOTHREE2, "/onetwothree", "/onetwothree is registered")
H.slash("ONETWOTHREE", "")
check(not ns.Bar.frame:IsShown(), "/123 hides the bar")
OneTwoThree_Toggle()
check(ns.Bar.frame:IsShown(), "the key binding shows it again")
H.slash("ONETWOTHREE", "debug")
check(H.messagesMatching("build 70205") > 0, "/123 debug prints the build")
check(H.messagesMatching("glass=fallback") > 0, "/123 debug names the glass in use")

-- Secrets are never compared.
eq(ns.API.Number(WoW.Secret("a number")), nil, "a secret is not a number")
eq(ns.API.Number(7), 7, "a plain number passes")

done("test_core")
