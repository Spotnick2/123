-- Loading: the Warlock gate, the saved table, the slash commands.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- A Warlock gets the bar and the commands.
local ns = H.loadAddon({ savedDB = { loadCount = 2, bar = { point = "TOP", x = 5, y = -40 } } })
H.check(ns.isWarlock, "a Warlock is recognised")
H.check(ns.Bar.frame and ns.Bar.frame:IsShown(), "the bar shows")
H.eq(ns.Bar.label:GetText(), "123", "the bar reads 123")
H.eq(OneTwoThreeDB.version, ns.Constants.VERSION, "the saved table is stamped")
H.eq(OneTwoThreeDB.loadCount, 3, "loadCount counts loads")
H.eq(OneTwoThreeDB.bar.point, "TOP", "a saved position survives the defaults merge")
H.eq(SLASH_ONETWOTHREE1, "/123", "/123 is registered")
H.eq(SLASH_ONETWOTHREE2, "/onetwothree", "/onetwothree is registered")
H.slash("ONETWOTHREE", "")
H.check(not ns.Bar.frame:IsShown(), "/123 hides the bar")
OneTwoThree_Toggle()
H.check(ns.Bar.frame:IsShown(), "the key binding shows it again")
H.slash("ONETWOTHREE", "debug")
H.check(H.messagesMatching("build 70205") > 0, "/123 debug prints the build")
H.check(H.messagesMatching("glass=fallback") > 0, "/123 debug names the glass in use")

-- Secrets are never compared.
H.eq(ns.API.Number(WoW.Secret(5)), nil, "a secret is not a number")
H.eq(ns.API.Number(7), 7, "a plain number passes")

H.done("test_core")
