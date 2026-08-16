# AFTERMATH — Neon Crime Prototype

An original Godot 4 top-down shooter inspired by the visual language and pacing of neon crime thrillers.

## Phase 1 foundation

- Native `320x180` viewport, displayed at `960x540` with 3x viewport scaling
- Borderless game window and a solid high-contrast viewport clear color
- Pixel snapping and nearest-neighbor texture filtering
- Explicit Input Map actions for WASD, mouse shooting and reload
- Imported utility folder with reusable UI defaults, a custom Theme and system-font configuration
- Shared `Actor` base script with HP, movement and `take_damage()`
- Player and enemy scenes inherit the Actor framework
- Reusable child `Gun` scene owns the 0.1-second fire rate, ammo and projectile emission
- Bullets are independent `CharacterBody2D` scenes with a 2x2 collision box
- Player art uses an imported transparent 16x16 PNG on a `Sprite2D`, with nearest filtering

## Controls

- `WASD` or arrow keys — move
- Mouse — aim
- Hold left mouse — fire / scrub during cleanup
- `R` — reload; restart after death or completion

## Game loop

1. Enter a multi-room neon floor with 12 rounds.
2. Eliminate nine armed enemies while managing distance and ammunition.
3. Chain kills before the combo timer expires.
4. Survive the one-hit lethality.
5. When combat ends, switch to cleanup mode.
6. Remove every procedurally shaped blood pool.

## Implemented presentation

- Pixel-snapped procedural art and room textures
- Checkerboard, wood, wallpaper, grass and tiled zones
- Layered red, green and magenta lighting pools
- Bullet trails, firing flash and screen shake
- Corpses, directional persistent blood pools and wall splatter
- Modular weapon-aware blood mist and animated impact droplets
- Enemy alert, pursuit, retreat and strafing behavior
- Ammo, reload, combo, kill and cleanup HUD states
- Combat-to-cleanup narrative transition

Run `project.godot` with Godot 4.7 or later.
