class_name EnemyNavigation
extends RefCounted

static func crowd_separation(actor: Node2D, radius: float = 13.0) -> Vector2:
	var separation := Vector2.ZERO
	for other in actor.get_tree().get_nodes_in_group("enemy"):
		if other == actor or not is_instance_valid(other) or not other is Node2D: continue
		var offset: Vector2 = actor.global_position - other.global_position
		var distance := offset.length()
		if distance < 0.01 or distance >= radius: continue
		separation += offset.normalized() * (1.0 - distance / radius)
	return separation.limit_length(1.0)

static func build_directional_search(tile_world: Node, origin: Vector2, likely_direction: Vector2, radius: float, distance_scale: float, strafe_sign: float) -> PackedVector2Array:
	var direction := likely_direction.normalized()
	if direction.length_squared() < 0.001: direction = Vector2.RIGHT
	var side := direction.rotated(PI * 0.5 * strafe_sign)
	var candidates := PackedVector2Array([origin, origin + direction * radius * distance_scale, origin + side * radius, origin - side * radius * 0.75])
	var points := PackedVector2Array()
	for candidate in candidates:
		if is_instance_valid(tile_world) and tile_world.has_method("is_navigation_position_walkable"):
			if not tile_world.is_navigation_position_walkable(candidate): continue
		points.append(candidate)
	return points
