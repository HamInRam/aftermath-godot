# Combat-only subtraction pass

## Removed from live execution
- Dormant enemies return before animation/perception/navigation work; their gun
  presentation process is disabled. Activation selects Chase. Attacking,
  staggering and knockdown remain essential combat substates. Distant gunshots
  and corpse incidents no longer fan out through the old CombatDirector
  investigation listeners. Room/contact activation and firing fairness remain.
- Removed corpse/blood-clue scan functions and the corpse incident autoload.
- Removed furniture restoration/drag methods and anchor creation, the unused
  footprint emitter, and footprint/smear stamping entry points. Furniture still
  moves on combat impacts and sleeps normally after settling.
- Cosmetic fragment storage 512 -> 256, ray budget 64 -> 32, burst 8–32 -> 6–18.
  Corpse overkill follow-ups 3 -> 1. Siphonable blood mass is not reduced.

## Weapon roster
24 definitions, three per class; discarded authored scene references resolve to
their retained class representative rather than loading another platform.
Retained roles emphasize mobility, piercing, heavy impulses, cadence and cover
damage. Existing three shotguns provide pump burst, rapid semi-auto and wide
spread. No claim is made that fewer catalog entries directly reduce in-combat
GPU cost: only instantiated weapons are rendered.

## Persistence
New `user://aftermath_run_v8.json` stores a whitelist of run records, equipment
and active selection fields. Versions other than 8 are rejected. The old
`aftermath_progress.json` remains untouched as a recoverable legacy file; no
user directory purge or automatic migration occurs. New progression starts
fresh. Legacy in-memory fields and disconnected menu/cleanup resources still
exist where older UI interfaces reference them: this is NOT a complete removal
of every historical source file or schema accessor.

## Presentation
Inspection confirmed one shared screen shader already implements CRT, grain,
vignette and grading; chromatic displacement is already disabled for crisp
native pixels. No redundant replacement postprocess was added.

## Verification scope
Focused regressions cover new v8 persistence/rejection, dormant immobility,
roster count, prop erosion, weapon configuration, blood ledger, corpse combat,
floor progression, breach awareness, hit reaction and cosmetic storage caps.
Old restoration-only tests were retired; corpse-investigation and career tests
now test the replacement contract. Full historical CI still needs an audit of
tests whose expected behavior explicitly describes retired patrol/stealth or
career features. No blanket bug-free/FPS claim is warranted.
