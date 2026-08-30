# Changelog

## [v1.2.1] - Native Pixel Unification

- Unified live characters, corpses, ragdolls, weapons, projectiles, casings, blood, water, debris, props and landmarks around one native 1x1 world-pixel material language.
- Replaced runtime sprite dependencies with deterministic cell-painted silhouettes and 16x16 compatibility frames; all live rendering uses nearest filtering and integer placement without fractional actor or weapon scaling.
- Converted blood, gore, footprints, puddles, sparks, glass and environmental bursts to one-pixel sources with directional motion while preserving continuous forensic cleanup strokes.
- Quantized doors, furniture, cameras, corpses, dropped limbs, recoil and casing presentation into readable authored angle frames while retaining continuous simulation accumulators.
- Pixel-locked the post-processing sample grid, chromatic separation, scanlines, lighting textures, reticle, ultraviolet feedback, context markers and UI animation.
- Reconfigured the project font and shared controls for bitmap-safe rendering, square panels, procedural pixel sliders, toggles and briefing portraits.
- Added regression compatibility for the unified procedural actor frames and fixed snapped door animation stalling at low opening speeds.
- Restored visible death ragdolls by accumulating corpse angular momentum between pixel-angle frames, enforcing readable root travel and amplifying weapon-specific relative limb articulation before a longer constrained settle phase.

## v0.1.1 - Universal Physical Death Pass

- Added one room-scale sparse pixel-liquid surface shared by water, oil, chemical spills and cleaner solution; every liquid now renders as nearest-filtered hard pixels instead of expanding vector circles.
- Broken sinks and toilets now burst directionally and continue feeding irregular water pixels until repaired, while finite containers and setpieces leave viscosity-specific pools that remain for cleanup.
- Water dilutes and transports blood into pale broken runoff, actors carry wet/oily pixels away on their feet, and mop/washer gestures erase local density through the same continuous stroke used by blood.
- Electrical hazards now damage through connected conductive pixels rather than a larger radial shortcut; oil exposes a reusable flammability query for later ignition systems.
- Added pixel-liquid regression coverage for sparse chunks, blood mixing, connected conductivity, dry-gap isolation, oil, continuous cleanup, footprints and source repair.
- Replaced runtime ground and wall stain nodes with sparse 32x32 nearest-filtered pixel blood canvases storing per-pixel blood density, dilution, age and ultraviolet residue.
- Weapon profiles now paint hard-pixel puncture chains, fan/radial sprays, wall deposits, drag smears, footprints and progressively spreading directional death pools into the same forensic data layer.
- Cleanup now uses a continuous capsule brush between consecutive cursor samples, locally removing blood instead of fading whole stains; remaining pixels dilute into a temporary wet trail and ordinary mopping leaves faint UV residue for the washer.
- Pixel pools settle before cleanup so wiped paths never refill, ground splatter and pool growth respect solid geometry, and dirty mops still only lose efficiency rather than creating new blood.
- Added sparse-chunk, cross-boundary stroke, wetness, UV residue, pool growth and stress-budget regression coverage.
- Added a shared weapon/distance/hit-zone impact resolver for every death ragdoll.
- Added separate hard-pixel human and quadruped rigs for the player, human enemies, and hounds.
- Added controlled arcade exaggeration: shotguns throw body mass, SMGs agitate limbs, bats add spin, and close hits carry more force than distant hits.
- Added a full player death corpse pipeline and preserved cleanup-safe enemy/hound corpses.
- Fixed non-player corpse ragdolls being created without their skeleton setup.
- Upgraded every player, human enemy, and hound to an always-present constrained physics skeleton.
- Locomotion, melee, reload, and attack animation now pull physical joints toward authored targets instead of replacing the body with static frames.
- Added localized living hit reactions, fully released knockdowns, physical recovery, and seamless living-pose transfer into death ragdolls.
- Reprojected living actors into a Suit-for-Hire-inspired orthographic 2.5D presentation: feet stay on the collision plane while shoulders, hands, and heads rise screen-up.
- Added bright wall caps over darker two-pixel wall faces so character height and environment height share one coherent pseudo-3D rule.
- Replaced continuously rotated living ragdoll drawings with stable eight-direction pixel skins over the same physical skeleton, including direction hysteresis, screen-space head height and aim-independent locomotion.
- Added direction-specific head, shoulder, hand and weapon occlusion, four-frame foot alternation, restrained idle breathing, role silhouettes for player/gunner/melee/assault/heavy enemies, and a dedicated compact hound composition.
- Added a readable fall transition before the skeleton fully releases into knockdown physics; living impacts remain clamped secondary motion and death still inherits the complete physical pose.
- Added a rendered eight-way character contact-sheet regression covering player, gunner, melee, heavy and hound silhouettes with real held weapons; corrected rear-facing hand spacing so north-facing grips no longer disappear inside the head.
- Removed false circular chest joints in NW/N/NE poses by moving the player identity color to one shoulder, connecting shoulder masses to the torso and replacing cross-shaped living hand/foot discs with compact square pixel blocks.
- Rebuilt NW/N/NE as dedicated rear-facing silhouettes: the head is hair-dominant with small ear and nape cues, diagonal poses occlude the far hand, straight north uses separated shoulder masses, and no bright sleeve or shoulder stroke crosses the torso.
- Replaced the remaining straight-north shoulder bar and equal-width back slab with two separated shoulder masses plus a compact stepped upper-back/waist silhouette; rear-facing player identity now comes from clothing rather than an overlaid cyan rectangle.

All notable project changes are recorded here. Version branches remain unreleased until explicitly approved and merged into `main`.

## [v1.2.0] - In development

### Ballistic aiming and physical death response

- Unified cursor intent, weapon-turn lag, muzzle origin and projectile direction into one ballistic solution; the compact reticle now shows actual barrel offset, distance-scaled dispersion, obstruction, target confirmation, reload progress and the final three rounds.
- Added a short contextual muzzle laser with blocked/clear/target colors and a restrained shotgun cone preview, plus configurable laser and reticle-detail toggles.
- Added controller right-stick aiming with line-of-sight-aware magnetic assistance and selectable OFF/LOW/MED/HIGH strength.
- Added short input buffers for firing, reloading and weapon throws so animation/cooldown boundaries no longer swallow deliberate actions.
- Replaced uniform random gun spread with center-weighted dispersion and stratified shotgun pellets, preserving readable misses while guaranteeing a useful central pellet.
- Added a perfect-mag precision chain: consecutive enemy hits arm a 0.28-second empty-mag reload and a score reward; misses reset the chain.
- Added a modular top-down Verlet ragdoll for fresh firearm deaths, including constrained limbs, wall collision, localized follow-up impacts and weapon-specific missing anatomy.
- Restricted corpse overkill to a brief three-hit post-death window; cleanup disables corpse projectile collision and freezes every ragdoll into a stable bagging/dragging pose.
- Removed antialiased runtime lines, fractional-radius circles and sub-pixel joint rendering from ragdolls; physics remains continuous while presentation is quantized into hard integer-pixel limb, head and wound clusters.

### Future-proof settings navigation

- Replaced the unbounded single-column settings form with AUDIO, ACCESS and AIM / INPUT categories, each hosted in an independent scroll viewport.
- Kept the title, category navigation, live status and action footer outside scrollable content so additional options can never push navigation below the 320x180 safe area.
- Added mouse-wheel category scrolling, controller/keyboard page switching and regression coverage that injects 24 synthetic future options while verifying the footer remains visible.

### Compact HUD and interface readability

- Fixed the action report's long unwrapped statistics, forensic and career strings widening its VBox and pushing the entire result screen off-center; report sections now use bounded multi-line layouts, compact controls and explicit horizontal safe-area regression tests.
- Replaced ad-hoc coordinates with four disjoint HUD safe zones: tactical counters at upper-left, transient state at upper-center, resources at lower-right and contextual actions at lower-center; regression coverage prevents their rectangles from overlapping again.
- Unified the visual language around tiny near-opaque pixel cards with a one-pixel semantic color rail, maintaining legibility over bright rooms without reintroducing large translucent grey overlays.
- Converted mop contamination from the stock themed ProgressBar to the same exact 26x1 custom renderer as ammunition and total cleanup progress.
- Applied the true-pixel micro-HUD language across combat and cleanup: ammunition now uses a 26x1 custom gauge, objective counters use 5px typography, combo is numeric-only, and the contextual action strip occupies only 102x12 native pixels.
- Mission/status and detail prose now appears transiently on state changes and automatically clears, leaving only tiny enemy/camera/alarm counters and ammunition visible during ordinary combat navigation.
- Rebuilt cleanup presentation around progressive disclosure: only scene cleanliness, active tool condition and urgent police response remain persistent; forensic category counts appear only during an active scan.
- Removed permanent room/global/risk/exit/workflow/shoe-contamination text walls from cleanup play, replaced them with color-coded cleanliness, a gradual mop-contamination icon/meter, contextual one-verb prompts and a conditional exit cue.
- Room verification, extraction readiness and sub-30-second response pressure now use distinct banners, icons, color and pulse feedback instead of competing status sentences.
- Reduced the cleanup progress gauge to a 26x1 native-pixel peripheral strip in the upper-left (about 8% of the 320px canvas), preserving the lower center exclusively for brief contextual actions after integer viewport scaling.
- Replaced the permanent full-width control sentence with short, input-sensitive combat and cleanup onboarding strips that disappear once the player acts.
- Rebuilt the mission HUD as three restrained corner information islands: compact objective/status chips, an icon-led contextual action card, and an ammunition/tool block with a visual state meter.
- Added world-anchored interaction prompts above the player so executions, pickups, body handling and cleanup actions are read where they happen rather than only at the screen edge.
- Expanded the shared 8x8 icon language for enemies, police, Heat, timers, mop, washer, evidence bags, ultraviolet inspection, sinks, exits, shoes, doors and weapons.
- Long runtime status sentences are reduced to short action phrases while detailed explanations remain available in briefing, intelligence and action-report pages.
- Reduced title and card-heading scale across case files, briefing, loadout, contracts, reports and settings, preserving large typography for grades and essential numbers only.
- Added pulse, low-ammo color, combo scale and banner entrance feedback so state changes are communicated through motion instead of repeated prose.
- Removed the full text label attached to the player silhouette; nearby executions, weapons, bodies and evidence now receive a small bobbing world icon and optional progress ring instead.
- Replaced combat objective prose with dedicated enemy, camera and alarm counters, and reduced cleanup's permanent display to cleanliness, unresolved risk and police response time.
- Added a reusable visual keycap separate from the context verb, allowing concise actions today and future keyboard/controller glyph swapping without rewriting gameplay prompts.
- Added consistent screen-entry motion, comparison bars for loadouts, three-node upgrade/specialization tracks and staged action-report disclosure.
- Removed the three permanent translucent HUD rectangles after enlarged output made them read as grey scene occlusion; outlined text and icons now float cleanly over play, with only a faint temporary strip behind an active context action.

### Fair lethal enemy gunplay

- Enemy gunners now commit to a predicted player position when their firing tell begins, then receive only archetype-specific limited tracking instead of snapping to the player's exact position on the firing frame.
- Added enemy-only accuracy multipliers and range-based spread: close exposure remains lethal, medium lanes stay threatening, and long shots suppress more often than they produce unavoidable pixel-perfect kills.
- Alerted enemies retain a minimum visual-confirmation window; reaction memory no longer collapses ordinary gunners below a readable response threshold.
- The Combat Director now grants spaced firing tokens to at most two simultaneous shooters, preventing same-frame firing squads while other enemies continue covering, flanking and repositioning.
- Gunner, Assault and Heavy profiles now have distinct tracking, prediction, spread and wind-up identities; Heavy fire is slower and suppressive while Assault remains aggressive at close range.
- Enemy wind-up graphics now fill toward the committed shot and show a tiny short-range muzzle-direction tell without introducing a full laser overlay.

### Added

- Added a centralized gameplay-design rules layer for cleanup certification, active workflow guidance and loadout aftermath burden, replacing duplicated threshold and consequence calculations.
- The 90% certification threshold now produces a single explicit `EXIT AVAILABLE` milestone while preserving optional 95% area-clean and 100% perfect-clean pursuits.
- Equipment selection now forecasts LOW/MED/HIGH aftermath burden before deployment, so heavy firearms communicate their later biological and ballistic cleanup cost as a strategic tradeoff.
- Mop and pressure washer roles no longer collapse into one another: washing handles broad liquid contamination, while solid gore requires a deliberate mop pass.
- Player death feedback now identifies both the lethal weapon and incoming direction.
- The first three campaign profiles expose authored signature rules, combat hooks and cleanup hooks through one data model; briefing screens teach the current case's distinctive rule before deployment.

- The first three release-critical cases now author target mission duration and combat/cleanup pacing; briefings expose the target and reports show the actual phase split.

- A dedicated effects-accessibility page independently controls hit stop, camera tilt, chromatic separation, blood density and dismemberment without weakening the core visual identity.

- Mission-authored contract whitelists now prevent contradictory objectives; the terms screen marks the contract that best matches the current case.
- Action reports track the dominant firearm and its projected cleanup burden, making high-volume and high-gore weapon choices visible after the mission.
- Combat AI now shares short-lived casualty hotspots: repeated deaths in one doorway become a suspected fatal funnel, suppressing direct push assignments in favor of one lateral sweep and room-preserving containment roles.
- Fatal-funnel memory is now keyed to authored door identity when possible; flank responders stop at distinct safe approach points on their existing side instead of resolving to the corpse center or accidentally reusing the lethal doorway.
- Detailed mission information now lives on a dedicated scrollable Intel screen with a fixed action footer; the briefing only retains deploy-critical information.
- Added authored mission intelligence covering location type, resistance, access routes, hazards, cleanup complications, and recommended approach.
- Briefings now forecast the combined mission, selected field kit, contract terms, and response pressure before deployment.
- Cleanup HUD now teaches a practical five-step workflow: bag bodies, recover evidence, contain spills, clean biological traces, then UV verify.
- Action reports now identify the dominant avoidable cost and give a concrete recommendation for the next attempt.
- Added regression coverage for operational forecasts and contextual post-mission coaching.

- Combat HUD consequence calls now disclose ballistic traces, forced-entry/property damage and body/biological load at the moment the player creates them, making violent convenience visibly translate into cleanup cost.
- Cleanup status simultaneously exposes current-room percentage, whole-scene percentage, remaining risk, extraction distance and whether the 90% stop-loss threshold has been reached.
- Enemy state language now distinguishes ordinary sound investigation from corpse discovery with a dedicated compact blue body glyph, while existing search, return, attack and guard symbols remain consistent.
- Combat now uses a compact pixel reticle that expands and shifts from cyan to amber with live weapon heat, movement and turn instability, making pistol precision and automatic-fire bloom readable before the shot.
- Active forensic scans now identify the nearest highest-risk trace by type and distance instead of presenting every tiny stain as equally urgent.
- Verified rooms receive a dedicated `AREA CLEAN` banner and rising two-note confirmation cue.
- Contract terms and field weapon configuration now live on dedicated full-screen pages between case selection, briefing and deployment; loadout cards show every issued weapon plus magazine and reserve ammunition.
- Career mastery now tracks five market-readable challenges per case: no alarms, restrained shooting, immaculate cleanup, total body/ballistic recovery and zero property damage.
- The runtime icon vocabulary now includes weapon-class ammunition, reload, combo, blood, casing, execution, alert, suspicion and floor-marker glyphs; melee-held visuals use the same ink/cyan/magenta/wood palette as firearms.
- Gunmen, knife rushers and heavy LMG enemies now use separate original overhead silhouettes and baked identity palettes instead of one shared sprite with destructive runtime tinting; the knife and heavy armor remain legible at native 320x180 scale.
- Camera motion is now a single three-layer stack: independently damped X/Y mouse look-ahead (25% normal, 55% Shift peek), sub-one-degree position tilt plus 0.4-degree low-frequency drift, and trauma-squared impact shake layered over existing one-to-three-frame hit stop.
- The production scale is now explicit and regression-friendly: the project renders a 16px reference grid at half-native scale (8px tiles, 16px doors, 24–32px corridors), while 32px actor canvases contain compact 16–20px body cores.
- A shared limited neon-noir palette now governs characters, weapons, blood, tissue, bone, UI portrait art and screen grading, preventing mixed pixel styles across systems.
- Corpses, body bags and every firearm/slash/blunt/execution wound variant now retain the same readable 26-pixel footprint as living actors instead of collapsing into tiny floor marks.
- Pistol, AK/SMG, LMG and shotgun art now shares a one-pixel ink silhouette, bright metal read, cyan muzzle marker and distinct wood/magazine geometry.
- Briefings now include an original 64x64 low-color handler portrait, establishing a separate higher-detail scale for narrative art without increasing gameplay sprite density.
- Player, human enemies and hounds use original 32x32 animation canvases with compact 16–20 pixel body cores, one-pixel dark outlines and high-contrast heads/shoulders; remaining canvas space is reserved for weapons and attacks.
- Human actors separate authored legs, upper body and weapon layers: legs track movement while the torso aims, weapons remain readable beyond the hands, and the fixed five-pixel collision radius preserves all existing CQB routes.
- Authored gameplay sprites retain a strict limited-color, connected-pixel silhouette while animation remains transform-driven; experimental procedural anatomy stays disabled to preserve the project's simple visual language.
- Player motion now includes hard-stop lean, aim-weight lag, reload tuck, weapon handling, drag/cleanup poses and weapon-specific three-stage ground executions without adding high-density frames.
- Enemy performance communicates state through acquisition lean, attack compression, cover peeking, archetype-specific weight and animated fall/recovery applied to the original compact sprite silhouette.
- A reusable native 8x8 pixel-icon language now covers cases, locks, deployment, navigation, settings, objectives, ammunition, interaction, cleaning, bodies, evidence, hazards, currency, upgrades, audio and reports without introducing high-density UI art.
- HUD icons automatically follow live text state, switching between target, ammunition, cleaning, body, evidence, completion and danger semantics as combat and cleanup objectives change.
- Every major menu now uses semantic button icons plus a cyan keyboard/controller focus rail and magenta pointer-hover state, making available actions discoverable without sacrificing the 320x180 layout.
- A production violence language now gives pistol, SMG, LMG, shotgun, fist, knife, bat and execution impacts distinct entry wounds, exit geometry, mist density, gore load, pool bias and corpse damage instead of merely scaling one generic effect.
- Blood mist droplets perform continuous wall raycasts, settle onto contacted surfaces and merge nearby floor evidence to preserve dense-looking scenes without unbounded node growth.
- Death pools grow asymmetrically from the actual wound, follow shot direction and floor-material spread, collect in floor grooves and retain a corpse-shaped negative space beneath the body.
- High-energy and bladed deaths support modular missing limbs with physical detached pieces, collision blood transfer, short death twitches and exposed low-pixel tissue/bone silhouettes.
- Dragged corpses now leave continuous directional smears, while shell casings landing in fresh blood become visibly stained and produce a dampened clink.
- Blood-forensics regressions now lock weapon trauma identities, shared DamageContext profiles, modular corpse damage and drag-smear generation.
- A unified destruction pipeline now routes projectile, shotgun, melee, thrown-weapon, door and corpse impact energy through wood, glass, metal, plastic, fabric, ceramic and liquid material profiles.
- Destructible props use readable structural stages: localized damage and altered collision, structural failure, then directional collapse into delayed physical major chunks and short-lived pixel fragments.
- Settled chunks become cleanup evidence, while plumbing, powered equipment, glass and containers create persistent water, electrical, glass, oil, spill or smoke hazards; active leaks must be repaired before their residue can be removed.
- Physical chunks can strike enemies and other props, corpses create secondary blood/noise and transfer lethal momentum into scenery, smoke interrupts enemy sight lines, and connected water expands electrical danger.
- Every campaign landmark now has a signature chain reaction: club/DJ power loss, diner spill, training smoke, crane oil, motel-sign arcs, penthouse glass, freezer fog, casino spill, archive dust, conveyor oil, broadcast electrical failure and finale blackout.
- Material-specific procedural impact transients, energy-scaled micro hit-stop, layered camera response and delayed debris emission create distinct wood, glass, metal, fabric and ceramic impact weight.
- Destruction-pipeline regression coverage verifies material identity, structural staging, physical debris, stopped leak sources, cleanup registration and all twelve setpiece events.
- A campaign-wide high-readability neon-crime art pass gives all twelve cases unique bright ambient grades, two-color lighting accents, cream wall caps and fixed right-down pixel shadows while retaining the original low-density 8x8 construction.
- Visual-readability regression coverage verifies twelve distinct palette signatures, minimum ambient luminance, visible accent-light counts, nearest-neighbor rendering and restrained post-processing.
- All twelve campaign maps now use independently authored functional-room topologies; Nightclub, Sandwich Shop and After Hours were rebuilt alongside the nine late-campaign cases instead of preserving their legacy layouts.
- A native low-density 8x8 overlay set adds sparse cracks, papers, glass fragments, grime, direction markers, hazard stripes, cables and drains without increasing the game's pixel density.
- A unified destructible environment supports intact, damaged, debris and restored states for furniture, appliances, equipment and signature landmarks.
- Bullets, melee attacks, thrown weapons and dangerous swinging doors damage scenery; destroyed objects open navigation cells, generate forensic property damage and become optional cleanup interactions.
- Per-case door, light, surveillance, supply, disposal, clue, furniture and noise-lure layouts now follow each floor's actual room graph.
- Every redesigned case has a unique floor-material composition, functional furniture plan and signature pixel landmark: cargo crane, motel sign, skyline wall, freezer fans, roulette table, evidence board, processing conveyor, broadcast console or destroyed DJ booth.
- Campaign-map and destruction regressions validate unique wall signatures, room connectivity, valid doors, required cameras, rinse points, destructible density, navigation changes and restoration.

### Changed

- Level shutdown now clears combat-director incidents, runtime-budget registrations, shared blood-clue snapshots and navigation crowd caches for safer repeated retries and scene transitions.

- Career upgrades now cross explicit perk thresholds—wide finishing passes, expanded evidence batches, risk triage, rapid body sealing and residue stripping—rather than remaining purely percentage-based.
- Restoration accounting, dominant-cost analysis and grade calculation now live in a dedicated mission-result builder, reducing scoring responsibilities inside the level controller.
- Combat completion now enters a short, input-safe scene-stabilization beat before cleanup, with explicit checks for loose weapons, bodies and active hazards instead of an abrupt mode switch.
- Cleanup tool compatibility and the five-stage professional workflow now live in a dedicated controller rather than being duplicated inside the level monolith.

- A saturated mop now retains 60% of its cleaning efficiency rather than falling to 40%, preserving rinse-route optimization without turning the sink into mandatory busywork.
- Runtime ultraviolet materials, procedural audio and generated 8x8 HUD icon textures are explicitly released when a level exits; repeated retries no longer retain the icon texture cache.
- Chain-reaction debris defers collision-shape attachment until PhysicsServer2D finishes the active contact query, eliminating runtime flushing-query errors during cascading destruction.
- Cleanup scoring now credits partial stain removal immediately and preserves each room's original evidence baseline, so percentages never jump backward when cleaned nodes disappear.
- Tactical rooms verify at a forgiving 95% cleanliness threshold, while mission extraction remains available at 90%; this removes last-pixel busywork without erasing the value of a perfect cleanup.
- Context collection now secures up to twelve nearby casings, dropped weapons and debris pieces in one local batch with an explicit item count prompt.
- Rebuilt every campaign floor around CQB legibility: a dominant movement spine, two or three breach choices, controlled long-firearm lanes, protected door thresholds, useful flank loops and broad cleanup return routes replace the previous maze-like divider density.
- Re-authored enemy staging around room roles rather than even spacing. Door pressure, lateral patrols, overwatch, reserve response and close-range ambushes now occupy distinct positions, while ammunition sits in readable but exposed recovery pockets.
- Tactical room identities now follow the rebuilt walls exactly, preserving room-based hearing, investigation, telemetry and cleanup verification across all twelve cases.
- Rebalanced campaign encounters around a seven-to-eleven enemy budget with at least three authored roles per case; later missions now create pressure through gunner, assault, heavy, melee and dog relationships instead of twelve-to-fifteen bodies competing for the same rooms.
- Player presentation adds reload tuck, corpse-drag lean, cleanup stroke and permanent high-readability outline poses, while moving enemies gain subtle stride and actively engaging threats receive an immediate red outline.
- Environmental dressing saturation and noninteractive decoration contrast were reduced so actors, projectiles, blood, hazards and current interactions retain the strongest visual values.
- Body bagging is now one deliberate action, and the evidence bag magnetically resolves up to four nearby shells, weapons or debris pieces per interaction, removing repeated presses that did not create a tactical choice.
- A room-verification flash provides one clear completion beat per cleanup zone, while opt-in local playtest telemetry records death rooms, weapon usage, combat/cleanup duration and abandoned evidence for future balancing.
- Re-authored furniture density across all twelve cases around realistic functional anchors: paired lounge seating, perimeter work surfaces, sanitary fixtures and one signature landmark now explain each room while preserving clear central combat space.
- Reduced decorative floor striping to sparse navigation markers and capped authored physical furniture at fourteen pieces per case, with six as the minimum needed for environmental identity and destruction gameplay.
- Preserved two-cell door openings plus collision-free approach cells, broad room centres and connected cleanup return paths so visual storytelling no longer competes with player movement.
- Rebalanced violent feedback into readable layers: compact entry cue, directional exit fan, persistent evidence and corpse state, all sharing one attack profile and runtime budget.
- Corrected authored door hinges to the edge of each two-cell opening, kept settled one-way door leaves non-blocking, cleared furniture from both approaches and moved the Sandwich Shop T-junction door off its collision corner so every campaign doorway remains traversable after opening.
- Existing cleanup tools absorb destruction work without tool bloat: the evidence bag rapidly sorts fragments and glass, the mop/washer handles spills, contextual repair stops active sources, and the scan HUD reports debris and liquid hazards separately.
- Rebalanced the global environment from light-dependent darkness to a clearly visible stage grade; local neon lights now identify zones and focal points instead of acting as the only source of visibility.
- Repainted the native atlas with brighter material mids, cream-white architectural highlights and bolder but sparse cyan, magenta, rust and teal color blocks. CRT curvature, scanlines, vignette, chromatic aberration, glow, contrast and saturation were reduced to preserve hard pixel edges and readable text.
- Ammunition and extraction points now project safely to nearby walkable floor after a topology change, matching the existing player, enemy, patrol and cleanup-object placement safeguards.
- Floor material zones now communicate room purpose and cleanup behavior directly: absorbent carpet and wood, washable tile, industrial concrete and high-contrast stage surfaces vary by case.

## [v1.1.0] - In development

### Added

- A shared `DamageContext` carries weapon, hit point, direction, distance, energy, hit zone and lethality into blood, corpse and combat feedback systems.
- Stronger two-stage firearm wounds: compact entry puffs, high-energy exit cones, lethal secondary floor spray, expanded mist and weapon-scaled gore chunks.
- Dynamic wall-blood runs, fresh-to-coagulated color aging and corpse clothing absorption around the actual wound location.
- Movement and rapid-turn accuracy penalties, sustained-fire spread, weapon-specific aim recovery and solid-wall muzzle obstruction.
- Procedural stride/bob and weapon sway layered safely above the existing melee wind-up/strike/recovery and firearm kick animations.
- Twelve named TileWorld variants with distinct palette scripts, accent flooring, room signatures, furnishing clusters and route-safe spawn projection.
- Deterministic replay conditions: Blackout, Armed Response, Scarce Ammo and Forensic Nightmare alter visibility, enemy composition, supplies, blood load and police timing.
- Per-case permanent mastery for zero alarms, eight-shot restraint and 100% cleanup.
- Date-seeded Daily Challenge records and a continuous Gauntlet mode with escalating payout streaks.
- Persistent route analytics split between combat and cleanup distance.
- Five career-driven endings: Clean Break, Ghost, Professional, Kingpin and Exposed, derived from cumulative shots, alarms, theft, Heat and scene quality.

### Changed

- Replay mode selection now cycles Standard, Score Attack, New Game+, Daily Challenge and Gauntlet after campaign completion.
- New Game+ and seeded conditions vary patrol endpoints while projecting them back onto reachable floor.
- Career saves migrate to schema version 5 with mastery, attempts, modifiers, route challenge records, gauntlet streak and aggregate behavior statistics.

## [v1.0.0] - Integrated into v1.1.0

### Added

- Three persistent finale outcomes—Clean Break, Professional and Exposed—derived from final cleanup quality, Heat, timeout state and stolen valuables.
- Post-campaign replay modes cycled with `M`: Score Attack grants a 1.5x score economy, while New Game+ sharpens enemy reactions/chase speed, tightens police windows and grants a 1.25x score multiplier.
- Version-4 career saves retain discovered endings and the selected replay mode with automatic migration from every earlier career schema.
- Finale-specific action-report narrative and an explicit Ending Secured state after Last Call.

### Changed

- New Game+ modifies live AI and cleanup timing rather than merely labeling the run as a harder mode.
- Case Files show the active run mode alongside Heat and campaign completion.

## [v0.3.0] - Integrated into v1.0.0

### Added

- A complete twelve-case campaign arc from Nightclub to Last Call, with nine new authored briefings, escalating combat rosters, cleanup deadlines, rewards and forensic epilogues.
- A paged 320x180 Case Files interface showing four campaign cases at a time, with `A/D` navigation and persistent Tactical Lab access on `L`.
- Late-campaign security objectives, fixed sentry formations, heavy/assault/hound mixes and increasingly tight cleanup response windows.
- A three-act narrative trail through the harbor, motel, penthouse, cold depot, casino, police archive, packing plant and broadcast tower before the finale.

## [v0.2.0] - Integrated into v0.3.0

### Added

- A five-contract pre-mission layer with Ghost, Controlled Force, Immaculate and Rapid Response conditions, explicit payout multipliers and debrief outcomes.
- A dedicated Safehouse opened with `H`, persistent Heat, one specialization point per first case completion and three rank-three career identities: Executioner, Ghost and Cleaner.
- Real specialization effects: combat mobility, quieter player firearms and stronger biological cleaning instead of cosmetic stat labels.
- Mission-authored police cleanup pressure, accelerated by career Heat, with a live ETA and compromised forced extraction on timeout.
- Interactive red environmental noise lures that can redirect unalerted guards through the existing occluded hearing and tactical-role network.
- Contract success, timeout and multiplier fields in persistent forensic reports and career payout calculation.

### Changed

- Career saves now migrate to schema version 3 with contracts, Heat and specialization state.
- The case menu exposes Safehouse, Workshop, cleaner mode and Heat without hiding progression behind silent hotkeys.

## [v0.1.2] - Integrated into v0.2.0

### Added

- A dedicated five-route workshop opened with `U`, with player-selected purchases, exact effects, level comparison, balance, max-state and insufficient-funds feedback.
- Version-2 career saves with automatic migration from legacy v1 progress instead of destructive reset.
- Tiered cleanup outcomes: 90% earns a certified exit while 100% remains the perfect-clean requirement for the highest result.
- Persistent post-mission forensic reports that summarize remaining bodies, ballistics, biological traces, alarms, damage and theft consequences.
- Authored alternate corpse routes in every mission: low-capacity dumpsters and louder incinerators supplement the distant extraction zone.
- Per-level authored clue, valuable and furniture positions replace player-relative random cleanup objectives, enabling deliberate environmental storytelling and routes.
- Career payouts, persistent credits and a five-track three-level upgrade ladder for mop power/capacity, scanner reach, body handling and pressure washing.
- Normal and Professional cleaner modes, toggled from the case menu, with room/category guidance hidden in Professional play.
- Per-scene story clues, a secure-or-steal valuable choice, three quick-reset furniture props and expanded cleanup scoring.
- A slot-2 pressure washer for broad fast biological cleanup without mop saturation.
- Split residue detection into a default hold-right-mouse ultraviolet cone and a separate cooldown-based `Tab` circular scan skill.
- Drag-driven mopping: hold left mouse and move the cursor to scrub, with stroke-speed efficiency, diluted wet trails and gradual drying.
- A unified `E` context action that automatically rinses, bags or drags bodies, secures loose evidence, and handles optional scene interactions.
- Room-level cleanup verification and named local cleanliness feedback.
- Right-click during cleanup to trigger a PowerWash-style ultraviolet dirt-finder pulse that briefly reveals nearby visible blood evidence before recharging.
- Mop-head contamination now shifts visibly from cyan to dark red as saturation rises.
- Bounded area mopping for nearby blood/gore, local area-cleanliness feedback and progress-weighted live evidence risk.
- A stable combat-completion confirmation window that revalidates objectives before cleanup begins.
- Dynamic blood mist droplets that settle into bounded, permanent and cleanable micro-stains at their visible endpoints.
- Head, torso and limb hit classification that drives wound-relative corpse pools and future authored body-state selection.
- Four seconds of postmortem wound seepage plus repeated drag-route contamination from the corpse wound position.
- Floor-aware blood behavior: compact easy-clean tile droplets, longer wood smears and darker high-risk carpet absorption.
- Blood-trail perception that lets idle guards investigate visible fresh stains and bloody footprints without omniscient tracking.
- A seven-pellet Shotgun with radial close-range gore, strong knockback, loud floor-wide reporting and recoverable Assault drops.
- A dedicated pixel shotgun sprite, original procedural blast/pump audio and authored shotgun reserve pickups in every mission.
- An expanded 64x36-tile Tactical Lab with east/south sectors, 17 mixed-archetype enemies and high-density combat validation.
- Readable alert-transition pulses, local cleanup progress, required-tool feedback and live shoe-contamination percentage.
- Surface-aware footprints and shell impacts, including carpet absorption, hard-floor sharpness and turning smears.
- Buffered melee/execution inputs, a real pause overlay and directional death feedback with instant restart messaging.
- A finite mop-soil loop with live saturation, authored sinks and in-world rinsing across every campaign layout.
- Mission-authored zero-alarm and limited-shot bonuses, property-damage penalties and expanded action-report statistics.
- An accessibility toggle for high-contrast enemy outlines.

### Changed

- Reduced cleanup loadout selection to `1` Mop and `2` Pressure Washer; evidence bags and body bags are now automatic context equipment.
- Detailed evidence/category counts appear during the active `Tab` scan, while the default HUD focuses on local room cleanliness.
- Clues, valuables and furniture restoration are explicitly optional scoring opportunities and never block scene completion.
- Increased base mop capacity from 12 to 18 soil units and reduced soil gain per stroke.
- A fully dirty mop now continues at reduced efficiency instead of hard-locking cleanup; sinks restore its full speed and clean color.

### Fixed

- Corrected the 32x32 animation-canvas/world-grid mismatch: actors now render at 55%, corpses at 45% and held firearms at 68%, restoring a roughly one-to-one-and-a-half-tile body footprint instead of oversized overlapping block silhouettes; chromatic separation is reduced to preserve the one-pixel outline.
- Split the career status into a compact centered two-line block so it no longer stretches, offsets or clips the level-select menu.
- Validate zero-efficiency cleanup tools before stroke scaling or cleaner boosts, preventing the body-bag slot from receiving a forced minimum blood-cleaning step.
- Replace pixel-perfect local stain targeting with a forgiving smart-stroke brush: wider selection, larger mop radius and nearest-dirty-section fallback guarantee progress on every valid moving stroke.
- Disable bloody-footprint generation throughout cleanup so cleaning cannot create an endless evidence loop.
- Replace shrinking whole-stain removal with progressive color dilution and fading while preserving the original splatter footprint until fully clean.
- Remove individual splatter lobes and pool sections only where the mop stroke passes, giving large stains true local spatial cleaning.
- Decouple the ultraviolet scan visual from cleaning redraws: right-click now immediately flashes a fixed circular detection zone instead of revealing a delayed, growing ring after left-clicking.
- Harden footprint-source filtering and reduce near-invisible micro-drop contact radius, preventing hidden droplets beside old tracks from appearing to make footprints self-replicate.
- Refresh mop rendering whenever contamination changes and interpolate its visible wet-blood tint continuously; sink rinsing now visibly restores the clean cyan color.
- Limit ultraviolet evidence highlighting to the local scan radius and block it behind solid walls instead of revealing the entire map.
- A saturated mop now loses efficiency without stopping cleanup or creating additional blood/evidence.
- Clip blood-pool lobes against solid geometry to reduce visible seepage through walls.
- Refresh corpse and blood-pool contact at the combat-to-cleanup boundary so crossing an already-nearby unbagged corpse reliably produces bloody footprints during cleanup.
- Use swept corpse/blood contact, renewable shoe contamination and a 512-footprint mission budget so fast traversal and long cleanup sessions do not silently stop producing tracks.
- Clamp airborne blood droplets against walls and project invalid endpoints onto reachable floor, preventing inaccessible cleanup evidence.
- Continue postmortem seepage after dropping an unbagged corpse.
- Transfer duplicate-weapon magazine overflow into reserve ammunition instead of deleting rounds.
- Apply shotgun camera trauma once per trigger pull rather than once per pellet, and preserve the longest overlapping hit-stop window.
- Cluster nearby floor blood into one AI clue region, exclude wall stains and reject unreachable investigation targets.
- Prioritize extraction over corpse dragging inside the extraction zone.
- Count only explicit cleaning, collection or body extraction as resolved evidence; unexpected node deletion no longer inflates cleanup scores.
- Clear the final thrown firearm's live gun state and reject gun selection while the inventory is empty.
- Project primary floor splatter onto reachable tiles so wall-adjacent kills cannot create impossible cleanup evidence.
- Version regional blood evidence so guards can notice a later incident without repeatedly scanning hundreds of permanent footprints.
- Split the expanded Tactical Lab into nine tactical sectors and dress its new rooms with props and dedicated lighting.
- Lock player movement, attacks and dragging after death or mission completion.
- Separate fresh contamination sources from permanent footprints and share a spatial blood-clue cache across guards to bound long-session scan cost.
- Stagger enemy vision raycasts and share crowd snapshots so large encounters avoid synchronized per-frame scans.
- Limit slammed-door knockdown to the initial high-speed sweep, apply tangential knockback and bleed speed after a body impact.
- Merge overlapping micro-blood deposits, vary footprint cadence/stance, and distinguish connected melee hits from empty swings.
- Reject mismatched cleanup tools instead of allowing them to make hidden progress, and expose evidence-specific completion feedback.
- Apply diminishing camera-trauma accumulation so automatic fire remains forceful without pinning shake at its maximum.
- Make cleanup, pickup, dragging, sink and extraction interactions mutually exclusive and priority-driven.
- Spatially bucket cleanup evidence so nearby interaction queries no longer traverse an entire long-session crime scene.

### Tests

- Added blood-forensics coverage for surface cleanup, clue registration, hit zones and Shotgun blood/ammo data.
- Added regressions for fast corpse traversal, contamination renewal, duplicate-ammo overflow, corpse seepage after dragging, hit-stop overlap, unreachable blood projection, shotgun trauma, explicit cleanup scoring and expanded Tactical Lab scale/navigation.
- Added regressions for final-weapon disposal, regional clue generations, footprint source filtering, ground-splatter reachability, expanded-room identity/lighting and post-result input locking.
- Added regressions for door danger windows, harmless gentle pushes, micro-blood merging, surface foot smears and mismatched cleanup tools.
- Added regressions for mop saturation/rinsing, optional mission constraints, property penalties and high-contrast settings persistence.

## [v.0.1.0] - 2026-08-18

### Fixed

- Render 2D canvas items directly at the integer-scaled output resolution and use the bundled grid-designed Silkscreen font at larger menu sizes, retaining the pixel aesthetic without damaging ordinary system-font glyphs.

### Added

- Scored, navigation-validated cover/peek pairs for ranged enemies plus lateral alternate-route waypoints when no usable cover exists.
- Explicit friendly-fire lane classification so an allied body prevents attack commitment instead of relying on an incidental miss.
- Authored tactical room identities and responder limits that retain defenders in rooms containing multiple guards.
- Empty-gunner evaluation of reachable dropped firearms, preserving weapon identity and remaining magazine ammunition.
- Finite per-weapon reserve ammunition, reserve-aware reload transfer and three weapon-specific ammunition pickups in every mission.

### Changed

- Gunners no longer create ammunition through unlimited reloads; after exhausting a magazine they must claim a viable dropped gun.
- The combat HUD displays magazine capacity and the currently equipped weapon's reserve.

### Tests

- Added encounter-intelligence coverage for open firing lanes, friendly obstruction, alternate routing, room-aware assignments, enemy weapon decisions, finite reloads and ammunition pickups.

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
### Weapon-specific corpse dismemberment

- Added distinct corpse anatomy for pistol punctures, SMG cluster wounds, LMG limb/torso tearing, and several shotgun blast outcomes.
- High-energy deaths can now show destroyed heads, severed limbs, torn cavities, missing upper bodies, or bisected torsos instead of an intact body beneath unrelated gore.
- Corpse cleanup, dragging, bleeding, bagging, evidence registration, and footprint contamination remain unified and compatible.
### Corpse trauma readability

- Raised corpses above persistent pools, drops, footprints, and loose gore without reducing blood volume.
- Added bright severed-edge rims, dark wound cavities, exposed tissue, and bone highlights so each dismemberment state remains readable on blood-covered floors.
### Dismemberment visibility correction

- Increased corpse art from sub-pixel trauma marks to a readable compact scale.
- Added physically separated limb and skull fragments with clear gaps, outlines, tissue, and bone pixels.
- Added death-style fallback inference so high-energy kills cannot accidentally render an intact pistol corpse when a legacy caller omits the weapon id.
### Modular orthographic character redesign

- Added a reversible replacement set of strict 32x32 crisp-pixel player, gunner, melee, and heavy figures.
- Separated head, neck, torso, pelvis, upper arms, forearms, thighs, and boots with readable one-pixel joints and hard ink outlines.
- Preserved fast faction recognition through constrained cyan, white, magenta, red, and yellow clothing accents.
- Aligned living anatomy with the modular corpse/dismemberment language while retaining the pure overhead camera.
### Compact overhead silhouette restored

- Restored the tightly overlapping living-character silhouettes after the separated-joint experiment read as an insect-like assembly from above.
- Retained modular anatomy where it improves communication: wounded corpses, severed modules, exposed tissue, and weapon-specific dismemberment.
- Preserved the experimental modular SVG set outside runtime for future corpse-piece and animation reference.
### Per-weapon corpse variation

- Added four universal fall poses with different arm spreads, leg placement, curled posture, and crossed-limb silhouettes.
- Added multiple wound variants per firearm even when repeated shots hit the same zone.
- Pistol now varies puncture location and pose; SMG varies cluster height and tearing; LMG varies torso splitting and severed modules; shotgun combines pose variation with its existing blast outcomes.
### Readable corpse silhouette cycling

- Replaced random micro-variation with per-weapon four-step silhouette cycling, preventing consecutive duplicate bodies.
- Rebuilt pose differences around the whole anatomy: straight fall, curled side fall, spread-eagle fall, and twisted torso fall.
- Moved the head, torso polygon, arms, and legs by large readable distances rather than changing only wound pixels.
### Authored corpse sprite replacement

- Replaced the abstract runtime rectangle-and-circle corpse base with dedicated 32x32 human corpse pixel sprites.
- Added straight, curled, spread, twisted, head-destroyed, limb-severed, bisected, and upper-body-destroyed assets.
- Runtime drawing now handles only changing blood saturation and body-bag feedback; recognizable human anatomy lives in authored textures.
### Inner Animal-inspired unified art direction

- Enlarged living actors to a readable 23px world silhouette and authored corpses to roughly 30px while preserving gameplay collision sizes.
- Shifted the global palette from saturated synthwave primaries toward ink black, aged cloth, muted metal, controlled cyan/magenta accents, and deeper forensic reds.
- Reduced chromatic splitting, CRT distortion, scanline strength, and excess saturation so authored pixel forms remain legible.
- Rebalanced global and local lighting toward grounded pools of red, green, amber, and violet rather than full-scene neon wash.
- Unified UI text, focus, and interaction colors with the grounded crime-noir palette.

### Enemy ragdoll readability

- Added an enemy-only articulation and root-motion presentation boost so deaths remain readable while combat continues.
- Extended enemy ragdoll settling without changing the player's existing game-over presentation.
- Delayed cleanup-phase pose freezing briefly so the final enemy's death animation is no longer cut off by the phase transition.
- Made enemy blood particles optional so a missing or hot-reloaded VFX node can no longer abort the death signal before the corpse ragdoll is created.
