# Changelog

## Unreleased
- Compact bar (#3): Demon (the demon last out), Armor (best rank known), Soulstone and Healthstone
  (use the stone carried, else create the best rank known), Summoning (Ritual of Summoning) and the
  soul shard count. Secure buttons, rebuilt out of combat; shift-drag the "123" handle to move it.
- Clicking Demon while that demon is out asks first ("Summon it again?"), with "Don't ask again";
  `/123 confirm` turns the question back on. No question in combat.
- Armor (#7): glows while the armor it casts is not on you (any rank of that armor counts; Demon
  Skin doesn't count once Demon Armor is learned). No glow in combat, where buffs can't be read.
  Fel Armor 403619 (in Forever's database) waits until it is measured.
- Demon wheel (#4): left-click Demon opens it (right-click re-summons). The demons you can switch
  to, Forever's Incubus included, around the active one (a 3D portrait), shift-click for Fel Domination, and a Sacrifice pill
  (Demonic Sacrifice, or the Voidwalker's own). Opens with LibShowcase's cinematic camera and
  hidden game UI (`/123 camera` to turn off); closes on Escape, a summon or combat.
- Scaffold: the Warlock-only glass bar loads, `/123` and `/123 debug`, key binding.
