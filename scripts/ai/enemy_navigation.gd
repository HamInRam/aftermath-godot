class_name EnemyNavigation
extends RefCounted

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
