class_name ShotResolvedEvent
extends RefCounted
## One terminal projectile outcome. Strings exist only at legacy signal boundaries.
enum Outcome { ENEMY, OVERKILL, WORLD, EXPIRED, BUDGET, OTHER }
var shot_id: int
var outcome: Outcome
var lethal: bool
var weapon_id: String

static func create(id: int, kind: String, killed: bool, weapon: String) -> ShotResolvedEvent:
	var event := ShotResolvedEvent.new()
	event.shot_id = id
	event.outcome = {"enemy": Outcome.ENEMY, "overkill": Outcome.OVERKILL, "world": Outcome.WORLD, "expired": Outcome.EXPIRED, "budget": Outcome.BUDGET}.get(kind, Outcome.OTHER)
	event.lethal = killed
	event.weapon_id = weapon
	return event
