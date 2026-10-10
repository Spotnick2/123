# 123 agent instructions

123 ("123 — Warlock Summons, Demons & Stones") is a Warlock-only smart bar for **WoW: Forever**:
Vanilla content on the Retail (Mainline) API, client 1.60.1, `## Interface: 16001`. It is built on
the architecture and conventions of `C:\Projects\PortalRoulette` (the Mage teleport wheel) and,
for the bar, `C:\Projects\Apotheca`.

Read before changing code:
- `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`: what changed from TBC, measured.
- `C:\Projects\References\forever-api-1.60.1.70291.md`: the client's API (grep it; it is huge).
- `C:\Projects\References\EMBEDDED-LIBRARIES.md`: rules for the embedded libraries.
- `C:\Projects\LibGlass\docs\GLASS-MATERIAL.md`: the glass material.
- `C:\Projects\LibShowcase\docs\DESIGN.md`: the camera presentation when the demon wheel opens.
- `C:\Projects\wow-ui-source`: FrameXML (build 70291).
- `docs/DESIGN.md`: what 123 does. `docs/FOREVER-PROBE.md`: what has been measured for it.
- Sibling addons have already answered a lot (secure buttons, roster, range, sounds, models):
  look there before writing a probe. `docs/DESIGN.md` lists where.

The rule is **measured beats reasoned**. Anything spell-, item-, trade-, chat- or combat-dependent
is confirmed with the dev probe (`Tools/OneTwoThreeProbe`, `/123probe`) before code relies on it.

## Build, test, deploy
- Tests: `pwsh tests/run.ps1` (Lua 5.1 at `C:\Program Files (x86)\Lua\5.1\`): `luac -p` over every
  Lua file, then `tests/test_*.lua` against `tests/wow_stubs.lua`. Reading an unstubbed global is
  an error. Stub a global only after confirming it in the API dump.
- Deploy: `pwsh Tools/deploy.ps1` (`-Probe` adds the dev probe, `-ProbeOnly` deploys just the probe).
  It deploys git-tracked files only (stage new files first) to
  `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`, and LibGlass from the
  sibling checkout `..\LibGlass`.
- A brand-new addon folder needs a client restart; otherwise `/reload`. Enable `/console scriptErrors 1`.

## Workflow
- Issue → branch (`feature/<n>-slug`, `fix/<n>-slug`, `measure/<n>-slug`) → PR with `Closes #N`.
  The owner reviews and merges.
- Adversarial reviews with Codex, when the owner asks: `.claude/skills/codex-consult` (gpt-6-astra,
  high effort), iterated to consensus. Adopt what is simpler or safer; avoid overengineering.
- Art and animation are Codex handoffs (`codex-handoff` label), on the model of
  `C:\Projects\PortalRoulette-Codex-Handoff\START-HERE.txt`.
- Releases: tag `vX.Y.Z` after main's CI is green; CurseForge packages from `.pkgmeta`.

## Naming
- Addon folder and TOC: `123`. Lua identifiers can't start with a digit, so globals, frames and
  SavedVariables use `OneTwoThree` (`OneTwoThreeDB`, `OneTwoThreeBar`, `SlashCmdList.ONETWOTHREE`).
- Slash: `/123` and `/onetwothree`. Chat prefix `123:` in Warlock purple (`9482c9`).

## Technical guardrails (from Portal Roulette, measured)
- Warlock only: other classes get no UI and no commands.
- Secure casting:
  - `SecureActionButtonTemplate` with `RegisterForClicks("AnyUp", "AnyDown")`.
  - Numbered attribute families only (`typeN` + `spellN`/`itemN`/`unitN`). Never unnumbered `type`,
    and **never `typerelease`** (it double-casts and spends two reagents).
  - Secure buttons are stationary and are the only mouse-enabled frames in their footprint. Visuals
    and animations live on mouse-disabled children.
  - Attribute writes happen out of combat, via a coalesced rebuild at `PLAYER_REGEN_ENABLED`
    (`PortalRoulette/Core/SecureAction.lua`). A `unitN` token (`raid5`) can change occupant: rebuild
    on roster change and never let a stale token target the wrong person.
  - No `SecureHandler*`, state drivers or `WrapScript`: they are broken on this client.
- Combat: the parent of secure buttons is protected (no Hide, move, scale or reparent in combat).
  `InCombatLockdown()` is still false inside `PLAYER_REGEN_DISABLED` handlers.
- Secret values (cooldowns, counts and auras in combat; health and power always): never compare,
  truth-test or do arithmetic on an API return without `ns.API.Readable` first. Pass secrets to
  widgets untouched.
- People are keyed on GUID; names are "First Surname" (`GetUnitName(unit, false)`).
- Never use Blizzard StaticPopups (they taint); draw our own glass prompts. Trades are always
  player-initiated and the player accepts them; nothing is delivered automatically.
- SavedVariables load after the addon's files: read them at `PLAYER_LOGIN`, never at file scope.
- Register events through `ns.API.RegisterEvents` (pcall; a false return is a failure).
- Options use the Settings canvas API. There is no UIDropDownMenu.
- Sounds: in-game kits (`PlaySound`, vanilla-era kits) or FileDataIDs; `PlaySoundFile` refuses
  built-in paths. Models: `ModelScene` + `SetModelByCreatureDisplayID`.
- Embedded libraries live in `Libs\`, gitignored and pinned in `.pkgmeta` (LibGlass-1.0 r5,
  LibShowcase-1.0 r3); `tests/fetch_lib.sh` fetches a pin for CI. LibStub is vendored.
