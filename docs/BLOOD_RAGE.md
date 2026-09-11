# Magazine combat and Blood Rage

The current production mode uses conventional magazine/reload gunplay; it no
longer binds the legacy blood-payment callable to the player's gun.

* A new run starts with 0/100 blood; health is independent.
* RMB siphons the existing 224px, 90-degree sector plus 48px proximity area,
  at up to 60 blood/second. Movement and shooting remain available.
* At 100 blood, rage starts automatically and cancels any unfinished reload.
* Rage grants 1.25x movement, 1.65x projectile damage, +0.85 penetration,
  crimson bullets/muzzle flashes, flowing crimson skin on torso and feet,
  and orbiting native pixels. The skin uses quantized local-cell rivulets and
  is removed immediately when rage ends; it creates no absorbable blood.
* Every successful trigger retains its rate of fire, spread, recoil and collision.
  It spends neither magazine ammo nor reserve ammo during rage. Enemy guns do
  not inherit this behavior. R does nothing while unlimited fire is active.
* Stronger ground spray uses a 2.0 yield multiplier with a finite shared trigger
  budget divided across pellets. Existing batching and particle limits remain.
* Rage projectiles enable the breach route: twice their normal erosion damage
  against destructible terrain/props, with bounded debris impulses. Surviving
  wall collision and navigation updates still follow the existing damage pipeline.
* Rage drains 14 blood/second. A 56px automatic full-circle vacuum recovers at
  most 10/second from actual removable ground/wall blood, respecting occlusion.
  RMB cannot bypass this limit. Duration is about 7.1s without recovery and at
  most about 25s with ideal continuous recovery (minor fixed-tick differences).
* At zero, rage ends and ordinary gunplay resumes using the stored ammunition.
  Floor checkpoints retain both meter charge and the separate rage state.
* The top-left ammo card returns; the bottom-right blood card stays separate.
  The ammo card says INF / RAGE during rage, and returns to real ammo afterward.

Regression scene: `tests/test_blood_rage.tscn` exercises production wiring,
every currently enabled weapon, reload interruption, finite auto-recovery,
red projectiles, floor-state restoration and normal fire after rage.
Legacy blood-ammo tests remain isolated compatibility coverage, not the active
player controls contract.
