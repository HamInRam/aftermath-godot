# Changelog

All notable project changes are recorded here. Version branches remain unreleased until explicitly approved and merged into `main`.

## [v.0.0.1] - Unreleased

### Added

- Godot 4 top-down shooter project foundation at a native 320×180 resolution.
- Shared Actor framework for player and enemy health and damage handling.
- Modular Gun node with 0.1-second firing interval and ammunition tracking.
- CharacterBody2D projectile system with collision-driven damage.
- WASD movement, mouse aiming, shooting, reload and cleanup controls.
- Neon multi-room environment, enemy AI, corpses, blood stains and cleanup loop.
- Custom utility theme, font defaults and imported 16×16 player sprite.
- Modular BloodSystem with directional impact metadata from projectiles.
- Short-lived blood mist and animated droplets on actor impact.
- Persistent directional ground splatter and raycast-driven wall splatter.
- Weapon, damage, lethality and projectile-distance scaling for blood intensity.
- CC0 field-recorded gunshot, reload, dry-fire, shell-casing and blood-splat audio effects.
- Per-shot pitch variation and randomized fire interval for less robotic weapons.
- Persistent 2×1 pixel shell casings with ejection motion and settled floor state.
- Dedicated reload timer with reload state feedback and delayed ammo refill.
- Autoload Events signal bus for decoupled ammo, reload and weapon-fire updates.
- Explicit Z-index layering for stains, shell casings, corpses, actors and blood mist.
- Trauma-based Camera2D shake using layered FastNoiseLite octaves and nonlinear decay.
- Reusable GunData Resource class with separate Pistol and SMG configurations.
- More natural shell-casing scatter through randomized spawn offsets, velocity and rotation.
- One-shot GPUParticles2D blood spray detached from defeated enemies so it finishes playing.
- Dedicated Enemies scene container and immediate collision-layer shutdown on death.
- Spatial shell-casing clinks with speed-based volume, pitch variation and occasional secondary bounces.
- Rebalanced weapon/casing mix with clearer, longer metal transients and wider spatial reach.
- Replaced synthesized effects with trimmed and normalized real-world CC0 recordings and documented provenance.
- Imported an 8×8 pixel-art environment atlas with concrete, wood, red carpet, dark tile, grass, walls, windows and stairs.
- Grid-authored room layout using separate Floor, Walls and Decoration TileMapLayer nodes.
- TileSet physics for wall and window tiles so actors and projectiles collide with the environment.
- Open doorways, window runs and a stairwell marker integrated into the room layout.

### Changed

- Restored the standard macOS window frame and window controls.
- Replaced the procedural environment renderer with an editable layered TileMap workflow.

### Validation

- Phase-one architecture smoke test passed.
- 300-frame headless runtime test completed without project errors.
- Environment smoke test verified layer population, wall physics, projectile-blocking collision and shot-only camera trauma.
