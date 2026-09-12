# Local injury and improvised combat

- Existing overhead view, native-pixel rendering, magazines and blood rage remain unchanged.
- Enemy head/torso/arm damage accumulates in bounded anatomical records. Edge notches are authored in local pixel space before rotation; the detached record travels with the corpse pose.
- Movable scenery retains a maximum 40 px launch distance and 125 px/s speed, then settles. Contact with actors causes no damage, injury, stagger or knockdown. Cosmetic fragments never cause damage; prop-to-prop recursive damage is disabled. Explicitly picked-up improvised weapons retain their melee/throw damage.
- Floors place up to 12 loose items beside furniture on navigable, unoccupied points. These are non-processing while resting: bottles, chairs and clubs have 1/2/3 effective-hit durability and 32/48/38 damage respectively.
- E prioritizes nearby guns, then loose objects, with line-of-sight checks. LMB swings the object, Q throws it. Taking an object retains the gun and magazine. Breaking, throwing or switching away restores the gun. No new input action or inventory panel is added.
- Swept throws start at the player's physical position; they break on first impact. Unused throws settle as pickups. Ground items can be broken by gunfire.
- Existing ammo card shows item uses and Q THROW while held. Near-item E hints reuse the existing context marker.

Regression: `tests/test_improvised_combat.tscn`; actual-floor renderer: `tests/render_improvised_review.tscn` (capture `/tmp/aftermath-improvised-review.png`).
