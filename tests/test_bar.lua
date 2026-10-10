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

local function armed(key)
    local b = byKey[key]
    return b:GetAttribute("type1"), b:GetAttribute("spell1") or b:GetAttribute("item1")
end
local function neverUnnumbered()
    for _, b in ipairs(Bar.buttons) do
        for _, attr in ipairs({ "type", "typerelease", "typerelease1", "spell", "item" }) do
            if b:GetAttribute(attr) ~= nil then return false end
        end
    end
    return true
end

local t, v = armed("demon")
H.eq(t, "spell", "Demon casts a spell"); H.eq(v, 688, "the only demon known: Imp")
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

-- The Demon button follows the last demon summoned.
WoW.spells[697].known = true
WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 697)
WoW.runTimers(0)
t, v = armed("demon"); H.eq(v, 697, "Voidwalker after summoning it")
H.eq(ns.db.demon, 697, "remembered across sessions")
WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-2", 688)
WoW.runTimers(0)
t, v = armed("demon"); H.eq(v, 697, "another unit's casts are ignored")

-- In combat nothing is written; the rebuild waits for the end of combat.
WoW.enterCombat()
WoW.spells[698].known = true
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(#WoW.blocked, 0, "no attribute write attempted in combat")
t = armed("summoning"); H.eq(t, nil, "still unarmed in combat")

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
t, v = armed("summoning"); H.eq(v, 698, "Ritual armed once combat ends")
H.check(not byKey.summoning.icon:IsDesaturated(), "and looks available")
H.check(neverUnnumbered(), "still only numbered attributes")

H.done("test_bar")
