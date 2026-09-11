# Runtime integration repair verification — 2026-09-10

Godot 4.7.1.stable.official.a13da4feb on macOS / Apple M1, using an isolated self-contained engine and test data.

## Consolidated run

**84/84 active regression scenes passed, plus checked resource import: 85/85 runner jobs.**
The exact scene list is `tests/regressions.txt`; local and CI use the same runner.

```sh
python3 tools/run_regressions.py --godot /path/to/Godot --timeout 120 --output build/regressions
```

Coverage includes evidence-driven AI, dormant patrol movement, actual Rage reward/reload/projectile integration, finite recovery, weapon and collision systems, six-floor transfer and retry, intermediate-floor exits and scoring, corrupt-save recovery, failed-write preservation and liquid/pool lifecycle regressions. Current HUD, roster and permanent-destruction expectations were updated to match the active gameplay contract.

`git diff --check` passed. Scanning fixed, non-wildcard `res://` literals in scripts and resource files found no missing targets; this does not cover dynamically constructed paths.

## Real renderer

`tests/render_run_review.tscn` completed with `RENDER_REVIEW_OK`, without renderer or script errors, using OpenGL Compatibility on Apple M1 at 1920×1080. Combat, reward selection, help, aftermath and floor-clear captures were visually inspected. This verifies controlled engine rendering, not an entire human playthrough.

## Remaining limits

The consolidated run still reported shutdown ObjectDB/resource diagnostics in these short fixtures:

- `test_weapon_throw`
- `test_feedback_hierarchy`
- `test_blood_action_flow`
- `test_blood_rage`
- `test_floor_exit`
- `test_blood_terrain_room`
- `test_cleanup_scoring`
- `test_vertical_slice`
- `test_mission_result_flow`
- `test_rage_perk_integration`

These are recorded separately from functional pass/fail; this is not a clean memory-leak audit. Individual verbose reruns of weapon_throw and blood_rage did not reproduce the warnings, so their cause remains unresolved.

No sustained target-device GPU/memory profile, full human six-floor playthrough or Windows/Linux export verification was performed. Retired tests outside the active manifest were not all reactivated. Large scripts were incrementally split, not comprehensively rewritten.
