# 123 — what is measured on WoW: Forever

Run the probe on a Warlock: `pwsh Tools/deploy.ps1 -Probe`, restart the client (a new addon folder),
`/console scriptErrors 1`, then the `/123probe` commands below. Results print in chat and are saved
to `WTF\Account\<id>\SavedVariables\OneTwoThreeProbe.lua` on `/reload` or logout.

Status: **OPEN** (not measured), **MEASURED** (build + date), **PARTIAL**.

| # | Question | Probe | Issue | Status |
|---|---|---|---|---|
| 1 | Warlock spell IDs: learned ranks vs. existing IDs for demons, Fel Domination, Demonic Sacrifice, Soul Link, armors, Create Healthstone / Soulstone, Ritual of Summoning, Portal of Summoning (402265) | `book` | #1 | OPEN |
| 2 | Active pet: GUID NPC id, family, pet bar | `pet` | #1 | OPEN |
| 3 | Stones and shards: item IDs created, counts, cooldowns, item spells, cache misses | `stones` | #1 | OPEN |
| 4 | Ritual of Summoning: channel start / stop / success, `INCOMING_SUMMON_CHANGED` and `IncomingSummonStatus` through accept, decline, timeout, arrival | `watch on` | #1 | OPEN |
| 5 | Secure `unitN`: Ritual as a spell action, Soulstone as an item action, both click edges, in combat, after a roster reshuffle | `secure <unit>` | #2 | OPEN |
| 6 | Trade: `InitiateTrade` from a click, `TRADE_SHOW` recipient, placing a stone from the event vs. from a click | `trade <unit>`, `tradeitem <id>` | #2 | OPEN |
| 7 | Chat: PARTY / RAID / INSTANCE_CHAT sent typed vs. from a timer, seen by another player; incoming sender name / GUID, group and non-group whispers | `say <chan>`, `watch on` | #2 | OPEN |
| 8 | Range and position for group members (near, far, offline, instanced): `UnitPosition`, `UnitDistanceSquared`, `CheckInteractDistance`, `UnitIsVisible`, `UnitInRange`, map, spell range | `range` | #2 | OPEN |

Already measured elsewhere (do not re-probe): see `docs/DESIGN.md` and
`C:\Projects\References\PORTING-TBC-TO-FOREVER.md`.
