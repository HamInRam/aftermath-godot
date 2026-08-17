class_name ExecutionController
extends RefCounted

static func query_target(actor: CharacterBody2D, radius: float = 24.0) -> CharacterBody2D:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = actor.global_transform
	query.collision_mask = 2
	query.exclude = [actor.get_rid()]
	var nearest: CharacterBody2D = null
	var nearest_distance := INF
	for result in actor.get_world_2d().direct_space_state.intersect_shape(query, 8):
		var candidate = result.collider
		if candidate is CharacterBody2D and candidate.has_method("is_knocked_down") and candidate.is_knocked_down():
			if blocked_by_geometry(actor, candidate): continue
			var distance := actor.global_position.distance_squared_to(candidate.global_position)
			if distance < nearest_distance:
				nearest = candidate
				nearest_distance = distance
	return nearest

static func find_safe_position(actor: CharacterBody2D, target: CharacterBody2D, approach: Vector2) -> Dictionary:
	var body_shape := CircleShape2D.new()
	body_shape.radius = 5.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_shape
	query.collision_mask = 14
	query.exclude = [actor.get_rid(), target.get_rid()]
	for angle_offset in [0.0, -PI * 0.25, PI * 0.25, -PI * 0.5, PI * 0.5, PI]:
		var candidate := target.global_position - approach.rotated(angle_offset) * 11.0
		query.transform = Transform2D(0.0, candidate)
		if not actor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
		var travel_query := PhysicsRayQueryParameters2D.create(actor.global_position, candidate, 46)
		travel_query.exclude = [actor.get_rid(), target.get_rid()]
		if actor.get_world_2d().direct_space_state.intersect_ray(travel_query).is_empty():
			return {"found": true, "position": candidate}
	return {"found": false}

static func blocked_by_geometry(actor: CharacterBody2D, target: CollisionObject2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(actor.global_position, target.global_position, 44)
	query.exclude = [actor.get_rid(), target.get_rid()]
	return not actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
