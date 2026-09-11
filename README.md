# AFTERMATH — Monochrome Blood Roguelike

An original Godot 4 room-combat shooter built around monochrome pixels, persistent crimson blood and modular firearms.

## Current build: 1.3.2

- Six floors draw distinct venues from twelve authored building shells. Each floor has four or five combat rooms and 18–24 enemies.
- A 100-composition deck supplies enemy, patrol and cover arrangements, with eight rotations/reflections. A fresh scene entry (including retry) re-deals formations; explicit preview seeds reproduce layouts.
- The first floor requires an entry loadout. Later floors carry exact weapons, fitted parts, magazines, reserves, health, armor, blood and learned combat synergies. Death retries restore the floor-entry resource checkpoint and count toward the report.
- 24 firearm platforms across eight classes, with compatible attachments and original native-pixel previews.
- Ordinary shots spend ammunition; R reloads. Hold RMB to siphon blood. A full meter automatically starts Blood Rage: unlimited empowered shots, +25% movement and crimson feedback. Recovery remains slower than drain, including with upgrades.
- Untouched rooms retain ambient patrols. Entry and direct harm activate local combat. Activated enemies use sight, sound and attack-source evidence; investigation and search are not replaced with omniscient chase.
- Optional F1–F3 combat rewards appear after every third room, when no room is engaged. Rage-specific descriptions match live movement, projectile and resource effects.
- Pixel blood uploads, projectiles, transient effects and physical fragments have budgets. Props, doors, corpses and detached anatomy react to combat. Cleanup, restoration and the old blood-skill/Focus controls are retired from the active mode.
- Progress and settings use staged JSON writes with a previous-valid backup and recovery from corrupt primary files.

## Run

Open `project.godot` with **Godot 4.7.1**. The default scene is the title menu; rendering uses Compatibility with nearest-filtered pixels and a 320×180 native composition.

| Input | Action |
| --- | --- |
| WASD / arrows | Move |
| Mouse / LMB | Aim / shoot |
| RMB | Siphon existing blood |
| R | Reload; retry on the death screen |
| Q | Throw the current gun |
| E | Interact / pick up |
| Space | Roll (brief invulnerability) |
| Shift | Look ahead |
| F1–F3 | Choose a visible optional reward |
| Esc | Pause / back |

See [code architecture](docs/ARCHITECTURE.md), [current runtime rules](docs/ROGUELIKE_RUNTIME.md), [Blood Rage and synergies](docs/BLOOD_RAGE.md), and [room compositions](docs/ROOM_DECK_100.md). Historical version notes live in [CHANGELOG.md](CHANGELOG.md); they are not the current gameplay contract.

## Verify

```sh
python3 tools/run_regressions.py --godot /path/to/Godot --output build/regressions
```

Local runs and CI both read `tests/regressions.txt`. The runner saves every scene's output and a JSON summary, bounds scene runtime, and terminates script failures instead of leaving failed assertion coroutines running indefinitely. CI uploads the logs even on failure. For a completely cold checkout, prime the editor import cache once with `Godot --headless --editor --quit --path .` before the checked run.

The manifest covers combat, AI, collisions, floor transfer/retry, visual layout, runtime budgets, corrupt saves and actual reward-to-projectile integration. See [latest verification](docs/LATEST_VERIFICATION.md) for measured results and remaining limitations. Headless checks do not establish sustained GPU framerate or replace a human playthrough.

Optional game-viewport captures: run `tests/render_run_review.tscn` with the real renderer. Windows and Linux export presets are provided in `export_presets.cfg`.

## Licenses

See [LICENSE.md](LICENSE.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [AUDIO_LICENSES.md](AUDIO_LICENSES.md) and [GODOT_LICENSE.txt](GODOT_LICENSE.txt). Artwork is original; the project does not use extracted OTXO assets or claim to reproduce its full content.
