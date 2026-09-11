class_name PixelRagdoll2D
extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const ACTOR_ART := preload("res://utility/pixel_actor_art.gd")
const FIXED_STEP := 1.0 / 60.0
const SETTLE_TIME := 2.15
const WALL_MASK := 4

var points: Dictionary = {}
var constraints: Array[Dictionary] = []
var missing_modules := PackedStringArray()
var active_time := 0.0
var accumulated_time := 0.0
var frozen := false
var cloth_color := Color("dedede")
var accent_color := Color("666666")
var rig_kind := "human"
var impact_profile: Dictionary = {}
var wound_state := "intact"
var wound_variant := 0
var visual_role := "gunner"
var wall_query := PhysicsRayQueryParameters2D.new()

func setup(impact_direction: Vector2, intensity: float, missing: PackedStringArray, corpse_variant := 0, new_rig_kind := "human", new_impact_profile := {}, initial_pose := {}) -> void:
	missing_modules = missing.duplicate()
	rig_kind = "hound" if new_rig_kind == "hound" or new_rig_kind == "dog" else "human"
	# Appearance rides beside the existing joint snapshot, never in place of a
	# joint. Old callers without a snapshot still receive a neutral enemy outfit.
	var owner_role := "player" if is_instance_valid(get_parent()) and str(get_parent().get("victim_role")) == "player" else "gunner"
	visual_role = "hound" if rig_kind == "hound" else str(initial_pose.get("_visual_role", owner_role))
	cloth_color = ACTOR_ART.palette(visual_role).c
	accent_color = ACTOR_ART.palette(visual_role).s
	impact_profile = (new_impact_profile as Dictionary).duplicate()
	if rig_kind == "hound": _build_hound_rig(corpse_variant)
	else: _build_human_rig(corpse_variant)
	_configure_wound_constraints()
	if initial_pose is Dictionary and not initial_pose.is_empty():
		for name in points:
			if not initial_pose.has(name): continue
			var point: Dictionary = points[name]
			point.position = initial_pose[name]
			point.previous = initial_pose[name]
			points[name] = point
	_apply_initial_impulse(impact_direction, float(impact_profile.get("limb_force", intensity)))
	# A living pose can have a hand very close to a wall. Seed each joint from
	# the safe body origin, then remember world positions so root translation and
	# rotation cannot carry its local simulation through solid room geometry.
	for name in points:
		var point: Dictionary = points[name]
		var impulse: Vector2 = point.position - point.previous
		point.position = _resolve_wall_collision(Vector2.ZERO, point.position)
		point.previous = (point.position as Vector2) - impulse
		point.world_position = to_global(point.position)
		points[name] = point
	accumulated_time = 0.0
	active_time = SETTLE_TIME + clampf(float(impact_profile.get("linear_force", intensity)) / 145.0, 0.0, 1.0) * 0.65 + clampf(float(impact_profile.get("settle_bonus", 0.0)), 0.0, 1.2)
	frozen = false
	set_physics_process(true)
	queue_redraw()

func _build_human_rig(corpse_variant: int) -> void:
	var pose_sign := -1.0 if corpse_variant % 2 == 0 else 1.0
	points = {
		"pelvis": _point(Vector2(-3, 0)),
		"chest": _point(Vector2(2, 0)),
		"head": _point(Vector2(7, 0)),
		"elbow_a": _point(Vector2(1, -4 * pose_sign)),
		"hand_a": _point(Vector2(-2, -7 * pose_sign)),
		"elbow_b": _point(Vector2(1, 4 * pose_sign)),
		"hand_b": _point(Vector2(-3, 7 * pose_sign)),
		"knee_a": _point(Vector2(-7, -3)),
		"foot_a": _point(Vector2(-11, -5)),
		"knee_b": _point(Vector2(-7, 3)),
		"foot_b": _point(Vector2(-11, 5)),
	}
	# Four readable layouts rather than two mirrored seeds repeated four times.
	# These only seed the fall; joints remain free once the impulse is applied.
	if corpse_variant % 4 == 1:
		points.hand_a = _point(Vector2(5, 8))
		points.hand_b = _point(Vector2(6, -7))
	elif corpse_variant % 4 == 2:
		points.knee_a = _point(Vector2(-6, -5))
		points.foot_a = _point(Vector2(-3, -8))
		points.hand_b = _point(Vector2(6, 5))
	elif corpse_variant % 4 == 3:
		points.knee_b = _point(Vector2(-5, -4))
		points.foot_b = _point(Vector2(-9, -7))
		points.hand_a = _point(Vector2(6, 5))
	constraints = [
		_constraint("pelvis", "chest", 5.0),
		_constraint("chest", "head", 5.0),
		_constraint("chest", "elbow_a", 4.3),
		_constraint("elbow_a", "hand_a", 4.2),
		_constraint("chest", "elbow_b", 4.3),
		_constraint("elbow_b", "hand_b", 4.6),
		_constraint("pelvis", "knee_a", 4.8),
		_constraint("knee_a", "foot_a", 4.8),
		_constraint("pelvis", "knee_b", 4.8),
		_constraint("knee_b", "foot_b", 4.8),
	]

func _configure_wound_constraints() -> void:
	# A bisected corpse must have two physically independent masses. Previously
	# only the non-ragdoll fallback knew this wound state; the visible rig kept a
	# perfectly intact pelvis/chest connection after a shotgun bisection.
	if wound_state not in ["bisected", "torso_split"]: return
	for index in range(constraints.size() - 1, -1, -1):
		if constraints[index].a == "pelvis" and constraints[index].b == "chest":
			constraints.remove_at(index)

func _build_hound_rig(corpse_variant: int) -> void:
	var pose_sign := -1.0 if corpse_variant % 2 == 0 else 1.0
	points = {
		"pelvis": _point(Vector2(-5, 0)),
		"chest": _point(Vector2(1, 0)),
		"neck": _point(Vector2(5, 0)),
		"head": _point(Vector2(8, 0)),
		"front_knee_a": _point(Vector2(2, -3 * pose_sign)),
		"front_paw_a": _point(Vector2(5, -5 * pose_sign)),
		"front_knee_b": _point(Vector2(1, 3 * pose_sign)),
		"front_paw_b": _point(Vector2(4, 5 * pose_sign)),
		"rear_knee_a": _point(Vector2(-7, -3 * pose_sign)),
		"rear_paw_a": _point(Vector2(-10, -5 * pose_sign)),
		"rear_knee_b": _point(Vector2(-7, 3 * pose_sign)),
		"rear_paw_b": _point(Vector2(-10, 5 * pose_sign)),
	}
	constraints = [
		_constraint("pelvis", "chest", 6.0),
		_constraint("chest", "neck", 4.0),
		_constraint("neck", "head", 3.0),
		_constraint("chest", "front_knee_a", 3.6),
		_constraint("front_knee_a", "front_paw_a", 3.6),
		_constraint("chest", "front_knee_b", 3.6),
		_constraint("front_knee_b", "front_paw_b", 3.6),
		_constraint("pelvis", "rear_knee_a", 3.6),
		_constraint("rear_knee_a", "rear_paw_a", 3.6),
		_constraint("pelvis", "rear_knee_b", 3.6),
		_constraint("rear_knee_b", "rear_paw_b", 3.6),
	]

func apply_impact(world_direction: Vector2, power: float, local_hit := Vector2.ZERO) -> void:
	if points.is_empty(): return
	var local_direction := world_direction.rotated(-global_rotation).normalized()
	var nearest_name := "chest"
	var nearest_distance := INF
	for name in points:
		var distance: float = (points[name].position as Vector2).distance_squared_to(local_hit)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_name = name
	for name in points:
		var point: Dictionary = points[name]
		var weight := 1.0 if name == nearest_name else 0.34
		point.previous = point.position - local_direction * clampf(power, 3.0, 28.0) * weight * FIXED_STEP
		points[name] = point
	active_time = maxf(active_time, 0.72)
	frozen = false
	set_physics_process(true)
	queue_redraw()

func freeze_pose() -> void:
	frozen = true
	active_time = 0.0
	set_physics_process(false)
	queue_redraw()

func get_body_anchor_local() -> Vector2:
	# Every joint is free to travel inside the corpse node, so the node origin is
	# not necessarily where the visible body eventually lands. The torso midpoint
	# is stable across human and hound rigs and is the useful cleanup interaction
	# position (unlike an outstretched hand or detached extremity).
	if points.is_empty(): return Vector2.ZERO
	if points.has("pelvis") and points.has("chest"):
		return ((points.pelvis.position as Vector2) + (points.chest.position as Vector2)) * 0.5
	var total := Vector2.ZERO
	for point in points.values(): total += point.position as Vector2
	return total / float(points.size())

func rebase_to_body_anchor() -> Vector2:
	# Move the simulated pose around a new local origin without changing its
	# world-space appearance. Corpse owns the matching root translation.
	var anchor := get_body_anchor_local()
	if anchor.length_squared() <= 0.0001: return Vector2.ZERO
	for name in points:
		var point: Dictionary = points[name]
		point.position = (point.position as Vector2) - anchor
		point.previous = (point.previous as Vector2) - anchor
		points[name] = point
	queue_redraw()
	return anchor

func _physics_process(delta: float) -> void:
	if frozen or points.is_empty(): return
	accumulated_time += minf(delta, 0.05)
	while accumulated_time >= FIXED_STEP:
		_simulate_step(FIXED_STEP)
		accumulated_time -= FIXED_STEP
	active_time = maxf(0.0, active_time - delta)
	if active_time <= 0.0:
		frozen = true
		set_physics_process(false)
	queue_redraw()

func _simulate_step(delta: float) -> void:
	for name in points:
		if _module_missing_for_point(name): continue
		var point: Dictionary = points[name]
		var position: Vector2 = point.position
		var motion: Vector2 = (position - (point.previous as Vector2)) * 0.93
		point.previous = position
		var candidate := position + motion
		point.position = candidate
		points[name] = point
	# Three early passes preserve readable elbow/knee lag. Tighten the final pose
	# only after the energetic phase, so the body never looks like one rigid tile.
	var solve_iterations := 2 if active_time > 0.72 else (3 if active_time > 0.35 else 5)
	for iteration in range(solve_iterations):
		for constraint in constraints:
			_satisfy_constraint(constraint)
	# Enforce walls after constraints as well as after momentum. Constraint
	# corrections can be larger than the free motion, so doing this beforehand
	# allowed knees/hands to be dragged through thin walls at the end of a step.
	for name in points:
		if _module_missing_for_point(name): continue
		var point: Dictionary = points[name]
		var previous_local := to_local(point.get("world_position", to_global(point.previous)))
		var desired: Vector2 = point.position
		var resolved := _resolve_wall_collision(previous_local, desired)
		point.position = resolved
		if resolved.distance_squared_to(desired) > 0.01:
			point.previous = resolved
		point.world_position = to_global(resolved)
		points[name] = point

func _resolve_wall_collision(from_local: Vector2, to_local: Vector2) -> Vector2:
	if not is_inside_tree(): return to_local
	var from_world := to_global(from_local)
	var to_world := to_global(to_local)
	if from_world.distance_squared_to(to_world) < 0.0001: return to_local
	wall_query.from = from_world
	wall_query.to = to_world
	wall_query.collision_mask = WALL_MASK
	var result := get_world_2d().direct_space_state.intersect_ray(wall_query)
	if result.is_empty(): return to_local
	var normal: Vector2 = result.normal
	return to_local(result.position + normal * 1.2)

func _satisfy_constraint(constraint: Dictionary) -> void:
	var a_name := str(constraint.a)
	var b_name := str(constraint.b)
	if _module_missing_for_point(a_name) or _module_missing_for_point(b_name): return
	var a: Dictionary = points[a_name]
	var b: Dictionary = points[b_name]
	var delta: Vector2 = (b.position as Vector2) - (a.position as Vector2)
	var distance := delta.length()
	if distance <= 0.001: return
	var correction := delta * ((distance - float(constraint.length)) / distance) * 0.5
	a.position = (a.position as Vector2) + correction
	b.position = (b.position as Vector2) - correction
	points[a_name] = a
	points[b_name] = b

func _apply_initial_impulse(world_direction: Vector2, intensity: float) -> void:
	var local_direction := world_direction.rotated(-global_rotation).normalized()
	if local_direction.length_squared() < 0.001: local_direction = Vector2.RIGHT
	var power := clampf(intensity, 12.0, 180.0)
	var spin_power := float(impact_profile.get("spin_force", 0.8))
	var presentation_scale := clampf(float(impact_profile.get("presentation_scale", 1.0)), 0.75, 2.0)
	var spin_sign := -1.0 if randf() < 0.5 else 1.0
	# Low-calibre hits previously moved most joints by less than one world pixel;
	# after pixel snapping that was invisible. Scale relative articulation more at
	# low power while keeping shotgun extremes controlled.
	var articulation_scale := lerpf(4.35, 2.05, clampf(power / 170.0, 0.0, 1.0)) * presentation_scale
	var point_index := 0
	for name in points:
		var point: Dictionary = points[name]
		var variation_angle := randf_range(-0.68, 0.68) + sin(float(point_index) * 2.17) * 0.16
		var variation := local_direction.rotated(variation_angle)
		var is_extremity: bool = name.begins_with("hand") or name.begins_with("foot") or name.begins_with("front_paw") or name.begins_with("rear_paw")
		var limb_scale := 1.82 if is_extremity else (1.22 if name in ["head", "neck"] else (0.28 if name == "pelvis" else 0.64))
		var radial: Vector2 = (point.position as Vector2).normalized()
		var alternating_sign := spin_sign * (-1.0 if point_index % 2 == 0 else 1.0)
		var tangential := radial.orthogonal() * alternating_sign * power * 0.56 * spin_power
		point.previous = point.position - (variation * power * limb_scale + tangential) * articulation_scale * FIXED_STEP
		points[name] = point
		point_index += 1

func _point(position: Vector2) -> Dictionary:
	return {"position": position, "previous": position}

func _constraint(a: String, b: String, length: float) -> Dictionary:
	return {"a": a, "b": b, "length": length}

func _module_missing_for_point(point_name: String) -> bool:
	if point_name == "head": return "head" in missing_modules
	if rig_kind == "hound":
		if point_name in ["front_knee_a", "front_paw_a"]: return "arm_front" in missing_modules
		if point_name in ["front_knee_b", "front_paw_b"]: return "arm_back" in missing_modules
		if point_name in ["rear_knee_b", "rear_paw_b"]: return "leg_back" in missing_modules
		return false
	if point_name in ["elbow_a", "hand_a"]: return "arm_front" in missing_modules
	if point_name in ["elbow_b", "hand_b"]: return "arm_back" in missing_modules
	if point_name in ["knee_b", "foot_b"]: return "leg_back" in missing_modules
	return false

func _draw() -> void:
	if points.is_empty(): return
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	for at: Vector2 in get_art_pixels():
		PIXEL_PAINTER.pixel(self, at, _art_pixels_cache[at].color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var _art_pixels_cache: Dictionary = {}

func get_art_pixels() -> Dictionary:
	var cells := {}
	if points.is_empty(): return cells
	var colors := ACTOR_ART.palette(visual_role)
	var pelvis: Vector2 = points.pelvis.position
	var chest: Vector2 = points.chest.position
	if rig_kind == "hound":
		for suffix in ["a", "b"]:
			_art_bone(cells, "chest", "front_knee_" + suffix, colors.c, 1, "arm_front" if suffix == "a" else "arm_back")
			_art_bone(cells, "front_knee_" + suffix, "front_paw_" + suffix, colors.g, 1, "arm_front" if suffix == "a" else "arm_back")
			_art_bone(cells, "pelvis", "rear_knee_" + suffix, colors.c, 1, "leg_front" if suffix == "a" else "leg_back")
			_art_bone(cells, "rear_knee_" + suffix, "rear_paw_" + suffix, colors.g, 1, "leg_front" if suffix == "a" else "leg_back")
		_art_bone(cells, "chest", "neck", colors.c, 3, "neck")
		_art_bone(cells, "neck", "head", colors.g, 2, "head")
	else:
		for suffix in ["a", "b"]:
			var arm := "arm_front" if suffix == "a" else "arm_back"
			var leg := "leg_front" if suffix == "a" else "leg_back"
			_art_bone(cells, "pelvis", "knee_" + suffix, colors.b, 2, leg)
			_art_bone(cells, "knee_" + suffix, "foot_" + suffix, colors.b, 2, leg)
			_art_bone(cells, "chest", "elbow_" + suffix, colors.u, 2, arm)
			_art_bone(cells, "elbow_" + suffix, "hand_" + suffix, colors.h if visual_role == "melee" else colors.u, 1, arm)
			if not _module_missing_for_point("hand_" + suffix):
				var hand: Vector2 = points["hand_" + suffix].position
				ACTOR_ART._stamp(cells, [".ii", "ihh", ".ii"], hand, colors, arm)
			if not _module_missing_for_point("foot_" + suffix):
				ACTOR_ART._stamp(cells, ["iii.", "ibbi", "iii."], points["foot_" + suffix].position, colors, leg)
	# Narrow waist, broader shoulders, attached sleeve chains. A cut torso has
	# separated masses and an open gap; no visual bridge joins the two halves.
	if wound_state in ["bisected", "torso_split"]:
		_art_segment(cells, pelvis, pelvis.lerp(chest, 0.12), colors.b, 3, "pelvis")
		_art_segment(cells, chest.lerp(pelvis, 0.12), chest, colors.c, 4, "torso")
	elif wound_state == "upper_destroyed":
		_art_segment(cells, pelvis, pelvis.lerp(chest, 0.4), colors.c, 3, "torso")
	else:
		_art_segment(cells, pelvis, pelvis.lerp(chest, 0.55), colors.c, 3, "torso")
		_art_segment(cells, pelvis.lerp(chest, 0.5), chest, colors.c, 4, "torso")
		var side := pelvis.direction_to(chest).orthogonal()
		ACTOR_ART._segment(cells, pelvis + side, chest + side, 1, colors.s, "seam")
	if not _module_missing_for_point("head"):
		var head: Vector2 = points.head.position
		if rig_kind != "hound":
			_art_segment(cells, chest, head, colors.h, 1, "neck")
		var head_rows := ACTOR_ART.HOUND_HEAD if rig_kind == "hound" else (ACTOR_ART.MASK if visual_role == "player" else (ACTOR_ART.HELMET if visual_role == "heavy" else ACTOR_ART.CROWN))
		ACTOR_ART._stamp(cells, head_rows, head, colors, "head")
	for missing in missing_modules:
		var cut := _wound_point_for_module(missing).round()
		ACTOR_ART._put(cells, cut, colors.i, "cut")
		ACTOR_ART._put(cells, cut + Vector2(1, 0), colors.n, "cut")
	_art_wound(cells, colors)
	_art_pixels_cache = ACTOR_ART.rotate_pixels(cells, global_rotation)
	return _art_pixels_cache

func _art_bone(cells: Dictionary, start_name: String, end_name: String, color: Color, width: int, part: String) -> void:
	if _module_missing_for_point(start_name) or _module_missing_for_point(end_name): return
	_art_segment(cells, points[start_name].position, points[end_name].position, color, width, part)

func _art_segment(cells: Dictionary, start: Vector2, finish: Vector2, color: Color, width: int, part: String) -> void:
	ACTOR_ART._segment(cells, start, finish, width + 2, Color("090909"), part)
	ACTOR_ART._segment(cells, start, finish, width, color, part)

func _art_wound(cells: Dictionary, colors: Dictionary) -> void:
	if wound_state == "intact": return
	var anchor: Vector2 = (points.pelvis.position as Vector2).lerp(points.chest.position, 0.58)
	if "head" in wound_state and not _module_missing_for_point("head"): anchor = points.head.position
	elif wound_state == "limb_puncture": anchor = points.elbow_b.position if rig_kind == "human" else points.front_knee_b.position
	elif wound_state == "shoulder_puncture": anchor = (points.chest.position as Vector2) + Vector2(0, -2)
	if wound_state in ["bisected", "torso_split", "upper_destroyed"]:
		for joint in ["pelvis", "chest"]:
			ACTOR_ART._put(cells, (points[joint].position as Vector2).round(), colors.n, "cut")
		return
	var heavy_wound := wound_state in ["torso_torn", "torso_cavity", "side_torn", "cluster_torso", "cluster_low"]
	ACTOR_ART._stamp(cells, ["i.i", "ini", ".si"] if heavy_wound else ["in", ".i"], anchor, colors, "wound")

func _snap_pixel(value: Vector2) -> Vector2:
	return Vector2(roundi(value.x), roundi(value.y))

func _wound_point_for_module(module_name: String) -> Vector2:
	if rig_kind == "hound":
		match module_name:
			"head": return points.neck.position
			"arm_front": return points.chest.position + Vector2(0, -2)
			"arm_back": return points.chest.position + Vector2(0, 2)
			"leg_back": return points.pelvis.position + Vector2(0, 2)
		return points.chest.position
	match module_name:
		"head": return points.chest.position
		"arm_front": return points.chest.position + Vector2(0, -2)
		"arm_back": return points.chest.position + Vector2(0, 2)
		"leg_back": return points.pelvis.position + Vector2(-1, 2)
	return points.chest.position
