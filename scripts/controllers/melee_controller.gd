class_name MeleeController
extends RefCounted

static func query_bodies(actor: CharacterBody2D, melee_shape: CollisionShape2D, collision_mask := 2) -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = melee_shape.shape
	query.transform = melee_shape.global_transform
	query.collision_mask = collision_mask
	query.exclude = [actor.get_rid()]
	var bodies: Array = []
	for result in actor.get_world_2d().direct_space_state.intersect_shape(query, 32):
		bodies.append(result.collider)
	return bodies

static func blocked_by_geometry(actor: CharacterBody2D, target: CollisionObject2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(actor.global_position, target.global_position, 44)
	query.exclude = [actor.get_rid(), target.get_rid()]
	return not actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
