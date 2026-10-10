-- The demon wheel (#4, "Fel concept"): seven beads, the active demon in the
-- centre and marked on its bead, Sacrifice on the centre's right click, Fel
-- Domination on shift, reagents, the hint strip, and closing (a cast,
-- Escape, combat). Then, with the real LibShowcase ($LIBSHOWCASE or
-- ../LibShowcase), the presentation.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local root = os.getenv("LIBSHOWCASE") or "../LibShowcase"
local libFile = root .. "/LibShowcase.lua"
local haveLib = io.open(libFile) ~= nil

WoW.spells[688] = { name = "Summon Imp", known = true }
WoW.spells[697] = { name = "Summon Voidwalker", known = true }
WoW.spells[712] = { name = "Summon Succubus", known = false }
WoW.spells[691] = { name = "Summon Felhunter", known = false }
WoW.spells[713] = { name = "Summon Incubus", known = false }
WoW.spells[1122] = { name = "Inferno", known = false }
WoW.spells[18540] = { name = "Ritual of Doom", known = false }
WoW.spells[7812] = { name = "Sacrifice", known = false }
WoW.spells[18708] = { name = "Fel Domination", known = false }
WoW.spells[18788] = { name = "Demonic Sacrifice", known = false }
WoW.items[5565] = "Infernal Stone"
WoW.items[6265] = "Soul Shard"
WoW.counts[6265] = 3
-- The Voidwalker is out (GUID as measured in run 2), Sacrifice on its bar.
WoW.petGUID = "Pet-0-4613-0-1234-1860-0000ABCDEF"
WoW.petActions[5] = { name = "Sacrifice", spellID = 7812 }

local ns = H.loadAddon(haveLib and { libs = { libFile } } or nil)
local Wheel = ns.Wheel
local demonButton = ns.Bar.buttons[1]
local function click(button, mouse) button:GetScript("PostClick")(button, mouse or "LeftButton", false) end
local function attr(node, k) return node.button:GetAttribute(k) end

click(demonButton)
H.check(Wheel.open and Wheel.root:IsShown(), "the Demon button's left click opens the wheel")

-- Seven beads, clockwise from 12, as in the mockup.
local n = Wheel.nodes
local order = { 697, 691, 1122, 18540, 688, 712, 713 }
H.eq(#n, 7, "seven beads")
for i, spellID in ipairs(order) do H.eq(n[i].spellID, spellID, "bead " .. i) end
local void, inferno, imp, succubus, incubus = n[1], n[3], n[5], n[6], n[7]
H.eq(n[4].label:GetText(), "Doomguard", "Ritual of Doom's bead is the Doomguard")
H.eq(imp.label:GetText(), "Imp", "the others by their summon")

-- The active demon: the centre, and its bead marked; a click there asks.
H.eq(Wheel.centerName:GetText(), "Voidwalker", "the Voidwalker in the centre")
H.check(Wheel.centerState:GetText():find("Active"), "marked active")
H.check(void.isActive and void.sub:GetText():find("Active"), "its bead too")
H.eq(attr(void, "type1"), nil, "its bead casts nothing: it asks first")
click(void.button)
H.check(ns.Resummon:IsShown(), "the re-summon question")
H.eq(ns.Resummon.summon:GetAttribute("spell1"), 697, "armed with the Voidwalker")
ns.Resummon.summon:GetScript("PostClick")(ns.Resummon.summon, "LeftButton", false)
H.check(not Wheel.open, "Summon there closes the wheel too")
click(demonButton)

-- Learned and not.
H.eq(attr(imp, "spell1"), 688, "the Imp is armed")
H.eq(attr(succubus, "type1"), nil, "not learned: no action")
H.check(succubus.icon:IsDesaturated(), "and greyed out")
H.eq(succubus.sub:GetText(), "Not learned", "and says so")
H.eq(attr(imp, "shift-type1"), nil, "no Fel Domination before it is learned")

-- The hint strip: shards, and what the hovered bead does.
H.eq(Wheel.strip.shards:GetText(), 3, "soul shards in the strip")
H.eq(Wheel.strip.hint:GetText(), "Select a demon to summon", "the resting hint")
imp.button:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(), "Click: Summon Imp", "hovering a bead says what it does")
imp.button:GetScript("OnLeave")()
H.eq(Wheel.strip.hint:GetText(), "Select a demon to summon", "and back")

-- The centre: right-click Sacrifice (the Voidwalker's pet action).
local center = Wheel.center
H.eq(center:GetAttribute("type1"), nil, "a left click on the centre does nothing")
H.eq(center:GetAttribute("type2"), "pet", "right-click: the Voidwalker's Sacrifice")
H.eq(center:GetAttribute("action2"), 5, "on its pet bar slot")
center:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(), "Right-click: Sacrifice Voidwalker", "the hint says so")
center:GetScript("OnLeave")()

-- A cast closes the wheel.
click(imp.button)
H.check(not Wheel.open and not Wheel.root:IsShown(), "summoning closes the wheel")

-- Fel Domination, Demonic Sacrifice and Inferno, once learned.
WoW.spells[18708].known = true
WoW.spells[18788].known = true
WoW.spells[1122].known = true
WoW.spellDescriptions[18788] = "When activated, sacrifices your summoned Demon.\n\n"
    .. "Imp: Increases your Shadow damage by 15%.\n\nVoidwalker: Restores 2% of your total Mana every 4 sec."
click(demonButton)
H.eq(attr(imp, "shift-type1"), "macro", "shift-click: a macro")
H.eq(attr(imp, "shift-macrotext1"), "/cast Fel Domination\n/cast Summon Imp", "Fel Domination, then the summon")
H.eq(attr(imp, "spell1"), 688, "a plain click still just summons")
H.eq(center:GetAttribute("spell2"), 18788, "the talent replaces the pet action")
center:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(),
    "Right-click: Demonic Sacrifice - Voidwalker: Restores 2% of your total Mana every 4 sec.",
    "with the active demon's effect, read from the client")
center:GetScript("OnLeave")()
H.eq(attr(inferno, "spell1"), 1122, "Inferno is armed once learned")
H.eq(attr(inferno, "shift-type1"), nil, "no Fel Domination for Inferno")
H.eq(inferno.count:GetText(), 0, "its Infernal Stones counted")
H.eq(inferno.sub:GetText(), "|cffff6060No Infernal Stone|r", "and the missing one named")
WoW.counts[5565] = 2
WoW.fire("BAG_UPDATE_DELAYED")
H.eq(inferno.count:GetText(), 2, "the count follows the bags")
H.eq(inferno.sub:GetText(), "", "nothing missing")
H.eq(imp.count:GetText(), "", "no count on a pet's bead (shards are in the strip)")

-- Reagent Economy: vendor reagents are free; Soul Shards are not.
WoW.counts[5565] = 0
WoW.spells[1262650] = { name = "Reagent Economy", known = true }
WoW.fire("BAG_UPDATE_DELAYED")
H.eq(inferno.count:GetText(), "", "no Infernal Stone count with Reagent Economy")
H.eq(inferno.sub:GetText(), "", "and nothing missing")
WoW.spells[1262650] = nil

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

-- No demon out: an empty centre, no Sacrifice, no bead active.
WoW.petGUID = nil
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
click(demonButton)
H.eq(Wheel.centerName:GetText(), "No demon", "an empty centre")
H.eq(center:GetAttribute("type2"), nil, "no Sacrifice without a demon")
H.eq(attr(void, "spell1"), 697, "the Voidwalker can be summoned again")
H.eq(void.sub:GetText(), "", "and has its shard")
WoW.counts[6265] = 0
WoW.fire("BAG_UPDATE_DELAYED")
H.eq(void.sub:GetText(), "|cffff6060No Soul Shard|r", "a learned demon without a shard says so")

-- Forever's Incubus out (NPC 185317, from Wowhead's Forever database).
WoW.petGUID = "Pet-0-4613-0-1234-185317-0000ABCDEF"
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
H.eq(Wheel.centerName:GetText(), "Incubus", "the Incubus in the centre")
H.check(incubus.isActive, "its bead marked")
H.eq(ns.char.demon, 713, "and remembered for the Demon button")

-- An Infernal out: named by its family, no bead active, no Sacrifice, and
-- never the Demon button's demon.
WoW.petGUID = "Pet-0-4613-0-1234-89-0000ABCDEF"
WoW.petFamily = { "Infernal", 0 }
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
H.eq(Wheel.centerName:GetText(), "Infernal", "the Infernal in the centre")
H.eq(center:GetAttribute("type2"), nil, "no Sacrifice for an Infernal")
local anyActive = false
for _, node in ipairs(n) do anyActive = anyActive or node.isActive end
H.check(not anyActive, "no bead active")
H.eq(ns.char.demon, 713, "the Demon button keeps its demon")
WoW.petFamily = nil

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
