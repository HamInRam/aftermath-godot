class_name EnemyPerception
extends RefCounted

static func can_see_target(observer: CollisionObject2D, target: Node2D, maximum_distance: float, fov_degrees: float, collision_mask: int) -> bool:
	if not is_instance_valid(observer) or not is_instance_valid(target): return false
	return can_see_position(observer, target.global_position, maximum_distance, fov_degrees, collision_mask)

static func can_see_position(observer: CollisionObject2D, world_position: Vector2, maximum_distance: float, fov_degrees: float, collision_mask: int) -> bool:
	var offset := world_position - observer.global_position
	if offset.length() > maximum_distance or offset.length_squared() < 0.001: return false
	var facing := Vector2.RIGHT.rotated(observer.rotation)
	if absf(rad_to_deg(facing.angle_to(offset.normalized()))) > fov_degrees * 0.5: return false
	var query := PhysicsRayQueryParameters2D.create(observer.global_position, world_position, collision_mask)
	query.exclude = [observer.get_rid()]
	return observer.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

static func evaluate_noise(observer: CollisionObject2D, world_position: Vector2, radius: float, collision_mask: int) -> Dictionary:
	var direct_distance := observer.global_position.distance_to(world_position)
	if direct_distance > radius: return {"eligible": false, "priority": INF, "occluded": false}
	var query := PhysicsRayQueryParameters2D.create(observer.global_position, world_position, collision_mask)
	query.exclude = [observer.get_rid()]
	var occluded := not observer.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	var effective_distance := direct_distance * (1.5 if occluded else 1.0)
	return {"eligible": effective_distance <= radius, "priority": effective_distance, "occluded": occluded}
