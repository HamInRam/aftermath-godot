extends Node

signal ammo_updated(current: int, maximum: int, is_reloading: bool)
signal reload_started(duration: float)
signal reload_finished(current: int, maximum: int)
signal weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String)
signal combat_noise(world_position: Vector2, radius: float, source_kind: String)
signal tactical_alert(world_position: Vector2, likely_direction: Vector2, source_kind: String, reporter: Node)
signal combat_ended
signal door_impact(world_position: Vector2, intensity: float)
signal glass_shattered(world_position: Vector2)

func publish_ammo(current: int, maximum: int, is_reloading: bool) -> void:
	ammo_updated.emit(current, maximum, is_reloading)

func publish_combat_noise(world_position: Vector2, radius: float, source_kind: String) -> void:
	combat_noise.emit(world_position, radius, source_kind)

func publish_tactical_alert(world_position: Vector2, likely_direction: Vector2, source_kind: String, reporter: Node) -> void:
	tactical_alert.emit(world_position, likely_direction, source_kind, reporter)
