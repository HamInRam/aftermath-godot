# Performance lifecycle pass — 2026-09-09

## Shipped changes

- ProjectilePool owns one active-list physics dispatcher. Pooled rounds no longer
  each register a physics callback; empty pools sleep. Direct scene/test rounds
  still work independently. Deferred retirement and external deletion both remove
  dispatcher entries and runtime budget leases.
- Retained the native CharacterBody2D 2x2 swept collision, finite flight time,
  penetration, glass, corpse overkill and hostile Focus scaling.
- Blood resource density can change without dirtying an unchanged opaque red pixel.
  Zero-to-visible, visible-to-zero and pollution replacement still dirty the exact
  pixel. Canvas upload processing sleeps when its queue is empty; removal dissolve
  completion wakes pending uploads. No change to resource mass or particle caps.
- Blood mist shares exponential drag per update except a particle's final partial
  time step. Emission reference counts replace a second full particle scan every
  frame. Wall query parameter objects are reused.
- Ragdoll joints and micro debris reuse wall-query parameters. Their collision and
  motion rules remain unchanged. Empty debris fields start asleep; impact and
  suction wake them.
- Doors now use AnimatableBody2D with explicit rotation; obsolete rigid material,
  anchor body, CCD and PinJoint2D were removed. Closed/open doors stop processing;
  hit-area monitoring is enabled only while opening. One-hit kick feedback remains.

## Measured decisions, not architecture assumptions

Apple M1 / Godot 4.7.1, headless microbenchmarks (not whole-game FPS):

- 1,332 living mist particles: simulation median 1,310 us before, 1,025 us after
  (21 samples, 1 ms steps). Same seeded emission count; no reduction of particles.
- A prototype replacing native projectile sweeps with script-driven shape queries
  increased 3,840 empty-flight updates from 2,111 us to 4,106 us. A conservative
  same-frame broadphase cache measured 4,941 us. Both prototypes were discarded.
- A whole-buffer MultiMesh upload prototype measured 2,194 us versus ~1,923 us for
  existing per-instance updates in the tested workload. Discarded; original exact
  render path retained. This does not establish GPU bottlenecks on other hardware.

Reproduce with `tests/benchmark_mist_upload.tscn` and
`tests/benchmark_projectile_dispatch.tscn`. Timings are machine/load dependent.

## Verification

`test_optimization_lifecycle` covers one dispatcher, exact travel speed, deferred
retirement, external deletion, blood density/no-upload behavior, final pixel
removal, complete mist ledger expiry and a real timed kick knocking down once.
Run existing projectile, shotgun, siphon, overload, transition, door passage,
ragdoll, destruction, floor-flow and performance tests as well.

`render_shotgun_review.tscn` uses the real renderer and production
Gun → Bullet → Enemy → Main path; captures before/impact/aftermath and verifies a
persistent corpse. This pass does not claim all legacy CI tests or every gameplay
combination are bug-free. Earlier uncommitted core-subtraction edits are preserved.

Final validation: 25 distinct targeted regression scenes passed across the
juo8mxjv/u5f3p1hj/agjbsj5f runs (the two obsolete assertions in the supplemental
run were updated and rerun). The vertical-slice scene still reports its existing
shutdown resource warning; this is not presented as a warning-free full CI run.
Its assertions now reflect disabled Focus in the blood-ammo mode and a walkable
floor exit, not the retired modal report. The blood-canvas stale-upload test
explicitly flushes a never-presented empty chunk before checking its disposal.
