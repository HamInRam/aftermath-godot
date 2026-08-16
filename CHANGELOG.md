# Changelog

All notable project changes are recorded here. Version branches remain unreleased until explicitly approved and merged into `main`.

## [v.0.0.2] - Unreleased

### Added

- GunData-driven recoil, camera shake, muzzle-flash size/duration, bullet speed, knockback, hearing radius and lethal hit-stop tuning.
- One-to-two-frame muzzle flash geometry with a short-lived PointLight2D for dark-room illumination.
- Layered gunshot audio using transient, mechanical and low-pitched punch components with restrained pitch variation.
- 35 ms lethal hit stop, directional corpse knockback and simple wall-aware corpse settling.
- Predictable enemy IDLE, INVESTIGATE, CHASE and STAGGERED states.
- 90-degree enemy vision with distance checks and wall/closed-door line-of-sight occlusion.
- Gunshot and door-impact hearing events that send enemies to the sound position without revealing the player's live position.
- Physics-door enemy stagger, impact noise and impact-tier camera feedback.
- Lightweight non-blurring scanline/grain overlay and brief player-death red flash.
- CombatAudioDirector interface for future copyright-safe combat music and cleanup ambience.
- Delayed 0.42-second Violence-to-Silence transition event before `CLEANUP REQUIRED`.
- Weapon-profiled blood geometry: long line splashes for pistol, directional fans for SMG/LMG and a reusable radial profile for future shotgun attacks.
- Slowly expanding corpse-centered blood pools that begin small and bloom over roughly 4–8 seconds.
- Three modular firearm wound overlays for corpses with intensity-scaled blood/tissue pixels.
- Detachable pixel gore chunks with directional flight, wall collision, spin, settling and existing cleanup compatibility.
- Fixed-direction pixel fake shadows for walls, players, enemies, weapons, shell casings, corpses and rotating door panels.
- Window-aware wall-shadow breaks that preserve sightline and architectural light framing.
- Sixteen original 8x8 environment and furnishing tiles for checkerboard, plank, carpet, stage, corridor, brick and bathroom surfaces plus sofas, tables and fixtures.
- High-contrast Nightclub room zoning with bright architectural trim, distinct room identities and a dedicated furniture layer.
- Fixed-offset object shadows for furniture and fixtures, matching the existing actor, weapon, casing and door shadow language.
- Position-driven camera tilt that mirrors across the room center, with a configurable center buffer, maximum angle and exponential smoothing.
- Static deep-color exterior backdrop beneath the building, revealed by an unpainted perimeter floor band to create a layered architectural cutout.
- Hold-Shift tactical look-ahead with a longer cursor-directed camera reach, while normal aiming uses a restrained 0.25 positional weight.
- Enemy visual reaction delay randomized from 0.2–0.4 seconds, requiring continuous exposure before pursuit and firing begin.
- Separate opaque-vision collision layer: walls and doors block sight while physical glass windows remain transparent to AI raycasts.
- Optional per-enemy translucent FOV debug cone with range arc for angle and distance tuning.
- Wall-aware instantaneous hearing: opaque geometry applies a 1.5x effective-distance penalty while glass does not attenuate sound.
- Authored two-point idle patrol routes for spawned enemies, replaced immediately by investigation or chase targets when alerted.
- Safer diagonal AStarGrid2D routing with 7–10 frame human refresh intervals and solid furniture included in navigation.
- Reusable `human` / `dog` AI profile foundation with faster dog reaction, movement, path refresh and direct open-room pursuit.
- Patrol micro-state machine with AStar-driven movement, randomized 0.5–1.5 second waypoint waits and separate level-authored 48–64px routes.
- Automatic sentry fallback for missing or unreachable patrol routes, smoothly scanning ±45 degrees every 2–4 seconds.
- Soft navigation clearance costs around walls and furniture, encouraging safer paths without sealing narrow two-tile doorways.
- Corpse discovery checks for idle guards using the same distance, FOV and opaque-ray rules as player vision, triggering an incident investigation once per corpse.
- Investigation arrival behavior with a configurable 2.2-second multi-direction look-around before returning to patrol or sentry duty.
- Explicit high-priority visual chase transition with 1.25x human pursuit speed and last-seen-position investigation after contact is lost.
- Named Player, Enemy, Solid_Wall, Glass_Window, Projectile and Vision_Occluder physics layers with purpose-specific collision masks.
- Glass now blocks actor movement while allowing projectile, vision and non-attenuated sound passage; solid walls and doors retain all relevant blocking behavior.
- Red/green FOV debug feedback that changes immediately when raw visual contact is established.
- Runtime `F3` toggle that enables or disables FOV visualization for every active enemy without requiring Inspector edits.
- Larger 7–10px HUD typography, stronger muted-text contrast and a shorter control legend for legibility at the native 320x180 viewport.
- Configurable gunner/melee enemy combat roles, with two melee guards enabled in the default Nightclub encounter.
- Direct 1.25x-speed CHASE rush whenever the opaque line to the player is clear, falling back to A* only while geometry blocks pursuit.
- 1.5-second chase memory before last-known-position investigation, preventing instant disengagement when the player cuts a corner.
- Short-range one-hit melee attacks with hidden firearms, independent cooldown and a brief visible swing arc.
- Nearest-sampled full-screen CRT shader with restrained scanlines, vignette, curvature and chromatic separation, toggleable with `F4`.
- Exterior-only HSV hue cycling over the architectural void, independently toggleable with `F5`.
- Four low-energy scripted neon lights with sine-wave breathing and optional broken-tube flicker.
- WorldEnvironment glow plus 1.3 contrast and 1.5 saturation grading, with the HUD rendered above screen distortion.
- Ambient 0.005-radian camera drift and a reusable kill-effect interface combining trauma shake with short red/white flashes.
- Dedicated four-room Tactical Lab selectable from the debug menu, built around four physical doors, internal glass firing lanes, blind corners and multiple routes.
- Mixed Tactical Lab encounter with melee patrols, mobile gunners and two anti-bait fixed sentries that ignore sound investigation while retaining vision and attacks.
- Tiered door-panel combat: high-angular-speed impacts kill one-hit enemies while lower impacts apply a preserved stagger state.

### Changed

- Player movement is now immediate at 115 px/s with no acceleration or release inertia.
- Projectile speed increased from 295 to a 650–720 px/s weapon-specific range.
- Pistol is semi-automatic with 12 rounds, 0.15-second interval and 0.75-degree spread; SMG and LMG remain automatic.
- Camera mouse lead remains approximately 30 pixels with whole-pixel smoothing and fast trauma decay.
- Door force falls off with angular speed and angular velocity is capped, preventing exaggerated late-swing acceleration.
- Player/enemy/interaction colors were brightened for combat readability without changing the existing identity.
- Environment lighting combines a readable global grade with restrained breathing PointLight2D accents; combat muzzle lights remain enabled.
- Hue cycling is confined to the exterior void and can be disabled independently without altering interior art.
- STAGGERED enemies ignore the door's own noise event, preventing impact feedback from being overwritten by INVESTIGATE in the same frame.
- Exterior void cells are excluded from AStar navigation so the visual background cannot become a traversable shortcut.
- Enemy aim requires current line of sight; losing sight transitions to investigation at the last seen position.
- Player death accepts immediate `R` restart with no fade, confirmation or loading screen.

### Validation

- v0.0.2 combat smoke test verifies movement, pistol tuning, projectile speed, muzzle flash, recoil, layered audio, hit stop, hearing, stagger and corpse knockback.
- Vision regression verifies walls block sight while unobstructed targets remain detectable.
- Nightclub completed a 600-physics-frame integration run without runtime errors or leaked time scale.
- Gore-system regression verifies line/fan/radial patterns, lethal chunks, progressive pools, wound variants and the complete enemy-death wiring.
- Fake-lighting regression verifies global visibility, window shadow breaks and fixed-offset shadows that follow rotating doors and weapons.
- Interior-style regression verifies all seven Nightclub material zones, bright wall trim, furniture placement and synchronized object shadows.
- Camera-tilt regression verifies a level center dead zone, mirrored left/right angles and the configured maximum rotation.
- Orthographic-layer regression verifies the exterior underlay, transparent floor perimeter, solid navigation boundary, 0.25 normal look weight and Shift extended view.
- Enemy-FOV regression verifies continuous reaction timing, exposure reset, distance/angle rejection, wall and door occlusion, and sight through physical windows.
- Hearing/patrol/path regression verifies glass and wall propagation differences, patrol motion, furniture obstacles, diagonal routing and weapon-specific sound radii.
- Patrol-cadence coverage verifies moving/waiting/sentry transitions, minimum route length and weighted obstacle clearance.
- AI-state-network regression verifies corpse discovery, investigation targeting and scanning, reaction gating and aggressive chase configuration.
- Physics-layer/glass regression fires real projectiles through a window and into an adjacent solid wall while verifying every named layer and mask.
- Debug/UI regression verifies global F3 cone toggling, red/green-capable enemy flags and minimum readable HUD/theme font sizes.
- Chase-combat regression verifies role configuration, direct-path rushing, wall-triggered A*, chase-memory expiration, shared gunfire and melee lethality.
- Neon/shader/camera regression verifies Shader compilation, nearest sampling, post-processing values, light controllers, F4/F5 toggles, HUD isolation and kill flashes.
- Tactical Lab regressions verify menu access, four-room layout, glass lanes, four doors, fixed sentries, cross-room A*, lethal/stagger door tiers and a 600-frame run.

## [v.0.0.1] - 2026-08-16

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
- AStarGrid2D navigation generated from wall TileMap cells, with periodically refreshed room-to-room enemy paths.
- Enemy detection range and idle deceleration that prevent off-range movement jitter.
- Debug title menu with VBoxContainer buttons for direct Nightclub and Sandwich Shop scene loading.
- A separately configured Sandwich Shop level with its own floor, wall, object-layer layout, lighting grade, spawns and atmosphere.
- Per-weapon projectile spread values for pistol, SMG and LMG fire patterns.
- Deferred ammo-state synchronization after every gameplay scene load.

### Changed

- Restored the standard macOS window frame and window controls.
- Replaced the procedural environment renderer with an editable layered TileMap workflow.
- Enemy placeholder drawing was replaced by imported pixel art; pistol and SMG weapons now use distinct visuals.
- Weapon rendering moved to an animated pivot shared by sprites and muzzle placement.
- Viewport scaling now uses integer multiples to prevent full-frame resampling blur.
- Dynamic camera smoothing and trauma offsets are rounded to whole pixels; rotational shake is disabled for pixel clarity.
- UI system-font antialiasing is disabled and small/body/heading sizes were increased for legibility at 320×180.
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
- Level-navigation smoke test verifies menu targets, Sandwich Shop layers, A* routes, idle enemies, ammo initialization and spread data.
- Pixel-clarity regression verifies integer scaling, non-antialiased UI text and whole-pixel camera/shake transforms.
