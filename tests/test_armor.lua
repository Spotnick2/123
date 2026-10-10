-- The Armor button (#7): the best rank of the preferred armor known, and a
-- glow while that armor is not on. Auras are secret in combat: "unknown".

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[687] = { name = "Demon Skin", known = true }
WoW.spells[696] = { name = "Demon Skin", known = true }
WoW.spells[706] = { name = "Demon Armor", known = false }
WoW.spells[403619] = { name = "Fel Armor", known = false }

local ns = H.loadAddon()
local Bar = ns.Bar
local armor = Bar.armorButton

local function auras(...)
    WoW.auras.HELPFUL = {}
    for _, a in ipairs({ ... }) do WoW.SetAura("HELPFUL", a[1], a[2]) end
    WoW.fire("UNIT_AURA", "player", { isFullUpdate = true })
end
local function glowing() return armor.glow:IsShown() and armor.pulse:IsPlaying() end

H.eq(armor:GetAttribute("spell1"), 696, "Demon Skin's highest rank")
H.eq(armor.armorState, "missing", "no armor on at login")
H.check(glowing(), "the button glows")

auras({ "Demon Skin", 696 })
H.eq(armor.armorState, "on", "Demon Skin on")
H.check(not glowing(), "no glow")

auras({ "Demon Skin", 687 })
H.eq(armor.armorState, "on", "a lower rank of the same armor counts")

WoW.fire("UNIT_AURA", "target")
H.eq(armor.armorState, "on", "another unit's auras are not read")

-- Demon Armor learned: Demon Skin no longer counts.
WoW.spells[706].known = true
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(armor:GetAttribute("spell1"), 706, "Demon Armor over Demon Skin")
H.eq(armor.armorState, "missing", "Demon Skin does not satisfy Demon Armor")
H.check(glowing(), "the button asks for the upgrade")

-- Matched by name too, when the aura's spell ID differs from the cast's.
auras({ "Demon Armor", 999999 })
H.eq(armor.armorState, "on", "matched by the spell's name")

-- Combat: auras are secret, so the state is unknown and the glow goes out.
auras()
H.check(glowing(), "missing again")
WoW.enterCombat()
H.eq(armor.armorState, "unknown", "unknown in combat")
H.check(not glowing(), "no glow in combat")
local ok, err = pcall(WoW.fire, "UNIT_AURA", "player", { isFullUpdate = WoW.Secret(true) })
H.check(ok, "a UNIT_AURA in combat raises nothing: " .. tostring(err))
H.eq(armor.armorState, "unknown", "still unknown")
-- Even if read in combat, the throwing index read gives "unknown", not "missing".
Bar.inCombat = false
Bar:UpdateArmor()
H.eq(armor.armorState, "unknown", "a throwing aura read is unknown")
Bar.inCombat = true
WoW.leaveCombat()
WoW.runTimers(0)
H.eq(armor.armorState, "missing", "read again once combat ends")

-- Forever's Fel Armor, if it ever ships, is preferred.
WoW.spells[403619].known = true
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(armor:GetAttribute("spell1"), 403619, "Fel Armor once learned")
H.eq(armor.armorState, "missing", "Demon Armor no longer counts")

H.done("test_armor")
