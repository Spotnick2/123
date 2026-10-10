-- ============================================================
-- Data: Warlock spell and item IDs. Every list is ordered best first.
--
-- Spell IDs measured on 70334 (docs/FOREVER-PROBE.md run 2: Forever keeps
-- Vanilla's IDs). Item IDs from References/forever-consumables-1.60.1.70009.tsv
-- and Apotheca's ApothecaItems.lua.
-- ============================================================

local _, ns = ...

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
    WHEEL = {
        { spell = 697 },                                -- Voidwalker
        { spell = 691 },                                -- Felhunter
        { spell = 1122, major = true },                 -- Inferno
        { spell = 18540, major = true, label = "Doomguard" },
        { spell = 688 },                                -- Imp
        { spell = 712 },                                -- Succubus
        { spell = 713 },                                -- Incubus
    },

    -- What each summon consumes (Wowhead's Forever database): a Soul Shard
    -- for every demon but the Imp, an Infernal Stone for Inferno, a Demonic
    -- Figurine for Ritual of Doom. The wheel shows what is missing.
    REAGENT = {
        [697] = 6265, [712] = 6265, [713] = 6265, [691] = 6265,
        [1122] = 5565,      -- Infernal Stone
        [18540] = 16583,    -- Demonic Figurine
    },

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
    -- once `/123probe book` shows it known and castable.
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

    CREATE_HEALTHSTONE = { 11730, 11729, 5699, 6202, 6201 },
    CREATE_SOULSTONE = { 20757, 20756, 20755, 20752, 693 },
    RITUAL_OF_SUMMONING = 698,

    SOUL_SHARD = 6265,

    -- By tier, strongest tier first; within a tier the base stone comes
    -- before the Improved Healthstone variants, as Apotheca lists them. Which
    -- heals more within a tier is unmeasured on Forever (#6). All ranks share
    -- one cooldown (Apotheca; to be confirmed in #1).
    HEALTHSTONES = {
        9421, 19013, 19012,     -- Major
        5510, 19011, 19010,     -- Greater
        5509, 19009, 19008,     -- Healthstone
        5511, 19007, 19006,     -- Lesser
        5512, 19005, 19004,     -- Minor
    },

    SOULSTONES = { 16896, 16895, 16893, 16892, 5232 },  -- Major ... Minor
}
