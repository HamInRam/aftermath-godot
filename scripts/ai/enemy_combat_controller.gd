class_name EnemyCombatController
extends RefCounted

static func attack_windup(enemy_type: String) -> float:
	return randf_range(0.14, 0.22) if enemy_type == "gunner" else randf_range(0.12, 0.18)

static func distance_accuracy_multiplier(distance: float, shoot_range: float, profile_multiplier: float) -> float:
	var ratio := clampf(distance / maxf(1.0, shoot_range), 0.0, 1.0)
	if ratio <= 0.32: return 0.78
	if ratio <= 0.64: return 1.0
	return lerpf(1.0, maxf(1.0, profile_multiplier), inverse_lerp(0.64, 1.0, ratio))

static func committed_target(player: CharacterBody2D, prediction_seconds: float) -> Vector2:
	if not is_instance_valid(player): return Vector2.ZERO
	return player.global_position + player.velocity * clampf(prediction_seconds, 0.0, 0.2)

static func has_clear_shot(enemy: CollisionObject2D, gun: Node2D, player: Node2D) -> bool:
	return bool(evaluate_fire_lane(enemy, gun.global_position if is_instance_valid(gun) else Vector2.ZERO, player).get("clear", false))

static func evaluate_fire_lane(enemy: CollisionObject2D, origin: Vector2, player: Node2D) -> Dictionary:
	if not is_instance_valid(enemy) or not is_instance_valid(player): return {"clear": false, "reason": "invalid"}
	var query := PhysicsRayQueryParameters2D.create(origin, player.global_position, 35)
	query.exclude = [enemy.get_rid()]
	var result := enemy.get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return {"clear": false, "reason": "no_target"}
	var collider: Object = result.collider
	if collider.is_in_group("player"): return {"clear": true, "reason": "player", "collider": collider}
	if collider.is_in_group("enemy"): return {"clear": false, "reason": "friendly", "collider": collider}
	return {"clear": false, "reason": "solid", "collider": collider}

static func choose_cover_plan(enemy: CollisionObject2D, player: Node2D, tile_world: Node, preferred_distance: float, flank_sign: float) -> Dictionary:
	if not is_instance_valid(enemy) or not is_instance_valid(player): return {}
	var forward: Vector2 = enemy.global_position.direction_to(player.global_position)
	if forward.length_squared() < 0.001: forward = Vector2.RIGHT
	var side: Vector2 = forward.rotated(PI * 0.5)
	var best: Dictionary = {}
	var best_score := -INF
	for side_distance in [18.0, 26.0, 34.0, -18.0, -26.0, -34.0]:
		for depth in [-12.0, 0.0, 12.0]:
			var cover_position: Vector2 = enemy.global_position + side * side_distance + forward * depth
			if not _is_reachable(enemy, tile_world, cover_position): continue
			if not _is_occluded_from_player(enemy, cover_position, player.global_position): continue
			for peek_sign in [1.0, -1.0]:
				var peek_position: Vector2 = cover_position + side * 11.0 * float(peek_sign)
				if not _is_reachable(enemy, tile_world, peek_position): continue
				if not _position_has_player_lane(enemy, peek_position, player): continue
				var target_distance: float = peek_position.distance_to(player.global_position)
				var distance_score := 1.0 - minf(1.0, absf(target_distance - preferred_distance) / maxf(preferred_distance, 1.0))
				var travel_penalty := enemy.global_position.distance_to(peek_position) * 0.018
				var preferred_side_bonus := 0.25 if signf(side_distance) == signf(flank_sign) else 0.0
				var score := 3.0 + distance_score + preferred_side_bonus - travel_penalty
				if score > best_score:
					best_score = score
					best = {"mode": "cover", "cover": cover_position, "peek": peek_position, "score": score}
	if not best.is_empty(): return best
	for sign_value in [flank_sign, -flank_sign]:
		var waypoint: Vector2 = enemy.global_position + side * 30.0 * float(sign_value) + forward * 14.0
		if not _is_reachable(enemy, tile_world, waypoint): continue
		return {"mode": "flank", "cover": waypoint, "peek": waypoint, "score": 0.5}
	return {}

static func _is_reachable(enemy: CollisionObject2D, tile_world: Node, position: Vector2) -> bool:
	if is_instance_valid(tile_world) and tile_world.has_method("is_navigation_position_walkable"):
		if not tile_world.is_navigation_position_walkable(position): return false
	if is_instance_valid(tile_world) and tile_world.has_method("get_navigation_path"):
		return not tile_world.get_navigation_path(enemy.global_position, position).is_empty()
	return true

static func _is_occluded_from_player(enemy: CollisionObject2D, position: Vector2, player_position: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(position, player_position, 32)
	query.exclude = [enemy.get_rid()]
	return not enemy.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

static func _position_has_player_lane(enemy: CollisionObject2D, position: Vector2, player: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(position, player.global_position, 35)
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
