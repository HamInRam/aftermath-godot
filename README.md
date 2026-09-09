# AFTERMATH — Monochrome Blood Roguelike

An original Godot 4 room-combat roguelike built around hard-boiled monochrome violence, persistent crimson blood and modular firearms.

## Current presentation: The Descent rebuild

The world, six actor roles, corpse anatomy, eight firearm classes, title menu and corner HUD have been redrawn in native monochrome pixels. Direct mouse aim, mechanically staged reloads, bounded directional recoil and non-stacking hit stop emphasize fast, readable room combat. This is original OTXO-informed work, not a copy of its assets or full content catalog. See [implementation and reference decisions](docs/OTXO_REDESIGN.md).

## Current build: a complete six-floor run loop

- A descent draws six different venues from twelve authored shells. Each floor contains four or five combat rooms; health, armor, magazines, reserves, fitted parts, blood, skill cooldowns and Focus carry into the next floor.
- The first floor offers the entry loadout bench. Death retries restore that floor's entry checkpoint without reopening the bench or issuing free resources; retries are counted in the final report. The sixth floor ends the run and offers a new descent.
- Buildings now occupy 768×448 native world pixels rather than 384×224. Actors, furniture, 8px tiles and 24px doors retain their original scale. This expands physical combat space, not the art pixels or camera alone.
- 48 authored enemy/cover formations with eight safe transformations supply room variation. Standard floors have 16–20 hostiles. Seeded layouts remain identical on a death retry and change on a new run.
- Current player fire consumes shared blood directly; magazines and reloads do not gate it. Empty blood dry-fires; only Q throws the gun. Throws rotate, sweep against thin walls, rebound and knock down enemies.
- Grayscale detached anatomy matches the corpse's missing parts. Limbs and ragdolls collide with walls, preserve angular motion, settle, and remain readable above crimson blood. Blood-enhanced shots retain a strictly lossy resource return budget.
- Active cleanup transitions, tool handlers, extraction scoring and title-menu links to the retired cleaning workshop are removed. Old save fields and isolated legacy resources remain compatible; they do not gate the current run.
- HOW TO PLAY is a scrollable page with a fixed Back action. Death/clear actions stay onscreen rather than disappearing with transient HUD hints. See [runtime design and verification](docs/ROGUELIKE_RUNTIME.md).

## v1.3.0 modular armory foundation

- All twelve venues now use four to five broad hand-authored combat chambers instead of dense realistic-building mazes. Short links, wide movement lanes, alternate thresholds and restrained destructible cover keep the next threat readable at full combat speed.
- Forty-eight complete authored tactical modules bind hostile positions, patrol intent, role order and destructible cover into coherent room puzzles. Eight safe rotations/reflections create 384 spatial variants; a stable floor seed avoids repeats, death retries reproduce the same board and a new run reshuffles it.
- The former sequential Case Files screen is gone. `START NEW RUN` enters a nonlinear roguelike floor immediately, and every cleared floor advances to a newly selected venue without repeating the previous one.
- Blood reserve and `X` Focus use separate compact HUD cards and update paths, so neither resource can cover or overwrite the other.
- Standard venues field 16–20 mixed enemies. Every hostile patrols, dormant rooms remain visible without attacking early, and entrance/doorway safety checks prevent unfair spawn pressure or blocked traversal.
- Ballistic blood remains weapon-, penetration-, range-, hit-zone- and energy-sensitive, but ordinary ground spray, airborne mist, terminal bursts and wound trails are now more legible and forceful. Empowered crimson rounds retain their lossy mass budget, so stronger presentation cannot create infinite blood.
- The entire application now passes through one persistent noir presentation layer: title screens, loadout benches, HUD, world art and reports are quantized to pure grayscale, while deep crimson is reserved for blood, muzzle violence, lethal hazards and crisis feedback.
- High-contrast practical lighting, pure-black occlusion, restrained glow, native-pixel grain, monochrome print-registration echo, scanlines and a stronger vignette create a legible lo-fi film-noir image without softening the 320x180 pixel grid.
- Door impacts throw white/gray splinters; wall strikes pair hard white sparks with concrete dust. Ordinary muzzle flashes are white/gray, and only paid blood-enhanced shots receive crimson flash. Persistent blood remains the dominant colour memory of a cleared room.
- Replaced the four abstract gun identities with 64 distinct real-world platforms across handguns, PDWs, SMGs, shotguns, carbines, DMRs, sniper rifles and machine guns—eight authored choices in every class.
- Added a dedicated Armory and Gunsmith flow before deployment. Primary and secondary slots, unlock progression, platform specifications, signature traits and saved personal builds now live on separate native-resolution screens.
- A new descent starts outside the venue. Walking to the white equipment case opens a paused, image-first entry bench; enemies and mission timing remain dormant until the loadout is confirmed. Later floors inherit equipment.
- The entry bench is a contained 312x170 workbench over the still-visible level rather than a replacement full-screen page. Five pictured preset cards and five pictured inventory cards sit beside a paginated weapon table; every row leads with a side-profile firearm render and follows with icon-only damage, accuracy, magazine, report, mobility and weight cells. Pictured modification hardpoints, part feedback, segmented signature/mobility and one confirm action occupy a fixed lower strip.
- The roster has clearly named handgun, PDW, SMG, shotgun, carbine, DMR, sniper and machine-gun filters. Right-click either an equipped card or any available weapon row to enter its independent modification workbench; locked future requisitions remain visible but cannot be equipped or modified.
- The modification workbench keeps the current firearm large and central, shows live stat trade-offs, and presents compatible muzzle, optic, underbarrel, magazine/ammunition and stock/grip choices as unique 32x20 pixel pictures rather than a text-only list.
- Click a roster row to equip, `Tab` changes primary/secondary, arrows browse platforms or selected parts, and `Enter` deploys. Closing a required loadout cannot release the player into a frozen encounter.
- All 64 firearms and every compatible part receive strict nearest-filtered pixel renders. Receiver, stock, feed system, barrel length, optic, muzzle, underbarrel and magazine changes remain visible in the same preview used by presets, the Armory and the Gunsmith.
- Added five compatibility-aware attachment slots covering real muzzle devices, optics, underbarrel equipment, magazines/ammunition and stocks/grip modules. Calibre, rail, magazine-family and proprietary-mount restrictions are enforced rather than cosmetic.
- Every platform now carries individual calibre, action, feed, capacity, weight, length, cadence, handling, spread, recoil, report, penetration, property damage and aftermath values derived from its real role and tuned for readable top-down play.
- Attachments alter the live simulation: suppressors change report, muzzle flash and overall length; optics alter accuracy, handling and camera reach; magazines preserve actual capacity; stocks change doorway length and mobility; ammunition changes penetration and cleanup consequences.
- Player issue, enemy equipment, dropped and thrown guns, pickups, reload caches and old-save aliases preserve stable platform IDs plus installed parts. Weapon-scaled corpse damage now recognizes every new class.
- The current CI suite includes 51 regression scenes, including real floor-to-floor resource inheritance, actual death/retry, native-pixel art, gun handling, weapon inventory, collisions, room geometry, UI and blood economy. Further legacy tests remain available individually.

The version sections below are historical notes, not the current gameplay contract. Cleanup, UV inspection, linear case selection and their old controls are retired. Use the current loop above and [runtime guide](docs/ROGUELIKE_RUNTIME.md) for active behavior.

## v1.2.9 tactical sites and unified pixel feedback

- Moved the Sandwich Shop hound and its patrol deeper into the kitchen so a motionless player is not attacked from the exterior arrival point.
- Patrol actors now face the first authored route leg immediately instead of briefly inheriting an arbitrary east-facing orientation.
- Campaign regressions now reject direct hostile sight on an exterior spawn, patrol points that camp the exterior threshold and incorrect initial patrol headings.
- Gunfire now travels through authored room sectors, doors and windows with venue-specific attenuation instead of waking an entire level through one global radius.
- A small response team investigates while fixed sentries and passive guards retain room control; repeated shots merge into one incident and enemy fire cannot recursively summon another wave.
- The first doorway casualty marks a temporary fatal funnel. Responders contain, stage, reserve narrow thresholds or use another entrance instead of walking into the same ambush one by one.
- All twelve sites now carry a distinct acoustic/response profile, from nightclub music masking and cold-storage machinery to penthouse glass transmission and coordinated police/broadcast searches.
- Enlarged doors keep a fixed portal coordinate after opening, while compact procedural weapons, readable bullets, top-down ragdolls, sparse blood/liquids, pressure washing and restoration feedback share the same one-pixel visual language.
- That historical build used 48 Godot regression scenes covering the former combat-to-cleanup loop, campaign geometry, AI, UI and performance-sensitive effects.

## v1.2.8 responsive hostile-local Focus

- Combat Focus no longer changes the global engine clock: player movement, mouse aim, reticle, camera and HUD remain fully real-time.
- Enemy thinking, turning, movement, attack wind-up, weapon cadence and hostile bullets run at the Focus multiplier through local simulation scales.
- Focus transitions update hostile objects only when the state changes, eliminating global slow-motion aim drag and clock-induced visual stutter.

## v1.2.7 spatial ultraviolet flashlight

- Right-mouse UV inspection now renders a filled, wall-clipped flashlight fan instead of two decorative guide lines.
- Sparse pixel blood is illuminated per world pixel inside the fan, eliminating visible 32x32 chunk activation at cone edges.
- The separate active scan remains a short radial pulse, while ordinary blood and forensic residue only fluoresce inside the actual illuminated region.

## v1.2.6 exterior approach and room-scale exploration

- Every campaign venue is now a complete site rather than a single floating floor plate: a playable grass/service perimeter, façade walk, parking/loading strip and entrance approach surround the authored interior.
- Missions default to an exterior arrival aligned with the real front/service door. A per-level `player_spawn_context` switch preserves authored indoor starts for later story beats without another coordinate rewrite.
- Existing indoor plans, enemies, patrols, ammunition, security, lights, landmarks, cleanup secrets, disposal points and restoration props are translated together into the building coordinate space, keeping all systems synchronized.
- Each façade gains a physical exterior threshold with actor-width clearance. Offset entrances avoid internal partitions in asymmetric motel and penthouse layouts, and every hostile remains reachable from the outdoor start.
- The camera uses a wider 1.18x arcade framing and derives its clamps from the complete site. At the native 320x180 viewport it shows about 271x153 world pixels: enough floor for rapid lateral combat while still revealing the venue one chamber at a time.
- Interior rooms retain functional floor zoning and perimeter furniture, while the new exterior-to-lobby-to-restricted-area sequence gives each contract a believable architectural hierarchy and a clearer first breach decision.
- Regression coverage now validates exterior spawning, explicit outdoor room identity, partial-building camera coverage, connected entry routes and real-collider passage through every exterior and interior door.

## v1.2.5 blood performance, pressure response and combat Focus

- Dense blood keeps the same one-pixel density, spray counts, trails, pooling, ultraviolet residue and persistent cleanup evidence, but chunks now age and repaint only occupied or changed cells instead of scanning and rebuilding every 32x32 texture.
- Airborne blood keeps every visible droplet and collision deposit while resolving its straight damped trajectory with one wall query, replacing the former per-droplet, per-frame physics raycasts.
- The stock pressure washer now starts at 12 cleaning power, emits five focused or up to eight broad physical packets, reaches stable pressure sooner and builds a 35% sustained-target bonus.
- Far/wide washing retains useful force, impact radii start at 1.9 pixels and grow to 2.4 pixels at tier two, and real pressure impacts remove more density per arrived packet without becoming an endpoint eraser.
- Combat gains a finite Focus resource on right mouse/left trigger. Focus slows the world to 42% while preserving live aim; kills, head hits, close combat and combos replenish it, and its one-pixel HUD gauge appears only while relevant.
- Sound response now includes a short distance-, wall- and source-aware orientation delay on top of the existing radius attenuation, uncertain localization and push/sweep/guard assignments, so alerted enemies react credibly without instantly acquiring an exact route.
- Focus composes with lethal hit-stop instead of fighting the global time scale, then always resets for cleanup, mission completion and scene exit. Cleanup right mouse remains the ultraviolet lamp.

## v1.2.4 physical pixel pressure washing

- Mopping is physically anchored to the visible head in front of the character: the cursor aims the handle, while player movement and rotation determine the only floor path that can be cleaned. Upgrades widen that local head footprint and strengthen contact without creating remote reach.
- The pressure washer now emits visible 1x1 water packets from its nozzle. They fly across the room, stop at walls, break into small impact splashes and settle into the same sparse pixel-liquid surface used by damaged plumbing.
- Cleaning occurs only after water reaches the target: sustained spray progressively thins blood into a pale wet layer, produces short diluted-red runoff and removes the remaining ultraviolet trace.
- Close aim remains narrow and forceful while extended aim becomes a wider, weaker fan; these modes now alter actual packet spread, impact radius and cleaning force.
- The stock unit starts at 9 cleaning power and builds 25% extra pressure after 0.25 seconds of steady aim. Its compact HUD marks this as `WASH+`; releasing the trigger or sweeping away vents the bonus instead of rewarding blind spraying.
- Upgrades change the physical stream: level 1 raises packet speed and pump response, level 2 adds a 20% broad-nozzle footprint with softer edge falloff, and level 3 detergent strips diluted/UV residue 50% faster with less contaminated runoff. Solid gore remains mop work.
- The stream is a bounded batched draw list rather than dozens of physics nodes, keeping continuous spraying compatible with the existing low-pixel performance budget.

## v1.2.3 physical set dressing and cleaning flow

- Mop input is now a real gesture rather than a held-button eraser: direction continuity and a deliberate stroke-speed window determine efficiency, while successful sweeps build three compact FLOW tiers for slightly wider, stronger follow-through.
- The pressure washer changes shape with cursor distance. Close aim is a narrow high-pressure jet for stubborn residue; extended aim becomes a wider, weaker finishing fan, with the pixel spray and HUD communicating the current mode.
- Blood removal is layered per sparse 32x32 evidence region: dense blood lifts into a visibly diluted film, ordinary mopping leaves UV residue, and washing the last trace produces restrained local completion feedback.
- Cleanup remains forgiving: weak strokes always make progress, a saturated mop never creates new blood, and cleanup movement cannot generate bloody footprints.

- Scene dressing now has two readable physical outcomes: heavy fixtures chip and progressively collapse, while lighter props such as plants, televisions, speakers, crates, machines and tables receive material/weapon-weighted launch impulses.
- Movable props remain recognizable after impact, collide safely with walls and actors, can knock enemies down at meaningful speed, and settle without continuous off-screen simulation.
- Every displaced object becomes explicit forensic cleanup work. Its exact authored position appears as a cyan hard-pixel ghost only after combat, and `E` lets the player drag the object with the existing body-handling language.
- Guiding an object into its slot automatically snaps position and rotation, restores solidity, resolves cleanup risk and awards restoration credit; unfinished objects prevent a perfect scene certification.
- Original navigation cells open while props are displaced and close on restoration, preserving combat routes without allowing invisible blockers.

## v1.2.2 controlled corpse physics

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
- `WASD` or arrow keys — move; mouse — aim.
- Left mouse — fire using the shared blood reserve. No player magazine limit, reload animation or automatic reload; insufficient blood triggers a rate-limited dry fire.
- Hold right mouse — siphon enemy blood in an invisible 90°/224px forward sector plus a 48px proximity circle. Movement remains available; the reserve fills at a bounded global rate.
- `Space` — directional dodge roll with an invulnerability window. Actual blood underfoot gives a dynamic 35% roll-speed bonus, without extending invulnerability.
- `1` — cycle owned guns; `2` fists / `3` knife / `4` bat.
- `Q` — throw the equipped gun; `E` — pick up weapons or interact with the entrance loadout case.
- `R` — no combat reload; retry the floor-entry checkpoint after death.
- Focus, blood active skills and blood healing are disabled in the current blood-ammunition mode.
- Move into a closed door — push it open; fast contact can slam it.
- Hold `Shift` — extend the camera toward the cursor.
- `F3` enemy vision debug; `F4` screen FX; `F6` performance diagnostics.
- `Esc` — pause/resume; `Enter` from pause returns to the run launcher.

Enemy ammunition and legacy save/test interfaces remain conventional. They do not limit the player's blood-powered weapons. Historical release notes below/above may describe retired modes.

## Game loop

1. Start a randomized descent and confirm the first-floor entrance loadout.
2. Shoot to create enemy blood, roll through it for mobility, and hold right mouse to recover ammunition.
3. Live-enemy impact droplets gain 10% recoverable mass per active combo kill, capped at 2×. A lethal hit includes its own kill; the existing combo timeout resets the bonus. Geometry, crimson color and particle counts do not grow with this bonus. Saturated pixels can yield less than the nominal multiplier.
4. Walls and corpse overkill generate no new recoverable resource. Legacy enhanced rounds retain their finite lossy budget and receive no combo bonus.
5. Advance with remaining resources; death retries restore the floor-entry checkpoint without issuing free resources.

## Levels and AI

- Forty-eight validated combat-room modules, each with eight safe transforms, are distributed without repeats across the active floor; enemy and cover placement remain authored together rather than independently randomized
- Twelve venue shells supply distinct architecture and presentation while roguelike progression selects them nonlinearly and avoids immediate venue repetition
- Tactical Lab menu entry provides an expanded 64x36-tile, 17-enemy combat stress puzzle for door breaches, glass crossfire, blind corners, mobile patrol baiting and room-by-room response
- Every campaign case has a named TileWorld signature, palette, divider/accent geometry, furnishings, enemy composition and cleanup pressure configuration
- Enemy routes use an AStarGrid2D generated from solid wall cells
- Enemy vision uses distance/angle broad-phase checks followed by an opaque-only 2D raycast; `debug_draw_vision` exposes the tuning cone
- Weapon-specific circular hearing events propagate through walls at a 1.5x effective-distance penalty with distance- and occlusion-scaled uncertainty
- Centralized hearing assigns the two nearest guards to push, a third to sweep an offset lane and remaining listeners to hold position instead of abandoning the whole floor
- Melee hits and executions create their own alert radii, making committed close-range actions audible risks
- Unalerted enemies follow two-point patrol routes; alerted enemies switch to frequently refreshed diagonal A* paths around walls and solid furniture
- Patrol routes span 48–64px, use A* instead of blind straight-line motion, and pause 0.5–1.5 seconds at each waypoint
- Patrol endpoints are validated against navigation and room boundaries; deterministic local fallbacks keep every guard mobile while soft obstacle costs reduce furniture and corner rubbing
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
