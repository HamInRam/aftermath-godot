# AFTERMATH — Neon Crime Prototype

An original Godot 4 top-down shooter inspired by the visual language and pacing of neon crime thrillers.

## v1.2.3 systemic incident ecology

- Combat can now rupture authored fuel, alcohol, grease, coolant, chemical, sprinkler, electrical, glass, paper and gas-line props. These consequences persist into cleanup instead of ending as short-lived VFX.
- A shared sparse pixel surface simulates fuel fire, smoke, foam, coolant, ash and dust alongside water, oil, chemicals and blood. Fire consumes connected fuel, smoke blocks AI sight, water and foam suppress flames, chemicals neutralize into foam, and drains remove runoff by material-specific rates.
- Every campaign layout has its own two-prop incident pairing and floor-drain route, turning architecture into a different combat/cleanup problem rather than reskinning the same objective.
- Cleanup now begins with source and hazard stabilization. Repaired furniture offsets its property penalty and fully restored destruction remains eligible for the top grade, supporting intentional chaos followed by deliberate reconstruction.
- Reaction work remains bounded and chunk-based: no liquid, smoke, flame or footprint pixel creates an individual scene node.

- Weapon impacts now separate expressive limb articulation from restrained body-mass travel, with per-weapon root-speed caps and hard wall damping that prevent corpses from launching through encounter geometry.

- Every ground liquid now uses the same sparse hard-pixel simulation: plumbing water, oil, chemical spills and cleaner solution burst, spread, evaporate and clean at pixel density instead of appearing as smooth translucent discs.
- Water crossing blood creates pale directional runoff, footsteps carry local liquid color, active plumbing must be repaired, and electricity follows only connected wet pixels across the floor.
- Blood evidence now lives in sparse 32x32 hard-pixel texture chunks rather than one node per stain: airborne pixels settle into the same density map used by pools, wall spray, drag smears and bloody footprints.
- Mop and washer movement is resampled into a continuous capsule brush between cursor frames, producing a literal clean strip with diluted wet edges and UV-only residue instead of making whole blood objects disappear at once.
- Campaign encounters target 7-11 enemies with mixed roles, readable threat outlines and clearer character poses; cleanup removes redundant confirmations through one-action body bags and short-range evidence magnetism.
- Local `user://playtest_telemetry.json` records the last 100 completed runs (death locations, weapon usage, phase timing and leftover evidence) without networking or personal data, supporting evidence-based balance passes.
- The interface uses a consistent 8x8 icon vocabulary and color semantics across HUD, case files, briefing, reports, settings, safehouse and workshop; strong focus rails make keyboard/controller navigation immediately visible.
- Interior dressing follows a restrained real-space rule: furniture lives in perimeter utility bands or small purposeful groups, every room keeps a readable open centre, and doors retain clear approach/exit lanes.
- Every campaign map follows a CQB floor-plan grammar: one instantly readable primary spine, multiple breach options, limited cross-map firing lanes, door staging space, a flank loop and a low-friction cleanup route. Enemy groups occupy tactical jobs instead of forming a uniform scatter.
- Combat aftermath now has weapon grammar rather than generic red volume: pistols puncture and trail, automatics tear in clustered lines, shotguns blast broad exit fans, blades cut directional seams and blunt weapons crush compact regions.
- Airborne droplets collide with walls, blood pools follow wound direction and floor material, corpses can lose modular limbs, dragging paints continuous smears, and casings become bloodied when they settle in fresh evidence.
- The presentation remains native low-pixel art: a few deliberate dark, arterial, tissue, bone and wet-highlight pixels carry the detail while evidence merging and runtime budgets keep large scenes stable.
- Destruction is energy- and material-driven rather than a sprite swap: wood splinters, glass bursts, metal dents/arcs, fabric tears, ceramic fractures and liquid leaks progress through damage, failure and directional collapse.
- A small number of real physical chunks can hit enemies or other props before settling into sortable cleanup evidence; short-lived fragments supply density without exceeding the runtime budget.
- Corpse momentum, doors, firearms, melee and thrown weapons share the same chain-reaction interface. Water, electricity, oil, glass, spills and smoke persist into cleanup, and active sources must be repaired first.
- Each of the twelve cases has one signature destructive setpiece with a tactical consequence, while existing mop, washer and evidence-bag controls handle the aftermath without adding a row of fiddly tools.
- The whole campaign uses a bright, original 1980s neon-crime stage grade: rooms remain readable without local lights, while restrained cyan/magenta/amber accents, cream wall caps and right-down fake shadows create depth.
- Scanlines, vignette, curvature, chromatic separation, glow and color grading are deliberately subtle so the low-resolution image and interface stay crisp instead of becoming dark or smeared.
- All twelve campaign cases now have their own functional room graph, sight-line risks, glass lanes, flanking routes, furnishing rhythm and cleanup return path, including a complete rebuild of the original Nightclub.
- The environment stays deliberately low-density: native 8x8 floors/walls, 8x8 or 16x16 props, hard edges, limited colors and sparse transparent wear marks.
- Furniture, appliances, mission equipment and large landmarks can be damaged by gunfire, melee, thrown weapons and door impacts, collapse into simple debris, alter navigation and be restored during cleanup.
- Strong visual anchors make every location recognizable at a glance, from Harbor Exchange's crane and Cold Storage's freezer bank to Police Archive's evidence wall and Last Call's destroyed DJ booth.
- Material zoning serves gameplay as well as art: carpet, plank, tile and concrete immediately signal room function, blood absorption and expected cleaning effort.
- Spawn, patrol, ammunition and extraction placement is protected against future layout edits, while a dedicated regression gate verifies unique topology and navigation across the campaign.

## v1.1.0 visceral replay overhaul

- Every projectile now creates one shared DamageContext, so hit zone, range, energy and weapon identity drive the same blood, corpse and feedback result.
- Firearms gain movement spread, turning instability, sustained-fire recoil recovery and wall-safe muzzle checks; pistol, SMG, LMG and Shotgun retain distinct handling identities.
- Blood now has entry/exit behavior, stronger lethal spray, wall runs, coagulation, clothing absorption and higher-energy weapon-specific gore under existing runtime budgets.
- All twelve cases have named visual/layout variants, safe procedural dividers and palette identities in addition to their authored enemy, security and cleanup routes.
- Completed campaigns unlock five modes through `M`: Standard, Score Attack, New Game+, date-seeded Daily Challenge and continuous Gauntlet.
- Replay conditions alter light, enemy roles, ammunition, blood load and police response; each case permanently tracks Ghost, Restraint and Immaculate mastery.
- Final outcomes now include Clean Break, Ghost, Professional, Kingpin and Exposed using behavior accumulated across the campaign.

## v1.0.0 complete game loop

- Finish all twelve cases to unlock Score Attack and New Game+; cycle the active run with `M` from Case Files.
- The final action report resolves into Clean Break, Professional or Exposed according to cleanup quality, Heat, police timeout and whether valuables were stolen.
- Career schema v4 persists campaign records, credits, tool upgrades, three specializations, contracts, Heat, endings and replay mode.
- New Game+ accelerates enemy recognition/chase behavior and police arrival while preserving the one-hit combat rules; Score Attack focuses on leaderboard-style route optimization.

## v0.3.0 full campaign

- Twelve sequential cases now form a complete three-act crime arc, with escalating archetype mixes, security objectives and cleanup pressure.
- Case Files display four missions per page; use `A/D` to navigate, `L` for the unrestricted Tactical Lab, and complete each case to unlock the next.
- Every new case has its own briefing, debrief, reward curve and combat/cleanup route configuration while reusing the stable systemic level kit.

## v0.2.0 contracts and safehouse

- Select one of five contracts from each briefing with `C`; optional conditions change payout and are recorded in the forensic debrief.
- Press `H` in Case Files for the Safehouse, where first-time case completions fund Executioner, Ghost and Cleaner specializations.
- Persistent Heat shortens authored police-response windows, turning the cleanup phase into a route-planning decision rather than a consequence-free checklist.
- Red environmental lure props can be triggered with `E` to redirect nearby guards through the same wall-attenuated hearing network as weapons and doors.
- Press `U` for the independent five-route tool Workshop; 90% cleanup is certified while 100% remains the perfect-clean target.

## v0.1.1 blood forensics

- Visible mist droplets settle into permanent micro-stains instead of simply disappearing, while wounds continue seeping and dragged bodies repaint their route.
- Head/torso/limb impacts anchor the death pool near the actual wound; tile, wood and carpet alter stain spread, darkness and cleanup effort.
- Idle guards can investigate visible blood and footprint trails, and Assault enemies introduce a recoverable seven-pellet Shotgun with radial close-range gore.
- Melee and execution inputs are buffered, AI perception/crowd work is staggered and cleanup evidence uses a spatial index for stable high-density play.
- Cleanup now tracks mop saturation: rinse at an authored sink before a dirty mop can continue, while the HUD reports tool progress and shoe contamination.
- Campaign profiles support zero-alarm and limited-shot bonuses plus property-damage penalties; reports disclose shots, alarms, damage and bloody tracks.
- Pause/resume, directional death feedback and an optional high-contrast enemy outline improve usability without changing the pixel presentation.

## v0.1.0 encounter intelligence

- Ranged enemies score reachable cover/peek pairs and fall back to a lateral route when their firing lane is blocked
- Shots are rejected when another enemy occupies the projectile lane; gunners can fire from a peek and briefly retreat behind cover
- Combat noise and corpse alerts preserve defenders in staffed rooms instead of draining every space into one incident
- Empty gunners seek reachable dropped firearms while melee-only archetypes retain their role
- Reloading now transfers finite per-weapon reserves, and every authored mission contains weapon-specific ammunition pickups

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
- The starting pistol has 24 reserve rounds; cyan ammunition boxes replenish only their marked weapon reserve
- Each owned gun preserves its own partially used magazine when cycling weapons
- Left mouse — fire or melee attack; during cleanup, hold and move the cursor to scrub along a real stroke (holding still does not clean)
- Hold right mouse during cleanup — inspect residue with a forward ultraviolet lamp
- `Tab` during cleanup — trigger the cooldown-based circular residue scan pulse
- Melee is deliberately unforgiving: fists 12px, knife 16px and bat 28px, with forward-anchored compact trails
- `R` — reload during combat; restart after death or completion
- `Space` — execute a nearby knocked-down enemy
- `E` — context action: pick up, drag/drop a body, rinse a mop at a sink, use security or extract
- Cleanup mode disables new bloody footprints, reports named room cleanliness, and renders diluted wet mop trails that dry over time
- Career cleanup pays credits after every case; press `H` for the Safehouse, `U` for the five-route Workshop and `T` to switch Normal/Professional cleaner guidance
- On Case Files, use `A/D` to page through twelve cases, `L` for Tactical Lab and—after completing Last Call—`M` to cycle Standard, Score Attack, New Game+, Daily Challenge and Gauntlet
- Cleanup scenes contain two story clues, one valuable with secure/steal choice, and three pieces of furniture that can be restored with `E`
- During cleanup, `1` equips the Mop and `2` equips the broad Pressure Washer; `E` automatically handles rinsing, loose evidence, body bags, corpse dragging and nearby scene interactions
- A dirty mop gradually loses efficiency but never stops working; rinse it at a sink to restore full cleaning speed
- Detailed cleanup counts appear during the active `Tab` scan; clues, valuables and furniture are optional score opportunities
- `Q` — throw the equipped gun; the weapon remains recoverable with its current magazine
- Move into a closed door — contact opens it once; ≥81 px/s is a dangerous slam, slower contact is a quiet non-damaging push
- Hold `Shift` — extend the camera toward the cursor
- `F3` — toggle enemy vision debug cones
- `F4` — toggle and save the CRT/screen post-processing preference
- `F5` — toggle exterior hue cycling
- `F6` — toggle the performance diagnostics overlay
- All other presentation options are available from the title-screen Settings menu
- `Esc` — pause/resume; press `Enter` on the pause screen to return to the case menu

## Game loop

1. Select a contract, replay condition and one of twelve escalating multi-room cases.
2. Eliminate the authored or seeded armed roster while managing weapon-specific ammunition and movement accuracy.
3. Chain kills before the combo timer expires.
4. Survive the one-hit lethality.
5. When combat ends, switch to cleanup mode.
6. Reach 90% scene certification or pursue 100% cleanup, optional clues, mastery medals and a stronger ending.

## Levels and AI

- Paged Case Files expose twelve sequential campaign cases; Tactical Lab remains an unrestricted stress sandbox
- Tactical Lab menu entry provides an expanded 64x36-tile, 17-enemy combat stress puzzle for door breaches, glass crossfire, blind corners, patrol baiting and fixed-sentry counterplay
- Every campaign case has a named TileWorld signature, palette, divider/accent geometry, furnishings, enemy composition and cleanup pressure configuration
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
