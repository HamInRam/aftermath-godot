class_name PixelRagdoll2D
extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const FIXED_STEP := 1.0 / 60.0
const SETTLE_TIME := 2.15
const WALL_MASK := 4

var points: Dictionary = {}
var constraints: Array[Dictionary] = []
var missing_modules := PackedStringArray()
var active_time := 0.0
var accumulated_time := 0.0
var frozen := false
var cloth_color := Color("d8e2df")
var accent_color := Color("8e244f")
var rig_kind := "human"
var impact_profile: Dictionary = {}

func setup(impact_direction: Vector2, intensity: float, missing: PackedStringArray, corpse_variant := 0, new_rig_kind := "human", new_impact_profile := {}, initial_pose := {}) -> void:
	missing_modules = missing.duplicate()
	rig_kind = "hound" if new_rig_kind == "hound" or new_rig_kind == "dog" else "human"
	impact_profile = (new_impact_profile as Dictionary).duplicate()
	if rig_kind == "hound": _build_hound_rig(corpse_variant)
	else: _build_human_rig(corpse_variant)
	if initial_pose is Dictionary and not initial_pose.is_empty():
		for name in points:
			if not initial_pose.has(name): continue
			var point: Dictionary = points[name]
			point.position = initial_pose[name]
			point.previous = initial_pose[name]
			points[name] = point
	_apply_initial_impulse(impact_direction, float(impact_profile.get("limb_force", intensity)))
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
		point.position = _resolve_wall_collision(position, candidate)
		points[name] = point
	# Three early passes preserve readable elbow/knee lag. Tighten the final pose
	# only after the energetic phase, so the body never looks like one rigid tile.
	var solve_iterations := 2 if active_time > 0.72 else (3 if active_time > 0.35 else 5)
	for iteration in range(solve_iterations):
		for constraint in constraints:
			_satisfy_constraint(constraint)

func _resolve_wall_collision(from_local: Vector2, to_local: Vector2) -> Vector2:
	if not is_inside_tree(): return to_local
	var from_world := to_global(from_local)
	var to_world := to_global(to_local)
	var query := PhysicsRayQueryParameters2D.create(from_world, to_world, WALL_MASK)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
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
	if rig_kind == "hound":
		_draw_hound()
		return
	_draw_bone("pelvis", "chest", cloth_color, 5.0)
	_draw_bone("chest", "head", accent_color, 3.0)
	_draw_bone("chest", "elbow_a", cloth_color, 2.0)
	_draw_bone("elbow_a", "hand_a", Color("e1a07f"), 2.0)
	_draw_bone("chest", "elbow_b", cloth_color, 2.0)
	_draw_bone("elbow_b", "hand_b", Color("e1a07f"), 2.0)
	_draw_bone("pelvis", "knee_a", Color("17141b"), 3.0)
	_draw_bone("knee_a", "foot_a", Color("17141b"), 3.0)
	_draw_bone("pelvis", "knee_b", Color("17141b"), 3.0)
	_draw_bone("knee_b", "foot_b", Color("17141b"), 3.0)
	if not _module_missing_for_point("head"):
		var head := _snap_pixel(points.head.position)
		PIXEL_PAINTER.material_circle(self, head, 3, Color("17141b"), Color("30242d"), Color("09070c"), 31)
		PIXEL_PAINTER.material_block(self, head, Vector2(3, 3), Color("e1a07f"), 37, &"grain")
	for missing in missing_modules:
		var wound_point := _snap_pixel(_wound_point_for_module(missing))
		PIXEL_PAINTER.material_circle(self, wound_point, 1, Color("7b001b"), Color("c31338"), Color("34000b"), str(missing).hash())
		PIXEL_PAINTER.pixel(self, wound_point, Color("f2a3a8"))

func _draw_hound() -> void:
	var fur := Color("6e4a37")
	var fur_light := Color("a36c45")
	_draw_bone("pelvis", "chest", fur, 5.0)
	_draw_bone("chest", "neck", fur_light, 4.0)
	_draw_bone("neck", "head", fur_light, 3.0)
	_draw_bone("chest", "front_knee_a", fur, 2.0)
	_draw_bone("front_knee_a", "front_paw_a", fur_light, 2.0)
	_draw_bone("chest", "front_knee_b", fur, 2.0)
	_draw_bone("front_knee_b", "front_paw_b", fur_light, 2.0)
	_draw_bone("pelvis", "rear_knee_a", fur, 2.0)
	_draw_bone("rear_knee_a", "rear_paw_a", fur_light, 2.0)
	_draw_bone("pelvis", "rear_knee_b", fur, 2.0)
	_draw_bone("rear_knee_b", "rear_paw_b", fur_light, 2.0)
	if not _module_missing_for_point("head"):
		var head := _snap_pixel(points.head.position)
		PIXEL_PAINTER.material_block(self, head, Vector2(6, 5), Color("17141b"), 41, &"grain")
		PIXEL_PAINTER.material_block(self, head, Vector2(4, 3), fur_light, 43, &"fabric")
		PIXEL_PAINTER.material_block(self, head + Vector2(2, 0), Vector2(2, 1), Color("d8e2df"), 47, &"grain")
	for missing in missing_modules:
		var wound_point := _snap_pixel(_wound_point_for_module(missing))
		PIXEL_PAINTER.material_circle(self, wound_point, 1, Color("7b001b"), Color("c31338"), Color("34000b"), str(missing).hash())
		PIXEL_PAINTER.pixel(self, wound_point, Color("f2a3a8"))

func _draw_bone(a_name: String, b_name: String, color: Color, width: float) -> void:
	if _module_missing_for_point(a_name) or _module_missing_for_point(b_name): return
	var start := _snap_pixel(points[a_name].position)
	var finish := _snap_pixel(points[b_name].position)
	# The simulation remains sub-pixel and smooth, but its presentation is a
	# hard-edged chain of integer pixel blocks. This prevents both line AA and
	# fractional joint coordinates from contaminating the final 3x image.
	_draw_pixel_segment(start, finish, Color("17141b"), roundi(width) + 2)
	_draw_pixel_segment(start, finish, color, roundi(width))

func _draw_pixel_segment(start: Vector2, finish: Vector2, color: Color, pixel_width: int) -> void:
	PIXEL_PAINTER.material_line(self, _snap_pixel(start), _snap_pixel(finish), color, maxi(1, pixel_width), roundi(start.x) * 11 + roundi(start.y) * 17 + pixel_width, &"fabric")

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
