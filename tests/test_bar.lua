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

eq(#Bar.buttons, 7, "seven buttons")
-- Banish and Subjugate (#29) only once learned: this Warlock knows neither.
check(not Bar:Button("banish"):IsShown() and not Bar:Button("subjugate"):IsShown(), "Banish and Subjugate hidden until learned")
for _, button in ipairs(Bar.buttons) do
    check(button._template == "SecureActionButtonTemplate", button.key .. " is a secure button")
    eq(button._clicks and button._clicks[1], "AnyUp", button.key .. " takes the up edge")
    eq(button._clicks and button._clicks[2], "AnyDown", button.key .. " takes the down edge")
    check(not button.cooldown:IsMouseEnabled(), button.key .. " cooldown takes no mouse")
    check(button:GetFrameLevel() > Bar.glass.top:GetFrameLevel(), button.key .. " sits above the glass")
end
check(not Bar.frame:IsMouseEnabled(), "the bar itself takes no mouse")

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
eq(t, "spell", "Demon's right click casts a spell"); eq(v, 688, "the only demon known: Imp")
t, v = armed("demon"); eq(v, 688, "its left click summons too")
-- The wheel has its own button, "Demons", first on the bar.
local wheelButton = Bar.wheelButton
check(wheelButton and wheelButton._template == nil, "Demons is a plain button: it casts nothing")
eq(wheelButton.label:GetText(), "Demons", "labelled Demons")
wheelButton:GetScript("OnClick")()
check(ns.Wheel.open, "it opens the wheel")
ns.Wheel:Close()
t, v = armed("armor"); eq(v, 696, "Armor: Demon Skin's highest rank")
t, v = armed("soulstone"); eq(v, 693, "no soulstone carried: create one")
t, v = armed("healthstone"); eq(v, 6201, "no healthstone carried: create one")
t = armed("summoning"); eq(t, nil, "Ritual not learned: Summoning does nothing")
check(byKey.summoning.icon:IsDesaturated(), "and looks unavailable")
eq(Bar.shardCount:GetText(), 3, "shard count")
check(neverUnnumbered(), "only numbered attributes, never typerelease")

-- A stone in the bags: the button uses it.
WoW.counts[5512] = 1
WoW.items[5512] = "Minor Healthstone"
WoW.fire("BAG_UPDATE_DELAYED")
WoW.advance(0)
t, v = armed("healthstone")
eq(t, "item", "a carried healthstone is used"); eq(v, "item:5512", "the Minor Healthstone")

-- The names under the icons: off by default, /123 labels shows them.
check(not byKey.armor.label:IsShown(), "no names under the icons by default")
check(not Bar.wheelButton.label:IsShown(), "Demons' neither")
local bare = Bar.frame:GetHeight()
H.slash("ONETWOTHREE", "labels")
check(byKey.armor.label:IsShown(), "/123 labels shows them")
check(Bar.frame:GetHeight() > bare, "and the bar grows a row")
-- English names fit their room under the icon: none is shrunk.
local _, labelSize = byKey.armor.label:GetFont()
for _, button in ipairs(Bar.buttons) do
    eq(select(2, button.label:GetFont()), labelSize, button.label:GetText() .. " keeps its size")
end
H.slash("ONETWOTHREE", "labels")
check(not byKey.armor.label:IsShown() and Bar.frame:GetHeight() == bare, "and back")

-- An unchanged rebuild writes no attribute.
local writes = 0
for _, b in ipairs(Bar.buttons) do
    local orig = b.SetAttribute
    b.SetAttribute = function(self, k, val) writes = writes + 1 return orig(self, k, val) end
end
WoW.fire("BAG_UPDATE_DELAYED")
WoW.advance(0)
eq(writes, 0, "nothing changed, nothing rewritten")

-- The stack count draws above the cooldown swipe.
local hs = byKey.healthstone
check(hs.count._parent ~= hs and hs.count._parent:GetFrameLevel() > hs.cooldown:GetFrameLevel(),
    "the count sits above the cooldown")

-- The Demon button follows the demon that is out (GUID as measured in run 2).
WoW.spells[697].known = true
WoW.petGUID = "Pet-0-4613-0-1234-1860-0000ABCDEF"
WoW.fire("UNIT_PET", "party1")
WoW.advance(0)
t, v = armed("demon", 2); eq(v, 688, "another unit's pet is ignored")
WoW.fire("UNIT_PET", "player")
WoW.advance(0)
local demon = byKey.demon
eq(demon.action and demon.action.spellID, 697, "Voidwalker once it is out")
t = armed("demon", 2); eq(t, nil, "but a click asks first: the button is not armed")
check(not demon.icon:IsDesaturated(), "it still looks available")
eq(ns.char.demon, 697, "remembered for this character")
eq(OneTwoThreeDB.characters[WoW.playerGUID].demon, 697, "keyed on the player's GUID")
eq(OneTwoThreeDB.demon, nil, "not account-wide")

-- A demon already out at login (no UNIT_PET) is picked up by any rebuild.
ns.char.demon, Bar.seenPet = nil, nil -- a new session: nothing remembered, no pet seen
WoW.fire("SPELLS_CHANGED")
WoW.advance(0)
eq(demon.action and demon.action.spellID, 697, "the demon out at login")

-- The click opens our prompt, whose Summon button casts.
demon:GetScript("PostClick")(demon, "RightButton", true)
check(not ns.Resummon:IsShown(), "not on the down edge")
demon:GetScript("PostClick")(demon, "RightButton", false)
check(ns.Resummon:IsShown(), "the prompt opens")
check(ns.Resummon.text:GetText():find("Voidwalker"), "and names the demon")
eq(ns.Resummon.summon:GetAttribute("type1"), "spell", "Summon is a secure spell button")
eq(ns.Resummon.summon:GetAttribute("spell1"), 697, "armed with the demon")
ns.Resummon.cancel:GetScript("OnClick")()
check(not ns.Resummon:IsShown(), "Cancel closes it")
eq(ns.Resummon.summon:GetAttribute("type1"), nil, "and disarms Summon")

-- Combat: no prompt, so the button is armed while combat starts.
demon:GetScript("PostClick")(demon, "RightButton", false)
Bar.moving = true
WoW.enterCombat()
t, v = armed("demon", 2); eq(v, 697, "armed in combat, to re-summon a demon that died")
t, v = armed("demon"); eq(v, 697, "the left click too: the wheel can't open in combat")
check(not ns.Resummon:IsShown(), "the prompt closes as combat starts")
check(not Bar.moving, "a drag in progress is stopped as combat starts")

-- In combat nothing is written; the rebuild waits for the end of combat.
WoW.spells[698].known = true
WoW.fire("SPELLS_CHANGED")
WoW.advance(0)
eq(#WoW.blocked, 0, "no attribute write attempted in combat")
t = armed("summoning"); eq(t, nil, "still unarmed in combat")
demon:GetScript("PostClick")(demon, "RightButton", false)
check(not ns.Resummon:IsShown(), "no prompt in combat")

-- Counts are secret in combat: they reach the FontString untouched.
WoW.combatSecret = true
local ok, err = pcall(WoW.fire, "BAG_UPDATE_DELAYED")
check(ok, "a secret count does not break the refresh: " .. tostring(err))
check(issecretvalue(Bar.shardCount:GetText()), "the secret shard count is passed to the widget")
ok, err = pcall(WoW.fire, "SPELL_UPDATE_COOLDOWN")
check(ok, "secret cooldowns do not break the refresh: " .. tostring(err))
WoW.combatSecret = false

Bar:Toggle()
check(Bar.frame:IsShown(), "the bar is not hidden in combat")
check(H.messagesMatching("in combat") > 0, "and says why")

WoW.leaveCombat()
WoW.advance(0)
t, v = armed("summoning"); eq(v, 698, "Ritual armed once combat ends")
check(not byKey.summoning.icon:IsDesaturated(), "and looks available")
t = armed("demon", 2); eq(t, nil, "the Demon button asks again out of combat")
check(neverUnnumbered(), "still only numbered attributes")

-- "Don't ask again": Summon casts, and the button stays armed from then on.
demon:GetScript("PostClick")(demon, "RightButton", false)
ns.Resummon.dontAsk:SetChecked(true)
ns.Resummon.summon:GetScript("PostClick")(ns.Resummon.summon, "LeftButton", false)
WoW.advance(0)
check(not ns.Resummon:IsShown(), "the prompt closes after Summon")
eq(ns.db.confirmResummon, false, "the question is turned off")
t, v = armed("demon", 2); eq(v, 697, "the button re-summons without asking")
H.slash("ONETWOTHREE", "confirm")
WoW.advance(0)
t = armed("demon", 2); eq(t, nil, "/123 confirm asks again")

-- Demonic Sacrifice known with a demon out: right-click sacrifices, from
-- the bar (no reopening the wheel), in combat too.
WoW.spells[18788] = { name = "Demonic Sacrifice", known = true }
WoW.fire("SPELLS_CHANGED")
WoW.advance(0)
t, v = armed("demon", 2); eq(v, 18788, "right-click: Demonic Sacrifice")
demon:GetScript("PostClick")(demon, "RightButton", false)
check(not ns.Resummon:IsShown(), "no re-summon question then")
t = armed("demon"); eq(t, nil, "the left click still asks first (Codex, #19)")
demon:GetScript("PostClick")(demon, "LeftButton", false)
check(ns.Resummon:IsShown(), "it asks")
ns.Resummon.cancel:GetScript("OnClick")()
WoW.enterCombat()
t, v = armed("demon", 2); eq(v, 18788, "in combat too")
t, v = armed("demon"); eq(v, 697, "the left click summons in combat")
WoW.leaveCombat()
WoW.advance(0)
WoW.spells[18788] = nil
WoW.fire("SPELLS_CHANGED")
WoW.advance(0)

-- The demon is gone: the button summons it, no question.
WoW.petGUID = nil
WoW.fire("UNIT_PET", "player")
WoW.advance(0)
t, v = armed("demon", 2); eq(v, 697, "the Voidwalker after it is dismissed or dies")
WoW.spells[18788] = { name = "Demonic Sacrifice", known = true }
WoW.fire("SPELLS_CHANGED")
WoW.advance(0)
t, v = armed("demon", 2); eq(v, 697, "no demon out: right-click summons, Sacrifice or not")

-- Out of Soul Shards: the Demon button summons the Imp, the stones that
-- would be created and the Ritual grey out; a carried stone stays lit.
WoW.counts[6265] = 0
WoW.fire("BAG_UPDATE_DELAYED")
WoW.advance(0)
t, v = armed("demon"); eq(v, 688, "no shards: the Imp (needs none)")
eq(ns.char.demon, 697, "the remembered demon is kept")
check(byKey.soulstone.icon:IsDesaturated(), "Soulstone (create) greyed without shards")
check(byKey.summoning.icon:IsDesaturated(), "Ritual of Summoning greyed without shards")
check(not byKey.healthstone.icon:IsDesaturated(), "a carried Healthstone stays lit")
WoW.counts[5512] = 0
WoW.fire("BAG_UPDATE_DELAYED")
WoW.advance(0)
t, v = armed("healthstone"); eq(v, 6201, "no stone: create one")
check(byKey.healthstone.icon:IsDesaturated(), "greyed: it needs a shard")
-- The fallback Imp actually summoned and out: still not the remembered
-- demon (Codex, #19).
WoW.petGUID = "Pet-0-4613-0-1234-416-0000ABCDEF"
WoW.fire("UNIT_PET", "player")
WoW.advance(0)
eq(ns.char.demon, 697, "the fallback Imp out does not replace the Voidwalker")
WoW.counts[6265] = 2
WoW.fire("BAG_UPDATE_DELAYED")
WoW.advance(0)
t, v = armed("demon"); eq(v, 697, "shards back: the Voidwalker again")
WoW.petGUID = nil
WoW.fire("UNIT_PET", "player")
WoW.advance(0)
check(not byKey.soulstone.icon:IsDesaturated(), "and the stones light up")
check(not byKey.healthstone.icon:IsDesaturated(), "both")

-- Key bindings click the bar's secure buttons by name.
local binds = assert(io.open("Bindings.xml")):read("*a")
for i, b in ipairs({ "1:RightButton", "2:LeftButton", "3:LeftButton", "4:LeftButton", "5:LeftButton" }) do
    local name = "CLICK OneTwoThreeBarButton" .. b
    check(binds:find(name, 1, true), "binding " .. name)
    check(type(_G["BINDING_NAME_" .. name]) == "string", "and its label")
    check(_G["OneTwoThreeBarButton" .. b:match("^%d")] ~= nil, "on a button that exists")
end

done("test_bar")
