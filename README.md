# 123 — Warlock Summons, Demons & Stones

A small glass bar and a fel demon wheel for Warlocks on **WoW: Forever**: your demons, armor,
soulstone, healthstones and summoning, one click away. In English, French and German, following
the game's language.

![The demon wheel](https://raw.githubusercontent.com/Spotnick2/123/main/docs/screenshots/hero.jpg)

## The bar
![The bar](https://raw.githubusercontent.com/Spotnick2/123/main/docs/screenshots/bar.jpg)

**Demons** · **Demon** · **Armor** · **Soulstone** · **Healthstone** · **Summoning** · **Banish** ·
**Subjugate** | soul shards

- **Demons** opens the demon wheel.
- **Demon** summons your last demon (it asks before re-summoning the one that is out). Its
  right click is **Demonic Sacrifice** once you have the talent, so a Demonologist sacrifices
  from the bar.
- **Armor** casts your best armor (Demon Armor over Demon Skin, highest rank) and glows while
  it is not on you.
- **Soulstone / Healthstone** use the best stone you carry, or create the best one you know.
  **Right-click Soulstone** to pick who gets it (you or a group member): their name shows on
  the icon and the stone goes to them, no targeting. In combat it goes to your target.
- **Summoning** is Ritual of Summoning, on the next in the summon queue (or your target).
- **Banish** and **Subjugate** appear once you learn them (Subjugate Demon is Forever's Enslave
  Demon). Banish counts down from your cast and glows its last 5 seconds; it can't see a break
  before that. Subjugate counts down the most it lasts, alerts you when the demon breaks free
  (it is hostile again), and its right click dismisses the demon (never one of your own).
- Out of Soul Shards, the Demon button falls back to the Imp and the buttons that would spend
  one grey out, until shards come back.
- Shift-drag the "123" handle to move it. Scale, names under the icons and the rest are in
  **Options > AddOns > 123** (or `/123 options`, or right-click the minimap button).

![In the game](https://raw.githubusercontent.com/Spotnick2/123/main/docs/screenshots/ui.jpg)

## The demon wheel
![Hover, click: the Imp takes the centre](https://raw.githubusercontent.com/Spotnick2/123/main/docs/screenshots/wheel.gif)

[The demon wheel in action, with sound (YouTube)](https://www.youtube.com/watch?v=IvxhJ4iC4Sc).

![Three demons in the centre](https://raw.githubusercontent.com/Spotnick2/123/main/docs/screenshots/wheels.jpg)

- Seven demons on a fel ring: Voidwalker, Felhunter, Inferno, Doomguard, Imp, Succubus and
  Forever's own **Incubus**, each a live animated portrait that speaks when you hover it.
- The demon that is out stands in the centre, in 3D.
- Click to summon, **shift-click** for Fel Domination first. **Right-click the centre** for
  Demonic Sacrifice (or the Voidwalker's own Sacrifice); the strip shows its effect.
- Reagents at a glance: "No Soul Shard", Infernal Stones and Demonic Figurines counted
  (free with the Reagent Economy perk).
- Opens with a cinematic camera and the game UI hidden (`/123 camera` to turn it off);
  Escape, a summon or combat closes it.
- `/123 preview` shows every demon without casting: click one to put it in the centre.

## The summon queue
Anyone in your party or raid who types **123** in group chat joins a small list above the
Summoning button, with a sound, in the order they asked.
- The whole message must be the keyword: "123" or "123!" asks; "1234" or "123 dps" doesn't. Add
  your own keywords in the options.
- Asking again keeps your place. You drop off when you leave the group, after 10 minutes
  (adjustable), or when the Warlock clicks the x.
- `/123 queue test` adds two made-up requests, to see it alone.
- The **Summoning** button casts Ritual of Summoning on the first in line who still needs it:
  no targeting. Someone already beside you is marked "here" and skipped. In combat it casts on
  your target instead.
- Each row follows the summon: next, summoning, pending, accepted or declined. People leave the
  list once they accepted and stand beside you; someone who declined stays until they ask again.
- When the ritual starts, 123 tells the group "Summoning <name>, please click the portal".
  It can also ask for clickers when fewer than two others are near (off by default). Both
  texts are yours to change in the options.

## Healthstone requests
Someone in your group types **hs** (or "healthstone", or a keyword of yours) in group chat or
whispers it: a small prompt above the Healthstone button says who asks.
- **Open trade**, then **Place the healthstone**: two clicks, and you accept in the trade window.
  Nothing is given on its own. A trade they open themselves works too.
- Whispers from outside your group are ignored unless you turn them on; then target them first.
- **Skip** drops a request; it also ends after a trade where you placed the stone, when they
  leave the group, or after 5 minutes. `/123 hs test` shows the prompt alone.

## Commands
- `/123`: show or hide the bar (also `/onetwothree`, and a key binding)
- `/123 options`: the options page (Options > AddOns > 123)
- `/123 queue`: how many wait; `/123 queue test` adds test requests, `/123 queue clear` empties it
- `/123 hs`: healthstone requests; `/123 hs test` shows the prompt, `/123 hs clear` empties it
- `/123 wheel`: open the demon wheel (also the bar's "Demons" button, and a key binding)
- `/123 preview`: the wheel with every demon shown and nothing cast; click a demon to put it in
  the centre (screenshots, any level)
- `/123 camera`: open the wheel with or without the cinematic camera and hidden UI
- `/123 sounds`: the demons' voices on the wheel, on or off
- `/123 labels`: show the names under the bar's icons (off: the tooltips say it)
- `/123 confirm`: ask (or stop asking) before re-summoning the demon that is out
- `/123 debug`: client build, load state and what each bar button is armed with
- Minimap button: click for the demon wheel, shift-click to show or hide the bar, right-click for
  options (also in the Addon Compartment)
- Key bindings (Key Bindings > 123): the wheel, summon, Sacrifice-or-summon, Armor, Soulstone,
  Healthstone, Ritual of Summoning, Banish, Subjugate Demon and its dismiss

## Good to know
- Warlocks only: on any other class, 123 loads nothing.
- In combat the game locks what a button does, so the bar keeps what it was armed with as combat
  started. The Summoning button then casts on your target and the Demon button summons without
  asking. The demon wheel closes and can't open, and the bar can't be moved, shown or hidden
  until combat ends.
- 123 writes to group chat on its own only when your ritual starts: the summon announcement
  (on by default) and, if you turn it on, a call for clickers when fewer than two others are
  near. Each has its own switch in the options. It reads party, raid and instance chat for the
  queue's and the healthstone keywords, and whispers for the healthstone ones only. It never
  trades on its own: you open the trade, place the stone and accept.
- Spell, item and demon names come from the game, in its language. Other languages than
  English, French and German show 123's own text in English.

## Coming next
Portal of Summoning and a smarter Demonic Sacrifice. See the
[issues](https://github.com/Spotnick2/123/issues).

## Install
Install **123** from [CurseForge](https://www.curseforge.com/projects/1735903) or
[Wago Addons](https://addons.wago.io/addons/qGYBAONg), or unzip a release from
[GitHub](https://github.com/Spotnick2/123/releases) into the `Interface\AddOns` folder inside
your Forever game folder. Then `/reload`, or start the game.

## Bugs and ideas
In the [GitHub issues](https://github.com/Spotnick2/123/issues). For a bug, `/123 debug` prints
the client build and what each bar button is armed with: paste it in.

## Requirements
WoW: Forever (1.60.1), a Warlock (other classes get nothing). Uses
[LibGlass-1.0](https://github.com/Spotnick2/LibGlass) and
[LibShowcase-1.0](https://github.com/Spotnick2/LibShowcase), embedded, and LibDataBroker /
LibDBIcon for the minimap button.

## Credits
The demons' portraits and voices are the game's own.

## Development
See `AGENTS.md`. Tests: `pwsh tests/run.ps1`. Deploy: `pwsh Tools/deploy.ps1 [-Probe]`.
Screenshots: `python Tools/make_screenshots.py` (names blurred).

## Licence
MIT ([LICENSE](https://github.com/Spotnick2/123/blob/main/LICENSE)).
