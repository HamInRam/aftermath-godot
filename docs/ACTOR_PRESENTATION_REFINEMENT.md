# Actor presentation refinement

Original OTXO-inspired overhead pixel artwork, not extracted OTXO sprites or
an assertion about that game's internal animation implementation.

## Runtime changes

- Shared live/preview artwork uses a 32×32 transparent authoring canvas. This
  does not double body scale or change collisions; pixels remain native cells.
- Broader tailored shoulders, inset crown, asymmetric elbows and support grip.
- Handgun, rifle and long heavy-weapon grips; existing melee poses retained.
- Player and enemy reloads now drive support-hand movement. Gun visual recoil,
  tilt and ammunition motion feed the hands without rotating bullet carriers.
- Head and palms draw above gun stocks; barrels extend beyond the body.
- Independent moving feet, standing foot occlusion, bounded living hit response,
  knockdown/recovery and death ragdoll pipeline retained.
- Hound ears, muzzle and moving tail clarify its quadruped silhouette.
- Neutral shoe and door-frame pixels; furniture underside edge gives depth
  without adding noisy floor texture or changing navigation footprints.

## Validation and limits

The actor-art regression exercises six roles in eight directions, corpse
module continuity, three gun grips, melee grip and support-hand reload return.
Renderer fixture exercises an actual shotgun hit and death, not just a mockup.

The full suite on this iteration passed 54/55 jobs: randomized dense blood
occupancy exceeded its existing 20,000-cell assertion once. Its isolated rerun
passed without lowering effects or relaxing the assertion. This remains an
intermittent test/budget issue, not a demonstrated permanent fix.

This iteration refines shared production art and animation. It is not a
frame-for-frame reproduction of every OTXO animation, nor a complete replacement
of every environment asset. Boss, story and bar systems remain deferred.
