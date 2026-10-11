-- Smart stones (#6): a stone button uses the best stone carried (that the
-- player can use), else creates the best rank known. The right click stays
-- unarmed (a better rank while carrying a lesser one waits for #31).

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

-- Carrying a stone: it is the one used.
H.eq(arm(hs, 1), "item:5512", "use the Minor Healthstone")
H.eq(arm(hs, 2), nil, "right click unarmed")

-- A better rank learned: the stone carried is still the one used.
WoW.spells[6202].known = true
update()
H.eq(arm(hs, 1), "item:5512", "still use the stone carried")
H.eq(arm(hs, 2), nil, "right click still unarmed (#31)")

-- The better stone carried too: it is the one used.
WoW.counts[5511] = 1
update()
H.eq(arm(hs, 1), "item:5511", "the Lesser, the best carried")

-- None carried: create the best rank known.
WoW.counts[5511], WoW.counts[5512] = 0, 0
update()
H.eq(arm(hs, 1), 6202, "create the best rank known")
H.eq(arm(hs, 2), nil, "right click unarmed")

-- Out of shards: a carried stone stays lit (using it costs none); creating
-- one greys out.
WoW.counts[6265] = 0
update()
H.check(hs.icon:IsDesaturated(), "create without a shard: grey")
WoW.counts[5512] = 1
update()
H.eq(arm(hs, 1), "item:5512", "use the stone")
H.check(not hs.icon:IsDesaturated(), "lit: using it needs no shard")
WoW.counts[6265] = 3

-- Soulstones work the same way.
H.eq(arm(ss, 1), "item:5232", "soulstone: use the Minor Soulstone")
WoW.counts[5232] = 0
WoW.spells[20752].known = true
update()
H.eq(arm(ss, 1), 20752, "soulstone: create the best rank known")

-- A stone the player can't use yet (a traded higher-level one) is ignored.
WoW.counts[5510] = 1          -- a Greater Healthstone from a raid Warlock
WoW.unusable[5510] = true     -- level 36: not usable yet
update()
H.eq(arm(hs, 1), "item:5512", "an unusable stone is not the one used")
-- Reaching its level, with no bag or spell change: it is the one used.
WoW.unusable[5510] = nil
WoW.fire("PLAYER_LEVEL_UP", 36)
WoW.runTimers(0)
H.eq(arm(hs, 1), "item:5510", "after the level up the Greater is used")
WoW.counts[5510] = 0
update()

-- Counts unreadable (secret as combat starts): keep what is armed.
local before = arm(hs, 1)
WoW.combatSecret = true
WoW.fire("BAG_UPDATE_DELAYED")
WoW.runTimers(0)
H.eq(arm(hs, 1), before, "an unreadable count never turns use into create")
WoW.combatSecret = false
update()

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
