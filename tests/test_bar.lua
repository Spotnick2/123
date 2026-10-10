-- The compact bar: what each button is armed with, rebuilt out of combat
-- only, and visuals that take secrets untouched.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- A low-level Warlock, as measured in run 2: Imp, Demon Skin 1-2, the
-- Minor stones' create spells, no stone carried, no Ritual yet.
for _, id in ipairs({ 688, 687, 696, 6201, 693 }) do
    WoW.spells[id] = { name = "Spell " .. id, known = true }
end
WoW.spells[697] = { name = "Summon Voidwalker", known = false }
WoW.spells[698] = { name = "Ritual of Summoning", known = false }
WoW.counts[6265] = 3

local ns = H.loadAddon()
local Bar = ns.Bar
local byKey = {}
for _, button in ipairs(Bar.buttons) do byKey[button.key] = button end

H.eq(#Bar.buttons, 5, "five buttons")
for _, button in ipairs(Bar.buttons) do
    H.check(button._template == "SecureActionButtonTemplate", button.key .. " is a secure button")
    H.eq(button._clicks and button._clicks[1], "AnyUp", button.key .. " takes the up edge")
    H.eq(button._clicks and button._clicks[2], "AnyDown", button.key .. " takes the down edge")
    H.check(not button.cooldown:IsMouseEnabled(), button.key .. " cooldown takes no mouse")
    H.check(button:GetFrameLevel() > Bar.glass.top:GetFrameLevel(), button.key .. " sits above the glass")
end
H.check(not Bar.frame:IsMouseEnabled(), "the bar itself takes no mouse")

-- What a button's left (or `index`) click is armed with.
local function armed(key, index)
    local b, n = byKey[key], tostring(index or 1)
    return b:GetAttribute("type" .. n), b:GetAttribute("spell" .. n) or b:GetAttribute("item" .. n)
end
local function neverUnnumbered()
    for _, b in ipairs(Bar.buttons) do
        for _, attr in ipairs({ "type", "typerelease", "typerelease1", "spell", "item" }) do
            if b:GetAttribute(attr) ~= nil then return false end
        end
    end
    return true
end

local t, v = armed("demon", 2)
H.eq(t, "spell", "Demon's right click casts a spell"); H.eq(v, 688, "the only demon known: Imp")
t, v = armed("demon"); H.eq(v, 688, "its left click summons too")
-- The wheel has its own button, "Demons", first on the bar.
local wheelButton = Bar.wheelButton
H.check(wheelButton and wheelButton._template == nil, "Demons is a plain button: it casts nothing")
H.eq(wheelButton.label:GetText(), "Demons", "labelled Demons")
wheelButton:GetScript("OnClick")()
H.check(ns.Wheel.open, "it opens the wheel")
ns.Wheel:Close()
t, v = armed("armor"); H.eq(v, 696, "Armor: Demon Skin's highest rank")
t, v = armed("soulstone"); H.eq(v, 693, "no soulstone carried: create one")
t, v = armed("healthstone"); H.eq(v, 6201, "no healthstone carried: create one")
t = armed("summoning"); H.eq(t, nil, "Ritual not learned: Summoning does nothing")
H.check(byKey.summoning.icon:IsDesaturated(), "and looks unavailable")
H.eq(Bar.shardCount:GetText(), 3, "shard count")
H.check(neverUnnumbered(), "only numbered attributes, never typerelease")

-- A stone in the bags: the button uses it.
WoW.counts[5512] = 1
WoW.items[5512] = "Minor Healthstone"
WoW.fire("BAG_UPDATE_DELAYED")
WoW.runTimers(0)
t, v = armed("healthstone")
H.eq(t, "item", "a carried healthstone is used"); H.eq(v, "item:5512", "the Minor Healthstone")

-- The names under the icons: off by default, /123 labels shows them.
H.check(not byKey.armor.label:IsShown(), "no names under the icons by default")
H.check(not Bar.wheelButton.label:IsShown(), "Demons' neither")
local bare = Bar.frame:GetHeight()
H.slash("ONETWOTHREE", "labels")
H.check(byKey.armor.label:IsShown(), "/123 labels shows them")
H.check(Bar.frame:GetHeight() > bare, "and the bar grows a row")
H.slash("ONETWOTHREE", "labels")
H.check(not byKey.armor.label:IsShown() and Bar.frame:GetHeight() == bare, "and back")

-- An unchanged rebuild writes no attribute.
local writes = 0
for _, b in ipairs(Bar.buttons) do
    local orig = b.SetAttribute
    b.SetAttribute = function(self, k, val) writes = writes + 1 return orig(self, k, val) end
end
WoW.fire("BAG_UPDATE_DELAYED")
WoW.runTimers(0)
H.eq(writes, 0, "nothing changed, nothing rewritten")

-- The stack count draws above the cooldown swipe.
local hs = byKey.healthstone
H.check(hs.count._parent ~= hs and hs.count._parent:GetFrameLevel() > hs.cooldown:GetFrameLevel(),
    "the count sits above the cooldown")

-- The Demon button follows the demon that is out (GUID as measured in run 2).
WoW.spells[697].known = true
WoW.petGUID = "Pet-0-4613-0-1234-1860-0000ABCDEF"
WoW.fire("UNIT_PET", "party1")
WoW.runTimers(0)
t, v = armed("demon", 2); H.eq(v, 688, "another unit's pet is ignored")
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
local demon = byKey.demon
H.eq(demon.action and demon.action.spellID, 697, "Voidwalker once it is out")
t = armed("demon", 2); H.eq(t, nil, "but a click asks first: the button is not armed")
H.check(not demon.icon:IsDesaturated(), "it still looks available")
H.eq(ns.char.demon, 697, "remembered for this character")
H.eq(OneTwoThreeDB.characters[WoW.playerGUID].demon, 697, "keyed on the player's GUID")
H.eq(OneTwoThreeDB.demon, nil, "not account-wide")

-- A demon already out at login (no UNIT_PET) is picked up by any rebuild.
ns.char.demon = nil
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(demon.action and demon.action.spellID, 697, "the demon out at login")

-- The click opens our prompt, whose Summon button casts.
demon:GetScript("PostClick")(demon, "RightButton", true)
H.check(not ns.Resummon:IsShown(), "not on the down edge")
demon:GetScript("PostClick")(demon, "RightButton", false)
H.check(ns.Resummon:IsShown(), "the prompt opens")
H.check(ns.Resummon.text:GetText():find("Voidwalker"), "and names the demon")
H.eq(ns.Resummon.summon:GetAttribute("type1"), "spell", "Summon is a secure spell button")
H.eq(ns.Resummon.summon:GetAttribute("spell1"), 697, "armed with the demon")
ns.Resummon.cancel:GetScript("OnClick")()
H.check(not ns.Resummon:IsShown(), "Cancel closes it")
H.eq(ns.Resummon.summon:GetAttribute("type1"), nil, "and disarms Summon")

-- Combat: no prompt, so the button is armed while combat starts.
demon:GetScript("PostClick")(demon, "RightButton", false)
Bar.moving = true
WoW.enterCombat()
t, v = armed("demon", 2); H.eq(v, 697, "armed in combat, to re-summon a demon that died")
t, v = armed("demon"); H.eq(v, 697, "the left click too: the wheel can't open in combat")
H.check(not ns.Resummon:IsShown(), "the prompt closes as combat starts")
H.check(not Bar.moving, "a drag in progress is stopped as combat starts")

-- In combat nothing is written; the rebuild waits for the end of combat.
WoW.spells[698].known = true
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(#WoW.blocked, 0, "no attribute write attempted in combat")
t = armed("summoning"); H.eq(t, nil, "still unarmed in combat")
demon:GetScript("PostClick")(demon, "RightButton", false)
H.check(not ns.Resummon:IsShown(), "no prompt in combat")

-- Counts are secret in combat: they reach the FontString untouched.
WoW.combatSecret = true
local ok, err = pcall(WoW.fire, "BAG_UPDATE_DELAYED")
H.check(ok, "a secret count does not break the refresh: " .. tostring(err))
H.check(WoW.IsSecret(Bar.shardCount:GetText()), "the secret shard count is passed to the widget")
ok, err = pcall(WoW.fire, "SPELL_UPDATE_COOLDOWN")
H.check(ok, "secret cooldowns do not break the refresh: " .. tostring(err))
WoW.combatSecret = false

Bar:Toggle()
H.check(Bar.frame:IsShown(), "the bar is not hidden in combat")
H.check(H.messagesMatching("in combat") > 0, "and says why")

WoW.leaveCombat()
WoW.runTimers(0)
t, v = armed("summoning"); H.eq(v, 698, "Ritual armed once combat ends")
H.check(not byKey.summoning.icon:IsDesaturated(), "and looks available")
t = armed("demon", 2); H.eq(t, nil, "the Demon button asks again out of combat")
H.check(neverUnnumbered(), "still only numbered attributes")

-- "Don't ask again": Summon casts, and the button stays armed from then on.
demon:GetScript("PostClick")(demon, "RightButton", false)
ns.Resummon.dontAsk:SetChecked(true)
ns.Resummon.summon:GetScript("PostClick")(ns.Resummon.summon, "LeftButton", false)
WoW.runTimers(0)
H.check(not ns.Resummon:IsShown(), "the prompt closes after Summon")
H.eq(ns.db.confirmResummon, false, "the question is turned off")
t, v = armed("demon", 2); H.eq(v, 697, "the button re-summons without asking")
H.slash("ONETWOTHREE", "confirm")
WoW.runTimers(0)
t = armed("demon", 2); H.eq(t, nil, "/123 confirm asks again")

-- Demonic Sacrifice known with a demon out: right-click sacrifices, from
-- the bar (no reopening the wheel), in combat too.
WoW.spells[18788] = { name = "Demonic Sacrifice", known = true }
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
t, v = armed("demon", 2); H.eq(v, 18788, "right-click: Demonic Sacrifice")
demon:GetScript("PostClick")(demon, "RightButton", false)
H.check(not ns.Resummon:IsShown(), "no re-summon question then")
t = armed("demon"); H.eq(t, nil, "the left click still asks first (Codex, #19)")
demon:GetScript("PostClick")(demon, "LeftButton", false)
H.check(ns.Resummon:IsShown(), "it asks")
ns.Resummon.cancel:GetScript("OnClick")()
WoW.enterCombat()
t, v = armed("demon", 2); H.eq(v, 18788, "in combat too")
t, v = armed("demon"); H.eq(v, 697, "the left click summons in combat")
WoW.leaveCombat()
WoW.runTimers(0)
WoW.spells[18788] = nil
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)

-- The demon is gone: the button summons it, no question.
WoW.petGUID = nil
WoW.fire("UNIT_PET", "player")
WoW.runTimers(0)
t, v = armed("demon", 2); H.eq(v, 697, "the Voidwalker after it is dismissed or dies")
WoW.spells[18788] = { name = "Demonic Sacrifice", known = true }
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
t, v = armed("demon", 2); H.eq(v, 697, "no demon out: right-click summons, Sacrifice or not")

-- Out of Soul Shards: the Demon button summons the Imp, the stones that
-- would be created and the Ritual grey out; a carried stone stays lit.
WoW.counts[6265] = 0
WoW.fire("BAG_UPDATE_DELAYED")
WoW.runTimers(0)
t, v = armed("demon"); H.eq(v, 688, "no shards: the Imp (needs none)")
H.eq(ns.char.demon, 697, "the remembered demon is kept")
H.check(byKey.soulstone.icon:IsDesaturated(), "Soulstone (create) greyed without shards")
H.check(byKey.summoning.icon:IsDesaturated(), "Ritual of Summoning greyed without shards")
H.check(not byKey.healthstone.icon:IsDesaturated(), "a carried Healthstone stays lit")
WoW.counts[5512] = 0
WoW.fire("BAG_UPDATE_DELAYED")
WoW.runTimers(0)
t, v = armed("healthstone"); H.eq(v, 6201, "no stone: create one")
H.check(byKey.healthstone.icon:IsDesaturated(), "greyed: it needs a shard")
WoW.counts[6265] = 2
WoW.fire("BAG_UPDATE_DELAYED")
WoW.runTimers(0)
t, v = armed("demon"); H.eq(v, 697, "shards back: the Voidwalker again")
H.check(not byKey.soulstone.icon:IsDesaturated(), "and the stones light up")
H.check(not byKey.healthstone.icon:IsDesaturated(), "both")

-- Key bindings click the bar's secure buttons by name.
local binds = assert(io.open("Bindings.xml")):read("*a")
for i, b in ipairs({ "1:RightButton", "2:LeftButton", "3:LeftButton", "4:LeftButton", "5:LeftButton" }) do
    local name = "CLICK OneTwoThreeBarButton" .. b
    H.check(binds:find(name, 1, true), "binding " .. name)
    H.check(type(_G["BINDING_NAME_" .. name]) == "string", "and its label")
    H.check(_G["OneTwoThreeBarButton" .. b:match("^%d")] ~= nil, "on a button that exists")
end

H.done("test_bar")
