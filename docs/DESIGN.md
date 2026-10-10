# 123 — design

Target: `docs/mockups/storyboard.png`. Spell availability is still to be measured
(`docs/FOREVER-PROBE.md`); nothing below relies on an unmeasured API.

## Compact bar
One small glass bar, Apotheca-style: **Demon**, **Armor**, **Soulstone** (assigned target under the
icon), **Healthstone** (count), **Summoning**, then the soul shard count. Shift-drag moves it.
Every button is a stationary secure button; visuals refresh in combat, attributes only out of it.

- **Armor**: the highest learned rank of the preferred armor spell (Demon Armor over Demon Skin;
  any Forever armor only once measured). Spell choice refreshes on `SPELLS_CHANGED`; the "missing"
  glow comes from the player's auras, checked at login and on aura updates.
- **Stones**: create the best known rank when none is carried, otherwise use / trade it.

## Demon wheel
Left-click on the Demon button (or `/123 wheel`, or its key binding) opens it; right-click
re-summons the last demon. In combat the wheel can't open, so both clicks summon.
- The demons you can switch to spread evenly over the top arc, 9 to 3 (Succubus, Incubus, Imp,
  Voidwalker, Felhunter, left to right); with none out, all five spread from 8 to 4. The active demon is the centre, a 3D portrait (AltStable's
  recipe: NPC id from the pet GUID, display ID through a PlayerModel, ModelScene actor), never
  offered again. Not learned yet: greyed out, no action.
- Click summons and closes the wheel; shift-click casts Fel Domination first, once learned.
- The pill under the centre: Demonic Sacrifice when the talent is known, with the active demon's
  line of its description (Forever's effects differ from Vanilla's); otherwise the Voidwalker's
  own Sacrifice, a pet action on its bar slot.
- Opening hides the game UI and runs the cinematic camera through LibShowcase-1.0
  (`UI/Presentation.lua`, from Portal Roulette); `/123 camera` turns both off. Escape, the close
  button, a summon or combat closes it.
- Forever's Incubus is its own demon: Summon Incubus 713, NPC 185317 (Wowhead's Forever database,
  unmeasured). A pet with an unknown NPC id is shown by its family and every demon stays on offer.
  Art and animation: #13.

## Soulstone target
Assign a group member (GUID), then cast explicitly. The secure `unitN` is rebuilt on roster
change out of combat; a stale token is cleared, never retargeted.

## Healthstone request
Someone asks (whisper or group chat): a glass prompt offers a trade. The player clicks to open the
trade and to place the stone; the player accepts. Whispers from outside the group follow an
explicit policy (option).

## Summon queue
- Intake: "123" plus an editable keyword list in PARTY / RAID / INSTANCE_CHAT, exact matching,
  deduplicated by GUID, manual remove / retry, timeout.
- Execution: Ritual of Summoning on the next queued member. Members drop off only on measured
  signals (summon accepted and arrived, left the group); "unknown" keeps them.
- Announcements: "summoning X, click the portal" / "need clickers", configurable and throttled.

## Portal of Summoning
Grimoire of Portal of Summoning (item 216748; its use-spell 402265 is the generic "Learning" teach spell, not the portal) is in the database; whether it is
live is unknown (its IDs look like Season of Discovery leftovers in Forever's database). Everything about it is hidden unless the spell is known; its own spell ID is still to be measured.

## Already answered by sibling addons
| Topic | Where |
|---|---|
| Secure buttons, combat rebuild, wheel, Escape proxy | `PortalRoulette/Core/SecureAction.lua`, `UI/Wheel/*` |
| Secure item buttons, bag map, healthstone ranks | `Apotheca/Apotheca.lua` (`ApplySecureItemAttributes`, `BuildBagMap`, `FindBestHealthstone`), `ApothecaItems.lua` |
| Spell range (readable, three-state) | `LibGroupBuffs/LibGroupBuffs.lua` (`IsSpellInRange` helper) |
| Roster loop | `LibGroupBuffs/LibGroupBuffs.lua` |
| Chat events, group broadcast | `GlassChat/Url.lua`, `PortalRoulette/Core/CastTracker.lua` |
| Sounds (kit lists, theme, throttle) | `Gnomesweeper/docs/SOUNDS.md`, `PortalRoulette/Core/Sound.lua` |
| Demon models | `AltStable/Scanner.lua` (`DemonDisplayID`), `Gnomesweeper/docs/MODELS.md` |
| Incoming summon status | `wow-ui-source` `CompactUnitFrame.lua` (`C_IncomingSummon`) |
