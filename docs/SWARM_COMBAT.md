# Room-paced combat (current tuning)

The 56-enemy swarm experiment below is historical, not the active configuration.
Current population is authored count + 4, clamped to 18–24 per floor. Nearby-room
swarm recruitment is disabled by default. Existing local room activation remains.
Extra dressing is capped at two objects per tactical room (12 per floor maximum),
within 32px of an authored chamber perimeter, with the central floor kept clear
of *new* fill objects. Venue-specific prop pairs replace indiscriminate mixed
clutter. Existing authored walls/furniture and 48 modules are retained, not
claimed as exact OTXO room reproductions. Blood, erosion and walking exits remain.

OTXO's official publisher describes 150+ handcrafted rooms in a random layout;
it does not publish a fixed enemy count per map. Our 18–24 is a project-specific
balance target, not an asserted OTXO statistic.

## Historical swarm experiment

The 48 authored tactical modules are retained. `SwarmLayout` adds a deterministic
population/dressing pass only when main starts a roguelike floor.

- Target: 56 enemies, retaining original elite/ranged placements and adding
  Bleeders round-robin across chambers. Unsafe candidates are rejected rather
  than forcing a spawn. Every enemy exists before deployment; no wave spawning.
- Bleeder: 12 HP, no armor, speed 78 / chase 117 px/s, melee damage 16 with
  0.85-second cooldown. Pale clothing. Live-hit blood mass gets a 1.3 multiplier,
  still capped at the existing 2x combo ceiling. Dead bodies cannot be farmed.
- Up to 60 extra crates, tables, paper stacks and glass partitions. Existing
  pixel-erosion, bounded debris and material physics are reused. Glass collides
  on layer 4. Debris never pays blood. Extra props are not permanent walls.
- Navigation is 8px, NOT the 32px blood-storage chunk size. Reserve a five-cell
  wide path envelope from entrance to every spawn; preserve doorway clearance,
  existing obstacles, actor clearance and exterior deployment space.
- Seeded local RNG makes retry layouts repeatable without resetting global RNG.
- Player gunshots and door noise recruit melee enemies from the nearest two
  populated rooms within 320px. This is spatial proximity, not a new acoustic
  portal graph. Ranged enemies retain existing room isolation.
- Recruitment is staggered at 0.18s, with a 3s alarm cooldown. Additional recruits
  are capped by 18 minus already active melee and pending recruits. Entering a
  room still activates its full local encounter, so 18 is NOT a global AI cap.
- Recruits investigate the recorded sound position, not a continuously tracked
  player coordinate. Existing pathing and doors still apply; no teleportation or
  new ability for AI to chew through walls is added.

Regression coverage: all 12 venues reach 56 enemies and 60 props for the tested
seed, deterministic repeat, safe added spawns, preservation of original reachable
paths; predeployment/exterior/noise gates, queue cap, staggering, melee-only
recruitment, HUD count and reset. These checks do not certify every seed or
substitute for human balance testing / a sustained graphics frame-time benchmark.

The fixed stress workload now checks resident nodes (<2200), transient growth
(<750), and total (<2950) separately, instead of the former 1800-node total for
16–20 enemies. Initial measurement: resident 2001, peak 2676. Existing shell,
gore, tracked-object and particle limits were not increased. More living actors
do cost more CPU; this is budget accounting, not a claim of unchanged FPS.
