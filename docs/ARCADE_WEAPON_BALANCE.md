# Arcade weapon balance

All values here are game tuning, not real firearm specifications.

`ArcadeWeaponBalance` is the authoritative gameplay override after platform
identity and before attachments. Stable weapon IDs preserve saves and artwork.
Calibre no longer decides player damage: gameplay roles do.

## Roles

Handgun: mobile precision. PDW: close rush. SMG: sustained control. Shotgun:
burst. Carbine: versatile assault. DMR: heavy deliberate shots. Sniper: line
penetration. LMG: long volleys with a reload commitment.

Mossberg 590A1: nine 30-damage pellets, 0.58-second cycle, falloff starts at
85 world pixels. This is theoretical 270 torso damage if all pellets hit before
death removes the collider; the weapon UI's damage field is per projectile.
Room-distance and far-distance tests use actual bullets and enemy HP.

Shotgun identities: Mossberg heavy pump; 870 fast pump; M4 controlled semi-auto;
1301 fast lower-damage fire; M3 tight pattern; KSG wide pattern/deep capacity.

## Guardrails

- Enemy weapon resources are deep copies with damage/penetration ceilings.
  Player power increases do not mutate cached data or enemy loot.
- Blood-enhanced shots still pay one budget per trigger and divide it among
  pellets. The higher damage does not multiply the recoverable blood budget.
- Physics impulses were not increased to achieve damage changes.
- Blood upload queues compact once per frame batch instead of shifting the
  pending array for every chunk. Pixel density and upload order are unchanged.
- Stress-test random seed is fixed for reproducibility; this is not a claim
  that all possible random blood arrangements fit that fixture's assertion.

Tests cover weapon profiles, attachment compatibility, real shotgun contact,
armour, room/far distance, blood economy, and unmodified player data after enemy
tuning. Whole-run difficulty still requires player feedback across seeds.
