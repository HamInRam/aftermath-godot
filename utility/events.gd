extends Node

signal ammo_updated(current: int, maximum: int, is_reloading: bool)
signal reload_started(duration: float)
signal reload_finished(current: int, maximum: int)
signal weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String)
signal combat_noise(world_position: Vector2, radius: float, source_kind: String)
signal combat_ended
signal door_impact(world_position: Vector2, intensity: float)
signal glass_shattered(world_position: Vector2)

func publish_ammo(current: int, maximum: int, is_reloading: bool) -> void:
	ammo_updated.emit(current, maximum, is_reloading)

func publish_combat_noise(world_position: Vector2, radius: float, source_kind: String) -> void:
	var candidates: Array[Dictionary] = []
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy_node) or not enemy_node.has_method("get_noise_response_priority"): continue
		var priority: float = enemy_node.get_noise_response_priority(world_position, radius)
		if is_finite(priority): candidates.append({"enemy": enemy_node, "priority": priority})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.priority) < float(b.priority))
	for index in range(candidates.size()):
		var role := "push" if index < 2 else ("sweep" if index == 2 else "guard")
		var enemy_node: Node = candidates[index].enemy
		enemy_node.receive_combat_noise(world_position, radius, source_kind, role)
	combat_noise.emit(world_position, radius, source_kind)
