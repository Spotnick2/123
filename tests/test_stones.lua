-- Smart stones (#6): left uses the best stone carried, else creates the best
-- rank known; right creates the best rank known when it beats the stone
-- carried (stones are unique per rank), else does the same as left.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local function spell(id, name, known) WoW.spells[id] = { name = name, known = known } end
spell(6201, "Create Healthstone (Minor)", true)
spell(6202, "Create Healthstone (Lesser)", false)
spell(5699, "Create Healthstone", false)
spell(693, "Create Soulstone (Minor)", true)
spell(20752, "Create Soulstone (Lesser)", false)
WoW.items[5512], WoW.items[5511] = "Minor Healthstone", "Lesser Healthstone"
WoW.items[5232], WoW.items[16892] = "Minor Soulstone", "Lesser Soulstone"
WoW.counts[6265] = 3
WoW.counts[5512] = 1   -- a Minor Healthstone carried
WoW.counts[5232] = 1   -- a Minor Soulstone carried

local ns = H.loadAddon()
local Bar = ns.Bar
local hs, ss
for _, b in ipairs(Bar.buttons) do
    if b.key == "healthstone" then hs = b elseif b.key == "soulstone" then ss = b end
end
local function arm(b, n)
    local i = tostring(n)
    return b:GetAttribute("spell" .. i) or b:GetAttribute("item" .. i)
end
local function update()
    WoW.fire("SPELLS_CHANGED")
    WoW.fire("BAG_UPDATE_DELAYED")
    WoW.runTimers(0)
end

-- Carrying the best rank known: both clicks use it.
H.eq(arm(hs, 1), "item:5512", "left: use the Minor Healthstone")
H.eq(arm(hs, 2), "item:5512", "right: the same, nothing better to make")
H.check(not hs.upgradeMark:IsShown(), "no upgrade mark")
H.eq(hs.upgrade, nil, "no upgrade")

-- A better rank learned: left still uses the Minor, right makes a Lesser.
WoW.spells[6202].known = true
update()
H.eq(arm(hs, 1), "item:5512", "left: still use the stone carried")
H.eq(arm(hs, 2), 6202, "right: create the Lesser Healthstone")
H.check(hs.upgradeMark:IsShown(), "the green + says a better one can be made")
H.eq(hs.upgrade and hs.upgrade.spellID, 6202, "the upgrade is known for the tooltip")

-- The better stone carried too: it is the one used, nothing to upgrade.
WoW.counts[5511] = 1
update()
H.eq(arm(hs, 1), "item:5511", "left: the Lesser, the best carried")
H.eq(arm(hs, 2), "item:5511", "right: the same")
H.check(not hs.upgradeMark:IsShown(), "no mark once the best is carried")

-- None carried: both create the best rank known.
WoW.counts[5511], WoW.counts[5512] = 0, 0
update()
H.eq(arm(hs, 1), 6202, "left: create the best rank known")
H.eq(arm(hs, 2), 6202, "right: the same")

-- Out of shards: a carried stone stays lit (using it costs none), while the
-- upgrade that would spend one is still offered (the tooltip says it needs a
-- shard).
WoW.counts[5512], WoW.counts[6265] = 1, 0
update()
H.eq(arm(hs, 1), "item:5512", "left: use the stone")
H.check(not hs.icon:IsDesaturated(), "lit: using it needs no shard")
H.eq(arm(hs, 2), 6202, "right: the upgrade is still there")
WoW.counts[6265] = 3

-- Soulstones work the same way.
H.eq(arm(ss, 1), "item:5232", "soulstone left: use the Minor Soulstone")
WoW.spells[20752].known = true
update()
H.eq(arm(ss, 2), 20752, "soulstone right: create the Lesser Soulstone")
H.check(ss.upgradeMark:IsShown(), "with the mark")

-- Every tier pairs a create spell with its items, strongest first.
for _, tiers in ipairs({ ns.Data.HEALTHSTONE_TIERS, ns.Data.SOULSTONE_TIERS }) do
    H.eq(#tiers, 5, "five ranks")
    for _, tier in ipairs(tiers) do
        H.check(type(tier.create) == "number" and #tier.items > 0, "a tier has a spell and items")
        H.eq(ns.Data.REAGENT[tier.create], ns.Data.SOUL_SHARD, "creating it needs a Soul Shard")
    end
end

-- In combat nothing is rewritten: the stone used stays armed.
WoW.enterCombat()
WoW.counts[5512] = 0
WoW.fire("BAG_UPDATE_DELAYED")
WoW.runTimers(0)
H.eq(arm(hs, 1), "item:5512", "in combat the attributes wait")
H.eq(#WoW.blocked, 0, "no blocked write")
WoW.leaveCombat()
WoW.runTimers(0)
H.eq(arm(hs, 1), 6202, "after combat: create again")

H.done("test_stones")
