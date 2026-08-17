# AFTERMATH Roadmap

## v0.0.3 — Squad Tactics, Architecture and Cleanup

- Keep `Events` signal-only and route tactical hearing through `CombatDirector`.
- Track transitive corpse incidents and every cleanup target through centralized registries.
- Drive gun behavior, presentation and blood response from one data source.
- Split perception, search construction and HUD presentation out of core gameplay scripts.
- Run white-box and black-box regression coverage automatically in GitHub Actions.

## Next — Encounter Authoring

- Author role limits and room-specific guard responses using the new coordinator boundary.
- Add cleanup scoring by target type, time and evidence left behind.
- Supply copyright-safe combat music and room ambience to the implemented audio transition players.
- Add weapon pickups only after encounter and cleanup scoring are stable.

### Remaining encounter work

The following encounter-authoring features remain in the v0.0.3 scope:

- Shared squad knowledge with explicit pursuit, guard and flank assignments.
- Cover scoring, corner peeking and alternate-route selection for ranged guards.
- Stuck detection and local crowd separation around narrow doors.
- Weapon pickup decisions for unarmed enemies and dropped-weapon support.
- Automated behavioral regressions for perception, search, friendly-fire safety and dynamic navigation.

These build on the directional multi-point search, uncertain sound perception and explicit attack tells introduced during the v0.0.2 combat-feel work.
