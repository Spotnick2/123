# 123 — design

Target: `docs/mockups/storyboard.png`. Spell availability is still to be measured
(`docs/FOREVER-PROBE.md`); nothing below relies on an unmeasured API.

## Compact bar
One small glass bar, Apotheca-style: **Demons** (the wheel), **Demon**, **Armor**, **Soulstone** (assigned target under the
icon), **Healthstone** (count), **Summoning**, then the soul shard count. Shift-drag moves it.
No names under the icons unless `/123 labels` (the tooltips say it). Out of Soul Shards, the
Demon button summons the Imp (the one demon that needs none) until shards come back, and the
buttons that would spend one (create a stone, Ritual of Summoning) grey out.
Every button is a stationary secure button; visuals refresh in combat, attributes only out of it.

- **Armor**: the highest learned rank of the preferred armor spell (Demon Armor over Demon Skin;
  any Forever armor only once measured). Spell choice refreshes on `SPELLS_CHANGED`; the "missing"
  glow comes from the player's auras, checked at login and on aura updates.
- **Stones** (#6): use the best stone carried (that the player can use), else create the best
  rank known. `Data.HEALTHSTONE_TIERS` / `SOULSTONE_TIERS` pair each create spell with its items.
  Creating a better rank while carrying a lesser one (right click) waits for a measurement, #31.
  Trading a healthstone is #8.

## Demon wheel
The owner's "Fel concept" mockup (`docs/mockups/wheel-fel.png`): very close to Portal Roulette, fel
green. The bar's first button, "Demons" (Fel Domination's icon, like Retail's Summon Demon flyout),
opens it, as do `/123 wheel` and its key binding. The Demon button summons the last demon (asking
first when it is out); its right click is Demonic Sacrifice while a demon is out and the talent
is known (no reopening the wheel to sacrifice), otherwise the same summon. Key bindings click the
bar's buttons: summon, Sacrifice-or-summon, Armor, Soulstone, Healthstone, Ritual of Summoning.
- Seven beads on a ring, clockwise from 12: Voidwalker, Felhunter, Inferno, Doomguard (Ritual of
  Doom), Imp, Succubus, Incubus. Each bead is the demon's live, idling face (a PlayerModel through the
  creature's own portrait camera: GlassUnitFrames' recipe, `UI/Portrait.lua`), else the icon. A
  model can't be masked, so it sits in the square inscribed in the bead, under an opaque ring
  (`Media/Wheel_Node_256.tga`, `Tools/make_wheel_art.py`) whose hole is that square's inscribed circle.
  Not learned yet: greyed, "Not learned", no action.
- It opens two thirds of the way across the screen, not centred.
- Hovering or clicking a demon plays one of its lines (`Data.VOICE`, file IDs on the Dialog
  channel; a new line cuts the last): the summon lines for the Voidwalker, Succubus and Doomguard,
  the Imp's "order" lines, the Felhunter's and Infernal's roars, Shadowlands lines for the Incubus.
  `/123 sounds` turns them off.
- The centre: the active demon in 3D (AltStable's recipe: NPC id from the pet GUID, display ID
  through a PlayerModel, ModelScene actor), its name, the pet's name, "Active". Its bead stays on
  the ring, marked active; clicking it asks first (the re-summon prompt).
- Click summons and closes the wheel; shift-click casts Fel Domination first, once learned (not
  for Inferno or Ritual of Doom).
- Right-click the centre: Demonic Sacrifice when the talent is known, else the Voidwalker's own
  Sacrifice (a pet action on its bar slot). A left click there does nothing.
- The strip under the ring: soul shards, and what the hovered bead does (with Demonic Sacrifice,
  the active demon's line of its description: Forever's effects differ from Vanilla's).
- Reagents: a learned bead whose reagent is missing says so ("No Soul Shard": every summon but
  the Imp); Inferno and Ritual of Doom show their count (Infernal Stone, Demonic Figurine).
- With the "Reagent Economy" perk (any class's spell ID, as Portal Roulette detects it), vendor
  reagents are free: no Infernal Stone or Demonic Figurine count. Soul Shards still count.
- Forever's Incubus is its own demon: Summon Incubus 713, NPC 185317 (Wowhead's Forever database;
  713 confirmed in game). A pet with an unknown NPC id (an Infernal, a Doomguard) is shown by its
  family, never becomes the Demon button's demon, and gets no Sacrifice.
- `/123 preview` (Portal Roulette's `/pr preview`): every demon lit, nothing armed, no reagent
  warnings, "PREVIEW" under the title; a click puts that demon in the centre (model, name, voice),
  for screenshots on any level. The Demon button's remembered demon is untouched.
- Opening hides the game UI and runs the cinematic camera through LibShowcase-1.0
  (`UI/Presentation.lua`, from Portal Roulette); `/123 camera` turns both off. Escape, the close
  button, a cast or combat closes it.
- Wheel art and motion (#13): a horned metal crest, charcoal field, etched rune band, slow fel
  smoke and falling embers, opaque carved portrait rims, dark name plates and hint strip. The
  central model stands over a flattened summoning sigil; its own fire remains the game's effect.
  `UI/WheelEffects.lua` owns the decorative layers and one WorldFrame clock (so UI hiding does
  not freeze it). Opening ignites the field and then the nodes clockwise over 0.58 s; hover
  eases in/out over 0.16/0.24 s and grows the visual by 12% (inspired by Portal Roulette's Hearthstone);
  the active rim breathes over 2.8 s. The outer runes sway four degrees out and back,
  two seconds each way with eased reversals, matching Portal Roulette. Closing extinguishes over
  0.30 s, with a final pulse on a clicked summon. Input stops immediately; combat, loading and
  logout bypass animation. Secure positions, sizes and spells are unchanged.
  Art regenerates with `python Tools/make_wheel_art.py`; `python Tools/preview_wheel.py` builds
  an approximate offline study in `.release/`, with placeholders for the live models. The
  sacrificed-demon frame colour is ready for #20's measured `node.sacrificed` state; no buff
  detection is inferred here. Options/gear wiring belongs to #15.
  The first in-game art review added a sculpted crest (`Tools/Art/Crest/crest-fel-v2.png`),
  cloudy smoke, stronger metal bevels, a darker centre and backed status lines for crowds.
  Capture tuning strengthened hover growth and reduced smoke layer opacity by about 38%,
  keeping the runes, active rim and central fire distinct.
  LibShowcase r4 hides world names while the cinematic presentation is up and restores
  the player's CVar values when it ends. Nameplates are unaffected.

## Smart Demonic Sacrifice
- (#20, `Core/Sacrifice.lua`) The buff is followed from its cast: `UNIT_SPELLCAST_SUCCEEDED` for
  18788, the demon out at `_SENT`, saved per character (`ns.char.sacrifice`, `time()`), 2 hours.
  Out of combat, 3 s after the cast, the aura (`Data.SACRIFICE_BUFF`, by ID or the client's
  name) confirms it, and a buff gone is forgotten; in combat the estimate stands. Dying ends it.
  Its end (the player's `UNIT_AURA`, a timer for the two hours) rebuilds the bar and the wheel.
- A summon ends it: any pet demon, or with Demonic Pact (425464) only the sacrificed one. The
  Demon button (`Bar:HoldsDemon`) and the wheel's beads hold such a summon and ask first
  (`ns.Resummon`, which names the buff and has no "Don't ask again" for it). A summon that goes
  through anyway (`UNIT_PET`) ends it, in combat too.
- With Demonic Pact and a pair picked in Options (per character; the demon to keep skips the one
  to sacrifice), the Demon button's right click walks it: summon A, Demonic Sacrifice, summon
  B, then unarmed. Each step is re-armed out of combat. IDs from Wowhead's Forever database:
  ledger row 12.

## Soulstone target
- (#5, `Core/SoulTarget.lua`, `UI/SoulPicker.lua`) The Soulstone button's right click (unarmed:
  no `type2`) opens a glass list above it: you, then the group, class colours, the pick marked,
  "Clear". Saved per character on the GUID (`ns.char.soulTarget`).
- A carried soulstone's action gets `unit1` = the pick's token, read at each rebuild out of
  combat (so a reshuffle follows the same person). Creating a stone has no unit. In combat the
  unit comes off (`SA.inCombat`), also when unreadable counts keep the armed stone (KEEP): the
  stone goes to the target. The pick's first name sits on the icon, in class colour while the
  stone goes to them, grey otherwise.
- Someone gone from the group (`GROUP_ROSTER_UPDATE`) is cleared and 123 says so; never
  retargeted. Item action on a unit: unmeasured (ledger row 5).

## Healthstone request
- (#8, `Core/Requests.lua`, `UI/StonePrompt.lua`) A keyword (`db.stones.keywords`, default "hs",
  "healthstone") as the whole message, compared as the summon queue does, in party / raid /
  instance chat or a whisper. Keyed on GUID (12th payload), oldest first; asking again refreshes.
  A whisper from outside the group asks only with `db.stones.strangers` (off); trading them
  needs them targeted.
- A glass prompt above the Healthstone button (UIParent, `Bar:TopOf`; not secure): "Open trade"
  (`InitiateTrade` on their token, or "target"), then, once `TRADE_SHOW`'s `NPC` GUID is theirs,
  "Place the healthstone" (the best carried, any rank: pickup, `ClickTradeButton` into the first
  free slot, the cursor cleared if it didn't land). The player accepts in the game's window. A
  trade they open counts too. Two clicks, as run 2 measured (placing from `TRADE_SHOW` alone was
  inconclusive).
- Ends when a trade with them closes after the stone was placed, when they leave the group,
  after 5 minutes, or by Skip. `/123 hs test` shows the prompt alone.

## Summon queue
- Intake (#9, `Core/Queue.lua`): "123" plus an editable keyword list in PARTY / RAID /
  INSTANCE_CHAT (and their _LEADER events). The whole message must be a keyword, compared lower
  case, trimmed, trailing `! ? .` dropped. The sender must be a group member, found by the chat
  GUID (12th payload) among `partyN` / `raidN`; the player and an unreadable GUID are skipped.
  Keyed on GUID, oldest first; asking again keeps the place and refreshes the time. Dropped on
  `GROUP_ROSTER_UPDATE` when gone from the group, after `db.queue.timeout` minutes (a 10 s
  ticker, only while someone waits), or by the row's x. "Retry" belongs with execution (#10).
- List (`UI/QueueList.lua`): a glass list above the Summoning button, under UIParent at
  coordinates read off the button (never anchored to the bar, which is protected), so it updates
  in combat. Name in class colour, wait time, x; eight rows, then "and N more".
- Solo test: `/123 queue test` runs "123", "123!" and "1234" from made-up members through the
  same matching; test entries skip the roster check.
- Execution (#10): the Summoning button's `unit1` is `Queue:Next()`, the first entry that is not a
  test, has no summon state, isn't near (30 yd, `UnitDistanceSquared`) and is in the group, read
  at sync time. Rebuilt on queue change (`MarkDirty`) and **at once** on `GROUP_ROSTER_UPDATE`
  (`RunSyncs`), so no click meets a stale token. In combat (`SA.inCombat`, set before the
  `PLAYER_REGEN_DISABLED` sync) the unit comes off: the ritual casts on the target.
- Lifecycle (`Core/Summon.lua`): a ritual starts at `UNIT_SPELLCAST_START` / `_CHANNEL_START`
  (not `_SENT`: a refused cast announces nothing), on the member the button was clicked for
  (PostClick, 2 s), else the `_SENT` target name, else the target. States: "summoning", then
  `IncomingSummonStatus` Pending / Accepted / Declined. Pending going back to None is waiting
  again, as is a ritual that ends with no prompt (3 s). Dropped only on measured signals:
  accepted and then near, or gone from the group (and the timeout); unreadable status or
  distance keeps them. Asking again after declining puts them back in line.
- Announcements (#11, `Core/Announce.lua`): at the ritual's start, "Summoning {name}, please
  click the portal" (on) and "Need 2 clickers for the summon" (off; only when fewer than two
  others are within 30 yd, and never when a distance is unreadable). Instance, raid, then
  party chat; nothing solo; each at most every 10 s. Blank saved text means the default in the
  client's language.

## Portal of Summoning
Grimoire of Portal of Summoning (item 216748; its use-spell 402265 is the generic "Learning" teach spell, not the portal) is in the database; whether it is
live is unknown (its IDs look like Season of Discovery leftovers in Forever's database). Everything about it is hidden unless the spell is known; its own spell ID is still to be measured.

## Options, minimap, sounds (#14, #15)
- **Options > AddOns > 123** (`Options/Options.lua`): a Settings canvas category, built on first
  show, Portal Roulette's widgets (checkboxes, cycling buttons, steppers; no dropdown). A bar
  change (shown, scale, labels) is refused in combat and the page re-reads the saved value.
  The bar's shown state and scale are saved in `db.bar`.
- **Minimap** (`UI/Minimap.lua`): LibDataBroker + LibDBIcon (vendored) and the Addon
  Compartment. Click: the wheel; shift-click: the bar; right-click: options.
- **Sounds** (`Core/Sound.lua`): only what the game doesn't already announce. Spells (a summon,
  the Ritual, a stone) sound in game, so they get none; a summon request and a healthstone request
  do, each a client sound kit picked by ear on the options page (a refused kit says so),
  throttled to one per burst. The demons' voices stay with the wheel.

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
