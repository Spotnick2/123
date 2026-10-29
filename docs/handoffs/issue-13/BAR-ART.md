# Issue 13: the bar's art and animation (Codex handoff)

Repo `C:\Projects\WoW\123`, issue #13. Branch `feature/13-bar-art` from `main`. Open a PR with
`Closes #13`; the owner reviews and merges. Don't merge it yourself.

The demon wheel's art is done (#24, PR #23). Its record is `START-HERE.txt` in this folder. Read
it first: it is the model for this pass (generator scripts, Media TGAs, an effects module, tests, an
offline preview). This pass does the same for the **compact bar** (`UI/Bar.lua`), and nothing else.

**The game is offline until 2026-11-04.** There is no in-game check for this pass. The offline
preview (step 5) is the only visual review until then. The owner checks it in game afterwards, and
it ships in a beta first. So keep everything tunable from Lua: colours, alphas and timings in one
table, not baked into the art.

## Read first

- `AGENTS.md`: the technical guardrails. They all apply. The ones that matter here are repeated
  under "Hard rules".
- `docs/mockups/storyboard.png`, panel 01: the target look of the bar.
- `docs/handoffs/issue-13/START-HERE.txt`: how the wheel pass was built and validated.
- `UI/Bar.lua`: the bar. `UI/WheelEffects.lua`: the wheel's effects module (state palette,
  `FX.NodeState`, one clock). `UI/Skin.lua`: the glass pill. `Core/Constants.lua`: `ns.Media`,
  `ns.Colors`.
- `Tools/make_wheel_art.py` and `Tools/preview_wheel.py`: the art and preview pipeline to copy.
- API: `C:\Projects\WoW\References\Forever\api\forever-api-1.60.1.70532.md` (the newest dump;
  `AGENTS.md` still names 70450). Check every widget method you call against it.

## What the bar is today

```
[123] Demons · Demon · Armor · Soulstone · Healthstone · Summoning | (shard) 27
```

- A LibGlass "clean" pill tinted Warlock purple (`Skin:Pill`). A plain fallback is drawn when
  LibGlass is missing. Keep the pill and its tint; the bar matches the other Glass addons.
- "123" handle on the left (`Bar:CreateHandle`): text only. Shift-drag moves the bar.
- "Demons" (`Bar:CreateWheelButton`): a plain Button that opens the wheel.
- Five secure buttons (`Bar:CreateButton`), 36 px icons on a 60 px pitch. Each button has these
  parts:
  - the icon (`button.icon`) and a flat white HIGHLIGHT texture at 15%;
  - a `Cooldown` child (`button.cooldown`);
  - a mouse-disabled `overlay` child holding the count (`button.count`);
  - a label under it (`button.label`, off by default).
- Armor only: a placeholder glow (`Bar:CreateGlow`, Blizzard's `ButtonHilight-Square` pulsing
  0.8 s). It is marked "placeholder until the Codex art, #13". Replacing it is part of this job.
- Shard section (`Bar:CreateShards`): a 1 px divider, the Soul Shard icon and the count.
- "Unlearned" and "missing reagent" both look the same today: desaturated icon at 45% alpha
  (`Bar:RefreshButton`). They must become different.

## What to make

### 1. Art: `Tools/make_bar_art.py` → `Media/Bar_*.tga`

Procedural where possible, like the wheel. If a piece needs generated imagery, keep its source and
exact prompt under `Tools/Art/Bar/` (as `Tools/Art/Crest/` does). Output rules are the wheel's:
- deterministic;
- uncompressed, bottom-origin RGBA TGA;
- power-of-two sizes;
- never hand-edited;
- light layers are white RGB with the shape in alpha, so Lua tints them.

Pieces:
1. **Icon frame** (`Bar_Frame_64`): a rounded-square metal rim around a 36 px icon, as in the
   storyboard. It must cover the icon's edge, since the icon is cropped at 0.08–0.92. Draw it
   neutral grey/white so Lua can tint it. One frame serves all six buttons (Demons included).
2. **Rim light** (`Bar_RimLight_64`): the frame's inner and outer edge as a light layer, for state
   colour and hover.
3. **Glow** (`Bar_Glow_128`): a soft square-ish halo around the frame, a light layer. It replaces
   the armor placeholder and also serves the summon pulse.
4. **Handle grip** (`Bar_Grip_32`): the storyboard's two columns of dots, left of "123".
5. **Divider** (`Bar_Divider_8x64` or similar): a fading vertical line for the shard section.

Keep the set small (5 files, a few hundred KiB). Register each texture in `ns.Media`
(`Core/Constants.lua`) as `BAR_FRAME`, `BAR_RIM`, and so on.

### 2. States: `UI/BarEffects.lua`

A new module on the model of `UI/WheelEffects.lua`, listed in `123.toc` just before `UI\Bar.lua`.
Its first line after `local _, ns = ...` is `if ns.skip then return end` (`test_manifest` checks
it). Bar.lua calls it; it owns textures, the palette and the timings.

A button's state comes **only** from what Bar.lua already computes. Add no new API reads.

| State | Read from | Look |
|---|---|---|
| normal | `button.action` set, nothing below | rim in the Warlock purple (`ns.Colors.ACCENT`) |
| hover | the HIGHLIGHT draw layer (no script) | rim light brighter, replacing the flat white 15% |
| unlearned | `button.action == nil` | grey rim, icon desaturated and dim (as today) |
| missing reagent | `button.short` | red rim (the wheel's `missing` red), icon desaturated |
| armor missing | `button.armorState == "missing"` | the glow, pulsing (replaces `CreateGlow`) |
| people waiting | Summoning, `#ns.Queue.entries > 0` | the glow, slow summon pulse in fel green (`ns.Colors.FEL`) |

Precedence when several apply: unlearned > missing reagent > the glows > normal. The "Demons"
button only has normal and hover.

Notes:
- Keep `button.glow` and `button.pulse` on the armor button, with the same meaning:
  `UpdateArmor` and `tests/test_armor.lua` use them. Shown means glowing, and the pulse is not
  restarted while it already plays.
- Queue changes: `ns.Queue:OnChanged(fn)` (`Core/Queue.lua:93`). The queue changes in combat, which
  is when people ask, so this state must update in combat.
- One palette table, like `PALETTE` in `WheelEffects.lua`, plus one table of timings. The owner may
  move the bar to fel green after seeing it. That must be a palette edit, not new art.

### 3. Handle and shard section

- The grip texture left of the "123" text. Keep the text, its colour and the handle's size: the
  handle is the drag area.
- The divider texture instead of the 1 px line. The shard icon gets the same frame as the buttons,
  scaled to its 20 px, if it reads well in the preview; otherwise leave it bare.

### 4. Animation (defaults, tune in the preview)

| Animation | Default |
|---|---|
| armor glow | alpha 1 → 0.35, 0.8 s each way, bouncing (as today) |
| summon pulse | 2.8 s breathing (the wheel's active pulse) |
| hover | rim light fades in 0.12 s, out 0.2 s, only if it can be done without OnUpdate per button; otherwise the instant HIGHLIGHT layer is fine |

No growth or scaling on the bar: its buttons are secure and can't move or scale. Use
`AnimationGroup`s on textures. If a clock is needed, use one for the whole bar, running only while
something animates, on the model of `WheelEffects`.

### 5. Preview: `Tools/preview_bar.py`

It writes `.release/bar-preview.png` (gitignored). The image shows the bar on a dark backdrop and
on a bright one, at scale 1 and 1.5, with each state shown at least once:
- one button unlearned;
- one with a missing reagent;
- armor glowing;
- Summoning pulsing;
- one hovered;
- counts drawn ("3", "27").

Placeholder squares stand in for the icons. Label it "art study, not a game capture", as
`preview_wheel.py` does. A short GIF of the two pulses is welcome. Put the PNG path in the PR.

## Hard rules

- **Secure buttons don't change**: their size, anchor, frame level, template,
  `RegisterForClicks("AnyUp", "AnyDown")`, attributes and scripts (OnEnter/OnLeave tooltips,
  the Demon button's PostClick). They stay the only mouse-enabled frames in their footprint, so
  every new frame calls `EnableMouse(false)`.
- **Combat**: create every frame and texture at load (`Bar:Initialize`), never in combat. In combat
  only change textures' colour, alpha, desaturation, texture and shown state, and play or stop
  animations, on non-secure children. Never Show, Hide, move, scale or reparent the bar or a
  secure button.
- **Secret values**: counts and cooldowns can be secret in combat. They go to the widgets untouched
  (`setCount`, `SA.ApplyItemCooldown`). Never compare them or test their truth for a visual state;
  use the booleans in the table above, which are already safe.
- **Geometry**: keep `ICON`, `PITCH`, `PAD`, `HANDLE_W`, `SHARD_W` and the bar's height.
  `QueueList` places itself off the Summoning button, and players have saved positions. If the art
  truly needs more room, stop and say so in the PR instead.
- **LibGlass**: no changes to the library, no new dependency, and no LibGlass calls outside
  `UI/Skin.lua`. With LibGlass missing (the plain fallback, `tests/test_glass.lua`) the bar must
  still draw and work.
- **Don't touch**: the wheel (`UI/Wheel.lua`, `UI/WheelEffects.lua`, the `Wheel_*` TGAs),
  `Core/SecureAction.lua`, what the buttons resolve to (`RESOLVE`, `Bar:Sync`), the queue logic,
  the options and the probe.
- No StaticPopups. No sounds in this pass.

## Tests

- `pwsh tests/run.ps1` must pass. It runs `luac -p` over every file, then every `tests/test_*.lua`.
- Add `tests/test_bar_effects.lua`, covering:
  - the state precedence;
  - the summon pulse starts and stops with the queue, including in combat;
  - in combat, no Show, Hide, SetPoint, SetScale or SetParent on the bar or a secure button, and
    no frame created (spy on the stubs, as `test_wheel_effects.lua` does);
  - a secret count leaves the state unchanged;
  - every new frame is mouse-disabled and the secure buttons keep their geometry;
  - the plain fallback (no LibGlass) still builds the bar.
- `tests/wow_stubs.lua` errors on any unstubbed global. Stub a new widget method only after
  finding it in the 70532 dump.
- `tests/test_manifest.lua` checks the TOC and the first line of each file. Keep it green.
- Deploy copies git-tracked files only: `git add` the new TGAs, Lua files and tools.

## When done

1. All tests are green. The preview PNG stays out of git (`.release/`) and is attached to the PR.
2. Write `docs/handoffs/issue-13/BAR-NOTES.txt` in the style of `START-HERE.txt`: what was built,
   the asset list and sizes, the palette and timings, and what to check in game.
3. Add a line under a new `## Unreleased` heading at the top of `CHANGELOG.md`. Write it for
   players: "The bar's buttons get framed icons with state colours: …".
4. PR from `feature/13-bar-art` to `main`, body ending `Closes #13`, with the preview attached.
   Include an **in-game checklist** for the owner after 2026-11-04:
   - `/reload` and `/console scriptErrors 1`;
   - each state on a real character (unlearned Ritual, no shards, armor off, `/123 queue test`
     for the summon pulse);
   - hover in and out;
   - enter combat with the armor glowing and the queue pulsing;
   - bar scale 1.5 in the options;
   - `/123 labels` on and off;
   - the bar over bright snow and dark ground.

## Out of scope

- The soulstone target's name under its button: #5 builds it.
- Any wheel change.
- The queue list's look.
- New buttons (Banish and Enslave are #29).
- Localization (#22).
