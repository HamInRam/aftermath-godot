class_name ShotRecord
extends RefCounted
## Trigger-level accounting; all pellets share this record, including pool rejection.
var expected: int
var resolved := 0
var hit := false
var lethal := false
var reported := false
var weapon_id: String

func _init(pellets: int = 1, weapon: String = "") -> void:
	expected = maxi(1, pellets)
	weapon_id = weapon

func accept(event: ShotResolvedEvent) -> void:
	resolved += 1
	if event.outcome == ShotResolvedEvent.Outcome.ENEMY:
		hit = true
		lethal = lethal or event.lethal

func is_complete() -> bool:
	return resolved >= expected
