@AGENTS.md

## Consulting Codex

The shared `codex-consult` skill (user level) has the invocation and the gotchas. For this repo:

For 123, good things to hand Codex: a feature plan before coding, a secure-button or trade change,
or the probe results. Hand it `docs/FOREVER-PROBE.md` and `C:\Projects\WoW\References\Docs\PORTING-TBC-TO-FOREVER.md`
alongside: those are measured on the live client, and a cold reviewer will otherwise argue from
Classic-era API behaviour that no longer holds.

Iterate until consensus (usually two or three rounds). Adopt what makes the change simpler or
safer; push back on scope growth, since the owner wants no overengineering. Reviews run when the
owner asks; they are not a gate on every PR.
