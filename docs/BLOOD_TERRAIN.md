# Blood terrain

- Player feet sample the sparse ground canvas, not wall blood or rendered textures.
- Crimson: 1.30x walking speed. Ordinary floor: 1.00x. Gray striped contamination: 0.60x and no roll initiation. Existing rolls keep their speed, duration and invulnerability window.
- Right-mouse siphoning does not add a movement penalty. Removing the blood underfoot removes its speed bonus.
- Current siphon: invisible 86-degree forward sector, reach 224 world pixels; 48-pixel omnidirectional proximity circle. Both share the same resource budget, respect solid/vision-blocking geometry and exclude contamination. A bounded round-robin traversal drains multiple chunks together. Near motes arrive in roughly 0.075–0.13 seconds, distant ones up to 0.48 seconds. A small crimson cursor halo indicates actual absorption, not merely holding the button. Gain is credited once on removal; particles are visual only.
- Every eighth eligible authored spawn (index 5 modulo 8, excluding dogs) is a contamination carrier, identified by grayscale twin canisters. It keeps the underlying patrol/combat AI. Hits leave a radius-12 patch, limited to once per 150 ms; death leaves radius 23. No absorbable blood or wound trail comes from this variant.
- Contamination lives in a separate byte plane inside existing 32x32 chunks. It never credits blood currency. Incoming blood clears its pollution bit permanently; siphoning that blood reveals clean floor, not the old hazard.
- SMG/PDW impact and terminal splatters use separated dots. Existing weapon wound intensity still affects reach and density.
- Shotgun kills add an opaque, low-mass forward fan, radius 32 pixels. Exiting sniper wounds add a 3-pixel-wide route up to 320 pixels, stopped by solid walls. These are gameplay units, not claimed real-world distances. Existing weapon damage/penetration profiles still determine whether an exit wound occurs.
- Explicit empowered-blood budgets include these footprints. Normal hit generation continues the existing enemy-blood economy; long-run sustain balancing still needs playtesting.

Tests: test_blood_terrain covers negative world coordinates, speed states, roll restriction, non-absorbable pollution, permanent overpaint, footprint direction, mass caps, and solid-wall clipping. Renderer fixture adds blood_terrain.png. Neither is a substitute for a full human run.
