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
- **Stones**: create the best known rank when none is carried, otherwise use / trade it.

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
  Temporary world-name hiding is tracked in [LibShowcase #14](https://github.com/Spotnick2/LibShowcase/issues/14).

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
