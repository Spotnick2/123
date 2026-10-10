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
local function click(button, mouse) button:GetScript("PostClick")(button, mouse or "LeftButton", false) end
local function attr(node, k) return node.button:GetAttribute(k) end
local function openWheel() ns.Bar.wheelButton:GetScript("OnClick")() end

openWheel()
H.check(Wheel.open and Wheel.root:IsShown(), "the Demons button opens the wheel")

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
openWheel()

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

-- Voices: hovering or clicking a demon plays one of its lines, never the
-- same twice in a row, and a new one cuts the one playing.
local function voiced() return WoW.sounds[#WoW.sounds] end
local before = #WoW.sounds
succubus.button:GetScript("OnEnter")()
local first = voiced()
local lines = {}
for _, id in ipairs(ns.Data.VOICE[712]) do lines[id] = true end
H.eq(#WoW.sounds, before + 1, "hovering the Succubus speaks")
H.check(lines[first], "one of her summon lines (owner's file IDs)")
H.eq(WoW.soundChannels[#WoW.sounds], "Dialog", "on the Dialog channel")
succubus.button:GetScript("OnEnter")()
H.check(voiced() ~= first, "a different line the next time")
H.eq(WoW.stopped[#WoW.stopped], WoW.soundHandle - 1, "the previous line is cut")
ns.db.sounds = false
n[4].button:GetScript("OnEnter")()
H.eq(#WoW.sounds, before + 2, "/123 sounds off: silent")
ns.db.sounds = true
for _, entry in ipairs(ns.Data.WHEEL) do
    H.check(ns.Data.VOICE[entry.spell], "a voice for every bead: " .. entry.spell)
end

-- The centre: right-click Sacrifice (the Voidwalker's pet action).
local center = Wheel.center
H.eq(center:GetAttribute("type1"), nil, "a left click on the centre does nothing")
H.eq(center:GetAttribute("type2"), "pet", "right-click: the Voidwalker's Sacrifice")
H.eq(center:GetAttribute("action2"), 5, "on its pet bar slot")
center:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(), "Right-click: Sacrifice Voidwalker", "the hint says so")
center:GetScript("OnLeave")()

-- Only a click that cast something closes the wheel: a bead arms the left
-- button, and shift only with Fel Domination (not learned yet).
click(imp.button, "RightButton")
H.check(Wheel.open, "a right click on a bead casts nothing and keeps the wheel")
WoW.shiftDown = true
click(imp.button)
H.check(Wheel.open, "a bare shift-click casts nothing and keeps the wheel")
center:GetScript("PostClick")(center, "RightButton", false)
H.check(Wheel.open, "shift+right on the centre casts nothing either")
WoW.shiftDown = false

-- /123 confirm while the wheel is open: the active bead follows (Codex, #19).
H.eq(attr(void, "type1"), nil, "asking: the active bead casts nothing")
H.slash("ONETWOTHREE", "confirm")
WoW.runTimers(0)
H.eq(attr(void, "spell1"), 697, "confirmation off: the active bead summons at once")
H.check(not void.held, "and its PostClick won't ask")
H.slash("ONETWOTHREE", "confirm")
WoW.runTimers(0)
H.eq(attr(void, "type1"), nil, "back on: it asks again")
H.check(void.held, "both ways")

-- The re-summon question sits on the wheel's root: with the game UI hidden,
-- a prompt under UIParent would be hidden with it.
click(void.button)
H.eq(ns.Resummon.frame:GetParent(), Wheel.root, "the question is parented to the wheel")
ns.Resummon.cancel:GetScript("OnClick")()
H.check(Wheel.open, "Cancel keeps the wheel open")

-- A cast speaks and closes the wheel; the demon picked is remembered.
before = #WoW.sounds
click(imp.button)
H.eq(ns.char.demon, 688, "the Imp picked on the wheel is the Demon button's now")
H.eq(#WoW.sounds, before + 1, "clicking the Imp speaks")
H.check(not Wheel.open and not imp.button:IsMouseEnabled(), "summoning closes input immediately")
WoW.tick(0.31)
H.check(not Wheel.root:IsShown(), "the visual close finishes")

-- Fel Domination, Demonic Sacrifice and Inferno, once learned.
WoW.spells[18708].known = true
WoW.spells[18788].known = true
WoW.spells[1122].known = true
WoW.spellDescriptions[18788] = "When activated, sacrifices your summoned Demon.\n\n"
    .. "Imp: Increases your Shadow damage by 15%.\n\nVoidwalker: Restores 2% of your total Mana every 4 sec."
openWheel()
H.eq(attr(imp, "shift-type1"), "macro", "shift-click: a macro")
H.eq(attr(imp, "shift-macrotext1"), "/cast Fel Domination\n/cast Summon Imp", "Fel Domination, then the summon")
H.eq(attr(imp, "spell1"), 688, "a plain click still just summons")
H.eq(center:GetAttribute("spell2"), 18788, "the talent replaces the pet action")
center:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(),
    "Right-click: Demonic Sacrifice - Voidwalker: Restores 2% of your total Mana every 4 sec.",
    "with the active demon's effect, read from the client")
-- The effect line is matched on the names before its colon, whole.
WoW.spellDescriptions[18788] = "Improved: not this one.\n\nImp: Increases your Shadow damage by 15%.\n\n"
    .. "Succubus/Incubus: Increases your Fire damage by 15%."
WoW.petGUID = "Pet-0-4613-0-1234-416-0000ABCDEF"
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
center:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(), "Right-click: Demonic Sacrifice - Imp: Increases your Shadow damage by 15%.",
    "Imp's line, not 'Improved'")
WoW.petGUID = "Pet-0-4613-0-1234-185317-0000ABCDEF"
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
center:GetScript("OnEnter")()
H.eq(Wheel.strip.hint:GetText(), "Right-click: Demonic Sacrifice - Succubus/Incubus: Increases your Fire damage by 15%.",
    "the Incubus in a shared line")
center:GetScript("OnLeave")()
WoW.petGUID = "Pet-0-4613-0-1234-1860-0000ABCDEF"
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
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

-- Two thirds of the way across the screen.
local pt = Wheel.root._points[#Wheel.root._points]
H.eq(pt[1], "CENTER", "anchored on its centre")
H.check(math.abs(pt[4] - UIParent:GetWidth() / 6) < 1e-6, "a sixth of the screen right of centre: two thirds across")

-- A model can't be masked: its square sits inside the bead, under the
-- ring, and only the ring's hole (its inscribed circle) shows it.
local bead, side = imp.button:GetWidth(), imp.portrait.model:GetWidth()
local outer, hole = bead / 2 * 63 / 64, bead / 2 * 0.70 * 63 / 64
H.check(side * math.sqrt(2) / 2 <= outer, "the model's corners stay inside the bead")
H.check(side / 2 >= hole - 0.5, "and its square covers the ring's hole")

-- Portraits: each bead's PlayerModel shows its creature through the
-- portrait camera. The stub client loads no model file: the icon, in time.
local m = imp.portrait.model
H.eq(m._creature, 416, "the Imp's bead shows the Imp (npc 416)")
H.eq(inferno.portrait.model._creature, 89, "Inferno's bead shows the Infernal (npc 89), not a stale display")
H.eq(n[4].portrait.model._creature, 11859, "the Doomguard's bead shows the Doomguard")
H.eq(m._zoom, 1, "through the portrait camera")
H.check(not imp.icon:IsShown(), "the icon waits for the model")
for _ = 1, 20 do WoW.runTimers(0.1) end
H.check(imp.icon:IsShown() and not m:IsShown(), "no model file in time: the icon")
H.eq(succubus.portrait.model._desat, 1, "a demon not learned is greyed")

-- Closed, the wheel's buttons are left alone by the coalesced sync.
Wheel:Close()
local writes = 0
local orig = imp.button.SetAttribute
imp.button.SetAttribute = function(self, k, v) writes = writes + 1 return orig(self, k, v) end
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(writes, 0, "no attribute work while the wheel is closed")
imp.button.SetAttribute = orig
openWheel()

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
openWheel()
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
