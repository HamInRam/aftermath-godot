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
- Atmospheric CanvasModulate darkness with red, green, amber and magenta PointLight2D pools.
- Custom 16×16 enemy pixel-art sprite and a dedicated 12×5 AK-style weapon sprite for SMG enemies.
- Dynamic camera framing that smoothly follows the midpoint between the player and cursor while retaining trauma shake.
- Expanded the tile world to 384×224 so the dynamic camera can reveal nearby rooms without exposing the map edge.
- Reusable standalone death-blood GPUParticles2D scene with global-coordinate gravity, independent of actor rotation.
- AnimationPlayer-driven weapon kick and Marker2D muzzle points so projectiles originate at the barrel tip.
- Distinct imported pistol and AK weapon sprites plus a high-damage 60-round LMG GunData configuration.
- Two hinged physics doors built from static frames, RigidBody2D panels and PinJoint2D anchors.
- Scripted actor and projectile impulses that physically swing doors while preserving collision blocking.

### Changed

- Restored the standard macOS window frame and window controls.
- Replaced the procedural environment renderer with an editable layered TileMap workflow.
- Enemy placeholder drawing was replaced by imported pixel art; pistol and SMG weapons now use distinct visuals.
- Weapon rendering moved to an animated pivot shared by sprites and muzzle placement.
- Character slide collisions now continuously transfer force to pushable rigid bodies instead of relying only on the initial contact event.
- Increased door impact response and reduced angular damping so doors open clearly under player and projectile force.
- Door pushing now preserves pre-slide intended velocity, eliminating lost or sideways force after CharacterBody2D collision resolution.
- Removed duplicate first-contact impulses and added a stable ±80° hinge limit.
- Removed unstable door/frame self-collision, corrected the lobby door orientation and widened its wall opening to the full 16-pixel leaf length.
- Corrected door force and impulse lever arms to use world-space offsets, so rotated doors open in the physical direction of contact.

### Validation

- Phase-one architecture smoke test passed.
- 300-frame headless runtime test completed without project errors.
- Environment smoke test verified layer population, wall physics, projectile-blocking collision and shot-only camera trauma.
- Presentation smoke test verified four colored lights, both 16×16 actor textures, the AK sprite and bounded player/cursor camera targeting.
- Mechanics smoke test verified LMG data, standalone particles, muzzle-origin shooting, kick animation and projectile-driven door torque.
- Door regression test now simulates sustained CharacterBody2D contact and verifies resulting hinge rotation.
- Door-limit regression verifies forced over-rotation is clamped back inside the configured opening range.
- Standalone stability regression verifies a closed door remains motionless for 90 physics frames and opens visibly under actor force.
- Bidirectional torque regression verifies opposite-side pushes rotate a 90° door in opposite directions.
