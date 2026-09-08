class_name AimController
extends RefCounted

const AIM_MASK := 15
const MAX_AIM_DISTANCE := 300.0

static func resolve_controller_direction(actor: CollisionObject2D, raw_direction: Vector2, assist_strength: float) -> Vector2:
	if not is_instance_valid(actor) or raw_direction.length_squared() < 0.001: return Vector2.RIGHT
	var direction := raw_direction.normalized()
	var strength := clampf(assist_strength, 0.0, 1.0)
	if strength <= 0.001: return direction
	# Arcade-first magnetism: generous enough to make rapid target transitions
	# reliable, still requiring the stick/cursor to enter the target's lane.
	var cone := deg_to_rad(lerpf(5.0, 14.0, strength))
	var best_direction := direction
	var best_score := INF
	for node in actor.get_tree().get_nodes_in_group("enemy"):
		var target := node as CollisionObject2D
		if not is_instance_valid(target) or bool(target.get("is_dead")): continue
		var to_target := target.global_position - actor.global_position
		var distance := to_target.length()
		if distance < 5.0 or distance > MAX_AIM_DISTANCE: continue
		var target_direction := to_target / distance
		var angle := absf(direction.angle_to(target_direction))
		if angle > cone: continue
		if not _has_clear_lane(actor, target): continue
		var perpendicular := absf(to_target.cross(direction))
		var direct_bonus := -2.0 if perpendicular <= 5.5 else 0.0
		var score := angle / maxf(cone, 0.001) + distance / MAX_AIM_DISTANCE * 0.22 + direct_bonus
		if score < best_score:
			best_score = score
			best_direction = target_direction
	if best_score == INF: return direction
	var magnetic_weight := lerpf(0.34, 0.78, strength)
	return Vector2.RIGHT.rotated(lerp_angle(direction.angle(), best_direction.angle(), magnetic_weight))

static func solve_fire_lane(actor: CollisionObject2D, origin: Vector2, direction: Vector2, maximum_distance: float, include_context_targets := false) -> Dictionary:
	var endpoint := origin + direction.normalized() * maxf(1.0, maximum_distance)
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return {"point": endpoint, "blocked": false, "target": null}
	var query_mask := AIM_MASK | 32 if include_context_targets else AIM_MASK
	var query := PhysicsRayQueryParameters2D.create(origin, endpoint, query_mask)
	query.exclude = [actor.get_rid()]
	var result := actor.get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return {"point": endpoint, "blocked": false, "target": null}
	var collider := result.collider as Node
	return {
		"point": result.position,
		"blocked": not is_targetable(collider, include_context_targets),
		"target": collider,
	}

static func is_targetable(target: Node, include_context_targets := false) -> bool:
	if not is_instance_valid(target): return false
	if target.is_in_group("enemy"): return not bool(target.get("is_dead"))
	if not include_context_targets: return false
	if target.is_in_group("corpse"): return true
	if target.is_in_group("destructible_prop"): return true
	if target.is_in_group("security_device"): return not bool(target.get("is_offline"))
	return false

static func spread_radius_at_distance(spread_degrees: float, distance: float) -> float:
	return tan(deg_to_rad(clampf(spread_degrees, 0.0, 35.0))) * maxf(0.0, distance)

static func _has_clear_lane(actor: CollisionObject2D, target: CollisionObject2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(actor.global_position, target.global_position, AIM_MASK)
	query.exclude = [actor.get_rid()]
	var result := actor.get_world_2d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == target
