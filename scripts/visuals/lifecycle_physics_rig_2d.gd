class_name LifecyclePhysicsRig2D
extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const ACTOR_ART := preload("res://utility/pixel_actor_art.gd")

# A controlled Verlet skeleton is present for the actor's entire lifetime.
# Locomotion supplies targets, impacts displace individual joints, knockdown
# releases the targets, and recovery blends the same points back to animation.
enum Mode { ACTIVE, HIT_REACT, KNOCKED_DOWN, RECOVERING }

const FIXED_STEP := 1.0 / 60.0
const ACTIVE_FIXED_STEP := 1.0 / 30.0
const ACTIVE_REDRAW_STEP := 1.0 / 30.0
const IDLE_REDRAW_STEP := 1.0 / 12.0

@export_enum("player", "enemy", "hound") var rig_kind := "enemy"
@export var body_color := Color("7c235b")
@export var accent_color := Color("f23d78")
@export var skin_color := Color("e1a07f")
@export var visual_role := "gunner"
# Legs are a separate scene layer for living actors. The same joints remain in
# this rig for hit reactions, knockdown and seamless corpse handoff.
@export var external_legs := false

var points: Dictionary = {}
var constraints: Array[Dictionary] = []
var mode := Mode.ACTIVE
var local_velocity := Vector2.ZERO
var speed_reference := 80.0
var movement_ratio := 0.0
var stride_phase := 0.0
var upper_offset := Vector2.ZERO
var upper_rotation := 0.0
var action := "idle"
var action_amount := 0.0
var hit_react_time := 0.0
var recovery_progress := 1.0
var accumulator := 0.0
var flash_amount := 0.0
var world_velocity := Vector2.ZERO
var facing_sector := 0
var facing_direction := Vector2.RIGHT
var idle_time := 0.0
var knockdown_transition_time := 0.0
var weapon_stance := "gun"
var weapon_recoil_pulse := 0.0
var weapon_pose_supplied := false
var weapon_pose_offset := Vector2.ZERO
var weapon_pose_angle := 0.0
var weapon_feed_offset := Vector2.ZERO

func set_weapon_presentation(offset: Vector2, angle: float, feed_offset: Vector2) -> void:
	weapon_pose_supplied = true
	weapon_pose_offset = offset
	weapon_pose_angle = angle
	weapon_feed_offset = feed_offset
var redraw_accumulator := 0.0
var simulation_steps_total := 0
var redraw_requests_total := 0
var hit_feedback_time := 0.0
var hit_feedback_total := 0.0
var hit_feedback_white_time := 0.03
var hit_feedback_intensity := 0.0
var hit_feedback_kind := ""
var hit_feedback_impact_color := Color("fff4dc")
var hit_feedback_recovery_color := Color("e92245")

const DIRECTION_STEP := PI / 4.0
const DIRECTION_HYSTERESIS := deg_to_rad(6.0)
const KNOCKDOWN_TRANSITION_DURATION := 0.12

func _ready() -> void:
	# Overhead hands/head must occlude the gun stock in every direction. The
	# barrel extends past the body; aim sectors must not paint it over the face.
	z_index = 3
	_build_rig()
	queue_redraw()

func configure(kind: String, color: Color, accent := Color("f23d78"), role := "") -> void:
	rig_kind = "hound" if kind in ["dog", "hound"] else kind
	body_color = color
	accent_color = accent
	visual_role = ("hound" if rig_kind == "hound" else ("player" if rig_kind == "player" else "gunner")) if role.is_empty() else role
	weapon_stance = "hound" if rig_kind == "hound" else ("gun" if visual_role in ["player", "gunner", "assault", "heavy"] else "melee")
	_build_rig()
	queue_redraw()

func set_weapon_stance(new_stance: String) -> void:
	weapon_stance = new_stance

func trigger_weapon_recoil(amount := 1.0) -> void:
	weapon_recoil_pulse = maxf(weapon_recoil_pulse, clampf(amount, 0.0, 1.5))
	queue_redraw()

func get_facing_sector() -> int:
	return facing_sector

func weapon_should_render_behind() -> bool:
	return facing_direction.y < -0.35

func is_directional_skin_active() -> bool:
	return mode != Mode.KNOCKED_DOWN or knockdown_transition_time > 0.0

func update_lifecycle(delta: float, velocity_in_local_space: Vector2, reference_speed: float, new_upper_offset := Vector2.ZERO, new_upper_rotation := 0.0, new_action := "idle", new_action_amount := 0.0) -> void:
	local_velocity = velocity_in_local_space
	world_velocity = local_velocity.rotated(global_rotation)
	speed_reference = maxf(1.0, reference_speed)
	movement_ratio = clampf(local_velocity.length() / speed_reference, 0.0, 1.5)
	stride_phase += delta * lerpf(5.0, 14.0, movement_ratio)
	idle_time += delta
	_update_facing_sector()
	upper_offset = new_upper_offset
	upper_rotation = new_upper_rotation
	action = new_action
	action_amount = clampf(new_action_amount, 0.0, 1.0)
	flash_amount = maxf(0.0, flash_amount - delta * 8.0)
	hit_feedback_time = maxf(0.0, hit_feedback_time - delta)
	if hit_feedback_time <= 0.0:
		hit_feedback_intensity = 0.0
		hit_feedback_kind = ""
	weapon_recoil_pulse = maxf(0.0, weapon_recoil_pulse - delta * 14.0)
	knockdown_transition_time = maxf(0.0, knockdown_transition_time - delta)
	if mode == Mode.HIT_REACT:
		hit_react_time = maxf(0.0, hit_react_time - delta)
		if hit_react_time <= 0.0: mode = Mode.ACTIVE
	elif mode == Mode.RECOVERING:
		recovery_progress = minf(1.0, recovery_progress + delta / 0.42)
		if recovery_progress >= 1.0: mode = Mode.ACTIVE
	accumulator += minf(delta, 0.05)
	# Standing/moving silhouettes are deliberately pixel-stepped, so solving and
	# rebuilding their draw list at display refresh rate only burns CPU/GPU command
	# bandwidth. Impacts and knockdowns retain the full 60 Hz response cadence.
	var reactive := mode != Mode.ACTIVE or flash_amount > 0.0 or hit_feedback_time > 0.0 or weapon_recoil_pulse > 0.0 or action != "idle"
	var simulation_step := FIXED_STEP if reactive else ACTIVE_FIXED_STEP
	while accumulator >= simulation_step:
		_update_targets()
		_simulate_step(simulation_step)
		accumulator -= simulation_step
		simulation_steps_total += 1
	redraw_accumulator += delta
	var redraw_step := FIXED_STEP if reactive else (ACTIVE_REDRAW_STEP if movement_ratio > 0.05 else IDLE_REDRAW_STEP)
	if redraw_accumulator >= redraw_step:
		redraw_accumulator = 0.0
		redraw_requests_total += 1
		queue_redraw()

func apply_hit(world_direction: Vector2, power: float, hit_zone := "torso") -> void:
	if points.is_empty(): _build_rig()
	var direction := world_direction.rotated(-global_rotation).normalized()
	if direction.length_squared() < 0.001: direction = Vector2.RIGHT
	var focus: PackedStringArray
	match hit_zone:
		"head": focus = PackedStringArray(["head", "neck"])
		"limb": focus = PackedStringArray(["hand_a", "hand_b", "foot_a", "foot_b", "front_paw_a", "front_paw_b", "rear_paw_a", "rear_paw_b"])
		_: focus = PackedStringArray(["chest", "pelvis"])
	var impulse := clampf(power, 3.0, 34.0)
	for name in points:
		var point: Dictionary = points[name]
		var weight := 1.0 if name in focus else 0.24
		var tangent := direction.orthogonal() * (0.16 if posmod(str(name).hash(), 2) == 0 else -0.16)
		point.previous = point.position - (direction + tangent) * impulse * weight * FIXED_STEP
		points[name] = point
	mode = Mode.HIT_REACT
	hit_react_time = 0.14
	flash_amount = 1.0
	queue_redraw()

func trigger_damage_feedback(profile: Dictionary) -> void:
	var white_time := clampf(float(profile.get("white_time", 0.03)), 0.016, 0.05)
	var color_time := clampf(float(profile.get("color_time", 0.07)), 0.035, 0.12)
	var was_active := hit_feedback_time > 0.0
	hit_feedback_kind = str(profile.get("kind", "flesh"))
	hit_feedback_impact_color = profile.get("impact_color", Color("fff4dc")) as Color
	hit_feedback_recovery_color = profile.get("recovery_color", Color("e92245")) as Color
	hit_feedback_white_time = white_time
	hit_feedback_total = white_time + color_time
	hit_feedback_intensity = minf(1.0, maxf(hit_feedback_intensity, float(profile.get("intensity", 0.82))) + (0.10 if was_active else 0.0))
	# Automatic fire reinforces the coloured recovery instead of restarting the
	# bright first frame on every round, preventing a sustained strobe.
	hit_feedback_time = maxf(hit_feedback_time, color_time * 0.72) if was_active else hit_feedback_total
	queue_redraw()

func _feedback_color(base: Color, legacy_factor: float) -> Color:
	var result := base.lerp(Color.WHITE, flash_amount * legacy_factor)
	if hit_feedback_time <= 0.0 or hit_feedback_total <= 0.0: return result
	var elapsed := hit_feedback_total - hit_feedback_time
	var in_white_phase := elapsed <= hit_feedback_white_time
	var target := hit_feedback_impact_color if in_white_phase else hit_feedback_recovery_color
	var phase_progress := 0.0 if in_white_phase else clampf((elapsed - hit_feedback_white_time) / maxf(0.001, hit_feedback_total - hit_feedback_white_time), 0.0, 1.0)
	var envelope := 1.0 if in_white_phase else (1.0 - smoothstep(0.35, 1.0, phase_progress) * 0.58)
	return result.lerp(target, clampf(hit_feedback_intensity * envelope, 0.0, 0.94))

func enter_knockdown(world_direction: Vector2, power := 42.0) -> void:
	apply_hit(world_direction, power, "torso")
	# Once balance is lost, extremities fan away from the compact standing mass.
	# This is deliberately absent from ordinary hit reactions, so living actors
	# never resemble prone bodies while walking.
	for name in points:
		var point: Dictionary = points[name]
		var radial: Vector2 = (point.position as Vector2).normalized()
		var extremity: bool = str(name).begins_with("hand") or str(name).begins_with("foot") or str(name).contains("paw")
		var fan_power := power * (0.42 if extremity else 0.12)
		point.previous = (point.previous as Vector2) - radial * fan_power * FIXED_STEP
		points[name] = point
	mode = Mode.KNOCKED_DOWN
	recovery_progress = 0.0
	knockdown_transition_time = KNOCKDOWN_TRANSITION_DURATION

func begin_recovery() -> void:
	if mode != Mode.KNOCKED_DOWN: return
	mode = Mode.RECOVERING
	recovery_progress = 0.0

func force_active() -> void:
	mode = Mode.ACTIVE
	recovery_progress = 1.0
	_update_targets()
	for name in points:
		var point: Dictionary = points[name]
		point.position = point.target
		point.previous = point.target
		points[name] = point
	queue_redraw()

func get_performance_counters() -> Dictionary:
	return {
		"simulation_steps": simulation_steps_total,
		"redraw_requests": redraw_requests_total,
	}

func _update_facing_sector() -> void:
	var angle := wrapf(global_rotation, -PI, PI)
	var center := float(facing_sector) * DIRECTION_STEP
	if absf(angle_difference(center, angle)) > DIRECTION_STEP * 0.5 + DIRECTION_HYSTERESIS:
		facing_sector = wrapi(roundi(angle / DIRECTION_STEP), 0, 8)
	facing_direction = Vector2.RIGHT.rotated(angle)

func get_pose_snapshot() -> Dictionary:
	var snapshot := {}
	for name in points:
		snapshot[name] = (points[name].position as Vector2)
	snapshot["_visual_role"] = visual_role
	return snapshot

func _build_rig() -> void:
	if rig_kind == "hound":
		points = {
			"pelvis": _point(Vector2(-4, 0)), "chest": _point(Vector2(0, 0)),
			"neck": _point(Vector2(3, 0)), "head": _point(Vector2(6, 0)),
			"front_knee_a": _point(Vector2(1, -2)), "front_paw_a": _point(Vector2(3, -3)),
			"front_knee_b": _point(Vector2(1, 2)), "front_paw_b": _point(Vector2(3, 3)),
			"rear_knee_a": _point(Vector2(-5, -2)), "rear_paw_a": _point(Vector2(-7, -3)),
			"rear_knee_b": _point(Vector2(-5, 2)), "rear_paw_b": _point(Vector2(-7, 3)),
		}
		constraints = [
			_constraint("pelvis", "chest", 4.0), _constraint("chest", "neck", 3.0), _constraint("neck", "head", 3.0),
			_constraint("chest", "front_knee_a", 2.3), _constraint("front_knee_a", "front_paw_a", 2.3),
			_constraint("chest", "front_knee_b", 2.3), _constraint("front_knee_b", "front_paw_b", 2.3),
			_constraint("pelvis", "rear_knee_a", 2.3), _constraint("rear_knee_a", "rear_paw_a", 2.3),
			_constraint("pelvis", "rear_knee_b", 2.3), _constraint("rear_knee_b", "rear_paw_b", 2.3),
		]
	else:
		points = {
			"pelvis": _point(Vector2(-2, 0)), "chest": _point(Vector2(1, 0)), "head": _point(Vector2(4, 0)),
			"elbow_a": _point(Vector2(0, -3)), "hand_a": _point(Vector2(3, -4)),
			"elbow_b": _point(Vector2(0, 3)), "hand_b": _point(Vector2(3, 4)),
			"knee_a": _point(Vector2(-3, -2)), "foot_a": _point(Vector2(-5, -2)),
			"knee_b": _point(Vector2(-3, 2)), "foot_b": _point(Vector2(-5, 2)),
		}
		constraints = [
			_constraint("pelvis", "chest", 3.0), _constraint("chest", "head", 3.0),
			_constraint("chest", "elbow_a", 3.2), _constraint("elbow_a", "hand_a", 3.2),
			_constraint("chest", "elbow_b", 3.2), _constraint("elbow_b", "hand_b", 3.2),
			_constraint("pelvis", "knee_a", 2.2), _constraint("knee_a", "foot_a", 2.0),
			_constraint("pelvis", "knee_b", 2.2), _constraint("knee_b", "foot_b", 2.0),
		]
	_update_targets()
	for name in points:
		var point: Dictionary = points[name]
		point.position = point.target
		point.previous = point.target
		points[name] = point

func _update_targets() -> void:
	if points.is_empty(): return
	var step := roundf(sin(stride_phase * 2.0) * 2.3 * movement_ratio)
	if rig_kind == "hound":
		var dog_step := step * 0.65
		_set_target("pelvis", Vector2(-4, 0)); _set_target("chest", Vector2(0, 0)); _set_target("neck", Vector2(3, 0)); _set_target("head", Vector2(6, 0))
		_set_target("front_knee_a", Vector2(1 + dog_step, -2)); _set_target("front_paw_a", Vector2(3 + dog_step, -3))
		_set_target("front_knee_b", Vector2(1 - dog_step, 2)); _set_target("front_paw_b", Vector2(3 - dog_step, 3))
		_set_target("rear_knee_a", Vector2(-5 - dog_step, -2)); _set_target("rear_paw_a", Vector2(-7 - dog_step, -3))
		_set_target("rear_knee_b", Vector2(-5 + dog_step, 2)); _set_target("rear_paw_b", Vector2(-7 + dog_step, 3))
		return
	# A standing top-down person is a compact head/shoulder mass. Most leg length
	# is occluded by the torso; exposing the full death-rig span reads as prone.
	var human_step := step * 0.55
	_set_target("pelvis", Vector2(-2, 0))
	var upper_transform := Transform2D(upper_rotation, upper_offset)
	_set_target("chest", upper_transform * Vector2(1, 0)); _set_target("head", upper_transform * Vector2(4, 0))
	var attack_push := 2.0 * action_amount if action in ["attack", "execute"] else 0.0
	_set_target("elbow_a", upper_transform * Vector2(0 + attack_push, -3)); _set_target("hand_a", upper_transform * Vector2(3 + attack_push, -4))
	_set_target("elbow_b", upper_transform * Vector2(0 + attack_push, 3)); _set_target("hand_b", upper_transform * Vector2(3 + attack_push, 4))
	_set_target("knee_a", Vector2(-3 + human_step, -2)); _set_target("foot_a", Vector2(-5 + human_step, -2))
	_set_target("knee_b", Vector2(-3 - human_step, 2)); _set_target("foot_b", Vector2(-5 - human_step, 2))

func _simulate_step(_delta: float) -> void:
	var target_strength := 0.0
	match mode:
		Mode.ACTIVE: target_strength = 0.48
		Mode.HIT_REACT: target_strength = 0.17
		Mode.RECOVERING: target_strength = lerpf(0.08, 0.48, smoothstep(0.0, 1.0, recovery_progress))
		Mode.KNOCKED_DOWN: target_strength = 0.0
	var damping := 0.76 if mode in [Mode.ACTIVE, Mode.RECOVERING] else 0.88
	for name in points:
		var point: Dictionary = points[name]
		var position: Vector2 = point.position
		var motion: Vector2 = (position - (point.previous as Vector2)) * damping
		point.previous = position
		point.position = position + motion + ((point.target as Vector2) - position) * target_strength
		points[name] = point
	var solver_passes := 4 if mode == Mode.KNOCKED_DOWN else (3 if mode in [Mode.HIT_REACT, Mode.RECOVERING] else 2)
	for iteration in range(solver_passes):
		for link in constraints: _solve_constraint(link, 0.92 if mode == Mode.KNOCKED_DOWN else 0.72)

func _solve_constraint(link: Dictionary, stiffness: float) -> void:
	var a: Dictionary = points[link.a]
	var b: Dictionary = points[link.b]
	var delta: Vector2 = (b.position as Vector2) - (a.position as Vector2)
	var distance := delta.length()
	if distance <= 0.001: return
	var correction := delta * ((distance - float(link.length)) / distance) * 0.5 * stiffness
	a.position = (a.position as Vector2) + correction
	b.position = (b.position as Vector2) - correction
	points[link.a] = a
	points[link.b] = b

func _point(position: Vector2) -> Dictionary:
	return {"position": position, "previous": position, "target": position}

func _constraint(a: String, b: String, length: float) -> Dictionary:
	return {"a": a, "b": b, "length": length}

func _set_target(name: String, target: Vector2) -> void:
	var point: Dictionary = points[name]
	point.target = target
	points[name] = point

func _draw() -> void:
	if points.is_empty(): return
	# Every output cell is axis-aligned on the native screen pixel grid. Aim is
	# continuous; the eight-way sector API remains only for gameplay hysteresis.
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	if mode == Mode.KNOCKED_DOWN and knockdown_transition_time <= 0.0:
		if rig_kind == "hound": _draw_hound_prone()
		else: _draw_human_prone()
	else:
		var collapse := 0.0
		if mode == Mode.KNOCKED_DOWN: collapse = 1.0 - knockdown_transition_time / KNOCKDOWN_TRANSITION_DURATION
		elif mode == Mode.RECOVERING: collapse = 1.0 - smoothstep(0.0, 1.0, recovery_progress)
		if rig_kind == "hound": _draw_hound_standing(collapse)
		else: _draw_human_standing(collapse)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func get_live_art_pixels() -> Dictionary:
	if rig_kind == "hound":
		return ACTOR_ART.hound_pixels(global_rotation, _four_frame_step() * movement_ratio)
	var hands := _standing_hand_positions(Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, 0.0)
	var offsets := {}
	for joint in ["head", "hand_a", "hand_b"]:
		offsets[joint] = _joint_visual_offset(joint, 1.25 if mode == Mode.HIT_REACT else 0.4).rotated(-global_rotation)
	return ACTOR_ART.human_pixels(visual_role, global_rotation + upper_rotation, hands, offsets)

func _draw_human_standing(collapse := 0.0) -> void:
	var body_ground := _joint_visual_offset("chest", 1.6 if mode == Mode.HIT_REACT else 0.7)
	body_ground += upper_offset.rotated(global_rotation).limit_length(2.0)
	body_ground += facing_direction * collapse * 2.0
	body_ground = body_ground.round()
	if should_draw_legs() and not external_legs:
		_draw_directional_feet(body_ground, Color("090909"), Color("555555"))
	_draw_art_pixels(get_live_art_pixels(), body_ground)

func _standing_hand_positions(body_center: Vector2, forward: Vector2, side: Vector2, collapse: float) -> Array[Vector2]:
	var reach := (1.5 * action_amount if action in ["attack", "execute"] else 0.0) - weapon_recoil_pulse * 1.25
	var first := Vector2(5.3 + reach, 2.8)
	var second := Vector2(8.0 + reach, -1.5)
	if weapon_stance == "handgun":
		second = Vector2(6.0 + reach, -1.5)
	elif weapon_stance in ["shotgun", "sniper", "lmg"]:
		second = Vector2(10.0 + reach, -1.5)
	if weapon_stance in ["bat", "knife", "melee"]:
		first = Vector2(6.0 + reach, 3.0)
		second = Vector2(2.5, -4.0)
	elif weapon_stance == "cleanup":
		first = Vector2(5.0 + reach, 2.8)
		second = Vector2(3.5, -3.0)
	if action == "reload":
		# Presentation only: never rotate the ballistic carrier. The support
		# hand leaves the fore-end, retrieves ammunition, then returns to grip.
		var t := clampf(action_amount, 0.0, 1.0)
		var release := smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.7, 1.0, t))
		second = second.lerp(Vector2(-2.0, -5.0), release)
		first += Vector2(-1.0, 1.0) * release
	if weapon_pose_supplied and weapon_stance not in ["bat", "knife", "melee", "hound", "fist"]:
		# Match the gun's rendered pivot, not its collision/muzzle transform.
		if action == "reload":
			var feed_weight := smoothstep(0.12, 0.2, action_amount) * (1.0 - smoothstep(0.7, 0.9, action_amount))
			second = second.lerp(Vector2(5, -1) + weapon_feed_offset, feed_weight)
		first = Vector2(3, 0) + (first - Vector2(3, 0)).rotated(weapon_pose_angle) + weapon_pose_offset
		second = Vector2(3, 0) + (second - Vector2(3, 0)).rotated(weapon_pose_angle) + weapon_pose_offset
	first.x += collapse * 2.0
	second.x += collapse * 2.0
	return [body_center + forward * first.x + side * first.y, body_center + forward * second.x + side * second.y]

func _draw_art_pixels(cells: Dictionary, offset := Vector2.ZERO) -> void:
	for cell: Vector2 in cells:
		PIXEL_PAINTER.pixel(self, cell + offset, _feedback_color(cells[cell].color, 0.38))

func _draw_directional_feet(body_ground: Vector2, ink: Color, fill: Color) -> void:
	var move_forward := world_velocity.normalized() if world_velocity.length_squared() > 0.5 else facing_direction
	var move_side := Vector2(-move_forward.y, move_forward.x)
	var step := _four_frame_step() * 1.7
	for sign_value in [-1.0, 1.0]:
		var foot: Vector2 = body_ground - move_forward * (3.0 + step * float(sign_value)) + move_side * 2.0 * float(sign_value)
		_draw_block(foot, Vector2(3, 2), ink)
		PIXEL_PAINTER.pixel(self, foot.round(), fill)

func _four_frame_step() -> float:
	var frame := wrapi(floori(stride_phase * 0.9), 0, 4)
	return [-1.0, 0.0, 1.0, 0.0][frame]

func _draw_human_prone() -> void:
	var colors := ACTOR_ART.palette(visual_role)
	# The released rig exposes full articulated limbs. Sleeves run to the wrists;
	# short palm patches and shoes finish the chain without skin-coloured rods.
	for suffix in ["a", "b"]:
		_draw_segment("pelvis", "knee_" + suffix, colors.b, 2)
		_draw_segment("knee_" + suffix, "foot_" + suffix, colors.b, 2)
		_draw_segment("chest", "elbow_" + suffix, colors.u, 2)
		_draw_segment("elbow_" + suffix, "hand_" + suffix, colors.u, 1)
		_draw_block((points["hand_" + suffix].position as Vector2).rotated(global_rotation), Vector2(2, 2), colors.h)
	_draw_segment("pelvis", "chest", colors.c, 4)
	var head := (points.head.position as Vector2).rotated(global_rotation).round()
	var cells := {}
	ACTOR_ART._stamp(cells, ACTOR_ART.MASK if visual_role == "player" else ACTOR_ART.CROWN, Vector2.ZERO, colors, "head")
	_draw_art_pixels(ACTOR_ART.rotate_pixels(cells, global_rotation), head)

func _draw_hound_standing(collapse := 0.0) -> void:
	var center := _joint_visual_offset("chest", 1.5 if mode == Mode.HIT_REACT else 0.7)
	center += facing_direction * collapse * 2.0
	_draw_art_pixels(get_live_art_pixels(), center.round())

func _draw_hound_prone() -> void:
	var colors := ACTOR_ART.palette("hound")
	for suffix in ["a", "b"]:
		_draw_segment("chest", "front_knee_" + suffix, colors.c, 1)
		_draw_segment("front_knee_" + suffix, "front_paw_" + suffix, colors.g, 1)
		_draw_segment("pelvis", "rear_knee_" + suffix, colors.c, 1)
		_draw_segment("rear_knee_" + suffix, "rear_paw_" + suffix, colors.g, 1)
	_draw_segment("pelvis", "chest", colors.c, 4)
	_draw_segment("chest", "neck", colors.c, 3)
	_draw_segment("neck", "head", colors.g, 2)
	var cells := {}
	ACTOR_ART._stamp(cells, ACTOR_ART.HOUND_HEAD, Vector2.ZERO, colors, "head")
	_draw_art_pixels(ACTOR_ART.rotate_pixels(cells, global_rotation), (points.head.position as Vector2).rotated(global_rotation).round())

func _otxo_cloth_color() -> Color:
	return ACTOR_ART.palette(visual_role).c

func _otxo_skin_color() -> Color:
	# The protagonist's white mask against a black coat remains readable at a
	# glance; enemies invert that value hierarchy with pale clothing and gray skin.
	return ACTOR_ART.palette(visual_role).p if visual_role == "player" else ACTOR_ART.palette(visual_role).h

func _otxo_role_marker_color() -> Color:
	match visual_role:
		"player": return Color("f7f7f2")
		"heavy": return Color("a8aaa7")
		"assault": return Color("dedfdb")
		"melee": return Color("f1f1ed")
		_: return Color("858986")

func _joint_visual_offset(joint_name: String, maximum: float) -> Vector2:
	if not points.has(joint_name): return Vector2.ZERO
	var point: Dictionary = points[joint_name]
	var local_delta: Vector2 = (point.position as Vector2) - (point.target as Vector2)
	# Living physics is secondary motion only. It can sell impact and recoil, but
	# it may never pull a standing silhouette into a floor-hugging ragdoll pose.
	return local_delta.rotated(global_rotation).limit_length(maximum)

func _draw_pixel_disc(center: Vector2, radius: int, outline: Color, fill: Color) -> void:
	var snapped := _snap(center)
	PIXEL_PAINTER.circle(self, snapped, radius, outline)
	if radius <= 1: PIXEL_PAINTER.pixel(self, snapped, fill)
	else: PIXEL_PAINTER.circle(self, snapped, radius - 1, fill)

func _draw_block(center: Vector2, size: Vector2, color: Color, pattern: StringName = &"fabric") -> void:
	var snapped_size := Vector2(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	var origin := _snap(center) - (snapped_size / 2.0).floor()
	PIXEL_PAINTER.rect(self, Rect2(origin, snapped_size), color)

func should_draw_legs() -> bool:
	return movement_ratio > 0.12 and mode != Mode.KNOCKED_DOWN

func _project_height(ground_point: Vector2, height: float) -> Vector2:
	# Parent rotation expresses aim on the floor. Height must remain screen-up,
	# so counter-rotate the elevation vector before the parent's transform.
	return _snap(ground_point + _screen_offset(Vector2(0, -height)))

func _screen_offset(screen_space_offset: Vector2) -> Vector2:
	return screen_space_offset.rotated(-global_rotation)

func _draw_segment(a_name: String, b_name: String, color: Color, width: int) -> void:
	var start := _snap((points[a_name].position as Vector2).rotated(global_rotation))
	var finish := _snap((points[b_name].position as Vector2).rotated(global_rotation))
	_draw_pixel_line(start, finish, Color("090909"), width + 2)
	_draw_pixel_line(start, finish, color, width)

func _draw_pixel_line(start: Vector2, finish: Vector2, color: Color, width: int) -> void:
	PIXEL_PAINTER.line(self, _snap(start), _snap(finish), color, maxi(1, width))

func _snap(value: Vector2) -> Vector2:
	return Vector2(roundi(value.x), roundi(value.y))
