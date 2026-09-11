# Architecture refactor verification — 1.3.2 / 2026-09-11

Godot 4.7.1.stable.official.a13da4feb on macOS / Apple M1, with isolated engine data.

**85/85 active regression scenes passed, plus checked resource import: 86/86 jobs.**

```sh
python3 tools/run_regressions.py --godot /path/to/Godot --timeout 120 --output build/regressions
```

The shared manifest is `tests/regressions.txt`. Existing AI, inventory, ballistics, blood economy, destruction, budgets, floor-flow and save tests passed. The new architecture scene verifies nested snapshot isolation, JSON round trips, malformed input, mixed pellet outcomes, state notifications and idempotence, dead-actor rejection, duplicate completion, awaited transition rollback and controller teardown.

`git diff --check` passed. Fixed non-wildcard resource paths had no missing targets. Enemy has one runtime backing-state write, inside `transition_to`.

## Actual renderer

`tests/render_run_review.tscn` completed with `RENDER_REVIEW_OK` and no script/renderer errors, using OpenGL Compatibility on Apple M1 at 1920×1080. Combat, retry-menu and floor-clear captures were visually inspected.

## Shutdown diagnostics and limits

Shutdown ObjectDB/resource warnings occurred in:

- `test_weapon_throw`
- `test_feedback_hierarchy`
- `test_blood_action_flow`
- `test_blood_rage`
- `test_floor_exit`
- `test_blood_terrain_room`
- `test_vertical_slice`
- `test_mission_result_flow`
- `test_rage_perk_integration`
- `test_architecture_contracts`

These remain separate from functional pass/fail; their root causes were not resolved by this refactor. The new controller-lifetime check verifies both scene children are freed, not the absence of all leaks.

No sustained GPU/memory profile, full manual six-floor playthrough or Windows/Linux export verification was performed. Catalog/authoring dictionaries remain outside this typed-data conversion. See [ARCHITECTURE.md](ARCHITECTURE.md) for ownership and compatibility boundaries.
