# 123 — what is measured on WoW: Forever

Run the probe on a Warlock: `pwsh Tools/deploy.ps1 -Probe`, restart the client (a new addon folder),
`/console scriptErrors 1`, then the `/123probe` commands below. Results print in chat and are saved
to `WTF\Account\<id>\SavedVariables\OneTwoThreeProbe.lua` on `/reload` or logout, one entry per
session under `runs` (earlier sessions are kept).

Status: **OPEN** (not measured), **MEASURED** (build + date), **PARTIAL**.

API reference: `forever-api-1.60.1.70374.md` (2026-10-15). Against 70338 (and 70291 before it)
its documented API is identical (6604 functions, 1810 events); the `_G` walks differ only by Blizzard UI and addons loaded at dump
time. Every global 123 uses is unchanged.

| # | Question | Probe | Issue | Status |
|---|---|---|---|---|
| 1 | Warlock spell IDs: learned ranks vs. existing IDs for demons, Fel Domination, Demonic Sacrifice, Soul Link, armors, Create Healthstone / Soulstone, Ritual of Summoning, Portal of Summoning (spell ID unknown; 402265 is only the Grimoire's "Learning" teach spell) | `book` | #1 | PARTIAL (run 2: low level) |
| 2 | Active pet: GUID NPC id, family, pet bar | `pet` | #1 | PARTIAL (run 2: Voidwalker) |
| 3 | Stones and shards: item IDs created, counts, cooldowns, item spells, cache misses | `stones` | #1 | PARTIAL (run 2) |
| 4 | Ritual of Summoning: channel start / stop / success, `INCOMING_SUMMON_CHANGED` and `IncomingSummonStatus` through accept, decline, timeout, arrival | `watch on` | #1 | OPEN (needs a Warlock with Ritual) |
| 5 | Secure `unitN`: Ritual as a spell action, Soulstone as an item action, both click edges, in combat, after a roster reshuffle | `secure <unit>` | #2 | OPEN (needs Ritual or a soulstone) |
| 6 | Trade: `InitiateTrade` from a click, `TRADE_SHOW` recipient, placing a stone from the event vs. from a click | `trade <unit>`, `tradeitem <id>` | #2 | PARTIAL (run 2) |
| 7 | Chat: PARTY / RAID / INSTANCE_CHAT sent typed vs. from a timer, seen by another player; incoming sender name / GUID, group and non-group whispers | `say <chan>`, `watch on` | #2 | PARTIAL (run 1) |
| 8 | Range and position for group members (near, far, offline, instanced): `UnitPosition`, `UnitDistanceSquared`, `CheckInteractDistance`, `UnitIsVisible`, `UnitInRange`, map, spell range | `range` | #2 | PARTIAL (runs 1–2: far and near, open world) |

## Run 1 — build 70334, 2026-10-09, open world, party of 2

Player in Dun Morogh, party1 in Stormwind (about 2500 yd away), both on Eastern Kingdoms, no instance.
The Warlock account's results were lost to a probe bug (fixed: results after a `/reload` went to a
table nothing saved), so rows 1–6 need a re-run (row 4 once the Warlock has Ritual).

**Range (row 8), all readable (not secret) unless noted:**
- `UnitPosition("player")` / `("party1")`: plain x, y, 0, instance 0.
- `UnitDistanceSquared("party1")`: `6380325, true`.
- `CheckInteractDistance(party1, 4)`: `false`.
- `UnitIsVisible`: `false`.
- `C_Map.GetBestMapForUnit`: player 1426 (Dun Morogh), party1 1453 (Stormwind).
- `UnitInRange`: **secret, both returns**, as GlassRaidFrames measured.
- `C_Spell.IsSpellInRange(5697, party1)`: `nil`, because that character doesn't know the spell.
- `C_IncomingSummon.IncomingSummonStatus("party1")`: `0` (None), readable.

Still open: near (same spot), offline, inside an instance.

**Chat (row 7):** `C_ChatInfo.SendChatMessage(..., "PARTY")` raised no error either typed or from a
1 s timer. Still open: whether the other player received both.

## Run 2 — build 70334, 2026-10-09, low-level Warlock, open world, party of 2

**Spells (row 1).** Forever keeps Vanilla's IDs. `C_SpellBook.IsSpellKnown` and `IsPlayerSpell` agreed on every ID.
- **Known at this level:** Summon Imp 688, Summon Voidwalker 697, Demon Skin 687 and 696 (each rank is its own spellbook entry), Create Healthstone (Minor) 6201, Create Soulstone (Minor) 693, Unending Breath 5697.
- **Exist but not learned yet:**
  - Summon Succubus 712, Summon Felhunter 691, Inferno 1122, Ritual of Doom 18540
  - Fel Domination 18708, Demonic Sacrifice 18788, Soul Link 19028
  - Ritual of Summoning 698
  - Demon Armor 706 / 1086 / 11733 / 11734 / 11735
  - Create Healthstone 6202 / 5699 / 11729 / 11730
  - Create Soulstone 20752 / 20755 / 20756 / 20757
- **Fel Armor 28176 does not exist.** The armor line is Demon Skin, then Demon Armor. Fel Armor **403619** is in Forever's database (Wowhead), probably a Season of Discovery leftover, as the Grimoire's 402265 may be; it may never ship. `book` now lists it; the bar uses it only once it is measured known and castable.
- **The spellbook has a "Summon Demon" entry with a nil spell ID** (Demonology), next to the individual summons. It is probably a flyout; to be checked before the wheel relies on it.
- **Stones are unique per item** in Forever's client data (`forever-consumables-1.60.1.70009.tsv`: every healthstone and soulstone "Unique"). Still to confirm in game: creating a higher rank while carrying a lower one (#31, the stone buttons' right click; not shipped until measured). Heal values from the same data: the base stone ties the best Improved Healthstone variant (Major 1440 / 1440 / 1320).
- **Demonic Sacrifice is 18788 on Forever** (owner, 2026-10-10): with the talent taken, the wheel's right-click on the centre (spell 18788) sacrificed the demon. Its buff IDs per demon: `/123probe auras` after a sacrifice (#20).
- **Incubus (Forever):** Summon Incubus 713, level 20 from the quest "The Binding", summons NPC 185317 (Wowhead's Forever database). `book` lists 713; the NPC id is confirmed with `pet` once it is learned.
- **402265 is "Learning"**, the Grimoire's teach spell (item 216748 uses it). The Portal of Summoning spell ID itself is still unknown.

**Pet (row 2), Voidwalker "Hathnos":**
- GUID `Pet-0-...-1860-...` gives NPC 1860; `UnitCreatureFamily` returns `Voidwalker, 16`.
- `HasPetUI` returns `true, false` (not a hunter pet); `PetHasActionBar` returns true.
- Pet bar slot 5 is **Sacrifice (7812)**, the Voidwalker's own Sacrifice. Slot 4 is Torment 3716, slot 6 Consume Shadows 17767.
- So the wheel's Sacrifice pill is the Voidwalker pet action, while Demonic Sacrifice 18788 is a separate talent spell.

**Stones (row 3):**
- Minor Healthstone 5512: count 1. Soul Shard 6265: count 0.
- Item use-spells: healthstones 6262 / 6263 / 5720 / 5723 / 11732 (improved variants 23468–23477); soulstones 20707 / 20762 / 20763 / 20764 / 20765.
- `C_Container.GetItemCooldown` is readable out of combat: `0, 0, 1`, and `0, 0, 0` for the shard, which has no use.
- Still open: whether all healthstone ranks share one cooldown (needs one in use), in-combat readability, and shard consumption.

**Trade (row 6):**
- `InitiateTrade("party1")` from a click opens the trade.
- The `TRADE_SHOW` recipient is readable through the `NPC` unit: `Warthallas, Juliastus`, GUID `Player-4613-...`.
- **Placing from a click works:** `C_Container.PickupContainerItem` puts the stone on the cursor, `ClickTradeButton(1)` drops it in, and `TRADE_PLAYER_ITEM_CHANGED 1` fires.
- **Placing from `TRADE_SHOW` without a click: inconclusive.** The pickup left nothing on the cursor and the slot stayed empty, but the stone may still have been locked by the earlier trade. Re-test with a fresh trade.
- The run had no `TRADE_ACCEPT_UPDATE` before `TRADE_CLOSED`, so the trade was not accepted.

**Range (row 8), near:**
- party1 about 4.6 yd away (`UnitDistanceSquared` 21).
- `CheckInteractDistance` 4: true. `UnitIsVisible`: true. `C_Spell.IsSpellInRange(5697)`: true.
- Same map (1453). `UnitInRange` is still secret.

Already measured elsewhere (do not re-probe): see `docs/DESIGN.md` and
`C:\Projects\WoW\References\PORTING-TBC-TO-FOREVER.md`.
