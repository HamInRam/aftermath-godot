# Pixel erosion

All venues share lazy conversion of struck non-glass wall tiles into 8x8 pixel
masks. Furniture uses the same mask in its local coordinate frame, so holes
follow moving/rotating furniture. Every projectile removes a compact 1–4px
radius bite, scaled by damage/material resistance. The strengthened tuning uses
2.2–4.2px wall radii and 2.2–4.4px furniture radii; at 30 damage a wall bite has
roughly 3.1px radius instead of 2px. Movable furniture launch energy is 0.65,
still bounded by existing swept movement. Microfragments emit 8–32 per burst at
42–135px/s with the same 512-record and 64-ray budgets. Simulation scheduling
rotates to avoid starving new fragments behind older moving debris.
Glass retains its established
shatter behavior; outermost world-edge tiles are protected against escape.

Remaining rows merge into exact axis-aligned rectangles. Geometry changes are
deferred outside physics callbacks and coalesced per object. There is no rigid
body per pixel. Rendering drops removed pixels directly; no translucent fake
holes. Partial wall cells retain conservative 8px AI navigation blocking until
fully consumed; projectile/actor physics uses the actual remaining rectangles.
AI does not yet route through partial-cell corridors, even if a very small actor
could physically squeeze through. Fully consumed cells open navigation and
refresh acoustic sectors. Lighting replaces the old tile occluder with remaining
rectangles; wall caps/shadows are cleared alongside the original cell.

Wall texture edits are localized in a cached image, uploaded together. Lighting
and acoustic topology still rebuild on conversion/opening; this can be expensive
under sustained destruction and is not a claimed constant-time/AAA solution.
Fragments use the bounded MicroDebrisField and do not grant blood. A single
spatial clink voice rises from 0.85 to at most 1.65 pitch, resets after 400ms,
and accepts at most one event per 65ms. This reuses an existing clink asset;
it is not a bespoke material-specific audio library.

Tests cover mask/collision area equality, preserved internal holes, furniture,
wall elimination, navigation and common erosion integration across all venues.
Doors remain their existing swinging/destruction system, not pixel-eroded leaves.
Save compatibility fields are retained. Geometry is rebuilt for each new run or
retry; no permanent campaign-world terrain changes are saved.
