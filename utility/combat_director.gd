extends Node

## Converts raw combat events into tactical assignments. Events remains a pure bus.

func _ready() -> void:
	Events.combat_noise.connect(_on_combat_noise)
	Events.tactical_alert.connect(_on_tactical_alert)

func _on_combat_noise(world_position: Vector2, radius: float, source_kind: String) -> void:
	var candidates: Array[Dictionary] = []
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy_node) or not enemy_node.has_method("evaluate_noise_response"): continue
		var response: Dictionary = enemy_node.evaluate_noise_response(world_position, radius)
		if bool(response.get("eligible", false)):
			candidates.append({"enemy": enemy_node, "response": response})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.response.priority) < float(b.response.priority)
	)
	var rooms := PackedStringArray()
	for candidate in candidates: rooms.append(_candidate_room(candidate.enemy))
	var roles := build_room_role_plan(rooms, PackedStringArray(["push", "push", "sweep"]), "guard")
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		candidate.enemy.receive_combat_noise_result(world_position, radius, source_kind, roles[index], candidate.response)

func _on_tactical_alert(world_position: Vector2, likely_direction: Vector2, source_kind: String, reporter: Node) -> void:
	var candidates: Array[Dictionary] = []
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if enemy_node == reporter or not is_instance_valid(enemy_node) or not enemy_node.has_method("evaluate_tactical_assignment"): continue
		var response: Dictionary = enemy_node.evaluate_tactical_assignment(world_position)
		if bool(response.get("eligible", false)):
			candidates.append({"enemy": enemy_node, "priority": float(response.get("priority", INF))})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.priority) < float(b.priority)
	)
	var rooms := PackedStringArray()
	for candidate in candidates: rooms.append(_candidate_room(candidate.enemy))
	var roles := build_room_role_plan(rooms, PackedStringArray(["sweep_left", "sweep_right", "guard"]), "observe")
	for index in range(candidates.size()):
		candidates[index].enemy.receive_tactical_assignment(world_position, likely_direction, source_kind, roles[index])

func build_room_role_plan(room_ids: PackedStringArray, active_roles: PackedStringArray, passive_role: String) -> PackedStringArray:
	var totals := {}
	for room_id in room_ids: totals[room_id] = int(totals.get(room_id, 0)) + 1
	var active_by_room := {}
	var active_index := 0
	var roles := PackedStringArray()
	for room_id in room_ids:
		var room_limit := maxi(1, int(totals.get(room_id, 1)) - 1)
		var can_leave_room := int(active_by_room.get(room_id, 0)) < room_limit
		if active_index < active_roles.size() and can_leave_room:
			roles.append(active_roles[active_index])
			active_index += 1
			active_by_room[room_id] = int(active_by_room.get(room_id, 0)) + 1
		else:
			roles.append(passive_role)
	return roles

func _candidate_room(enemy: Node) -> String:
	return str(enemy.get_tactical_room_id()) if enemy.has_method("get_tactical_room_id") else "open_floor"
