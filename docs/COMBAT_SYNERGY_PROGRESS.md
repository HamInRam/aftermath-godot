# Combat synergy implementation and honest acceptance status

## Implemented

Six original behavior perks are offered outside combat, once per floor, without
pausing. Owned perks are removed from later offers and survive floor transfer.
The first choice also selects the established base blood style; its tank/cost/
damage tradeoff is displayed. A brief acquisition banner acknowledges selection.

| Perk | Trigger and result | Safety |
| --- | --- | --- |
| Harvest step | Actual blood absorption removes siphon movement penalty for 1s | No bonus when no blood was consumed |
| Reload breach | Completed reload primes +0.75 penetration for next paid blood trigger | One trigger, shared across pellets |
| Hot swap | Successful throw primes +25% blood-shot damage for 4s | Expires; consumed once |
| Last word | Final magazine blood shot gains 35% damage | Finite unchanged blood-return budget |
| Blood clock | Player ballistic kill trims Q/E/R cooldowns by .35s | Shared .6s kill-event lock; no negative cooldowns |
| Field cycle | Shotgun kill transfers one reserve round into magazine | No free ammo, no reload overlap, no stale weapon refill |

Weapon presentation now resolves platform-specific mechanical pitch/tilt and
separates semi-auto shotgun cycling from slower manual cycling. These are
original synthetic presentation changes, not new recorded audio assets.

## Coverage

Latest validation: 59/59 regression jobs passed. Feedback hierarchy and vertical
slice emitted shutdown warnings; these are not represented as a warning-free
run. The 1920x1080 render review completed without logged script errors, and the
optional offer screenshot was inspected for readability and clipping.

- 64 perk combinations, cached multi-pellet payment, ammo conservation,
  cooldown and timed-window bounds, save/restore covered by regression.
- All authored module transforms checked for anchor bounds and valid patrol
  vectors. Existing 12-venue tests check navigation, spawns, doors and patrols.
- Existing all-platform presentation test checks silhouettes and native pixels.

## Follow-up room and sound pass

- Nightclub entry floor and back bar increased from five to eight planning
  cells deep; the dance/bar halls yield three rows rather than expanding the
  entire map or changing actor scale.
- Casino VIP lane widened from six to nine cells; broadcast control gallery
  from eight to ten; last-call VIP lane from seven to ten. Adjacent large halls
  give up width, preserving building bounds and generated doorway connections.
- Seven non-shotgun class voices now have separate transient/body/tail synthesis;
  shotgun retains its blast voice. All effects have edge ramps and headroom.
- Player fire briefly ducks music up to 4dB, enemy fire up to 2dB. The bounded
  envelope recovers rather than accumulating with automatic weapons.
- Enemy gun layers attenuate with listener distance; player gun layers retain
  their reference gain. Material impacts now obey the SFX bus volume setting.
- Render fixture inspected at 1920x1080; this is not a manual combat playthrough.

Validation for this follow-up: full run 58/59, with a blood stress occupancy
failure. Its random workload depended on scene initialization; reseeding after
initialization isolates that workload without raising the occupancy threshold
or changing effects. The corrected test passed three consecutive isolated runs.
The full suite was not re-run after that test-only correction. Three full-run
tests emitted shutdown warnings. Renderer completed without logged errors.

These are implemented corrections, not a claim of completed human listening or
exhaustive subjective per-room balance review. The latter remains unverified.

## Not represented as complete

Automated geometry/navigation checks do NOT mean every room has been manually
played and balanced. Platform-specific parameters do NOT mean every firearm and
enemy sound has received a listening/mastering pass. Complete per-room playthrough
and subjective audiovisual tuning remain outstanding; these cannot be certified
by the regression count. This iteration does not claim all four requested areas
are finally complete or commercially mastered.
