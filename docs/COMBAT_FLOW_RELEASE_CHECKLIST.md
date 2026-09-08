# Combat flow iteration

This is an original implementation informed by the agreed OTXO-inspired design,
not a claim of identical source code or a guarantee of zero defects.

| Design area | Production implementation / acceptance |
| --- | --- |
| Combat siphon | 24 reserve/sec, 80% movement; full reserve leaves ground blood untouched. 0.5 sec provides at most 12 reserve, not a full refill. |
| Feedback hierarchy | Existing flesh/armour/head/lethal audio and bounded hit stop retained; lethal audio now coalesces within 65ms instead of restarting for every simultaneous kill. |
| Readable destruction | Existing weapon/distance/hit-zone ragdoll, missing-module and finite blood-round budget pipelines retained and regression tested; no force increase or infinite blood reward. |
| Weapon identities | Arcade roles and six shotgun variants retained; existing platform tests and real-projectile shotgun tests cover power/accuracy tradeoffs. |
| Enemy coordination | Existing firing permission pool now also gates melee windups; both release permission after the attack. Dormant rooms still do not participate. |
| Room rhythm | Seeded non-repeating module deck prefers different consecutive combat kinds; skirmishes use two hostiles, other modules four. Authored role-to-position relationship retained. |
| Run builds | After every third room, optional safe keyboard choice, once per floor. Hidden in active encounters, delayed one second after combat; no pause. Harvester/Heavy/Mobile have explicit costs, checkpointed across floors/retries. |
| Replay | Existing floor/checkpoint retry retained; death panel adds a debounced new-random-run option using saved loadout. Report shows floor best chain and selected style. |

## Validation

`test_combat_flow_upgrade` checks 40 deterministic decks, non-repetition,
encounter-type variety, safe offer visibility and single-use semantics, and
non-stacking build tradeoffs. Blood-loop tests check finite faster gain and no
full-tank waste. Existing run/session tests cover checkpoint restore. Renderer
review captures the offer and death choices within the real game viewport.

The safe offer is a non-modal intermission overlay, not a physical shop or bar.
The six combat kinds classify and arrange authored formations, not six new
procedural building generators. Best chain is currently a floor statistic.
Long-run balance and gamepad-accessible offer controls need further playtesting;
these tests do not establish commercial-release certification.

Final verification: 57/57 regression jobs passed (including import). The entry
loadout fixture retains an exit-time resource warning. Renderer review passed
at 1920x1080. The tactical lab deliberately retains four hostiles per chamber
for dense combat/physics validation instead of applying short skirmish counts.
