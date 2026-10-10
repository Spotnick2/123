-- The demon wheel (#4): which demon each slot summons, the Sacrifice pill,
-- Fel Domination on shift, and closing (click, Escape, combat). Then, with
-- the real LibShowcase ($LIBSHOWCASE or ../LibShowcase), the presentation.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local root = os.getenv("LIBSHOWCASE") or "../LibShowcase"
local libFile = root .. "/LibShowcase.lua"
local haveLib = io.open(libFile) ~= nil

WoW.spells[688] = { name = "Summon Imp", known = true }
WoW.spells[697] = { name = "Summon Voidwalker", known = true }
WoW.spells[712] = { name = "Summon Succubus", known = false }
WoW.spells[691] = { name = "Summon Felhunter", known = false }
WoW.spells[7812] = { name = "Sacrifice", known = false }
WoW.spells[18708] = { name = "Fel Domination", known = false }
WoW.spells[18788] = { name = "Demonic Sacrifice", known = false }
-- The Voidwalker is out (GUID as measured in run 2), Sacrifice on its bar.
WoW.petGUID = "Pet-0-4613-0-1234-1860-0000ABCDEF"
WoW.petActions[5] = { name = "Sacrifice", spellID = 7812 }

local ns = H.loadAddon(haveLib and { libs = { libFile } } or nil)
local Wheel = ns.Wheel
local demonButton = ns.Bar.buttons[1]
local function click(button, mouse) button:GetScript("PostClick")(button, mouse or "LeftButton", false) end

click(demonButton)
H.check(Wheel.open and Wheel.root:IsShown(), "the Demon button's left click opens the wheel")

local n = Wheel.nodes
local function attr(node, k) return node.button:GetAttribute(k) end
H.eq(attr(n[1], "spell1"), 688, "12 o'clock: the Imp")
H.eq(n[2].spellID, 712, "9 o'clock: the Succubus")
H.eq(attr(n[2], "type1"), nil, "not learned: no action")
H.check(n[2].icon:IsDesaturated(), "and greyed out")
H.eq(n[3].spellID, 691, "3 o'clock: the Felhunter")
H.check(not n[4].button:IsShown(), "the Voidwalker is out: no fourth slot")
H.eq(Wheel.centerName:GetText(), "Voidwalker", "the active demon in the centre")
H.eq(attr(n[1], "shift-type1"), nil, "no Fel Domination before it is learned")

local sac = Wheel.sacrifice
H.check(sac.button:IsShown(), "the Sacrifice pill shows")
H.eq(sac.button:GetAttribute("type1"), "pet", "the Voidwalker's Sacrifice is a pet action")
H.eq(sac.button:GetAttribute("action1"), 5, "on the pet bar slot that holds it")
H.eq(sac.label:GetText(), "Sacrifice Voidwalker", "and says so")

-- A click on a demon closes the wheel once the secure action has run.
click(n[1].button)
H.check(not Wheel.open and not Wheel.root:IsShown(), "summoning closes the wheel")

-- Fel Domination and Demonic Sacrifice, once learned.
WoW.spells[18708].known = true
WoW.spells[18788].known = true
WoW.spellDescriptions[18788] = "When activated, sacrifices your summoned Demon.\n\n"
    .. "Imp: Increases your Shadow damage by 15%.\n\nVoidwalker: Restores 2% of your total Mana every 4 sec."
click(demonButton)
H.eq(attr(n[1], "shift-type1"), "macro", "shift-click: a macro")
H.eq(attr(n[1], "shift-macrotext1"), "/cast Fel Domination\n/cast Summon Imp", "Fel Domination, then the summon")
H.eq(attr(n[1], "spell1"), 688, "a plain click still just summons")
H.eq(sac.button:GetAttribute("spell1"), 18788, "the talent replaces the pet action")
H.eq(sac.effect:GetText(), "Voidwalker: Restores 2% of your total Mana every 4 sec.",
    "with the active demon's effect, read from the client")

-- Escape (the proxy in UISpecialFrames) closes it.
H.check(Wheel.escape:IsShown() or ns.Presentation:IsGameUIHidden(), "Escape is armed")
local found = false
for _, name in ipairs(UISpecialFrames) do found = found or name == "OneTwoThreeWheelEscape" end
H.check(found, "the proxy is a special frame")
if Wheel.escape:IsShown() then
    Wheel.escape:Hide()
    H.check(not Wheel.open, "Escape closes the wheel")
else
    Wheel:Close()
end

-- No demon out: four demons around an empty centre, no Sacrifice.
WoW.petGUID = nil
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
click(demonButton)
H.eq(n[1].spellID, 688, "12: Imp"); H.eq(n[2].spellID, 697, "9: Voidwalker")
H.eq(n[3].spellID, 712, "3: Succubus"); H.eq(n[4].spellID, 691, "6: Felhunter")
H.check(n[4].button:IsShown(), "all four slots")
H.eq(Wheel.centerName:GetText(), "No demon", "an empty centre")
H.check(not sac.button:IsShown(), "no Sacrifice without a demon")

-- A demon arriving while it is open: re-resolved at once.
WoW.petGUID = "Pet-0-4613-0-1234-416-0000ABCDEF"
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
H.eq(Wheel.centerName:GetText(), "Imp", "the Imp in the centre")
H.eq(n[1].spellID, 697, "12: the Voidwalker now")

-- Combat closes it at once (still unlocked in PLAYER_REGEN_DISABLED).
WoW.blocked = {}
WoW.enterCombat()
H.check(not Wheel.open and not Wheel.root:IsShown(), "combat closes the wheel")
H.eq(#WoW.blocked, 0, "nothing protected was blocked: " .. table.concat(WoW.blocked, ", "))
if haveLib then
    H.eq(WoW.uiVisible, true, "the game UI is back at combat entry")
end
Wheel:Open()
H.check(not Wheel.open, "it does not open in combat")
H.check(H.messagesMatching("can't open in combat") > 0, "and says why")
WoW.leaveCombat()
WoW.runTimers(1)

-- With the real LibShowcase: opening hides the game UI and lifts the root.
if haveLib then
    H.check(ns.Presentation:Lib() ~= nil, "LibShowcase r3+ is picked up")
    H.slash("ONETWOTHREE", "wheel")
    H.check(Wheel.open, "/123 wheel opens it")
    H.eq(WoW.uiVisible, false, "the game UI is hidden")
    H.eq(Wheel.root:GetParent(), nil, "the root is lifted out of UIParent")
    H.slash("ONETWOTHREE", "wheel")
    WoW.runTimers(5)
    H.check(not Wheel.open, "and closes it")
    H.eq(WoW.uiVisible, true, "the game UI is back")
    H.eq(Wheel.root:GetParent(), UIParent, "the root is back under UIParent")
else
    io.write("test_wheel: LibShowcase part skipped (no checkout at " .. root .. ")\n")
end

H.done("test_wheel")
