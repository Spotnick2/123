-- Smart Demonic Sacrifice (#20): the buff is followed from its cast; a
-- summon that would end it asks first (the Demon button and the wheel);
-- with Demonic Pact only the sacrificed demon ends it, and a picked pair
-- is walked by the Demon button's right click.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local function spell(id, name, known) WoW.spells[id] = { name = name, known = known } end
spell(688, "Summon Imp", true)
spell(697, "Summon Voidwalker", true)
spell(712, "Summon Succubus", true)
spell(18788, "Demonic Sacrifice", true)
spell(425464, "Demonic Pact", false)
spell(18789, "Burning Shadow", false)
spell(18790, "Fel Stamina", false)
WoW.counts[6265] = 3
local IMP = "Pet-0-4613-0-1234-416-0000ABCDEF"
local VOID = "Pet-0-4613-0-1234-1860-0000ABCDEF"
WoW.petGUID = IMP

local ns = H.loadAddon()
local Bar, S = ns.Bar, ns.Sacrifice
local demon = Bar:Button("demon")
local function pet(guid)
    WoW.petGUID = guid
    WoW.fire("UNIT_PET", "player")
    WoW.runTimers(0)
end
local n = 0
local function sacrifice(buffID, buffName)
    n = n + 1
    local cast = "Cast-3-0-0-18788-" .. n
    WoW.fire("UNIT_SPELLCAST_SENT", "player", "", cast, 18788)
    pet(nil)
    WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "player", cast, 18788)
    WoW.auras.HELPFUL = {}
    WoW.SetAura("HELPFUL", buffName, buffID)
    WoW.runTimers(0)
end
local function tooltip(b)
    b:GetScript("OnEnter")(b)
    return table.concat(GameTooltip._lines, "\n")
end
local function openWheel()
    Bar.wheelButton:GetScript("OnClick")()
    return ns.Wheel.nodes
end

-- Sacrificing the Imp: followed from the cast, saved per character.
sacrifice(18789, "Burning Shadow")
H.eq(ns.char.sacrifice and ns.char.sacrifice.spell, 688, "the Imp was sacrificed")
H.eq(S:BuffName(), "Burning Shadow", "its buff, by the client's name")

-- Without Demonic Pact, any summon would end it: the Demon button asks.
H.check(S:Cancels(697) and S:Cancels(688), "without Demonic Pact any summon ends it")
H.eq(demon:GetAttribute("type1"), nil, "the Demon button's left click is held")
H.check(tooltip(demon):find("(ends your Demonic Sacrifice: asks first)", 1, true) ~= nil, "the tooltip says why")
demon:GetScript("PostClick")(demon, "LeftButton", false)
H.check(ns.Resummon:IsShown(), "a click asks")
H.eq(ns.Resummon.text:GetText(), "Summoning Imp ends your Demonic Sacrifice (Burning Shadow). Summon anyway?",
    "and says what it ends")
H.check(not ns.Resummon.dontAsk:IsShown(), "no \"Don't ask again\" for it")
ns.Resummon:Hide()
-- The wheel asks too: every pet bead is held, a major demon isn't.
local nodes = openWheel()
H.check(nodes[1].held and nodes[5].held, "the Voidwalker's and the Imp's beads ask first")
H.eq(nodes[1].button:GetAttribute("type1"), nil, "so they cast nothing")
H.check(not nodes[3].held, "Inferno doesn't end it")
ns.Wheel:Close()

-- Summoning anyway ends it.
pet(VOID)
H.eq(ns.char.sacrifice, nil, "a summon ended it")
H.check(tooltip(demon):find("(already out: asks first)", 1, true) ~= nil, "the Demon button only asks about re-summoning now")

-- With Demonic Pact only the sacrificed demon ends it.
spell(425464, "Demonic Pact", true)
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
pet(IMP)
sacrifice(18789, "Burning Shadow")
H.check(not S:Cancels(697), "with Demonic Pact the Voidwalker keeps it")
H.check(S:Cancels(688), "but the Imp again ends it")
nodes = openWheel()
H.check(not nodes[1].held, "the Voidwalker's bead casts")
H.check(nodes[5].held, "the Imp's asks")
ns.Wheel:Close()

-- The aura gone (out of combat, after a moment): forgotten.
WoW.auras.HELPFUL = {}
H.check(S:Active() ~= nil, "right after the cast the aura isn't checked yet")
WoW.runTimers(3)
H.eq(S:Active(), nil, "the buff is gone: forgotten")

-- The buff cancelled while the bar and the wheel hold summons: both are
-- re-armed with no click and no other event.
pet(IMP)
sacrifice(18789, "Burning Shadow")
WoW.runTimers(3)
spell(425464, "Demonic Pact", false)
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
nodes = openWheel()
H.eq(demon:GetAttribute("type1"), nil, "held while the buff is up")
H.check(nodes[1].held, "the wheel's bead too")
WoW.auras.HELPFUL = {}
WoW.fire("UNIT_AURA", "player", { isFullUpdate = true })
WoW.runTimers(0)
H.eq(ns.char.sacrifice, nil, "the buff cancelled: forgotten")
H.eq(demon:GetAttribute("type1"), "spell", "the Demon button casts again")
H.check(not nodes[1].held and nodes[1].button:GetAttribute("type1") == "spell", "the open wheel's bead too")
ns.Wheel:Close()
spell(425464, "Demonic Pact", true)
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)

-- In combat auras are secret: the estimate stands. Dying ends it.
pet(IMP)
sacrifice(18789, "Burning Shadow")
WoW.runTimers(3)
WoW.enterCombat()
WoW.auras.HELPFUL = {}
H.check(S:Active() ~= nil, "in combat: kept (auras secret)")
WoW.leaveCombat()
WoW.SetAura("HELPFUL", "Burning Shadow", 18789)
WoW.fire("PLAYER_DEAD")
H.eq(ns.char.sacrifice, nil, "dying ends it")

-- Two hours later it is over.
pet(IMP)
sacrifice(18789, "Burning Shadow")
spell(425464, "Demonic Pact", false)
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(demon:GetAttribute("type1"), nil, "held during the two hours")
WoW.runTimers(2 * 60 * 60 + 1)
H.eq(ns.char.sacrifice, nil, "after two hours: over, with nothing asking")
H.eq(demon:GetAttribute("type1"), "spell", "and the Demon button re-armed")
spell(425464, "Demonic Pact", true)
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)

-- The pair (Options): sacrifice the Imp, keep the Voidwalker.
ns.char.sacrificePair = { sacrifice = 688, keep = 697 }
pet(nil)
WoW.auras.HELPFUL = {}
local function right() return demon:GetAttribute("type2"), demon:GetAttribute("spell2") end
local t, v = right()
H.eq(v, 688, "step 1: the right click summons the Imp")
H.check(tooltip(demon):find("Right-click: Summon Imp (to sacrifice)", 1, true) ~= nil, "and says so")
pet(IMP)
t, v = right()
H.eq(v, 18788, "step 2: the Imp is out: Demonic Sacrifice")
sacrifice(18789, "Burning Shadow")
t, v = right()
H.eq(v, 697, "step 3: summon the Voidwalker to keep")
H.check(tooltip(demon):find("Right-click: Summon Voidwalker (to keep)", 1, true) ~= nil, "and says so")
pet(VOID)
H.check(ns.char.sacrifice ~= nil, "the Voidwalker kept the buff (Demonic Pact)")
t, v = right()
H.eq(t, nil, "done: the right click is unarmed (no stray sacrifice of the one kept)")
H.check(tooltip(demon):find("Sacrifice pair done: Burning Shadow", 1, true) ~= nil, "and says it's done")
demon:GetScript("PostClick")(demon, "RightButton", false)
H.check(not ns.Resummon:IsShown(), "a right click then asks nothing")

-- No pair without Demonic Pact, or with the same demon twice.
spell(425464, "Demonic Pact", false)
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
t, v = right()
H.eq(v, 18788, "without Demonic Pact the right click is Demonic Sacrifice, as before")
spell(425464, "Demonic Pact", true)
ns.char.sacrificePair = { sacrifice = 697, keep = 697 }
H.eq(S:PairStep(), nil, "the same demon twice is no pair")

-- Options: the demon to keep passes over the one to sacrifice.
ns.char.sacrificePair = { sacrifice = 0, keep = 0 }
ns.Options.panel:GetScript("OnShow")(ns.Options.panel)
local sac, keep
for _, c in ipairs(ns.Options.panel._children) do
    local label = c._points and c._points[1] and c:GetText()
    if c.GetScript and c:GetScript("OnClick") and label then
        if label == "None" and not sac then sac = c elseif label == "None" and sac and not keep then keep = c end
    end
end
H.check(sac ~= nil and keep ~= nil, "two pair choices in Options")
sac:GetScript("OnClick")(sac)
H.eq(ns.char.sacrificePair.sacrifice, 688, "sacrifice: the Imp")
keep:GetScript("OnClick")(keep)
H.eq(ns.char.sacrificePair.keep, 697, "keep: skips the Imp, the Voidwalker")

H.done("test_sacrifice")
