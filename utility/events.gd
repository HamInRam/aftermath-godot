extends Node

signal ammo_updated(current: int, maximum: int, is_reloading: bool)
signal ammo_reserve_updated(reserve: int)
signal reload_started(duration: float)
signal reload_finished(current: int, maximum: int)
signal weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String)
signal precision_chain_updated(streak: int, primed: bool)
signal precision_reward(weapon_id: String, streak: int)
signal combat_noise(world_position: Vector2, radius: float, source_kind: String)
signal tactical_alert(world_position: Vector2, likely_direction: Vector2, source_kind: String, reporter: Node)
signal casualty_reported(world_position: Vector2, likely_attack_direction: Vector2)
signal combat_ended
signal door_impact(world_position: Vector2, intensity: float)
signal glass_shattered(world_position: Vector2)
signal prop_destroyed(world_position: Vector2, prop_kind: String)
signal prop_restored(world_position: Vector2, prop_kind: String)
signal prop_impacted(world_position: Vector2, material: String, energy: float, structural_stage: int)
signal hazard_spawned(world_position: Vector2, hazard_kind: String)
signal setpiece_triggered(world_position: Vector2, setpiece_kind: String, hazard_kind: String)

func publish_ammo(current: int, maximum: int, is_reloading: bool) -> void:
	ammo_updated.emit(current, maximum, is_reloading)

func publish_ammo_reserve(reserve: int) -> void:
	ammo_reserve_updated.emit(reserve)

func publish_combat_noise(world_position: Vector2, radius: float, source_kind: String) -> void:
	combat_noise.emit(world_position, radius, source_kind)

func publish_tactical_alert(world_position: Vector2, likely_direction: Vector2, source_kind: String, reporter: Node) -> void:
	tactical_alert.emit(world_position, likely_direction, source_kind, reporter)

func publish_casualty(world_position: Vector2, likely_attack_direction: Vector2) -> void:
	casualty_reported.emit(world_position, likely_attack_direction)
