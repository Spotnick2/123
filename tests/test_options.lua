-- Options page (#15), alert sounds (#14) and the minimap entry.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local ns = H.loadAddon()
local Options, Bar = ns.Options, ns.Bar

-- Registered in Options > AddOns, built on its first show.
H.check(Options.category ~= nil, "a Settings category is registered")
H.eq(Options.panel.name, "123", "listed as 123 under AddOns")
H.eq(#Options.panel._children, 0, "nothing built before the first show")
Options.panel:GetScript("OnShow")(Options.panel)
H.check(#Options.panel._children > 10, "built on the first show")

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
H.eq(labels:GetChecked(), false, "labels off by default")
labels:SetChecked(true)
click(labels)
H.eq(ns.db.barLabels, true, "the checkbox saves")

-- Hiding the bar is saved and applied.
local shown = find("Show the bar")
H.eq(shown:GetChecked(), true, "the bar shows by default")
shown:SetChecked(false)
click(shown)
H.eq(ns.db.bar.shown, false, "saved hidden")
H.check(not Bar.frame:IsShown(), "and hidden")
shown:SetChecked(true)
click(shown)
H.check(Bar.frame:IsShown(), "shown again")

-- /123 (and the minimap's shift-click) save the same value.
H.slash("ONETWOTHREE", "")
H.eq(ns.db.bar.shown, false, "the slash toggle is saved too")
H.slash("ONETWOTHREE", "")
H.eq(ns.db.bar.shown, true, "and back")

-- Scale steps by 0.05 within 0.6 .. 1.6.
local minus = find("-")
click(minus)
H.eq(Bar.frame:GetScale(), 0.95, "scale steps down")
H.eq(ns.db.bar.scale, 0.95, "and is saved")

-- In combat, a bar change is refused and the saved value kept.
WoW.enterCombat()
shown:SetChecked(false)
click(shown)
H.eq(ns.db.bar.shown, true, "refused in combat")
H.eq(shown:GetChecked(), true, "the checkbox goes back")
H.check(Bar.frame:IsShown(), "the bar stays")
H.check(H.messagesMatching("can't change in combat") > 0, "and says why")
WoW.leaveCombat()
WoW.runTimers(0)

-- Reset position.
ns.db.bar.point, ns.db.bar.x, ns.db.bar.y = "TOPLEFT", 50, -50
click(find("Reset position"))
H.eq(ns.db.bar.point, "CENTER", "back to the default point")
H.eq(ns.db.bar.y, -180, "and offset")

-- Alert sounds: picking one plays it.
local ping = find("Whisper")      -- the summon request's default
click(ping)
H.eq(ns.db.alerts.summonRequest, 880, "the next choice is saved")
H.eq(WoW.kits[#WoW.kits], 880, "and played")
WoW.refusedKits[8960] = true
click(ping)
H.eq(ns.db.alerts.summonRequest, 8960, "a refused kit can still be picked")
H.check(H.messagesMatching("didn't play that sound") > 0, "but the page says it didn't play")

-- Sound:Play: the chosen kit, throttled, off with alert sounds off.
ns.db.alerts.summonRequest = 3081
WoW.kits = {}
H.eq(ns.Sound:Play("summonRequest"), true, "an alert plays")
H.eq(WoW.kits[1], 3081, "its kit")
H.eq(ns.Sound:Play("summonRequest"), false, "a burst plays once")
WoW.time = WoW.time + 2
H.eq(ns.Sound:Play("summonRequest"), true, "plays again later")
WoW.time = WoW.time + 2
ns.db.alerts.summonRequest = 0
H.eq(ns.Sound:Play("summonRequest"), false, "None plays nothing")
ns.db.alerts.summonRequest = 3081
ns.db.alertSounds = false
H.eq(ns.Sound:Play("summonRequest"), false, "alert sounds off")
H.eq(#WoW.kits, 2, "two plays in all")

-- Every alert has a saved default among the choices.
for _, alert in ipairs(ns.Sound.ALERTS) do
    local found = false
    for _, c in ipairs(ns.Sound.CHOICES) do
        if c[1] == ns.Constants.DEFAULTS.alerts[alert.key] then found = true end
    end
    H.check(found, alert.key .. " defaults to a listed choice")
end

-- /123 options opens the page; not in combat.
H.slash("ONETWOTHREE", "options")
WoW.enterCombat()
H.slash("ONETWOTHREE", "options")
H.check(H.messagesMatching("can't open in combat") > 0, "options refuse combat")
WoW.leaveCombat()

-- The minimap libraries don't load in the stubs: no button, no error.
H.eq(ns.Minimap.icon, nil, "no LibDBIcon, no button")
ns.Minimap:RefreshVisibility()

-- A hidden bar stays hidden after a reload.
WoW.reset()
local saved = { bar = { shown = false, scale = 1.2 } }
ns = H.loadAddon({ savedDB = saved })
H.check(not ns.Bar.frame:IsShown(), "hidden after a reload")
H.eq(ns.Bar.frame:GetScale(), 1.2, "scaled after a reload")

H.done("test_options")
