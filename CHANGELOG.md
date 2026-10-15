# Changelog

## Unreleased
- Smart stones (#6): Healthstone and Soulstone use the best stone carried that you can use (a
  traded higher-level stone is skipped until you reach its level), else create the best rank known.
- Embeds LibGlass-1.0 r7 (was r5): no change to how 123 looks; a disabled glass surface now dims its
  wash too.

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
