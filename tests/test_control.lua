-- Banish and Subjugate Demon (#29): two bar buttons shown once learned; a
-- Banish counts down from its cast and glows its last seconds; the
-- subjugated demon is recognised, can be dismissed with a right click, and
-- breaking free is told apart from a dismissal or a death.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.counts[6265] = 3
local ns = H.loadAddon()
local Bar, Control = ns.Bar, ns.Control
local banish, subjugate = Bar:Button("banish"), Bar:Button("subjugate")
local IMP_PET = "Pet-0-4613-0-1234-416-0000ABCDEF"
local MOB = "Creature-0-4613-0-1234-7136-0000FEDCBA"   -- a demon mob

local function learn(id, name)
    WoW.spells[id] = { name = name, known = true }
    WoW.fire("SPELLS_CHANGED")
    WoW.advance(0)
end
local function cast(spellID, n)
    local guid = "Cast-3-0-0-" .. spellID .. "-" .. n
    WoW.fire("UNIT_SPELLCAST_SENT", "player", "Some Demon", guid, spellID)
    WoW.targetGUID = nil   -- the target may change before the cast lands
    WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
end
local function pet(guid)
    WoW.petGUID = guid
    WoW.fire("UNIT_PET", "player")
end
local function tooltip(b)
    b:GetScript("OnEnter")(b)
    return table.concat(GameTooltip._lines, "\n")
end

-- Hidden until learned; once learned, placed after Summoning, the bar wider.
local width = Bar.frame:GetWidth()
check(not banish:IsShown() and not subjugate:IsShown(), "neither shown before it is learned")
learn(710, "Banish")
check(banish:IsShown(), "Banish learned: shown")
eq(banish:GetAttribute("spell1"), 710, "it casts Banish, on the target")
eq(banish:GetAttribute("unit1"), nil, "no unit token: the target")
eq(Bar.frame:GetWidth(), width + 60, "the bar grows a slot")
local x = banish._points[1] and banish._points[1][4]
local sx = Bar:Button("summoning")._points[1][4]
eq(x, sx + 60, "right after Summoning")
learn(18647, "Banish")
eq(banish:GetAttribute("spell1"), 18647, "the best rank known")

-- A Banish: the countdown from the cast, on the target read when it was sent.
WoW.targetGUID = MOB
cast(18647, 1)
eq(Control.banish.guid, MOB, "on the target read at SENT")
eq(banish.timer:GetText(), "30", "30 seconds for rank 2")
eq(banish.cooldown._cooldown and banish.cooldown._cooldown[2], 30, "and the swipe")
check(tooltip(banish):find("Banished: 30 left", 1, true) ~= nil, "the tooltip says how long")
check(tooltip(banish):find("can't be seen", 1, true) ~= nil, "and that it is an estimate")
WoW.advance(20)
eq(banish.timer:GetText(), "10", "ten seconds left")
eq(banish.barState, "normal", "no glow yet")
WoW.advance(5.2)
eq(banish.barState, "ending", "the last five seconds glow, to re-banish on time")
check(banish.glow:IsShown(), "the glow shows")
-- A recast restarts it.
WoW.targetGUID = MOB
cast(18647, 2)
eq(banish.timer:GetText(), "30", "a recast restarts it")
eq(banish.barState, "normal", "and the glow goes")
-- The target dies: it ends.
WoW.fire("UNIT_DIED", MOB)
WoW.advance(0)
eq(banish.timer:GetText(), "", "the banished target died: the countdown ends")
-- Or it runs out.
WoW.targetGUID = MOB
cast(710, 3)
eq(banish.timer:GetText(), "20", "20 seconds for rank 1")
WoW.advance(20.2)
eq(Control.banish, nil, "ran out")
eq(banish.timer:GetText(), "", "the text goes")

-- Subjugate Demon: learned, a right click to dismiss.
learn(1098, "Subjugate Demon")
check(subjugate:IsShown(), "Subjugate learned: shown")
eq(Bar.frame:GetWidth(), width + 120, "a second slot")
eq(subjugate:GetAttribute("spell1"), 1098, "it casts Subjugate Demon")
eq(subjugate:GetAttribute("type2"), "macro", "the right click is a macro")
local macro = subjugate:GetAttribute("macrotext2")
eq(macro, "/stopmacro [nopet][pet:Imp/Voidwalker/Succubus/Incubus/Felhunter]\n/petdismiss",
    "it dismisses any pet but the Warlock's own demons")
check(tooltip(subjugate):find("Right-click: dismiss the subjugated demon", 1, true) ~= nil, "the tooltip says so")
WoW.counts[6265] = 0
WoW.fire("BAG_UPDATE_DELAYED")
WoW.advance(0)
check(subjugate.icon:IsDesaturated(), "no Soul Shard: greyed")
WoW.counts[6265] = 3
WoW.fire("BAG_UPDATE_DELAYED")
WoW.advance(0)

-- The subjugated demon: the pet that comes out right after the cast.
WoW.targetGUID = MOB
cast(1098, 4)
pet(MOB)
eq(Control.enslaved and Control.enslaved.guid, MOB, "the new pet is the subjugated demon")
eq(subjugate.timer:GetText(), "5m", "five minutes at most")
check(tooltip(subjugate):find("Subjugated: 5m left at most", 1, true) ~= nil, "the tooltip says so")

-- It breaks free: the pet goes with no dismissal and no death.
WoW.chat, WoW.kits = {}, {}
pet(nil)
eq(Control.brokenAt, nil, "judged a moment later")
WoW.advance(0.5)
check(H.messagesMatching("broke free: it's hostile again") > 0, "a chat line")
eq(#WoW.kits, 1, "a sound")
eq(subjugate.barState, "broken", "a red glow")
eq(subjugate.timer:GetText(), "", "the countdown ends")
WoW.advance(10.2)
eq(subjugate.barState, "normal", "the glow fades after ten seconds")

-- Dismissed: no alert.
cast(1098, 5)
pet(MOB)
WoW.chat = {}
WoW.fire("PET_DISMISS_START", 0)
pet(nil)
WoW.advance(0.5)
eq(H.messagesMatching("broke free"), 0, "dismissed: no alert")
eq(Control.brokenAt, nil, "no glow")

-- Died: no alert, whichever event comes first.
cast(1098, 6)
pet(MOB)
pet(nil)
WoW.fire("UNIT_DIED", MOB)
WoW.advance(0.5)
eq(H.messagesMatching("broke free"), 0, "died: no alert")

-- A second Subjugate replaces the first: the new demon and its countdown
-- are kept, and the first going is no break (the player's own doing).
local MOB2 = "Creature-0-4613-0-1234-7136-0000FEDCBB"
cast(1098, 61)
pet(MOB)
WoW.advance(60)
cast(1098, 62)
local second = Control.subjugate
pet(MOB2)
eq(Control.enslaved and Control.enslaved.guid, MOB2, "the replacement is the subjugated demon now")
WoW.advance(0.5)
eq(Control.subjugate, second, "judging the first leaves the second cast's countdown")
eq(subjugate.timer:GetText(), "5m", "still counting from the second cast")
eq(H.messagesMatching("broke free"), 0, "replaced: no alert")
-- And the second still breaks free like any other.
pet(nil)
WoW.advance(0.5)
check(H.messagesMatching("broke free") > 0, "the replacement breaking free alerts")
WoW.advance(10.2)
WoW.chat = {}
-- UNIT_PET before the cast's success: same outcome.
cast(1098, 63)
pet(MOB)
WoW.advance(60)
WoW.fire("UNIT_SPELLCAST_SENT", "player", "Some Demon", "Cast-3-0-0-1098-64", 1098)
pet(MOB2)
eq(Control.enslaved, nil, "the new pet before the success: not yet the subjugated one")
WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-0-0-1098-64", 1098)
eq(Control.enslaved and Control.enslaved.guid, MOB2, "either order: the replacement is followed")
WoW.advance(0.5)
check(Control.subjugate ~= nil, "and its countdown kept")
eq(H.messagesMatching("broke free"), 0, "and no alert")
WoW.fire("PET_DISMISS_START", 0)
pet(nil)
WoW.advance(0.5)

-- One of the Warlock's own demons after the cast isn't subjugated.
cast(1098, 7)
pet(IMP_PET)
eq(Control.enslaved, nil, "the Imp is not the subjugated demon")
pet(nil)
WoW.advance(0.5)
eq(H.messagesMatching("broke free"), 0, "and its going is no break")
-- Nor a pet long after the cast.
cast(1098, 8)
WoW.advance(6)
pet(MOB)
eq(Control.enslaved, nil, "a pet six seconds later isn't it")
pet(nil)
WoW.advance(400)

-- In combat the countdown still runs (visuals only).
WoW.targetGUID = MOB
WoW.enterCombat()
cast(18647, 9)
eq(banish.timer:GetText(), "30", "in combat: counts down too")
WoW.advance(10)
eq(banish.timer:GetText(), "20", "and ticks")
WoW.leaveCombat()

done("test_control")
