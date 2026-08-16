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

### Changed

- Restored the standard macOS window frame and window controls.

### Validation

- Phase-one architecture smoke test passed.
- 300-frame headless runtime test completed without project errors.
