# Changelog

## Unreleased
- The bar's buttons get framed icons with state colours: grey for unlearned abilities,
  red for missing reagents, a purple pulse for missing armor, and a fel-green pulse
  when people are waiting for a summon. Hover highlights, a dotted handle grip, and
  a fading shard divider complete the bar's new look (#13).
- French and German (#22): every text of 123 (bar, wheel, prompts, options, key bindings,
  messages) follows the game's language. Demon names now come from the game, so the wheel
  shows "Diablotin" or "Wichtel" instead of the whole summon spell, and Demonic Sacrifice's
  effect line is found on every client. Other languages show English for now.

## v0.3.0 (2026-10-18)
The summon queue, and releases on GitHub and Wago Addons as well as CurseForge.
- Summon queue (#9): anyone in the group who types "123" (or one of your keywords) in party,
  raid or instance chat joins a list above the Summoning button, with a sound. Exact matching,
  one place per person, dropped on leaving the group, after a timeout or by hand. Keywords and
  timeout in the options; `/123 queue test` tries it alone.
- Embeds LibGlass-1.0 r10 (opt-in additions only; 123's look is unchanged).
- On any class but Warlock, nothing of 123 runs (#39): every file stops on its first line, so
  there's no frame, event or command, and its key bindings do nothing.
- Every version is now also on Wago Addons (the Wago app installs and updates it) and a GitHub
  release with `release.json`, which addon managers such as WowUp read (#42).

## v0.2.0 (2026-10-15)
Smart stones, an options page and a minimap button, on LibGlass's clean glass.
- Smart stones (#6): Healthstone and Soulstone use the best stone carried that you can use (a
  traded higher-level stone is skipped until you reach its level), else create the best rank known.
- The bar uses LibGlass's clean glass (thin rims, no grain, a softer shadow), like the other Glass
  addons. Embeds LibGlass-1.0 r8 (was r5).
- Options page (#15) in Options > AddOns > 123: show, scale and reset the bar, names under the
  icons, the demon wheel's camera and confirm, demon voices, alert sounds, the minimap button.
  `/123 options` opens it. The bar's shown or hidden state and its scale are saved.
- Minimap button and Addon Compartment entry (#15): click for the demon wheel, shift-click to show
  or hide the bar, right-click for options.
- Alert sounds (#14): a sound per alert (summon request, healthstone request), picked by ear on
  the options page. They sound once those features land.
- The licence file now lists exactly the libraries that ship, with their licence texts.

## v0.1.0 (2026-10-10)
First public release: the compact bar, the armor reminder and the demon wheel. Group utilities
(healthstone requests, the summon queue) come next.
- `/123 preview`: the wheel with every demon shown and nothing cast; a click puts a demon in the
  centre, for screenshots on any level.
- Compact bar (#3): Demon (the demon last out), Armor (best rank known), Soulstone and Healthstone
  (use the stone carried, else create the best rank known), Summoning (Ritual of Summoning) and the
  soul shard count. Secure buttons, rebuilt out of combat; shift-drag the "123" handle to move it.
- Clicking Demon while that demon is out asks first ("Summon it again?"), with "Don't ask again";
  `/123 confirm` turns the question back on. No question in combat.
- Armor (#7): glows while the armor it casts is not on you (any rank of that armor counts; Demon
  Skin doesn't count once Demon Armor is learned). No glow in combat, where buffs can't be read.
  Fel Armor 403619 (in Forever's database) waits until it is measured.
- Demon wheel (#4), on the "Fel concept" mockup: left-click Demon opens it (right-click
  re-summons). Seven demons on a fel ring (Forever's Incubus, Inferno and the Doomguard included),
  each bead a live animated portrait that speaks its demon's lines on hover and click, the active one in 3D in the centre, two thirds across the
  screen, shift-click for Fel Domination, right-click the centre for
  Sacrifice, reagents shown where missing, a strip with shards and hints. Opens with LibShowcase's
  cinematic camera and hidden game UI (`/123 camera` to turn off); closes on Escape, a cast or
  combat.
- The re-summon prompt grows with its text (it overflowed).
- A "Demons" button opens the wheel; the Demon button summons (right-click: Demonic Sacrifice
  while a demon is out and the talent is known). Key bindings for both clicks and for Armor,
  Soulstone, Healthstone and Ritual of Summoning.
- Out of Soul Shards: the Demon button summons the Imp until shards come back, and Soulstone,
  Healthstone (when they would create a stone) and Summoning grey out.
- The names under the bar's icons are off by default (the tooltips say it); `/123 labels` shows them.
- Scaffold: the Warlock-only glass bar loads, `/123` and `/123 debug`, key binding.
