# Changelog

All notable project changes are recorded here. Version branches remain unreleased until explicitly approved and merged into `main`.

## [v.0.0.10] - In development

### Added

- Central runtime object budgets for projectiles, shell casings, transient effects, blood evidence, corpses, dropped weapons and debris, including peak/drop telemetry.
- A rolling performance monitor with average and p95 frame time, peak scene-tree size and an optional in-game `F6` diagnostics overlay.
- Windows and Linux export presets, original application icon, proprietary project license, third-party notices and the Godot engine license.
- A release checklist and GitHub Actions release workflow that builds both desktop targets, generates SHA-256 checksums and uploads packaged artifacts on manual dispatch or version tags.

### Changed

- Interaction prompts, corpse-deposit checks, cleanup counters and security-device discovery now use bounded sampling or cached collections instead of repeated full-tree scans.
- Gameplay effect creation now reserves capacity before entering the scene tree and releases reservations automatically when nodes exit.
- Headless test runs suppress disposable positional audio playback, preventing audio-server playback objects from surviving stress-scene teardown.

### Tests

- Added runtime-budget saturation/release coverage, a high-volume combat/evidence stress scenario and release-metadata/export-preset validation.
- Verified a real Godot resource-pack export from the Windows preset.

## [v.0.0.9] - In development

### Added

- Cached original procedural pulse, danger and electrical-room loops, providing an audible default score without external music dependencies.
- Event- and threat-driven music intensity that responds to gunfire, executions, tactical alerts, security alarms and actively pursuing enemies.
- Dedicated Music, SFX and Ambience buses with persistent master/category volume settings.
- Native-resolution settings screen for screen-shake strength, flash intensity, CRT effects and ambient camera motion.
- Persistent versioned settings plus live audio preview, restore-default controls and global fade transitions between missions and menus.

### Tests

- Added settings persistence, audio-bus application, accessibility-effect, settings-layout, procedural-loop cache and dynamic-mix regression coverage.

## [v.0.0.8] - In development

### Added

- A three-case campaign sequence from Nightclub through Sandwich Shop to After Hours, with Tactical Lab retained as an always-available training mission.
- Versioned local JSON progress containing completed cases and score-protected personal-best action reports.
- Locked mission selection, native-resolution case-file UI and mission-specific pre-operation briefings.
- Post-operation reports showing grade, score, time, cleanup percentage, alarms, unresolved risk and newly unlocked cases.
- Retry, return-to-menu and continue-to-next-case flow from completed operations.

### Tests

- Added campaign catalog, disk persistence, UI layout, unlock flow and real level-to-save integration regressions.

## [v.0.0.7] - In development

### Added

- Data-driven mission profiles and a bounded objective tracker for elimination and security requirements.
- Sweeping security cameras with line-of-sight detection buildup, alarm latching and floor-wide tactical alerts.
- Close-range camera shutdowns and projectile destruction as quiet/loud security counterplay choices.
- Persistent mission-objective HUD lines, alarm accounting, completion bonuses and alarm score penalties.
- Cleanup-phase gating that requires every configured combat and security objective instead of only eliminating enemies.

### Tests

- Added mission-objective, security-camera and alarm-sensitive final-grade regression coverage.

## [v.0.0.6] - In development

### Added

- Value-weighted evidence severity, resolved-risk tracking and cleanup completion ratios.
- Two-step body-bag packaging followed by physical corpse transport to the extraction zone.
- Optional early extraction with remaining evidence, score calculation and S/A/B/C/D cleanup grades.
- Cleanup HUD risk totals and contextual extraction prompts.

### Tests

- Added cleanup scoring, evidence severity, body-bag and extraction regression coverage.

## [v.0.0.5] - In development

### Added

- Data-driven Gunner, Rusher, Assault, Heavy and Hound enemy profiles with distinct perception, movement, weapons and attack timing.
- Heavy enemies resist ordinary knockdowns while Hounds trade firearms for extreme speed and a wide vision cone.
- `Q` weapon throwing that knocks down normal enemies, staggers resistant enemies and preserves the thrown magazine in a recoverable pickup.

### Tests

- Added enemy-archetype and weapon-throw regression scenes to CI.

## [v.0.0.4] - In development

### Added

- Three-tier enemy alert memory with faster reacquisition while suspicious or fully alerted.
- Corpse reports that assign nearby responders to left/right search sectors, guard duty and alert observation instead of stacking on one body.
- Explicit return-to-patrol behavior after a search expires.
- Sustained-fire spread growth and weapon-specific movement/reload handling for Pistol, SMG and LMG.
- Cleanup loadout with Mop, Evidence Bag and Body Bag efficiencies plus interactive corpse dragging.
- `After Hours` vertical-slice map combining doors, glass, mixed enemy roles, weapon acquisition and the complete cleanup loop.

### Tests

- Added tactical-alert, cleanup-tool and vertical-slice regression scenes to CI.

## [v.0.0.3] - 2026-08-17

### Fixed

- Throttled bloody-footprint source scans so evidence growth does not cause a full group traversal every physics frame.
- Made all footprints require exactly two cleanup strokes, including faint trailing prints.
- Removed duplicate weapon-pickup prompt scans and prevented empty enemy weapons from fabricating ammunition.
- Made CombatAudioDirector apply its exported combat and cleanup mix configuration automatically on scene startup.

### Added

- Dedicated CombatDirector, CleanupRegistry and CorpseIncidentRegistry boundaries.
- Transitive corpse-cluster ownership and completion across chained nearby bodies.
- Cleanup contracts for blood stains, pools, gore chunks, corpses and shell casings.
- Data-driven gun automatic mode, texture and audio streams plus a shared AttackCatalog for blood and death response.
- Real player Pistol/SMG/LMG cycling on repeated `1` input.
- EnemyPerception and EnemyNavigation helpers plus a standalone HUD controller.
- Cached execution targeting and event-driven enemy/cleanup counters.
- Cleanup-registry and wall-occluded black-box AI regressions.
- GitHub Actions workflow for Godot parsing and the full regression suite.
- Explicit SEARCH and ATTACK enemy states with short visible attack tells instead of firing or striking directly from movement logic.
- Direction-aware multi-point searches around the player's last confirmed position, with per-enemy route variation and walkability filtering.
- Distance- and occlusion-scaled sound uncertainty so guards investigate plausible nearby positions instead of receiving exact coordinates through walls.
- Friendly-fire ray checks that prevent gunners from wasting shots into allies standing between them and the player.
- Opaque vision collision for solid furniture, keeping sight, navigation, projectile and actor blocking rules consistent.
- Corpse-incident claims that merge bodies within 48px and assign only one active investigator, with automatic release when that guard is interrupted or killed.
- A six-second hard limit for area searches so guards reliably resume their authored patrol or sentry behavior.
- A standalone corpse-coordination regression covering exclusive claims, nearby incident merging, independent distant incidents and completed-scene propagation.
- Arrival-gated search budgets that begin only when a guard reaches the first scene-search point, preserving the full six-second inspection window regardless of travel time.
- Movement-progress watchdogs with forced replanning, unreachable search-point skipping, abandoned investigation recovery and patrol-route fallback.
- A standalone enemy-search regression covering travel-time exclusion, arrival activation and two-stage stuck recovery.
- Centralized noise dispatch that sorts eligible guards by effective heard distance, assigns two PUSH responders, one offset SWEEP responder and hold-position GUARD roles to the remainder.
- Role-specific human movement tuning with 42px/s gunners and 62px/s melee guards, plus stronger but still sub-player chase multipliers.
- Blocked-fire repositioning that makes rear gunners sidestep for a new firing lane instead of waiting indefinitely behind an ally.
- Player melee target caps: fists and knives strike only the nearest valid enemy, while the bat retains a three-target crowd-control niche.
- Weapon-specific whiff recovery, melee noise propagation and three-stage execution noise that exposes committed players to nearby guards.
- Upright in-world state glyphs for investigation, search, confirmed pursuit/attack and hold-position guard duty.
- Noise-role and melee-balance regressions covering responder assignments, speed profiles, single-target edged attacks, capped bat crowds and miss recovery.
- Enemy weapon drops with an `E` pickup prompt, pistol-only starting inventory and persistent per-weapon magazine state.
- Distinct pistol/SMG/LMG enemy loadouts, layered audio tuning and an original 14x5 LMG pixel silhouette.
- Weapon-specific firearm tearing, LMG disassembly, blade execution and blunt execution corpse states with up to twelve directional limb/tissue chunks.
- EnemyCombatController extraction for attack timing, friendly-fire lanes, chase velocity and scored left/right firing-lane repositioning.
- Local enemy crowd separation around searches, pursuits and narrow approaches.
- Weapon-inventory regression coverage and explicit test audio teardown.
- Blood contamination from corpses and floor blood, producing alternating pixel footprints for roughly 4.5 seconds with step-by-step fading.
- Blood footprints as individually tracked cleanup evidence, with bounded generation and dedicated regression coverage.

### Changed

- Events is now a pure signal bus; noise occlusion and priority are calculated once per listener.
- Scene completion now requires removal of all evidence rather than blood alone.
- CombatAudioDirector owns real combat and ambience players with an abrupt combat fade and cleanup ambience transition.

## [v.0.0.2] - 2026-08-16

### Added

- Data-driven player melee arsenal with extreme close-contact fists (12px/35°), knife (16px/45°) and bat (28px/120°), each with distinct windup and cooldown.
- Dynamic enemy-only MeleeArea broad phase followed by exact range/angle filtering and wall/glass ray occlusion, preventing attacks through geometry.
- 140ms neon weapon trails with white fist, cyan knife and magenta bat silhouettes; number keys 1–4 switch between gun and melee modes.
- Nonlethal fist knockdowns plus lethal knife and bat chains integrated with existing combo, hit-stop, trauma, blood, gore, corpse and cleanup systems.
- Distinct directional knife cuts and crushed red/white blunt trauma corpse rendering, with weapon-specific line versus radial blood profiles.
- Fixed player melee filtering against the project's singular `enemy` group, restoring fist, knife and bat hit detection.
- Synchronized each melee query circle and forward offset with its visible reach, plus distinct 60ms air-line fists, 50ms cyan knife flash and 120ms thick hot-pink bat arc.
- Anchored melee detection 14px ahead and visual trails 12px ahead while retaining a player-centered absolute range clamp, preventing the forward anchor from secretly extending reach.
- Additive-blended melee effects now brighten over dark floors and blood, with stable micro air particles, a six-step expanding cyan knife slash and a center-bulged dual-edge hot-pink bat sweep.
- Layered player `UpperBody` presentation with code-driven wind-up, 4–6px strike thrust, weapon-specific rotational overshoot and sine-smoothed recovery, without disturbing root physics, aim or camera transforms.
- BodySprite-attached `MeleeTip` global anchor now spawns root-level trails at the animated hand/weapon point; removed the duplicated 12px VFX offset and clamped knife/bat expansion inside the remaining physical reach.
- Moved the held fist/knife/bat drawing from the aim-only Player root into `BodySprite/MeleeWeaponVisual`, so the weapon visibly inherits local wind-up, overshoot and recovery instead of only translating forward.

- GunData-driven recoil, camera shake, muzzle-flash size/duration, bullet speed, knockback, hearing radius and lethal hit-stop tuning.
- One-to-two-frame muzzle flash geometry with a short-lived PointLight2D for dark-room illumination.
- Layered gunshot audio using transient, mechanical and low-pitched punch components with restrained pitch variation.
- 35 ms lethal hit stop, directional corpse knockback and simple wall-aware corpse settling.
- Predictable enemy IDLE, INVESTIGATE, CHASE and STAGGERED states.
- 90-degree enemy vision with distance checks and wall/closed-door line-of-sight occlusion.
- Gunshot and door-impact hearing events that send enemies to the sound position without revealing the player's live position.
- Contact-driven door knockdown, impact noise and camera feedback.
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
- Glass blocks actor movement while passing vision and non-attenuated sound; the first projectile shatters and removes it, then continues through.
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
- Frozen-until-contact physical doors with cast-shape continuous collision detection and an enlarged enemy-only sweep area.
- Opening door sweeps apply a consistent four-second knockdown; door-specific stagger and lethal tiers were removed.
- Directional door knockback, post-impact angular damping, high-energy white flash feedback and 30-piece pixel wood splinters.
- Four-second door knockdowns with a sideways prone pose, disabled attacks and an alerted recovery transition.
- Space-triggered 24px ground executions with nearest-target selection, full movement/fire/reload input lock and three timed impact beats.
- Execution-specific camera trauma, final-frame hit stop, red flash, radial blood burst, gore chunks, corpse pool and normal combo credit.
- Twelve-particle 0.24-second metal spark bursts on StaticBody2D and TileMapLayer wall impacts, emitted opposite the incoming trajectory and scaled for native-view visibility.
- Fixed real level walls not producing sparks because TileMapLayer colliders were omitted from the solid-surface classifier.
- Expanded lethal blood feedback with up to 60 directional mist droplets, a 48-particle death spray, 2–8 tissue/bone chunks and stronger kill trauma.
- Destructible TileMap glass: Layer 4 impacts erase the window cell, clear its navigation obstacle, emit 52 directional cyan shards and a cool camera flash.
- Projectiles continue nine pixels beyond shattered glass and retain their original direction, damage, owner and remaining lifetime for through-window kills.
- Context-sensitive center-screen `[ SPACE ] EXECUTE` prompt near a knocked-down enemy.
- Zero-input door activation: any moving player or enemy slide collision instantly starts the same fixed-speed slam.
- One-way CLOSED → SLAM_OPENING → OPEN state machine; opened doors remain open and cannot fight with a close transition.
- Door records its initiating actor and excludes that pusher from sweep damage, preventing enemies from knocking themselves down.
- Contact speed splits opening into a quiet 8 rad/s non-damaging push below 81 px/s and a dangerous 25 rad/s slam at or above the threshold.
- Corrected door-side math to use the panel normal, ensuring every E interaction swings away from the player instead of becoming body-blocked.
- Door damage is evaluated only during real deterministic SLAM_OPENING rotation, so a stationary or fully open panel cannot knock down an enemy.
- Door-panel collision is temporarily suppressed during the initial swing and restored only after the player leaves the sweep area, preventing depenetration jitter and body pinning.
- Door rotation is deterministic at 22 rad/s with physical blocking disabled only during the roughly 0.07-second sweep and restored at the open endpoint.
- Thirty-piece directional pixel splinter burst and stronger opening trauma on the first high-speed body impact.

### Changed

- Confirmed guards now require real FOV contact to keep tracking or attack; losing sight transitions through pursuit memory into a directional area search.
- Fixed sentries remain physically fixed during combat while retaining visual acquisition and ranged attacks.
- Solid furniture collision is enabled for players, enemies and projectiles.
- Pursuit memory now follows only the last confirmed player position; knockdown recovery searches locally instead of receiving the player's live coordinates.
- Lost-sight chase spacing and disengagement decisions now use last-known information rather than the player's live hidden distance.
- Gunshots no longer pull every hearing guard off duty; surplus listeners face the incident and hold their patrol position for 3.5 seconds.
- Player movement is now immediate at 115 px/s with no acceleration or release inertia.
- Projectile speed increased from 295 to a 650–720 px/s weapon-specific range.
- Pistol is semi-automatic with 12 rounds, 0.15-second interval and 0.75-degree spread; SMG and LMG remain automatic.
- Camera mouse lead remains approximately 30 pixels with whole-pixel smoothing and fast trauma decay.
- Door opening uses a fixed 22 rad/s deterministic sweep instead of accumulated rigid-body acceleration.
- Player/enemy/interaction colors were brightened for combat readability without changing the existing identity.
- Environment lighting combines a readable global grade with restrained breathing PointLight2D accents; combat muzzle lights remain enabled.
- Hue cycling is confined to the exterior void and can be disabled independently without altering interior art.
- STAGGERED enemies ignore the door's own noise event, preventing impact feedback from being overwritten by INVESTIGATE in the same frame.
- KNOCKED_DOWN enemies also ignore combat-noise state changes until their four-second recovery completes.
- Player-driven door torque can no longer cross into the lethal tier; lethality requires a fresh 0.22-second projectile-impact authorization and is consumed by the first target.
- Exterior void cells are excluded from AStar navigation so the visual background cannot become a traversable shortcut.
- Enemy aim requires current line of sight; losing sight transitions to investigation at the last seen position.
- Player death accepts immediate `R` restart with no fade, confirmation or loading screen.

### Validation

- Godot 4.7.1 editor parsing completed without errors after the AI state expansion.
- Nightclub, Sandwich Shop and Tactical Lab each completed a 600-frame headless integration run with the enhanced AI.
- Corpse-coordination regression passes under Godot 4.7.1, followed by clean editor parsing and fresh 600-frame runs of all three maps.
- Enemy-search regression passes under the normal project/autoload environment; all three maps then completed another clean 600-frame run.
- Noise-role and melee-balance regressions pass, followed by clean corpse/search reruns and 600-frame Nightclub, Sandwich Shop and Tactical Lab integrations.
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
- Tactical Lab regressions verify menu access, four-room layout, glass lanes, four one-way contact doors, fixed sentries, cross-room A*, knockdown sweeps and a 600-frame run.
- Ground-execution regression verifies the Space action, four-second prone state, disabled enemy weapon, input lock, three-hit sequence, normal kill/combo credit, corpse generation and persistent blood output.
- Door-state regression verifies player/enemy contact activation, fixed-speed sweep, one-way open state, collision restoration and range-gated Space execution prompts.

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
