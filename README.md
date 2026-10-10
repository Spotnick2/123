# 123 — Warlock Summons, Demons & Stones

A small glass bar for Warlocks on **WoW: Forever**: your demon, armor, soulstone, healthstones and
summoning, one click away. Plus the group chores: trade a healthstone to whoever asks, call for
summoning help, and a summon queue of everyone who typed **123**.

> Early development. The bar loads and shows; the features are being built. See the
> [issues](https://github.com/Spotnick2/123/issues).

![Concept](docs/mockups/storyboard.png)

## Commands
- `/123`: show or hide the bar (also `/onetwothree`, and a key binding)
- `/123 debug`: client build, load state and what each bar button is armed with

## Requirements
WoW: Forever (1.60.1). Uses [LibGlass-1.0](https://github.com/Spotnick2/LibGlass), embedded.

## Development
See `AGENTS.md`. Tests: `pwsh tests/run.ps1`. Deploy: `pwsh Tools/deploy.ps1 [-Probe]`.
