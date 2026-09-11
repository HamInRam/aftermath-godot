class_name EnemyVisualController
extends RefCounted
## Stateless integration controller; the scene retains lifetime and signal ownership.

static func _update_living_visuals(actor: Node2D, delta: float) -> void:
	if is_instance_valid(actor.legs_visual) and actor.legs_visual.visible:
		var local_motion = actor.velocity.rotated(-actor.rotation)
		if local_motion.length_squared() > 0.5: actor.legs_visual.rotation = local_motion.angle()
		actor.legs_visual.update_pose(delta, local_motion, actor.move_speed, "attack" if actor.state == actor.State.ATTACK else "idle", clampf(actor.state_pose_pulse / 0.22, 0.0, 1.0))
	if is_instance_valid(actor.lifecycle_rig):
		actor.visual_update_accumulator += delta
		var near_camera = not is_instance_valid(actor.player) or actor.global_position.distance_squared_to(actor.player.global_position) <= 260.0 * 260.0
		var reactive_visual = actor.state in [actor.State.ATTACK, actor.State.STAGGERED, actor.State.KNOCKED_DOWN] or actor.state_pose_pulse > 0.0 or actor.active_bleed_time > 0.0
		var visual_step = 1.0 / 30.0 if near_camera or reactive_visual else 1.0 / 8.0
		if actor.visual_update_accumulator >= visual_step:
			var visual_delta = minf(actor.visual_update_accumulator, 0.15)
			actor.visual_update_accumulator = 0.0
			var rig_action = "attack" if actor.state == actor.State.ATTACK or actor.melee_swing_time > 0.0 else "idle"
			var rig_amount = clampf(actor.state_pose_pulse / 0.22, 0.0, 1.0) if rig_action == "attack" else 0.0
			actor.lifecycle_rig.set_weapon_stance("hound" if actor.actor_type == "dog" else ("gun" if actor.enemy_type == "gunner" else "melee"))
			if actor.actor_type != "dog" and actor.enemy_type == "gunner" and actor.gun.gun_data != null:
				actor.lifecycle_rig.set_weapon_stance(actor.gun.gun_data.weapon_class)
				if actor.gun.is_reloading:
					rig_action = "reload"
					rig_amount = 1.0 - actor.gun.reload_timer.time_left / maxf(actor.gun.active_reload_duration, 0.01)
			actor.lifecycle_rig.set_weapon_presentation(actor.gun.visual_offset, actor.gun.visual_angle, actor.gun.magazine_offset)
			actor.lifecycle_rig.update_lifecycle(visual_delta, actor.velocity.rotated(-actor.rotation), actor.move_speed, Vector2.ZERO, 0.0, rig_action, rig_amount)
			actor.gun.z_index = 0 if actor.lifecycle_rig.weapon_should_render_behind() else 2
	if actor.state != actor.previous_visual_state:
		actor.state_pose_pulse = 0.22
		actor.previous_visual_state = actor.state
		actor.queue_redraw()


static func _draw(actor: Node2D) -> void:
	if not actor.is_dead and actor.get_meta("polluter", false):
		# Grayscale twin canisters identify the contamination carrier.
		for side in [-1, 1]:
			actor.draw_rect(Rect2(-7, side * 5 - 2, 6, 4), Color("eeeeee"))
			actor.draw_rect(Rect2(-6, side * 5 - 1, 4, 2), Color("222222"))
	# Tiny authored role badges survive blood and debris without becoming large
	# floating HUD markers: cyan gunner, pink rusher, orange assault, violet heavy.
	if not actor.is_dead:
		match actor.archetype_id:
			"melee":
				actor.draw_line(Vector2(-3, -7), Vector2(0, -9), Color("ff4f91"), 1.0)
				actor.draw_line(Vector2(0, -9), Vector2(3, -7), Color("ff4f91"), 1.0)
			"assault":
				actor.draw_rect(Rect2(-4, -9, 3, 2), Color("ff9a45"))
				actor.draw_rect(Rect2(1, -9, 3, 2), Color("ff9a45"))
			"heavy":
				actor.draw_rect(Rect2(-3, -10, 6, 3), Color("a59cff"), false, 1.0)
			"gunner":
				actor.draw_line(Vector2(-2, -8), Vector2(2, -8), Color("62e8ff"), 1.0)
	if not actor.is_dead and (Settings.high_contrast_enemies or actor.state in [actor.State.CHASE, actor.State.ATTACK]):
		var threat_color = Color(1.0, 0.16, 0.28, 0.92) if actor.state in [actor.State.CHASE, actor.State.ATTACK] else Color(1.0, 0.78, 0.18, 0.72)
		actor.draw_line(Vector2(-8, -7), Vector2(-4, -7), threat_color, 1.0)
		actor.draw_line(Vector2(-8, -7), Vector2(-8, -3), threat_color, 1.0)
		actor.draw_line(Vector2(-8, 7), Vector2(-4, 7), threat_color, 1.0)
		actor.draw_line(Vector2(8, -7), Vector2(5, -7), threat_color, 1.0)
	if actor.melee_swing_time > 0.0:
		actor.PIXEL_PAINTER.arc(actor, Vector2.ZERO, roundi(actor.melee_range), -0.65, 0.65, Color("ffd0a8"), 10)
	if actor.state == actor.State.ATTACK and actor.attack_windup_time > 0.0:
		var charge = 1.0 - clampf(actor.attack_windup_time / maxf(0.001, actor.attack_windup_duration), 0.0, 1.0)
		actor.PIXEL_PAINTER.arc(actor, Vector2.ZERO, 9, -0.48, lerpf(-0.48, 0.48, charge), Color("ffe56b"), 8)
		actor.PIXEL_PAINTER.pixel(actor, Vector2(7, 0), Color("fff3b0"))
		# A short two-pixel tell communicates the committed firing lane without
		# turning combat into a full laser-sight overlay.
		actor.draw_line(Vector2(9, -1), Vector2(13 + charge * 3.0, -1), Color(1.0, 0.38, 0.2, 0.35 + charge * 0.45), 1.0)
		actor.draw_line(Vector2(9, 1), Vector2(12 + charge * 2.0, 1), Color(1.0, 0.75, 0.28, 0.28 + charge * 0.38), 1.0)
	if actor.debug_draw_vision:
		var half_fov = deg_to_rad(actor.vision_fov_degrees * 0.5)
		var vision_color = Color(0.2, 1.0, 0.45, 0.16) if actor.player_in_sight else Color(1.0, 0.2, 0.32, 0.09)
		var points = PackedVector2Array([Vector2.ZERO])
		for index in range(17):
			var angle = lerpf(-half_fov, half_fov, float(index) / 16.0)
			points.append(Vector2.RIGHT.rotated(angle) * actor.detection_range)
		actor.PIXEL_PAINTER.arc(actor, Vector2.ZERO, roundi(actor.detection_range), -half_fov, half_fov, Color(vision_color, 0.5), 24)
		actor.PIXEL_PAINTER.line(actor, Vector2.ZERO, Vector2.RIGHT.rotated(-half_fov) * actor.detection_range, Color(vision_color, 0.5))
		actor.PIXEL_PAINTER.line(actor, Vector2.ZERO, Vector2.RIGHT.rotated(half_fov) * actor.detection_range, Color(vision_color, 0.5))
		for angle_step in range(-3, 4):
			var ray_angle = half_fov * float(angle_step) / 3.0
			for distance in range(16, roundi(actor.detection_range), 16):
				actor.PIXEL_PAINTER.pixel(actor, (Vector2.RIGHT.rotated(ray_angle) * distance).round(), vision_color)
	actor.draw_set_transform(Vector2.ZERO, -actor.rotation, Vector2.ONE)
	if actor.alert_transition_pulse > 0.0:
		var pulse_alpha = clampf(actor.alert_transition_pulse / 0.32, 0.0, 1.0)
		var pulse_color = Color("ff385f", pulse_alpha) if actor.alert_level == actor.AlertLevel.ALERT else Color("ffd166", pulse_alpha)
		actor.PIXEL_PAINTER.circle(actor, Vector2(0, -9), roundi(4.0 + (1.0 - pulse_alpha) * 3.0), pulse_color, true)
	if actor.state == actor.State.INVESTIGATE:
		if is_instance_valid(actor.claimed_corpse):
			# A compact body silhouette distinguishes corpse discovery from an
			# ordinary sound investigation without adding floating text.
			actor.PIXEL_PAINTER.pixel(actor, Vector2(0, -11), Color("82d8ff"))
			actor.PIXEL_PAINTER.line(actor, Vector2(-3, -9), Vector2(3, -9), Color("82d8ff"))
			actor.draw_line(Vector2(-2, -8), Vector2(-3, -6), Color("82d8ff"), 1.0)
			actor.draw_line(Vector2(2, -8), Vector2(3, -6), Color("82d8ff"), 1.0)
		else:
			actor.PIXEL_PAINTER.arc(actor, Vector2(0, -10), 2, -PI * 0.85, PI * 0.35, Color("ffd166"), 7)
			actor.PIXEL_PAINTER.pixel(actor, Vector2(0, -7), Color("ffd166"))
	elif actor.state == actor.State.SEARCH:
		actor.PIXEL_PAINTER.arc(actor, Vector2(0, -9), 3, -PI * 0.2, PI * 1.3, Color("66e0ff"), 9)
		actor.draw_line(Vector2(2, -7), Vector2(4, -5), Color("66e0ff"), 1.0)
	elif actor.state == actor.State.RETURN:
		actor.draw_line(Vector2(-3, -9), Vector2(3, -9), Color("9cc8ff"), 1.0)
		actor.draw_line(Vector2(-3, -9), Vector2(-1, -11), Color("9cc8ff"), 1.0)
	elif actor.state in [actor.State.CHASE, actor.State.ATTACK]:
		actor.PIXEL_PAINTER.line(actor, Vector2(0, -12), Vector2(0, -8), Color("ff385f"))
		actor.PIXEL_PAINTER.pixel(actor, Vector2(0, -7), Color("ff385f"))
	elif actor.tactical_role == "guard" and actor.guard_alert_time > 0.0:
		actor.draw_line(Vector2(-3, -9), Vector2(3, -9), Color("9cf7c8"), 1.0)
		actor.draw_line(Vector2(-3, -9), Vector2(0, -6), Color("9cf7c8"), 1.0)
		actor.draw_line(Vector2(3, -9), Vector2(0, -6), Color("9cf7c8"), 1.0)
