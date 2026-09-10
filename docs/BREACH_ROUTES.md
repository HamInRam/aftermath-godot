# Destructible side routes

Each building attempts to install up to two seeded breach panels in internal walls. Candidates require clear approaches, an existing detour, distance from doors and other panels, and no exterior or window cells. The main route remains available.

Panels are 16 × 24 or 24 × 16 world pixels, providing a 24-pixel passage. Native-pixel erosion updates merged collision rectangles. Navigation and acoustic connectivity remain conservatively blocked until every panel pixel is removed; then a single navigation event is emitted. Partial holes do not yet remove the full lighting occluder.

Only active, living enemies within 240 pixels in chase, investigate or search states receive staggered path refreshes. Their existing target is preserved. This enables shorter routes without waking dormant rooms or granting knowledge of the player's location.

The `Events.tactical_shortcut_opened` bus includes the originating world and actual 8-pixel navigation cells. Main rejects events from other worlds. At the next normal staggered path calculation, pursuing melee/assault enemies receive a one-second 1.1× movement overlay only if the computed path crosses the new opening. This is not a new omniscient AI state: existing perception, combat, collision and doorway safety remain authoritative. Pending openings expire after two seconds; the same notification cannot continuously renew the boost.

Projectile and thrown-weapon damage share the erosion path. Wood fragments use the existing bounded MicroDebrisField, including its cosmetic siphon behavior; fragments provide no blood resource and are not unlimited persistent rigid bodies.

Regression coverage:
- `test_breach_routes`: twelve buildings, closed/open physical passage, shorter A* routes, partial damage, thrown impact idempotence and one navigation notification.
- `test_breach_awareness`: nearby active enemies refresh; distant and dormant enemies remain unchanged.
- Existing door, floor transition, room-layout and performance regressions provide integration coverage.
