class_name WeaponFiredEvent
extends RefCounted
## Per-trigger presentation event; projectile emission remains a separate signal.
var origin: Vector2
var direction: Vector2
var enemy_owned: bool
var weapon_id: String

static func create(position: Vector2, heading: Vector2, hostile: bool, weapon: String) -> WeaponFiredEvent:
	var event := WeaponFiredEvent.new()
	event.origin = position
	event.direction = heading
	event.enemy_owned = hostile
	event.weapon_id = weapon
	return event
