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
local SA = ns.SecureAction

H.eq(armor:GetAttribute("spell1"), 696, "Demon Skin's highest rank")
H.eq(armor.armorState, "missing", "no armor on at login")
H.check(glowing(), "the button glows")

auras({ "Demon Skin", 696 })
H.eq(armor.armorState, "on", "Demon Skin on")
H.check(not glowing(), "no glow")

auras({ "Demon Skin", 687 })
H.eq(armor.armorState, "on", "a lower rank of the same armor counts")

local reads = 0
local orig = ns.API.HasAura
ns.API.HasAura = function(...) reads = reads + 1 return orig(...) end
WoW.fire("UNIT_AURA", "target")
H.eq(reads, 0, "another unit's UNIT_AURA never arrives")
WoW.fire("UNIT_AURA", "player")
H.eq(reads, 1, "the player's does")
ns.API.HasAura = orig

-- The pulse is not restarted by every aura change while missing.
auras()
local plays = 0
local play = armor.pulse.Play
armor.pulse.Play = function(self) plays = plays + 1 return play(self) end
auras()
auras()
H.eq(plays, 0, "the pulse keeps running")
armor.pulse.Play = play
auras({ "Demon Skin", 696 })

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
-- Combat ends while auras are still secret: unknown, then read again shortly.
WoW.inCombat = false
WoW.fire("PLAYER_REGEN_ENABLED")
WoW.runTimers(0)
H.eq(armor.armorState, "unknown", "a throwing aura read is unknown, not missing")
WoW.aurasThrow = false
WoW.runTimers(1)
H.eq(armor.armorState, "missing", "re-read a moment later, with no UNIT_AURA")
H.check(glowing(), "and the glow is back")

-- A secret field gives unknown, never a confident "missing".
auras({ "Demon Armor", WoW.Secret(706) })
H.eq(armor.armorState, "unknown", "a secret aura field is unknown")
WoW.auras.HELPFUL = {}
WoW.runTimers(1)
H.eq(armor.armorState, "missing", "readable again")

-- Fel Armor 403619 is unmeasured: never armed, even if reported known.
WoW.spells[403619].known = true
WoW.fire("SPELLS_CHANGED")
WoW.runTimers(0)
H.eq(armor:GetAttribute("spell1"), 706, "Demon Armor stays until Fel Armor is measured")

H.done("test_armor")
