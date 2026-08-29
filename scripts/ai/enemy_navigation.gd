class_name EnemyNavigation
extends RefCounted

static var crowd_cache_bucket := -1
static var crowd_cache: Array[WeakRef] = []

static func clear_shared_cache() -> void:
	crowd_cache_bucket = -1
	crowd_cache.clear()

static func crowd_separation(actor: Node2D, radius: float = 13.0) -> Vector2:
	var separation := Vector2.ZERO
	var bucket := int(Time.get_ticks_msec() / 16)
	if crowd_cache_bucket != bucket:
		crowd_cache_bucket = bucket
		crowd_cache.clear()
		for enemy in actor.get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy): crowd_cache.append(weakref(enemy))
	for other_ref in crowd_cache:
		var other = other_ref.get_ref()
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

static func build_sector_search(tile_world: Node, origin: Vector2, likely_direction: Vector2, radius: float, sector_sign: float) -> PackedVector2Array:
	var direction := likely_direction.normalized()
	if direction.length_squared() < 0.001: direction = Vector2.RIGHT
	var sector_direction := direction.rotated(deg_to_rad(48.0) * sector_sign)
	var side := sector_direction.rotated(PI * 0.5 * sector_sign)
	var candidates := PackedVector2Array([
		origin + sector_direction * radius * 0.8,
		origin + sector_direction * radius * 1.65,
		origin + sector_direction * radius * 1.25 + side * radius * 0.8,
		origin + direction * radius * 1.9
	])
	var points := PackedVector2Array()
	for candidate in candidates:
		if is_instance_valid(tile_world) and tile_world.has_method("is_navigation_position_walkable"):
			if not tile_world.is_navigation_position_walkable(candidate): continue
		points.append(candidate)
	return points
