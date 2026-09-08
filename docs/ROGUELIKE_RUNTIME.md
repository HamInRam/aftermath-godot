# AFTERMATH: current room-shooter contract

## Playable loop

New run → choose the first loadout → clear 4–5 occupied rooms → floor report → next venue → six-floor victory. A run draws six distinct venues from twelve shells. The room catalog contains 48 authored formations, transformed without scaling characters or props.

The first entry bench is required. Subsequent floors inherit exact equipment and resources. Death **R** retries the same floor and its entry checkpoint; it does not count a second reward, reshuffle that room or grant a fresh kit. Retries remain an explicit accessibility/practice concession and appear in the run summary. This is not a strict permadeath mode.

Entering a chamber or hitting one of its hostiles engages that chamber. Other engaged chambers continue fighting; untouched chambers keep patrolling. Hit reactions investigate the actual attack source using normal perception, not an immediate through-wall firing lock. Each chamber and floor can complete only once.

## Art and space

- Standard building: 768×448 native world pixels; 8px navigation/authoring cells; 24px functional doors. Continuous floor artwork is not an 8px checkerboard. Actor and prop silhouettes remain native size. These are this project's measured specifications, not purported extracted OTXO asset dimensions.
- Neutral black/white/gray world and anatomy; crimson blood and blood-powered violence. No generated replacement illustrations or enlarged mixed-resolution character sheets.
- Structural walls define stable traversal boundaries and shed impact chips/dust. Doors, movable props and corpses react physically; treating the entire architecture as loose ragdolls would invalidate room navigation and is deliberately not done.
- Native-resolution world graphics and independently rasterized UI remain sharp at the configured 1920×1080 output. UI does not inherit camera rotation. Long help content scrolls with its action outside the scrolling body.

## Controls and feedback

| Input | Normal combat | Blood stance (hold RMB) |
| --- | --- | --- |
| LMB | Shoot; a fresh empty-magazine click reloads | Shoot a paid enhanced round when enough blood is stored |
| Q | Throw current weapon | Blood step |
| E | Take a nearby visible weapon / context interaction | Blood pulse |
| R | Reload | Blood guard |
| B | Spend stored blood to heal | Spend stored blood to heal |
| X | Timed hostile-local Focus | Timed hostile-local Focus |
| Shift | Extend camera look-ahead | Extend camera look-ahead |

Ammo sits upper-left; health/armor and Focus are lower-left; blood is lower-right.
Resource bars never share a text label or screen rectangle. Context prompts appear
only for an available action. Long names elide instead of expanding the HUD.
The reticle has one high-contrast cross, a transient on-hit marker, and optional
reload/low-ammo feedback. Mouse pointing is immediate; reload and recoil are
visual layers rather than forced delays in the ballistic carrier.

## Resource invariants

`RoguelikeRunSession` is runtime-only. Persistent score/victory records live in `ProgressionStore`; loading the application never claims to resume an unsaved world.

The carry snapshot includes both owned weapons, exact magazines/reserves, installed parts, selected/unarmed state, movement/noise kit factors, health/max health, armor, blood guard, blood/capacity, skill cooldowns and Focus charges/recharge. New floors cancel transient reload/attack animations but do not create ammunition.

Only living enemies generate usable hit blood. Settled corpses and detached limbs do not regenerate blood. Blood-enhanced trigger pulls share one capped return ledger, including shotgun pellets and penetration chains. Maximum usable return stays below its paid blood cost.

Thrown guns and anatomically meaningful limbs are persistent gameplay objects. Cosmetic particle/debris limits cannot delete inventory or remove the missing arm from a corpse. Ragdoll and limb collisions are bounded; increased violence comes from shape and spray, not unbounded root impulse.

## Verification

Run `python3 tools/run_regressions.py --godot /path/to/Godot`. It reads the same scene list as CI, retains engine and combined stdout/stderr logs, and times out stalled tests. The current list has 51 scenes, including regression guards against reactivating the retired cleanup phase.

`test_roguelike_floor_flow` instantiates real floors, confirms the actual entry overlay, kills the player, sends the real R action, reloads the scene, clears through RoomRunController and instantiates the next floor. Resource values and attachments are compared at every boundary.

`tests/render_run_review.tscn` is an optional real-renderer check that saves this game's viewport to `/tmp/aftermath-render-review`; it does not capture the desktop. Headless tests cannot establish final visual quality or real GPU framerate.

Passing regressions is not a claim of zero bugs or commercial-release readiness. Shipping still requires prolonged player balancing, target-device frame-time profiling, controller-only playthroughs, localization/layout checks and distribution/export testing. Old campaign/save utilities remain as compatibility modules; the current runtime no longer enters cleanup, restoration or three-choice upgrade screens.

## Reference boundary

OTXO's developer/publisher description supports the combination of Focus, aggressive room combat and randomized authored spaces: https://store.steampowered.com/app/1608640/OTXO/ . AFTERMATH retains its own art, blood-resource system and implementation; it does not use extracted OTXO assets or claim identical hidden numerical tuning.
