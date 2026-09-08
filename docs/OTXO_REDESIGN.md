# The Descent — OTXO-informed presentation rebuild

Implemented September 7, 2026. This is original AFTERMATH artwork and tuning,
not extracted OTXO assets or a claim to reproduce its undisclosed source values.

## Reference decisions

The [official OTXO description](https://superraregames.com/pages/otxo) establishes
the useful pillars: fast room combat, Focus, hand-authored rooms recombined for
runs, and clear monochrome violence. In the
[developer interview](https://filmstories.co.uk/gaming/otxo-preview-living-out-the-john-wick-fantasy/),
Haddock specifically describes individual gun reloads and their sound as part
of each weapon's identity. Those principles informed the following shipped code.

## What changed

| Layer | Active implementation |
| --- | --- |
| World | Original grayscale atlas, continuous wood/stone/carpet/brick/metal; sparse seams instead of coarse tile borders and noisy highlights. White stone wall edges with black cores across twelve venues. Broken windows immediately update the wall painting. |
| Furnishings | Readable top-down upholstery, tabletops, drawers, consoles and sanitary fixtures. Existing destructibility, collisions and navigation remain. Debris uses neutral material colors. |
| Actors | Shared native-pixel templates for player, gunner, melee, assault, heavy and hound. Small crowns, shoulders, two articulated palms and movement-only feet; continuously aimed artwork, not north-facing chest patches. |
| Corpses | The live clothing role passes into the articulated body and severed parts. Missing modules have matching cut edges; grayscale anatomy stands apart from finite crimson liquid. Removed the obsolete detached rectangular corpse shadow. |
| Guns | Eight independently drawn class silhouettes cover the existing 64 platforms. Handheld, thrown and floor weapons share the source. Mechanical recoil and four-stage reload presentation are separate from ballistic muzzle transforms. |
| Handling | Direct mouse aiming; reduced motion/turn spread penalty; retained class dispersion. Automatic cadence carries bounded sub-frame remainder. Empty-magazine click reloads; Q explicitly throws; E pickup has 26px range and line-of-sight checks. |
| Impact | Shotgun shoulder impulse fires once per trigger pull. Directional camera kick is capped at 2.6 native pixels. Hit stop is capped at 28ms and does not extend for overlapping pellets, with a 75ms refractory interval. |
| Color feedback | Neutral ordinary flash/casings; crimson enhanced flash only when the blood ledger paid for that shot. Siphoning, enhanced damage and the lossy return cap are unchanged. |
| Interface | New original mansion ink-plate title, square monochrome controls, separated corner resources, one-pixel meters and a longer keylined aiming cross. Transient contextual messages replace an always-on throw prompt. Long labels elide within measured areas. |

## What is deliberately preserved

- Six-floor seeded descent, no repeated venue within a run, 48 authored formation
  modules with safe transformations, 16–20 hostiles per standard venue.
- 768×448 world geometry, unchanged actor/door scale, room-local engagement and
  no combat-interrupting three-choice reward popup.
- Blood absorption, Q/E/R blood skills, B healing, hostile-local X Focus, exact
  inventory/attachment/resource transfer, counted floor-checkpoint death retries.
- 320×180 native art composition with crisp integer enlargement to 1920×1080;
  UI text uses the existing high-resolution font path, not bilinear upscaling.

OTXO's full narrative, boss roster and large bartender-upgrade catalog are not
implemented by this rebuild. AFTERMATH's blood economy and retry rules are also
intentional differences, not represented as OTXO behavior.

## Shotgun follow-up: production collision, not a damage-number increase

The first shotgun is the Mossberg 590A1 in catalog/inventory insertion order;
the legacy `shotgun` ID resolves to the same platform. Its baseline remains
nine 18-damage pellets. The repair addresses three interacting defects:

1. At 11 native pixels centre-to-centre, a 19px muzzle was behind the target.
   A real trigger emitted nine pellets but landed zero. A single barrel query
   now selects an unobstructed projectile origin before the close target.
   Flash/recoil remain attached to the visible barrel, and solid-wall refusal
   still does not spend a shell.
2. Collision-surface classification labelled central back/side shots as limbs.
   Enemy classification now samples the forward trajectory closest to the body
   centre, retaining grazing limbs and off-centre head regions. Blood stays at
   the actual entry location. No enemy AI orders or player armour rules changed.
3. Spray density was applied again to spray shape, and generic stagger replaced
   the weapon-specific joint impulse. Both duplicate reductions were removed.
   Ragdoll root and joint caps are unchanged; this does not restore wall-crossing
   body launches.

Deterministic real-Gun/real-Bullet/real-Enemy trials exclude unaware instant kills.
At 20/45px, all three target facings receive 9 torso pellets (162 aggregate HP
against the high-HP measurement target); normal 75HP targets die in one shot.
At 70px normal targets still die in one shot. At 110px only five pellets land
and damage falls off, retaining the shotgun's close-range identity. Contact
checks cover 11/14/17px and eight world directions. These are controlled samples,
not a claim that every moving or partially covered target must take full damage.

The new enhanced-volley test exercises production Main dispatch, Bullet collision,
impact-to-death budget transfer and two-body penetration. One shot pays 3.5 blood;
the nine shares recover at most 72%, including terminal stains and settled mist.
Bosses, narrative and bartender upgrades remain deferred during this repair.

## Verification

New executable scenes: `test_noir_actor_art`, `test_manor_world_art`,
`test_weapon_presentation`, `test_noir_interface` (all included in CI).

The world fixture covers 12 venues and 576 seeded layouts with 48 base formation
IDs; actor fixtures cover 48 live directions and 30 corpse module cases. Weapon
fixtures check class/native pixels, reload resource integrity, aim, cadence,
pickup obstruction, flash, recoil and casing initialization. Interface fixtures
cover native artwork colors, menu bounds, long names, execution keycaps and
reticle redraw quantization.

`tests/render_run_review.tscn` uses the real renderer for menu, help, combat,
controlled bullet-impact/death presentation and floor-completion captures.
It is a visual fixture, not a substitute for prolonged human playtesting.
