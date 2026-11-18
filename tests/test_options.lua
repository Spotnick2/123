-- Options page (#15), alert sounds (#14) and the minimap entry.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local ns = H.loadAddon()
local Options, Bar = ns.Options, ns.Bar

-- Registered in Options > AddOns, built on its first show.
check(Options.category ~= nil, "a Settings category is registered")
eq(Options.panel.name, "123", "listed as 123 under AddOns")
eq(#Options.panel._children, 0, "nothing built before the first show")
Options.panel:GetScript("OnShow")(Options.panel)
check(#Options.panel._children > 10, "built on the first show")

-- The page's widgets, by their text.
local function find(text)
    for _, c in ipairs(Options.panel._children) do
        if (c.label and c.label:GetText() == text) or c:GetText() == text then return c end
    end
    error("no control " .. text)
end
local function click(c) c:GetScript("OnClick")(c) end

-- A checkbox shows the saved value and writes it.
local labels = find("Names under the icons")
eq(labels:GetChecked(), false, "labels off by default")
labels:SetChecked(true)
click(labels)
eq(ns.db.barLabels, true, "the checkbox saves")

-- Hiding the bar is saved and applied.
local shown = find("Show the bar")
eq(shown:GetChecked(), true, "the bar shows by default")
shown:SetChecked(false)
click(shown)
eq(ns.db.bar.shown, false, "saved hidden")
check(not Bar.frame:IsShown(), "and hidden")
shown:SetChecked(true)
click(shown)
check(Bar.frame:IsShown(), "shown again")

-- /123 (and the minimap's shift-click) save the same value.
H.slash("ONETWOTHREE", "")
eq(ns.db.bar.shown, false, "the slash toggle is saved too")
H.slash("ONETWOTHREE", "")
eq(ns.db.bar.shown, true, "and back")

-- Scale steps by 0.05 within 0.6 .. 1.6.
local minus = find("-")
click(minus)
eq(Bar.frame:GetScale(), 0.95, "scale steps down")
eq(ns.db.bar.scale, 0.95, "and is saved")

-- In combat, a bar change is refused and the saved value kept.
WoW.enterCombat()
shown:SetChecked(false)
click(shown)
eq(ns.db.bar.shown, true, "refused in combat")
eq(shown:GetChecked(), true, "the checkbox goes back")
check(Bar.frame:IsShown(), "the bar stays")
check(H.messagesMatching("can't change in combat") > 0, "and says why")
WoW.leaveCombat()
WoW.advance(0)

-- Reset position.
ns.db.bar.point, ns.db.bar.x, ns.db.bar.y = "TOPLEFT", 50, -50
click(find("Reset position"))
eq(ns.db.bar.point, "CENTER", "back to the default point")
eq(ns.db.bar.y, -180, "and offset")

-- Alert sounds: picking one plays it.
local ping = find("Whisper")      -- the summon request's default
click(ping)
eq(ns.db.alerts.summonRequest, 880, "the next choice is saved")
eq(WoW.kits[#WoW.kits], 880, "and played")
WoW.refusedKits[8960] = true
click(ping)
eq(ns.db.alerts.summonRequest, 8960, "a refused kit can still be picked")
check(H.messagesMatching("didn't play that sound") > 0, "but the page says it didn't play")

-- Sound:Play: the chosen kit, throttled, off with alert sounds off.
ns.db.alerts.summonRequest = 3081
WoW.kits = {}
eq(ns.Sound:Play("summonRequest"), true, "an alert plays")
eq(WoW.kits[1], 3081, "its kit")
eq(ns.Sound:Play("summonRequest"), false, "a burst plays once")
WoW.now = WoW.now + 2
eq(ns.Sound:Play("summonRequest"), true, "plays again later")
WoW.now = WoW.now + 2
ns.db.alerts.summonRequest = 0
eq(ns.Sound:Play("summonRequest"), false, "None plays nothing")
ns.db.alerts.summonRequest = 3081
ns.db.alertSounds = false
eq(ns.Sound:Play("summonRequest"), false, "alert sounds off")
eq(#WoW.kits, 2, "two plays in all")

-- Every alert has a saved default among the choices.
for _, alert in ipairs(ns.Sound.ALERTS) do
    local found = false
    for _, c in ipairs(ns.Sound.CHOICES) do
        if c[1] == ns.Constants.DEFAULTS.alerts[alert.key] then found = true end
    end
    check(found, alert.key .. " defaults to a listed choice")
end

-- Announcements (#11): the summon line on, the clickers line off; each text
-- box shows its default and saves the player's own; the default, or a
-- blank box, saves as blank (the default in the client's language).
local announce = find("Announce the summon in group chat")
eq(announce:GetChecked(), true, "the summon line is on by default")
eq(find("Ask for clickers when fewer than 2 are near"):GetChecked(), false, "the clickers line is off")
local box = find("Summoning {name}, please click the portal")
box:SetText("Portal for {name}!")
box.save()
eq(ns.db.announce.summonText, "Portal for {name}!", "a text of the player's own is saved")
box:SetText("   ")
box.save()
eq(ns.db.announce.summonText, "", "a blank box saves as the default")
eq(box:GetText(), "Summoning {name}, please click the portal", "and shows it")

-- /123 options opens the page; not in combat.
H.slash("ONETWOTHREE", "options")
WoW.enterCombat()
H.slash("ONETWOTHREE", "options")
check(H.messagesMatching("can't open in combat") > 0, "options refuse combat")
WoW.leaveCombat()

-- The minimap libraries don't load in the stubs: no button, no error.
eq(ns.Minimap.icon, nil, "no LibDBIcon, no button")
ns.Minimap:RefreshVisibility()

-- A hidden bar stays hidden after a reload.
WoW.reset()
local saved = { bar = { shown = false, scale = 1.2 } }
ns = H.loadAddon({ savedDB = saved })
check(not ns.Bar.frame:IsShown(), "hidden after a reload")
eq(ns.Bar.frame:GetScale(), 1.2, "scaled after a reload")
done("test_options")
