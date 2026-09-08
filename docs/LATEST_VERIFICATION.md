# The Descent / shotgun repair verification — 2026-09-07

## Final consolidated run

Godot 4.7.1, macOS: **54/54 regression scenes passed**, plus successful import
validation (**55/55 runner jobs**). `git diff --check` passed.

Report: `/var/folders/gx/j44c8k411wb4x99rnkgg3bgh0000gn/T/aftermath-regression-561exd2c/summary.json`.

Includes room-local AI, six-floor resource transfer and actual death/retry,
weapon inventory/reload/throw, cadence and aim, door/projectile collisions,
ragdoll wall safety, finite blood recovery, source-pixel artwork, settings,
interface sizing and retired-cleanup boundaries.

## Shotgun repair coverage

- Production Gun/Bullet/Enemy trials at 20/45/70/110px, three target facings,
  canonical/legacy weapon IDs, 11/14/17px contact, eight world-space contact
  directions, torso armour and a wall inside the barrel. The close-contact
  before case emitted nine pellets with zero hits; after repair all nine hit.
  No baseline damage increase was needed: the Mossberg remains 9×18.
- 64 actor/trajectory centre-line combinations, off-centre head/limb contacts,
  preserved world-space entry blood position and weapon-specific joint impulse.
- Nine enhanced pellets through two targets each, using production Main budget
  division and lethal transfer. Cost 3.5, raw budget 4581, nine 509-unit shares,
  actual recovered resource 2.51955 (71.987%); second-target budgets all zero.
  Expired enhanced mist creates no extra absorbable pixels. Peak 1935 unit-quad
  particles remains within the existing room-wide batch limit.
- Drained chunk queued for upload, deferred deletion, and immediate same-frame
  repaint at the same coordinate: no freed-object cast and no lost fresh blood.
- The first new corpse test observed only 200 frames (~3.33s), shorter than the
  existing enemy articulation deadline (~3.43s). Corrected the test to assert
  a maximum four-second deadline and observe 4.1s; physics was not shortened
  merely to satisfy the test. The final consolidated run then passed.

## Expanded coverage

- 12 venue shells, 576 seeded world layouts and 48 base formations: navigation,
  door apertures, source grayscale and broken-window paint invalidation.
- 48 live actor directions and 30 corpse missing-module combinations: shared
  artwork, role continuity, integer pixels, grayscale anatomy and continuous aim.
- 64 weapon platforms across 8 class silhouettes: independent reload/recoil
  presentation, conserved ammunition, pickup visibility, cadence and muzzle color.
- Native menu layout, disjoint resource corners, long gun names, execution
  keycaps, precision messages and reticle redraw quantization.
- Ragdoll fixture corrected an endpoint-only measurement: one failing sample
  moved 4.175px during the observation window but finished 1.126px from its start.
  The same hand/pelvis reference, 18-frame window and 2px threshold now measure
  peak excursion; no physics, seed or spawn was changed. Ten independent random
  repeats then passed, followed by the final consolidated run.

## Actual renderer

`tests/render_run_review.tscn` completed without script/renderer errors at
1920×1080. Viewed title, help, combat, controlled impact/death aftermath and
floor completion captures under `/tmp/aftermath-render-review`.
Final log: `/tmp/aftermath-noir-render.log`.

The captures confirm replacement artwork, gray anatomy against crimson blood,
readable text and removal of the unrelated rectangular corpse shadow. This is
controlled engine-rendered QA, not a claim of a prolonged human playthrough.

`tests/render_shotgun_review.tscn` additionally fired the real equipped Mossberg
through the complete production kill path at 1920×1080. Inspected its before,
impact and aftermath images under `/tmp/aftermath-shotgun-review`; the normal
alerted target died and left the articulated corpse. Log:
`/tmp/aftermath-shotgun-render.log`.

`tests/test_shotgun_blood_feedback.tscn` also passed with the real renderer,
including every submitted mist transform's unit scale/integer pixel edges.
The headless dummy server cannot report those GPU transforms, so CI checks
quad geometry/palette/economy while the renderer run checks transforms too.
Log: `/tmp/aftermath-shotgun-feedback-gpu.log`.

## Remaining limitations

- The final run still records shutdown resource/ObjectDB diagnostics in
  `test_weapon_throw`, `test_entry_loadout_flow` and `test_vertical_slice`. These are not represented as
  a clean memory-leak audit. Other short-fixture teardown warnings have also
  occurred in earlier runs.
- Headless stress checks are not a sustained GPU frame-rate guarantee.
- Long-run balancing, target-device profiling, controller-only playthroughs,
  localization and distribution/export verification remain before release.
- OTXO's complete boss, narrative and bartender-upgrade catalog is not included.
  No zero-bug or commercial-completeness claim is made.
