class_name LifecyclePhysicsRig2D
extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

# A controlled Verlet skeleton is present for the actor's entire lifetime.
# Locomotion supplies targets, impacts displace individual joints, knockdown
# releases the targets, and recovery blends the same points back to animation.
enum Mode { ACTIVE, HIT_REACT, KNOCKED_DOWN, RECOVERING }

const FIXED_STEP := 1.0 / 60.0

@export_enum("player", "enemy", "hound") var rig_kind := "enemy"
@export var body_color := Color("7c235b")
@export var accent_color := Color("f23d78")
@export var skin_color := Color("e1a07f")
@export var visual_role := "gunner"

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

const DIRECTION_STEP := PI / 4.0
const DIRECTION_HYSTERESIS := deg_to_rad(6.0)
const KNOCKDOWN_TRANSITION_DURATION := 0.12

func _ready() -> void:
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
	weapon_recoil_pulse = maxf(0.0, weapon_recoil_pulse - delta * 14.0)
	knockdown_transition_time = maxf(0.0, knockdown_transition_time - delta)
	if mode == Mode.HIT_REACT:
		hit_react_time = maxf(0.0, hit_react_time - delta)
		if hit_react_time <= 0.0: mode = Mode.ACTIVE
	elif mode == Mode.RECOVERING:
		recovery_progress = minf(1.0, recovery_progress + delta / 0.42)
		if recovery_progress >= 1.0: mode = Mode.ACTIVE
	_update_targets()
	accumulator += minf(delta, 0.05)
	while accumulator >= FIXED_STEP:
		_simulate_step(FIXED_STEP)
		accumulator -= FIXED_STEP
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

func _update_facing_sector() -> void:
	var angle := wrapf(global_rotation, -PI, PI)
	var center := float(facing_sector) * DIRECTION_STEP
	if absf(angle_difference(center, angle)) > DIRECTION_STEP * 0.5 + DIRECTION_HYSTERESIS:
		facing_sector = wrapi(roundi(angle / DIRECTION_STEP), 0, 8)
	facing_direction = Vector2.RIGHT.rotated(float(facing_sector) * DIRECTION_STEP)

func get_pose_snapshot() -> Dictionary:
	var snapshot := {}
	for name in points:
		snapshot[name] = (points[name].position as Vector2)
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
	for iteration in range(4):
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
	if mode == Mode.KNOCKED_DOWN and knockdown_transition_time <= 0.0:
		if rig_kind == "hound": _draw_hound_prone()
		else: _draw_human_prone()
		return
	# Living actors use authored eight-way screen-space silhouettes. The physics
	# rig remains underneath as secondary motion, but arbitrary aim angles can no
	# longer rotate one pixel drawing into unstable, unreadable "mixels".
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	var collapse := 0.0
	if mode == Mode.KNOCKED_DOWN:
		collapse = 1.0 - knockdown_transition_time / KNOCKDOWN_TRANSITION_DURATION
	elif mode == Mode.RECOVERING:
		collapse = 1.0 - smoothstep(0.0, 1.0, recovery_progress)
	if rig_kind == "hound": _draw_hound_standing(collapse)
	else: _draw_human_standing(collapse)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_human_standing(collapse := 0.0) -> void:
	# Eight separately composed directions: aim controls the silhouette while
	# movement independently controls the feet. This is a pixel "skin" over the
	# same physical joints used by hit reactions, knockdowns and corpses.
	var cloth := body_color.lerp(Color.WHITE, flash_amount * 0.42)
	var ink := Color("17141b")
	var hair := Color("35202b")
	var forward := facing_direction
	var side := Vector2(-forward.y, forward.x)
	var physics_offset := _joint_visual_offset("chest", 1.6 if mode == Mode.HIT_REACT else 0.8)
	var animation_offset := upper_offset.rotated(global_rotation).limit_length(2.5)
	var body_ground := _snap(physics_offset + animation_offset + Vector2(0, collapse * 2.0))
	var movement_lift := roundf(absf(sin(stride_phase * 2.0)) * movement_ratio)
	var idle_breath := -1.0 if movement_ratio < 0.08 and sin(idle_time * TAU / 1.65) > 0.82 else 0.0
	var body_center := _snap(body_ground + Vector2(0, -2.0 - movement_lift * 0.35 + collapse * 2.0))
	var heavy := visual_role == "heavy"
	var shoulder_span := 4.0 if heavy else 3.0
	var torso_width := 9 if heavy else 7
	var torso_back := body_center - forward * (2.2 if heavy else 1.8)
	var torso_front := body_center + forward * 1.8
	# The shadow is authored in the ground plane and never rotates or rises.
	_draw_pixel_line(body_ground - forward * 3.0 + Vector2(1, 2), body_ground + forward * 3.0 + Vector2(1, 2), Color(0.04, 0.025, 0.06, 0.42), 6 if heavy else 5)
	if should_draw_legs():
		_draw_directional_feet(body_ground, ink, cloth.darkened(0.46))
	var hands := _standing_hand_positions(body_center, forward, side, collapse)
	var hands_behind := forward.y < -0.35
	if hands_behind: _draw_rear_human_hands(body_center, hands, cloth.darkened(0.08), ink)
	# Shoulders are two readable masses, joined by a short torso spine. Diagonal
	# directions are deliberately asymmetric instead of rotating a square sprite.
	if hands_behind:
		_draw_rear_human_torso(body_center, forward, cloth, ink, torso_width)
	else:
		_draw_pixel_line(torso_back, torso_front, ink, torso_width + 2)
		_draw_pixel_line(torso_back, torso_front, cloth, torso_width)
	var shoulder_swing := _four_frame_step() * movement_ratio * 0.65
	var shoulder_a := body_center + side * shoulder_span + forward * shoulder_swing
	var shoulder_b := body_center - side * shoulder_span - forward * shoulder_swing
	if not hands_behind:
		_draw_pixel_line(body_center + side * 1.5, shoulder_a, ink, 4)
		_draw_pixel_line(body_center + side * 1.5, shoulder_a, cloth.lightened(0.05), 2)
		_draw_pixel_line(body_center - side * 1.5, shoulder_b, ink, 4)
		_draw_pixel_line(body_center - side * 1.5, shoulder_b, cloth.darkened(0.08), 2)
	elif absf(forward.x) < 0.25:
		# Straight north uses two short shoulder masses, never one continuous bar.
		# The head/nape occupies the center gap, so the silhouette reads as a person
		# instead of a rectangle pasted across the back.
		for sign_value in [-1.0, 1.0]:
			var rear_shoulder := body_center + side * (shoulder_span + 0.4) * float(sign_value) - forward * 0.2
			_draw_block(rear_shoulder, Vector2(3, 3), ink)
			_draw_block(rear_shoulder, Vector2(2, 2), cloth.darkened(0.05 if sign_value > 0.0 else 0.12))
	# Back-facing player clothing is already unique. Omitting the cyan identity tab
	# prevents a one-by-two marker from reading as another unexplained rectangle.
	if not (hands_behind and visual_role == "player"):
		_draw_role_marking(body_center, forward, side)
	if not hands_behind: _draw_human_arms(body_center, hands, cloth, ink)
	# Head height is always screen-up, while its ground anchor shifts toward the
	# selected facing sector. Hair and the one-pixel face cue make all eight views
	# recognizable without rendering a side-view face.
	var head := _snap(body_center + forward * 2.2 + Vector2(0, -4.0 + idle_breath + collapse * 3.0))
	if hands_behind:
		# A back-facing head is hair-dominant. Tiny ears and a nape provide human
		# anatomy without placing face-colored circles or UI-like marks on the back.
		_draw_pixel_disc(head, 4 if heavy else 3, ink, hair.lightened(0.06))
		_draw_block(head + side * (4.0 if heavy else 3.0), Vector2(1, 2), skin_color.darkened(0.06))
		_draw_block(head - side * (4.0 if heavy else 3.0), Vector2(1, 2), skin_color.darkened(0.06))
		_draw_block(head - forward * 2.5, Vector2(2, 1), skin_color.darkened(0.12))
		_draw_pixel_line(head - forward * 1.0 - side * 1.0, head - forward * 1.0 + side * 1.0, hair.lightened(0.18), 1)
	else:
		_draw_pixel_disc(head, 4 if heavy else 3, ink, skin_color.lerp(Color.WHITE, flash_amount * 0.35))
		var crown := head - forward * 2.0
		_draw_pixel_line(crown - side * 2.0, crown + side * 2.0, hair, 2)
		_draw_block(head + forward * 2.5, Vector2(2, 1), skin_color.lightened(0.18))

func _standing_hand_positions(body_center: Vector2, forward: Vector2, side: Vector2, collapse: float) -> Array[Vector2]:
	var reach := 1.5 * action_amount
	var hand_a: Vector2
	var hand_b: Vector2
	match weapon_stance:
		"gun":
			# When aiming screen-up, the head occupies the same projected pixels as
			# the ordinary grip. Pull the elbows slightly back and widen the hands so
			# both remain readable beside the back of the head instead of vanishing.
			var away_factor := clampf(-forward.y, 0.0, 1.0)
			var grip_reach := 4.4 - away_factor * 0.7 + reach - weapon_recoil_pulse * 2.0
			var grip := body_center + forward * grip_reach
			var lateral_grip := 1.3 + away_factor * 0.9
			hand_a = grip + side * lateral_grip
			hand_b = grip - side * lateral_grip
		"bat", "knife", "melee":
			hand_a = body_center + forward * (4.5 + reach) + side * 2.1
			hand_b = body_center + forward * 1.8 - side * 2.7
		"cleanup":
			hand_a = body_center + forward * (3.8 + reach) + side * 2.3
			hand_b = body_center + forward * 2.4 - side * 2.3
		_:
			hand_a = body_center + forward * (2.8 + reach) + side * 3.0
			hand_b = body_center + forward * (2.8 + reach) - side * 3.0
	var away_hand_drop := clampf(-forward.y, 0.0, 1.0) * 1.2 if weapon_stance == "gun" else 0.0
	hand_a += Vector2(0, -2.0 + away_hand_drop + collapse * 4.0)
	hand_b += Vector2(0, -2.0 + away_hand_drop + collapse * 4.0)
	return [hand_a, hand_b]

func _draw_human_arms(body_center: Vector2, hands: Array[Vector2], cloth: Color, ink: Color) -> void:
	var side := Vector2(-facing_direction.y, facing_direction.x)
	var swing := _four_frame_step() * movement_ratio * 0.65
	var shoulder_a := body_center + side * 3.0 + facing_direction * swing
	var shoulder_b := body_center - side * 3.0 - facing_direction * swing
	_draw_pixel_line(shoulder_a, hands[0], ink, 3)
	_draw_pixel_line(shoulder_a, hands[0], cloth, 1)
	_draw_pixel_line(shoulder_b, hands[1], ink, 3)
	_draw_pixel_line(shoulder_b, hands[1], cloth.darkened(0.08), 1)
	var hand_color := skin_color.lerp(Color.WHITE, flash_amount * 0.3)
	_draw_block(hands[0], Vector2(4, 3), ink)
	_draw_block(hands[0], Vector2(2, 2), hand_color)
	_draw_block(hands[1], Vector2(4, 3), ink)
	_draw_block(hands[1], Vector2(2, 2), hand_color)

func _draw_rear_human_hands(body_center: Vector2, hands: Array[Vector2], cloth: Color, ink: Color) -> void:
	var forward := facing_direction
	var side := Vector2(-forward.y, forward.x)
	var hand_color := skin_color.lerp(Color.WHITE, flash_amount * 0.24)
	if absf(forward.x) < 0.25:
		# Straight north: only two one-pixel skin cues escape the silhouette. Full
		# pale sleeves looked like circular or rectangular symbols on the back.
		for sign_value in [-1.0, 1.0]:
			var hand: Vector2 = body_center + forward * 2.3 + side * 4.1 * float(sign_value) + Vector2(0, -0.2)
			_draw_block(hand, Vector2(2, 2), ink)
			_draw_block(hand, Vector2(1, 1), hand_color)
		return
	# Rear diagonals: only the screen-near hand escapes the silhouette. The far
	# hand is naturally occluded by the back/head instead of becoming a chest icon.
	var near_index := 0 if hands[0].y > hands[1].y else 1
	var near_sign := 1.0 if near_index == 0 else -1.0
	var near_hand := body_center + forward * 2.6 + side * 3.8 * near_sign + Vector2(0, -0.2)
	_draw_block(near_hand, Vector2(2, 2), ink)
	_draw_block(near_hand, Vector2(1, 1), hand_color)

func _draw_rear_human_torso(body_center: Vector2, forward: Vector2, cloth: Color, ink: Color, torso_width: int) -> void:
	# Back-facing bodies need an anatomical taper, not the equal-width capsule used
	# by front/side poses. A broad upper back and a narrower waist remain one clean
	# clothing silhouette, with no emblem or geometric patch drawn over the center.
	if absf(forward.x) < 0.25:
		# Straight north is authored as a compact stepped silhouette. Using thick
		# lines here inflated their square brushes into one tall rectangular slab.
		_draw_block(body_center, Vector2(torso_width + 2, 5), ink)
		_draw_block(body_center + Vector2(0, -0.5), Vector2(torso_width, 3), cloth)
		_draw_block(body_center + Vector2(0, 2.5), Vector2(maxi(5, torso_width - 2), 3), ink)
		_draw_block(body_center + Vector2(0, 2.5), Vector2(maxi(3, torso_width - 4), 2), cloth.darkened(0.05))
		return
	var upper_start := body_center + forward * 1.15
	var upper_end := body_center - forward * 0.55
	var waist_start := body_center - forward * 0.35
	var waist_end := body_center - forward * 2.35
	_draw_pixel_line(upper_start, upper_end, ink, torso_width + 2)
	_draw_pixel_line(upper_start, upper_end, cloth, torso_width)
	_draw_pixel_line(waist_start, waist_end, ink, torso_width)
	_draw_pixel_line(waist_start, waist_end, cloth.darkened(0.05), maxi(3, torso_width - 2))

func _draw_directional_feet(body_ground: Vector2, ink: Color, fill: Color) -> void:
	var move_forward := world_velocity.normalized() if world_velocity.length_squared() > 0.5 else facing_direction
	var move_side := Vector2(-move_forward.y, move_forward.x)
	var step := _four_frame_step() * 1.7
	var foot_a := body_ground - move_forward * 3.0 + move_side * 2.0 + move_forward * step
	var foot_b := body_ground - move_forward * 3.0 - move_side * 2.0 - move_forward * step
	_draw_block(foot_a, Vector2(4, 3), ink)
	_draw_block(foot_a, Vector2(2, 2), fill)
	_draw_block(foot_b, Vector2(4, 3), ink)
	_draw_block(foot_b, Vector2(2, 2), fill)

func _four_frame_step() -> float:
	var frame := wrapi(floori(stride_phase * 0.9), 0, 4)
	return [-1.0, 0.0, 1.0, 0.0][frame]

func _draw_role_marking(center: Vector2, forward: Vector2, side: Vector2) -> void:
	match visual_role:
		# Keep the player identifier off the torso center. A centered cyan stripe
		# intersected the pale vertical body pixels in NW/N/NE poses and read as a
		# false circular chest joint. One shoulder tab stays recognizable without
		# inventing anatomy.
		"player": _draw_block(center + side * 3.4 - forward * 0.5, Vector2(1, 2), accent_color)
		"heavy":
			_draw_block(center + side * 4.0, Vector2(2, 3), accent_color.darkened(0.08))
			_draw_block(center - side * 4.0, Vector2(2, 3), accent_color.darkened(0.08))
		"assault":
			_draw_block(center + forward * 2.0 + side * 2.0, Vector2(2, 2), accent_color)
			_draw_block(center + forward * 2.0 - side * 2.0, Vector2(2, 2), accent_color)
		"melee": _draw_pixel_line(center, center + forward * 3.0 + side * 2.0, accent_color, 2)
		_: _draw_pixel_line(center - side * 2.0, center + side * 2.0, accent_color.darkened(0.08), 1)

func _draw_human_prone() -> void:
	var cloth := body_color.lerp(Color.WHITE, flash_amount * 0.42)
	_draw_segment("pelvis", "chest", cloth, 5)
	_draw_segment("chest", "head", cloth.lightened(0.08), 3)
	_draw_segment("chest", "elbow_a", cloth.darkened(0.16), 2); _draw_segment("elbow_a", "hand_a", skin_color, 2)
	_draw_segment("chest", "elbow_b", cloth.lightened(0.06), 2); _draw_segment("elbow_b", "hand_b", skin_color, 2)
	_draw_segment("pelvis", "knee_a", cloth.darkened(0.52), 3); _draw_segment("knee_a", "foot_a", Color("17141b"), 3)
	_draw_segment("pelvis", "knee_b", cloth.darkened(0.52), 3); _draw_segment("knee_b", "foot_b", Color("17141b"), 3)
	var head := _snap(points.head.position)
	_draw_block(head, Vector2(7, 7), Color("17141b"), &"grain")
	_draw_block(head, Vector2(4, 5), skin_color.lerp(Color.WHITE, flash_amount * 0.35), &"grain")
	_draw_block(head + Vector2(1, -1), Vector2(1, 2), Color("35202b"), &"grain")
	_draw_block(_snap(points.chest.position) + Vector2(0, -4), Vector2(4, 1), accent_color, &"fabric")

func _draw_hound_standing(collapse := 0.0) -> void:
	var fur := body_color.lerp(Color.WHITE, flash_amount * 0.38)
	var ink := Color("17141b")
	var forward := facing_direction
	var side := Vector2(-forward.y, forward.x)
	var physics_offset := _joint_visual_offset("chest", 1.5 if mode == Mode.HIT_REACT else 0.7)
	var ground_center := _snap(physics_offset + Vector2(0, collapse * 2.0))
	var center := _snap(ground_center + Vector2(0, -1.5 + collapse * 2.0))
	_draw_pixel_line(ground_center - forward * 5.0 + Vector2(1, 2), ground_center + forward * 4.0 + Vector2(1, 2), Color(0.04, 0.025, 0.06, 0.40), 5)
	var tail_root := center - forward * 3.8
	var tail_side := 1.0 if facing_sector % 2 == 0 else -1.0
	var tail_tip := center - forward * 6.2 + side * 2.0 * tail_side
	_draw_pixel_line(tail_root, tail_tip, ink, 3)
	_draw_pixel_line(tail_root, tail_tip, fur.darkened(0.08), 1)
	if should_draw_legs():
		var step := _four_frame_step() * 1.5
		for paw_data in [
			[center + forward * (2.5 + step) + side * 3.0, 0],
			[center + forward * (2.5 - step) - side * 3.0, 0],
			[center - forward * (3.5 + step) + side * 3.0, 0],
			[center - forward * (3.5 - step) - side * 3.0, 0],
		]:
			_draw_pixel_disc(paw_data[0], 1, ink, fur.lightened(0.12))
	else:
		# Two tucked contact pixels keep an idle hound readable as an animal rather
		# than a narrow vertical prop, without exposing a human-like full leg span.
		_draw_block(center - forward * 1.0 + side * 3.0, Vector2(1, 1), fur.lightened(0.18))
		_draw_block(center - forward * 1.0 - side * 3.0, Vector2(1, 1), fur.lightened(0.18))
	_draw_pixel_line(center - forward * 4.0, center + forward * 3.0, ink, 7)
	_draw_pixel_line(center - forward * 4.0, center + forward * 3.0, fur, 5)
	var head := _snap(center + forward * 5.0 + Vector2(0, -3.0 + collapse * 3.0))
	_draw_pixel_disc(head, 3, ink, fur.lightened(0.12))
	# Ears and muzzle are directional landmarks, not a rotated side-view dog.
	_draw_block(head - forward * 1.5 + side * 3.0, Vector2(2, 2), ink)
	_draw_block(head - forward * 1.5 - side * 3.0, Vector2(2, 2), ink)
	_draw_block(head + forward * 3.0, Vector2(2, 2), Color("e8d8c8"))
	_draw_block(head + forward * 3.5, Vector2(1, 1), Color("17141b"))

func _draw_hound_prone() -> void:
	var fur := body_color.lerp(Color.WHITE, flash_amount * 0.38)
	_draw_segment("pelvis", "chest", fur, 5); _draw_segment("chest", "neck", fur.lightened(0.1), 4); _draw_segment("neck", "head", fur.lightened(0.1), 3)
	for suffix in ["a", "b"]:
		_draw_segment("chest", "front_knee_" + suffix, fur.darkened(0.08), 2)
		_draw_segment("front_knee_" + suffix, "front_paw_" + suffix, fur.lightened(0.08), 2)
		_draw_segment("pelvis", "rear_knee_" + suffix, fur.darkened(0.08), 2)
		_draw_segment("rear_knee_" + suffix, "rear_paw_" + suffix, fur.lightened(0.08), 2)
	var head := _snap(points.head.position)
	_draw_block(head, Vector2(6, 5), Color("17141b"), &"grain")
	_draw_block(head, Vector2(4, 3), fur.lightened(0.12), &"fabric")
	_draw_block(head + Vector2(2, 0), Vector2(2, 1), Color("e8d8c8"), &"grain")

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
	else: PIXEL_PAINTER.material_circle(self, snapped, radius - 1, fill, fill.lightened(0.14), fill.darkened(0.18), facing_sector * 17 + radius)

func _draw_block(center: Vector2, size: Vector2, color: Color, pattern: StringName = &"fabric") -> void:
	PIXEL_PAINTER.material_block(self, _snap(center), size, color, facing_sector * 19 + roundi(center.x) * 3 + roundi(center.y) * 5, pattern)

func should_draw_legs() -> bool:
	return movement_ratio > 0.12 and mode != Mode.KNOCKED_DOWN

func _project_height(ground_point: Vector2, height: float) -> Vector2:
	# Parent rotation expresses aim on the floor. Height must remain screen-up,
	# so counter-rotate the elevation vector before the parent's transform.
	return _snap(ground_point + _screen_offset(Vector2(0, -height)))

func _screen_offset(screen_space_offset: Vector2) -> Vector2:
	return screen_space_offset.rotated(-global_rotation)

func _draw_segment(a_name: String, b_name: String, color: Color, width: int) -> void:
	var start := _snap(points[a_name].position)
	var finish := _snap(points[b_name].position)
	_draw_pixel_line(start, finish, Color("17141b"), width + 2)
	_draw_pixel_line(start, finish, color, width)

func _draw_pixel_line(start: Vector2, finish: Vector2, color: Color, width: int) -> void:
	PIXEL_PAINTER.material_line(self, _snap(start), _snap(finish), color, maxi(1, width), facing_sector * 23 + width, &"fabric")

func _snap(value: Vector2) -> Vector2:
	return Vector2(roundi(value.x), roundi(value.y))
