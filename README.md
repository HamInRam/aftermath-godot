# AFTERMATH — Neon Crime Prototype

An original Godot 4 top-down shooter inspired by the visual language and pacing of neon crime thrillers.

## v0.0.10 performance and release readiness

- Runtime budgets cap bullets, casings, transient effects, blood evidence, corpses, pickups and debris before long fights can grow the scene tree without bound
- High-frequency interaction, cleanup and security-device queries are cached or sampled instead of traversing groups every physics frame
- Press `F6` during a mission to display rolling average/p95 frame time, peak node count and tracked gameplay-object pressure
- A deterministic stress regression exercises sustained gunfire, lethal blood effects and evidence creation while enforcing object and node ceilings
- Windows and Linux export presets, release metadata, licensing notices, checksums and a tag/manual GitHub release-build workflow are ready for packaged builds

## v0.0.9 adaptive presentation and accessibility

- An original procedural score supplies cached pulse, danger and room-tone loops with no external music dependency
- Gunfire, executions, alarms and the proportion of enemies actively pursuing the player smoothly raise the danger layer
- Combat music cuts rapidly at cleanup while the isolated electrical ambience rises into the foreground
- Settings persist master, music, SFX and ambience levels in `user://aftermath_settings.json`
- Accessibility controls scale screen shake and full-screen flashes from 0–100%, and can disable CRT treatment or ambient camera motion
- Menus, briefings, missions and action reports now use a global input-blocking fade transition

## v0.0.8 campaign progression

- Campaign cases unlock in order: Nightclub → Sandwich Shop → After Hours; Tactical Lab remains an unrestricted training mission
- Selecting a case opens an authored briefing with objectives and the current personal best before deployment
- Completed missions write versioned progress to `user://aftermath_progress.json`, preserving the highest-scoring report for each case
- Press `Enter` after a completed cleanup to open an action report with grade, score, time, cleanup, alarms and remaining risk
- The action report supports immediate retry, return to case files or deployment to the newly unlocked next case

## v0.0.7 mission and security layer

- Each level can assign a `MissionProfile` with authored elimination, security, bonus and alarm-penalty rules
- `After Hours` now requires clearing ten hostiles and disabling two sweeping security cameras before cleanup begins
- Cameras build detection over time, report the player's position into the tactical AI network and re-arm only after losing the player
- Press `E` beside a camera for a quiet shutdown, or shoot it for a fast but noisy takedown
- The HUD tracks mandatory objectives and alarm count; alarms reduce score and prevent a perfect S grade

## v0.0.6 evidence and extraction

- Evidence types carry different risk values, with corpses and dropped weapons weighted above blood or shell casings
- Corpses require two Body Bag actions, then must be dragged into the glowing extraction zone
- Returning to the extraction zone and pressing `E` allows an early exit with an evidence penalty and S–D grade
- The cleanup HUD reports both remaining object count and total unresolved risk

## v0.0.5 combat expansion

- Data-driven Gunner, Rusher, Assault, Heavy and Hound archetypes
- Assault enemies push quickly with SMGs; Heavies carry LMGs and resist ordinary knockdowns; Hounds attack with extreme speed and wide perception
- Press `Q` to throw the equipped gun, knock down a normal enemy and recover the same weapon with its remaining magazine
- `After Hours` now mixes all advanced archetypes with the complete combat-to-cleanup loop

## v0.0.3 architecture, tactics and cleanup

- Pure `Events` signal bus with a dedicated `CombatDirector` for one-pass hearing evaluation and push/sweep/guard assignment
- Central `CorpseIncidentRegistry` with transitive A–B–C incident merging
- Unified `CleanupRegistry` covering blood, pools, gore, corpses and shell casings
- Corpse and blood-pool shoe contamination that leaves a short fading trail of alternating pixel footprints, each tracked as cleanup evidence
- Data-driven Pistol, SMG and LMG fire mode, visuals, audio and blood behavior through `GunData` and `AttackCatalog`
- Press `1` repeatedly while holding a gun to cycle Pistol → SMG → LMG
- Enemy perception and directional search construction split into focused helper modules
- Cached execution targeting, enemy-count tracking and cleanup registration replace repeated frame-wide queries
- Automated Godot parsing plus unit and black-box regressions in GitHub Actions

## Combat feel

- Immediate 115 px/s movement and instant stopping
- Semi-automatic high-precision pistol with near-instant 650 px/s projectiles
- GunData-driven recoil, muzzle light, shake, knockback, hearing and lethal hit stop
- Vision-cone and line-of-sight enemy detection with sound investigation instead of omniscience
- Continuous 0.2–0.4 second visual reaction delay, opaque wall/door occlusion and sight through physical glass windows
- Corpse discovery interrupts idle duty, drives A* incident investigation and produces a timed multi-direction search at the scene
- Confirmed sightings enter role-tuned pursuit, with 1.35x gunners and 1.48x melee guards; lost targets are searched at their last known position before patrol resumes
- Arrival-gated multi-point searches inspect the last-known direction for up to six seconds, with stuck replanning and unreachable-point skipping
- Named physics layers separate players, enemies, solid walls, glass, projectiles and opaque vision blockers
- Glass blocks movement, passes vision and full-strength sound, and shatters on the first bullet while allowing that projectile to continue
- Optional FOV debug cones switch from red to green on raw visual contact
- Press `F3` during gameplay to toggle every enemy FOV cone; no Inspector configuration is required
- Enlarged high-contrast HUD typography remains pixel-crisp at the native resolution
- Gunner and melee enemy roles share the same perception/state network but use ranged or one-hit close combat
- Clear CHASE sightlines produce an aggressive 1.25x direct rush; walls switch movement back to A* for a 1.5-second pursuit-memory window
- Enemy gunfire reuses GunData, muzzle, spread, ammo/reload, audio-bus and projectile systems; melee guards hide firearms and display a swing arc
- Nearest-sampled CRT/vignette/chromatic post-processing, WorldEnvironment glow/contrast/saturation and subtle ambient camera drift
- HUD renders above post-processing so text remains undistorted
- Frozen-until-contact physics doors with cast-shape CCD, a widened sweep detector and stable hinged rebound
- Fixed-speed contact doors knock enemies down for four seconds during their brief opening sweep, with loud AI alerts and wood splinters
- Four-second prone knockdowns create a Space-key execution window with three impact beats, locked controls and radial lethal gore
- Directional corpse impact, strong death feedback and immediate restart
- Subtle scanline/grain treatment that preserves pixel readability
- Abrupt combat-to-cleanup silence interface after the final kill
- Weapon-shaped directional blood, progressively expanding death pools, modular corpse wounds and physics-driven pixel gore chunks
- Globally visible stage lighting with fixed right-down pixel shadows, window-aware breaks and restrained breathing neon accents
- Original high-contrast Nightclub interior with room-specific floors, bright wall trim, dense furnishings and matching fake shadows
- Subtle position-driven camera tilt with mirrored directions, a stable center dead zone and smoothed transitions
- Layered architectural cutout over an exterior-only, independently toggleable HSV hue cycle
- Mouse-directed 0.25-weight camera lead and hold-Shift tactical look-ahead

## Phase 1 foundation

- Native `320x180` viewport, displayed at `960x540` with 3x viewport scaling
- Standard framed game window and a solid high-contrast viewport clear color
- Pixel snapping and nearest-neighbor texture filtering
- Integer-only viewport scaling and whole-pixel dynamic camera movement for crisp presentation
- Explicit Input Map actions for WASD, mouse shooting and reload
- Imported utility folder with reusable UI defaults, a custom Theme and system-font configuration
- Shared `Actor` base script with HP, movement and `take_damage()`
- Player and enemy scenes inherit the Actor framework
- Reusable child `Gun` scene owns the 0.1-second fire rate, ammo and projectile emission
- Swappable GunData resources configure pistol and SMG capacity, damage, timing and reload
- Randomized fire timing, pitch-varied gunshots, timed reload and dry-fire feedback
- AnimationPlayer kickback and barrel-tip Marker2D projectile spawning
- Pistol, SMG and high-damage 60-round LMG GunData configurations
- Per-weapon trajectory spread for distinct pistol, SMG and LMG handling
- Autoload event bus keeps gun state, UI and persistent shell casings decoupled
- Spatial shell-casing landing audio varies by ejection speed, pitch and occasional bounce
- Bullets are independent `CharacterBody2D` scenes with a 2x2 collision box
- Player art uses an imported transparent 16x16 PNG on a `Sprite2D`, with nearest filtering
- Enemy art uses a distinct imported 16x16 PNG, and SMG enemies carry a dedicated AK-style pixel sprite

## Controls

- `WASD` or arrow keys — move
- Mouse — aim
- `1` gun; press repeatedly to cycle pistol/SMG/LMG / `2` fists / `3` knife / `4` bat
- The player starts with only a pistol; armed enemies drop their current gun and remaining magazine, and `E` collects it
- Each owned gun preserves its own partially used magazine when cycling weapons
- Left mouse — fire or melee attack / scrub during cleanup
- Melee is deliberately unforgiving: fists 12px, knife 16px and bat 28px, with forward-anchored compact trails
- `R` — reload; restart after death or completion
- `Space` — execute a nearby knocked-down enemy
- `E` — pick up a nearby dropped weapon
- `Q` — throw the equipped gun; the weapon remains recoverable with its current magazine
- Move into a closed door — contact opens it once; ≥81 px/s is a dangerous slam, slower contact is a quiet non-damaging push
- Hold `Shift` — extend the camera toward the cursor
- `F3` — toggle enemy vision debug cones
- `F4` — toggle and save the CRT/screen post-processing preference
- `F5` — toggle exterior hue cycling
- `F6` — toggle the performance diagnostics overlay
- All other presentation options are available from the title-screen Settings menu
- `Esc` — return to the debug room-select menu

## Game loop

1. Enter a multi-room neon floor with 12 rounds.
2. Eliminate nine armed enemies while managing distance and ammunition.
3. Chain kills before the combo timer expires.
4. Survive the one-hit lethality.
5. When combat ends, switch to cleanup mode.
6. Remove every blood stain, pool, gore chunk, corpse and shell casing.

## Levels and AI

- Debug title menu loads the Nightclub, Sandwich Shop or Tactical Lab directly
- Tactical Lab menu entry provides a focused four-room combat puzzle for door breaches, glass crossfire, blind corners, patrol baiting and fixed-sentry counterplay
- Sandwich Shop has independent layered floors, walls, objects, lighting and spawn configuration
- Enemy routes use an AStarGrid2D generated from solid wall cells
- Enemy vision uses distance/angle broad-phase checks followed by an opaque-only 2D raycast; `debug_draw_vision` exposes the tuning cone
- Weapon-specific circular hearing events propagate through walls at a 1.5x effective-distance penalty with distance- and occlusion-scaled uncertainty
- Centralized hearing assigns the two nearest guards to push, a third to sweep an offset lane and remaining listeners to hold position instead of abandoning the whole floor
- Melee hits and executions create their own alert radii, making committed close-range actions audible risks
- Unalerted enemies follow two-point patrol routes; alerted enemies switch to frequently refreshed diagonal A* paths around walls and solid furniture
- Patrol routes span 48–64px, use A* instead of blind straight-line motion, and pause 0.5–1.5 seconds at each waypoint
- Unroutable guards become stationary sentries that smoothly scan ±45 degrees; soft obstacle costs reduce furniture and corner rubbing
- Human/dog AI profiles support faster dog reaction and direct open-room pursuit when dedicated dog content is added
- Fixed sentries ignore sound bait but still acquire and attack visible players; opening door sweeps knock enemies down without a lethal tier
- Enemies outside detection range decelerate to rest instead of jittering toward the player
- Ammo UI republishes the equipped gun state whenever a level finishes loading

## Implemented presentation

- Expanded original 8×8 pixel-art tile atlas with seven additional room materials and sixteen new environment/furnishing tiles overall
- Editable `TileMap` hierarchy with independent `Floor`, `Walls`, `Decoration`, `Objects` and matching shadow layers
- Grid-built rooms with open doorways, window sections and a stairwell marker
- Wall/window TileSet physics that stops actors and projectiles
- CanvasModulate night grading with four colored PointLight2D atmosphere pools
- Bullet trails, firing flash and screen shake
- Twelve-particle, 0.24-second reverse-direction metal sparks on StaticBody2D and TileMapLayer wall impacts
- Destructible Layer 4 glass tiles with 52 cyan shards, collision/navigation removal, a cool flash and projectile continuation
- 40–60-droplet lethal blood fans with 48-particle death bursts and expanded tissue/bone gore chunks
- Trauma/noise Camera2D shake with configurable decay, offsets and octaves; dry fire does not add trauma
- Smooth bounded camera framing between the player and cursor for forward visibility
- Static deep-color exterior backdrop visible through unpainted space around the room structure
- Pixel-snapped positional screen shake plus a separate restrained 1.4-degree location-driven camera tilt
- Standalone global-coordinate death particles that remain independent of actor rotation
- Hinged RigidBody2D doors with static frames, PinJoint2D anchors, actor/projectile torque, CCD and enlarged enemy sweep areas
- Corpses, directional persistent blood pools and wall splatter
- Modular weapon-aware blood mist and animated impact droplets
- Field-recorded CC0 blood-splat audio on lethal impact stains
- Auditable external audio provenance in `AUDIO_LICENSES.md`
- One-shot GPU death-blood particles that outlive the defeated enemy node
- Enemy alert, pursuit, retreat and strafing behavior
- Ammo, reload, combo, kill and cleanup HUD states
- Combat-to-cleanup narrative transition

Run `project.godot` with Godot 4.7 or later.
