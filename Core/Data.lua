-- ============================================================
-- Data: Warlock spell and item IDs. Every list is ordered best first.
--
-- Spell IDs measured on 70334 (docs/FOREVER-PROBE.md run 2: Forever keeps
-- Vanilla's IDs). Item IDs from References/Forever/consumables/forever-consumables-1.60.1.70009.tsv
-- and Apotheca's ApothecaItems.lua.
-- ============================================================

local _, ns = ...
if ns.skip then return end

ns.Data = {
    -- Best known first is the Demon button's pick until a demon has been out
    -- (the wheel, #4, picks from all of them).
    -- Forever's Incubus is its own demon, apart from the Succubus: Summon
    -- Incubus 713, level 20 (Wowhead's Forever database; unmeasured in game).
    DEMONS = {
        688,    -- Summon Imp
        697,    -- Summon Voidwalker
        712,    -- Summon Succubus
        713,    -- Summon Incubus (Forever)
        691,    -- Summon Felhunter
    },
    VOIDWALKER = 697,

    -- The wheel's seven beads, clockwise from 12 (owner's "Fel concept"
    -- mockup). Inferno and Ritual of Doom are major demons: not pets to
    -- switch to, never the Demon button's "last demon", no Fel Domination.
    -- Inferno (level 50) drops an Infernal where you click; Ritual of Doom
    -- (60) is a group ritual for a Doomguard. Both exist on Forever (run 2).
    -- `npc` is what each bead's live portrait shows: the DEMON_NPC ids, plus
    -- the Infernal (89) and the Doomguard (11859), Vanilla's.
    -- `family` (CreatureFamily, Forever's client data 70532) names the demon
    -- in the client's language (#22). The Infernal has no family: Inferno's
    -- own spell name labels its bead. `label` is the English fallback where
    -- the summon's name doesn't hold the demon's (Ritual of Doom).
    WHEEL = {
        { spell = 697, npc = 1860, family = 16 },                      -- Voidwalker
        { spell = 691, npc = 417, family = 15 },                       -- Felhunter
        { spell = 1122, npc = 89, major = true },                      -- Inferno
        { spell = 18540, npc = 11859, major = true, family = 19, label = ns.L["Doomguard"] },
        { spell = 688, npc = 416, family = 23 },                       -- Imp
        { spell = 712, npc = 1863, family = 17 },                      -- Succubus
        { spell = 713, npc = 185317, family = 302 },                   -- Incubus
    },

    -- What a spell consumes (Wowhead's Forever database): a Soul Shard for
    -- every demon but the Imp, for creating a stone and for Ritual of
    -- Summoning; an Infernal Stone for Inferno, a Demonic Figurine for
    -- Ritual of Doom. The wheel shows what is missing; the bar greys out.
    REAGENT = {
        [697] = 6265, [712] = 6265, [713] = 6265, [691] = 6265,
        [6201] = 6265, [6202] = 6265, [5699] = 6265, [11729] = 6265, [11730] = 6265,
        [693] = 6265, [20752] = 6265, [20755] = 6265, [20756] = 6265, [20757] = 6265,
        [698] = 6265,       -- Ritual of Summoning
        [1122] = 5565,      -- Infernal Stone
        [18540] = 16583,    -- Demonic Figurine
    },
    IMP = 688,

    -- Each demon's voice on the wheel (hover and click), by file ID: the
    -- summon lines the owner picked (succubusvo, doomguardvo) and the same set
    -- for the Voidwalker, from the community listfile. The Imp has no summon
    -- lines (impvo: order, dismiss, kill), so its "order" ones; the Felhunter
    -- and the Infernal don't speak (felhound and infernal sounds); Forever's
    -- Incubus only has Shadowlands-era lines (vo_92_incubus_*): candidates.
    VOICE = {
        [697] = { 563819, 563812, 563814, 563817 },    -- void_summon01-04
        [712] = { 561163, 561168, 561157, 561154 },    -- succubus_summon01-04
        [18540] = { 547320, 547328, 547335, 547332 },  -- doom_summon01-04
        [688] = { 552530, 552533, 552522, 552521 },    -- imp_order01-04
        [691] = { 548856, 548852, 548858 },            -- felhound stand roar, pre-aggro, aggro
        [1122] = { 552542 },                           -- minfernalaggroa
        [713] = { 4278423, 4278424, 4278425, 4278426 },-- vo_92_incubus_01-04
    },

    -- The "Reagent Economy" perk (Resourcefulness legacy tree): "Your class
    -- abilities no longer require reagents purchasable from vendors". Its
    -- spell IDs, one per class, from Portal Roulette's probe; which one is
    -- the Warlock's is unmeasured, so any of them counts. Only vendor
    -- reagents go: the Infernal Stone and the Demonic Figurine, not Soul
    -- Shards (they come from Drain Soul).
    REAGENT_ECONOMY_SPELLS = { 1225503, 1262636, 1262638, 1262643, 1262647, 1262650, 1262654, 1262662 },
    VENDOR_REAGENTS = { [5565] = true, [16583] = true },

    -- The active pet's NPC id (from its GUID) -> its summon spell, so the
    -- Demon button follows the demon that is out. Imp 416 and Voidwalker 1860
    -- measured on 70334 (#17); Succubus and Felhunter are Vanilla's NPC ids,
    -- the Incubus Wowhead's Forever database's.
    DEMON_NPC = {
        [416] = 688,     -- Imp
        [1860] = 697,    -- Voidwalker
        [1863] = 712,    -- Succubus
        [185317] = 713,  -- Incubus (Forever)
        [417] = 691,     -- Felhunter
    },

    -- Armor families, preferred first, each highest rank first. The button
    -- casts the best known rank of the first family known; any rank of THAT
    -- family on the player counts as wearing it (#7). Rank numbers do not
    -- compare across families. TBC's Fel Armor (28176) does not exist on
    -- Forever. Fel Armor 403619 is in Forever's database, probably a Season of
    -- Discovery leftover (like the Grimoire's 402265): it joins this list only
    -- once `/fp 123 book` shows it known and castable.
    ARMOR = {
        { 11735, 11734, 11733, 1086, 706 },     -- Demon Armor
        { 696, 687 },                           -- Demon Skin
    },

    -- The wheel (#4). Fel Domination is cast before a summon on shift-click.
    -- Demonic Sacrifice is a talent; Forever's effects differ from Vanilla's
    -- (#4), so they are read from the spell's own description. The
    -- Voidwalker's own Sacrifice is a pet action (run 2: pet bar slot 5).
    FEL_DOMINATION = 18708,
    DEMONIC_SACRIFICE = 18788,
    VOIDWALKER_SACRIFICE = 7812,

    RITUAL_OF_SUMMONING = 698,

    SOUL_SHARD = 6265,

    -- Stones by tier, strongest first (#6): the spell that creates the tier
    -- and the items it makes. Every stone is "Unique" per item in Forever's
    -- client data (References/Forever/consumables/forever-consumables-1.60.1.70009.tsv), so a
    -- lower rank carried shouldn't stop a higher one being created; that the
    -- client allows it is still to confirm in game (FOREVER-PROBE.md).
    -- Within a tier, items are strongest first by that data's heal values:
    -- the base stone ties the best Improved Healthstone variant and the
    -- other heals less (Major 1440 / 1440 / 1320 ... Minor 120 / 120 / 110).
    -- All healthstone ranks share one cooldown (Apotheca; to confirm, #1).
    HEALTHSTONE_TIERS = {
        { create = 11730, items = { 9421, 19013, 19012 } },  -- Major
        { create = 11729, items = { 5510, 19011, 19010 } },  -- Greater
        { create = 5699, items = { 5509, 19009, 19008 } },   -- Healthstone
        { create = 6202, items = { 5511, 19007, 19006 } },   -- Lesser
        { create = 6201, items = { 5512, 19005, 19004 } },   -- Minor
    },
    SOULSTONE_TIERS = {
        { create = 20757, items = { 16896 } },  -- Major
        { create = 20756, items = { 16895 } },  -- Greater
        { create = 20755, items = { 16893 } },  -- Soulstone
        { create = 20752, items = { 16892 } },  -- Lesser
        { create = 693, items = { 5232 } },     -- Minor
    },
}
