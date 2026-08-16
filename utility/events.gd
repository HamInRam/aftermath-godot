extends Node

signal ammo_updated(current: int, maximum: int, is_reloading: bool)
signal reload_started(duration: float)
signal reload_finished(current: int, maximum: int)
signal weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool)

func publish_ammo(current: int, maximum: int, is_reloading: bool) -> void:
	ammo_updated.emit(current, maximum, is_reloading)
