extends Node

## Converts raw combat events into tactical assignments. Events remains a pure bus.

func _ready() -> void:
	Events.combat_noise.connect(_on_combat_noise)

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
	for index in range(candidates.size()):
		var role := "push" if index < 2 else ("sweep" if index == 2 else "guard")
		var candidate: Dictionary = candidates[index]
		candidate.enemy.receive_combat_noise_result(world_position, radius, source_kind, role, candidate.response)
