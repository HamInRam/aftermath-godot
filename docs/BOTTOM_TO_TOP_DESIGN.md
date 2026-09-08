# New-game combat stack

Original implementation inspired by OTXO's published game-feel principles.
This is not an assertion about OTXO source code or physical simulation.

The current new game remains the seeded blood-combat descent. Do not restore
cleanup, linear mission selection or mid-combat reward popups. Full OTXO story,
boss replication and a hundred-drink bar are outside this design integration.

| Layer | Active code / acceptance |
| --- | --- |
| Reliable input and contact | player.gd, aim_controller.gd, bullet.gd; ballistic_contact and projectile_collision regressions. |
| Independent locomotion and aim | lifecycle_physics_rig_2d.gd, weapon_presentation_profile.gd; eight-way and weapon-presentation regressions. Recoil must not rotate ballistic aim. |
| Focus | main.gd actor-local slow motion, persistent grade/HUD; aiming_ragdoll regression. Player controls remain responsive. |
| Distinct firearm rhythm | arcade_weapon_balance.gd; platform, shotgun_combat and arcade_weapon_balance regressions. |
| Reload and weapon exchange | gun.gd four-phase class/feed animation and mechanical audio; weapon_presentation, inventory and throw regressions. |
| Enemy pressure | enemy_combat_controller.gd, room_run_controller.gd; encounter_intelligence and enemy_search regressions. Only active rooms fight; attack tokens include melee. |
| Nonlethal vs lethal confirmation | hit_feedback_profile.gd, combat_feedback.gd; new feedback_hierarchy test protects lethal audio from ordinary hit interruption. |
| Death momentum | ragdoll_impact_resolver.gd, pixel_ragdoll_2d.gd; corpse_wall_safety and noir_impact_physics tests. Bounded forces, matching severed anatomy. |
| Responsive environments | destructible_prop.gd, physical_debris.gd; destruction_pipeline and destructible_environment tests. Cosmetic debris does not replace gameplay collision. |
| Readable noir art | pixel_actor_art.gd, pixel_environment_atlas.gd, neon_palette.gd; actor/world/readability tests. Armour hits are gray/white; flesh confirmation is crimson. |
| Audio/camera hierarchy | combat_feedback.gd and trauma_camera.gd; same-frame impacts use the strongest peak, not additive debris count. Enemy trigger pulls do not shake player camera. |
| Room pacing | handcrafted_room_catalog.gd and tile_world.gd; seeded nonrepeating authored formations and short/full encounters. Tactical lab keeps dense validation encounters. |
| Replay and growth | safe_build_offer.gd and roguelike_run_session.gd; optional safe-period styles, floor transfer/checkpoints and best-chain reporting. Flow/session regressions cover these. |

## This iteration

- Prevent a weak pellet confirmation from cutting off a lethal sound for 100 ms.
- Reset audio arbitration when leaving/restarting combat.
- Coalesce same rendered-frame camera trauma by peak strength; preserve later
  trigger accumulation and the existing displacement cap.
- Remove enemy firing-only camera trauma without removing world-space gunfire,
  casings, muzzle flashes or player damage feedback.
- Eliminate blue/yellow hit-profile colors at their source.

These changes preserve damage, blood amount, geometry, player movement speed,
weapon cadence and existing cosmetic populations. They improve causal clarity,
not merely effect volume. Commercial release readiness still requires extended
playtesting, balance/accessibility coverage and hardware profiling.

## Verification

2026-09-07: 58/58 regression jobs passed, including import. Real OpenGL renderer
review completed at 1920x1080 without logged errors. Three fixtures reported
exit-time resource warnings (weapon throw, feedback hierarchy, entry loadout);
these remain recorded rather than being represented as a zero-warning release.
