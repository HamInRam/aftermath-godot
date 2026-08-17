class_name EnemyCombatController
extends RefCounted

static func attack_windup(enemy_type: String) -> float:
	return randf_range(0.1, 0.16) if enemy_type == "gunner" else randf_range(0.12, 0.18)

static func has_clear_shot(enemy: CollisionObject2D, gun: Node2D, player: Node2D) -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(gun) or not is_instance_valid(player): return false
	var query := PhysicsRayQueryParameters2D.create(gun.global_position, player.global_position, 3)
	query.exclude = [enemy.get_rid()]
	var result := enemy.get_world_2d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider.is_in_group("player")

static func chase_velocity(enemy_type: String, direction: Vector2, speed: float, chase_multiplier: float, actor_type: String, tactical_distance: float, melee_range: float, holds_position: bool, reposition_time: float, reposition_sign: float, strafe_sign: float) -> Vector2:
	if holds_position: return Vector2.ZERO
	if enemy_type == "gunner" and reposition_time > 0.0:
		return direction.rotated(PI * 0.5 * reposition_sign) * speed * 0.82
	if enemy_type == "melee" and tactical_distance <= melee_range * 0.7:
		return Vector2.ZERO
	if enemy_type == "gunner" and tactical_distance < 28.0:
		return direction.rotated(PI * 0.5) * speed * 0.4 * strafe_sign
	return direction * speed * (1.9 if actor_type == "dog" else chase_multiplier)

static func choose_reposition_sign(enemy: CollisionObject2D, player: Node2D, distance: float = 18.0) -> float:
	if not is_instance_valid(enemy) or not is_instance_valid(player): return 1.0
	var forward := enemy.global_position.direction_to(player.global_position)
	var side := forward.rotated(PI * 0.5)
	var best_sign := 1.0
	var best_score := -INF
	for sign_value in [-1.0, 1.0]:
		var candidate: Vector2 = enemy.global_position + side * distance * float(sign_value)
		var query := PhysicsRayQueryParameters2D.create(candidate, player.global_position, 35)
		query.exclude = [enemy.get_rid()]
		var result := enemy.get_world_2d().direct_space_state.intersect_ray(query)
		var score := 2.0 if not result.is_empty() and result.collider.is_in_group("player") else 0.0
		var wall_query := PhysicsRayQueryParameters2D.create(enemy.global_position, candidate, 36)
		wall_query.exclude = [enemy.get_rid()]
		if enemy.get_world_2d().direct_space_state.intersect_ray(wall_query).is_empty(): score += 1.0
		if score > best_score:
			best_score = score
			best_sign = sign_value
	return best_sign
