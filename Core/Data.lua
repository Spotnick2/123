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
    DEMONS = {
        688,    -- Summon Imp
        697,    -- Summon Voidwalker
        712,    -- Summon Succubus
        691,    -- Summon Felhunter
    },

    -- The active pet's NPC id (from its GUID) -> its summon spell, so the
    -- Demon button follows the demon that is out. Imp 416 and Voidwalker 1860
    -- measured on 70334 (#17); the others are Vanilla's NPC ids, and Forever's
    -- Incubus is still unknown (#4).
    DEMON_NPC = {
        [416] = 688,    -- Imp
        [1860] = 697,   -- Voidwalker
        [1863] = 712,   -- Succubus
        [417] = 691,    -- Felhunter
    },

    -- Armor families, preferred first, each highest rank first. The button
    -- casts the best known rank of the first family known; any rank of THAT
    -- family on the player counts as wearing it (#7). Rank numbers do not
    -- compare across families. TBC's Fel Armor (28176) does not exist on
    -- Forever. Fel Armor 403619 is in Forever's database, probably a Season of
    -- Discovery leftover (like the Grimoire's 402265); learned-only, so it
    -- changes nothing unless it ships.
    ARMOR = {
        { 403619 },                             -- Fel Armor (Forever)
        { 11735, 11734, 11733, 1086, 706 },     -- Demon Armor
        { 696, 687 },                           -- Demon Skin
    },

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
