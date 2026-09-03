extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String, shooter: CollisionObject2D)
signal clean_requested(world_position: Vector2, stroke_direction: Vector2, stroke_strength: float, stroke_start: Vector2, brush_radius: float, power_multiplier: float, stroke_quality: float)
signal cleaner_requested(world_position: Vector2)
signal died(source_position: Vector2)
signal execution_impact(world_position: Vector2, direction: Vector2, lethal: bool, execution_type: String)
signal melee_impact(target: CharacterBody2D, world_position: Vector2, direction: Vector2, melee_type: String, lethal: bool)
signal weapon_throw_requested(origin: Vector2, direction: Vector2, weapon_id: String, rounds: int)
signal extraction_requested
signal world_interaction_requested

const MELEE_TRAIL_SCENE := preload("res://scenes/effects/melee_trail.tscn")
const AIM_CONTROLLER := preload("res://scripts/controllers/aim_controller.gd")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const PIXEL_ACTOR_FRAMES := preload("res://utility/pixel_actor_texture_factory.gd")
const PLAYER_GUNS := [
	preload("res://resources/weapons/pistol.tres"),
	preload("res://resources/weapons/smg.tres"),
	preload("res://resources/weapons/lmg.tres"),
	preload("res://resources/weapons/shotgun.tres"),
]
const MELEE_DATA := {
	"fist": {"range": 12.0, "angle": 35.0, "windup": 0.03, "cooldown": 0.18, "duration": 0.06, "lethal": false, "color": Color("ffffff")},
	"knife": {"range": 16.0, "angle": 45.0, "windup": 0.02, "cooldown": 0.22, "duration": 0.05, "lethal": true, "color": Color("00ffff")},
	"bat": {"range": 28.0, "angle": 120.0, "windup": 0.08, "cooldown": 0.42, "duration": 0.12, "lethal": true, "color": Color("ff007f")},
}
const CLEANUP_TOOLS := ["mop", "evidence_bag", "body_bag", "pressure_washer"]

@onready var upper_body: Node2D = $UpperBody
@onready var legs_visual: PixelActorPart = $LegsVisual
@onready var body_sprite: Sprite2D = $UpperBody/BodySprite
@onready var lifecycle_rig = $LifecycleRig
@onready var melee_tip: Marker2D = $UpperBody/BodySprite/MeleeTip
@onready var melee_weapon_visual: Node2D = $UpperBody/BodySprite/MeleeWeaponVisual
@onready var gun = $UpperBody/Gun
@onready var melee_shape: CollisionShape2D = $MeleeArea/CollisionShape2D
var cleanup_mode := false
var is_executing := false
var execution_target: CharacterBody2D
var execution_pulse := 0.0
var equipped_mode := "gun"
var current_melee_type := "fist"
var melee_cooldown := 0.0
var is_melee_attacking := false
var melee_animation_generation := 0
var gun_index := 0
var owned_gun_indices: Array[int] = [0]
var cached_execution_target: CharacterBody2D
var execution_query_cooldown := 0.0
var current_cleanup_tool := "mop"
var dragged_corpse: Node2D
var dragged_restoration_prop: Node2D
var controls_enabled := true
var melee_input_buffer := 0.0
var execution_input_buffer := 0.0
var mop_saturation := 0.0
var visual_mop_saturation := 0.0
var ultraviolet_active := false
var ultraviolet_lamp_active := false
var ultraviolet_scan_time := 0.0
var ultraviolet_scan_cooldown := 0.0
var scan_button_was_down := false
var cleanup_stroke_cooldown := 0.0
var last_cleanup_cursor := Vector2.INF
var cleanup_flow := 0.0
var cleanup_flow_grace := 0.0
var cleanup_last_stroke_direction := Vector2.ZERO
var cleanup_stroke_quality := 0.0
var pressure_washer_distance := 24.0
var pressure_washer_stability := 0.0
var cleanup_sweep_sign := 1.0
var cleaner_charges := 6
var stride_time := 0.0
var cleanup_action_pulse := 0.0
var visual_aim_lag := 0.0
var previous_aim_angle := 0.0
var previous_move_velocity := Vector2.ZERO
var lifecycle_context_impact_frame := -1
var stop_pose_time := 0.0
var field_movement_multiplier := 1.0
var aim_intent_angle := 0.0
var actual_aim_angle := 0.0
var aim_target_world := Vector2.ZERO
var using_controller_aim := false
var last_controller_aim := Vector2.RIGHT
var aim_lane_point := Vector2.ZERO
var aim_lane_blocked := false
var aim_lane_has_target := false
var fire_input_buffer := 0.0
var reload_input_buffer := 0.0
var throw_input_buffer := 0.0
const ULTRAVIOLET_SCAN_DURATION := 0.8
const ULTRAVIOLET_SCAN_COOLDOWN := 1.65
const INPUT_BUFFER_DURATION := 0.14
const MOP_MAX_SATURATION := 18.0
const CLEANUP_REACH := 37.0
const CLEANUP_FLOW_GRACE := 0.42
const MOP_HEAD_REACH := 10.0

func _ready() -> void:
	super._ready()
	_ensure_gamepad_inputs()
	cleaner_charges = 6 + Progression.get_upgrade_level("cleaner") * 2
	gun.set_reserve_ammo("pistol", 24)
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	hit_received.connect(_on_hit_received)
	previous_aim_angle = rotation
	aim_intent_angle = rotation
	actual_aim_angle = rotation
	aim_target_world = global_position + Vector2.RIGHT.rotated(rotation) * 90.0
	# The authored sprite remains as an invisible animation carrier for weapon
	# anchors. The visible body is the constrained lifecycle skeleton.
	body_sprite.texture = PIXEL_ACTOR_FRAMES.get_frame("player")
	$FakeShadow.texture = body_sprite.texture
	legs_visual.visible = false
	body_sprite.self_modulate = Color(1, 1, 1, 0)
	$FakeShadow.visible = false
	lifecycle_rig.configure("player", Color("d8e2df"), Color("27c9ca"), "player")
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length_squared() > 0.01:
		using_controller_aim = false
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] and absf(event.axis_value) > 0.22:
		using_controller_aim = true

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		return
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	melee_input_buffer = maxf(0.0, melee_input_buffer - delta)
	execution_input_buffer = maxf(0.0, execution_input_buffer - delta)
	fire_input_buffer = maxf(0.0, fire_input_buffer - delta)
	reload_input_buffer = maxf(0.0, reload_input_buffer - delta)
	throw_input_buffer = maxf(0.0, throw_input_buffer - delta)
	execution_pulse = maxf(0.0, execution_pulse - delta)
	execution_query_cooldown -= delta
	ultraviolet_scan_time = maxf(0.0, ultraviolet_scan_time - delta)
	ultraviolet_scan_cooldown = maxf(0.0, ultraviolet_scan_cooldown - delta)
	cleanup_stroke_cooldown = maxf(0.0, cleanup_stroke_cooldown - delta)
	if not cleanup_mode or current_cleanup_tool != "pressure_washer" or not Input.is_action_pressed("shoot"):
		pressure_washer_stability = move_toward(pressure_washer_stability, 0.0, delta * 4.8)
	cleanup_flow_grace = maxf(0.0, cleanup_flow_grace - delta)
	if cleanup_mode and current_cleanup_tool == "mop" and cleanup_flow_grace <= 0.0:
		cleanup_flow = move_toward(cleanup_flow, 0.0, delta * 0.72)
	elif not cleanup_mode or current_cleanup_tool != "mop":
		cleanup_flow = move_toward(cleanup_flow, 0.0, delta * 1.8)
	cleanup_action_pulse = maxf(0.0, cleanup_action_pulse - delta)
	var mop_visual_target := get_mop_saturation_ratio()
	var previous_mop_visual := visual_mop_saturation
	visual_mop_saturation = move_toward(visual_mop_saturation, mop_visual_target, delta * (1.8 if mop_visual_target > visual_mop_saturation else 3.2))
	if not is_equal_approx(previous_mop_visual, visual_mop_saturation): queue_redraw()
	if execution_query_cooldown <= 0.0 and not is_executing and not cleanup_mode and not is_dead:
		execution_query_cooldown = 0.12
		cached_execution_target = _query_execution_target()
	if execution_pulse > 0.0: queue_redraw()
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		var death_velocity := velocity
		move_and_slide()
		push_contact_bodies(death_velocity)
		return
	if is_executing:
		velocity = Vector2.ZERO
		return
	if Input.is_action_just_pressed("execute"): execution_input_buffer = INPUT_BUFFER_DURATION
	if execution_input_buffer > 0.0:
		if attempt_ground_execution(): execution_input_buffer = 0.0
		if is_executing: return
	if Input.is_action_just_pressed("interact"):
		if cleanup_mode:
			if _is_inside_extraction_zone(): extraction_requested.emit()
			else: world_interaction_requested.emit()
		else:
			if not attempt_weapon_pickup(): world_interaction_requested.emit()
	if cleanup_mode: _handle_cleanup_tool_selection()
	ultraviolet_lamp_active = cleanup_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var scan_button_down := Input.is_key_pressed(KEY_TAB)
	if cleanup_mode and scan_button_down and not scan_button_was_down and ultraviolet_scan_cooldown <= 0.0:
		ultraviolet_scan_time = ULTRAVIOLET_SCAN_DURATION
		ultraviolet_scan_cooldown = ULTRAVIOLET_SCAN_COOLDOWN
	scan_button_was_down = scan_button_down
	var next_ultraviolet := cleanup_mode and (ultraviolet_lamp_active or ultraviolet_scan_time > 0.0)
	if next_ultraviolet != ultraviolet_active:
		ultraviolet_active = next_ultraviolet
		queue_redraw()
	elif ultraviolet_active:
		# The scan flash is time-driven and must redraw independently of cleaning input.
		queue_redraw()
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var hauling := is_instance_valid(dragged_corpse) or is_instance_valid(dragged_restoration_prop)
	var drag_multiplier := minf(0.94, 0.72 + Progression.get_upgrade_level("body_handling") * 0.07) if hauling else 1.0
	var executioner_mobility := 1.0 + Progression.get_specialization_level("executioner") * 0.03
	velocity = input_direction * move_speed * get_equipped_movement_multiplier() * drag_multiplier * executioner_mobility * field_movement_multiplier
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	_update_aim_solution(delta)
	_update_procedural_motion(delta)
	_handle_weapon_selection()
	if cleanup_mode: _handle_cleanup_stroke()
	if Input.is_action_just_pressed("shoot") and equipped_mode == "gun": fire_input_buffer = INPUT_BUFFER_DURATION
	var wants_to_fire: bool
	if equipped_mode == "gun":
		wants_to_fire = (gun.automatic and Input.is_action_pressed("shoot")) or fire_input_buffer > 0.0
	else:
		wants_to_fire = Input.is_action_just_pressed("shoot")
	if wants_to_fire and not cleanup_mode:
		if equipped_mode != "gun":
			if is_melee_attacking or melee_cooldown > 0.0: melee_input_buffer = INPUT_BUFFER_DURATION
			else: _start_melee_attack()
		else:
			if gun.try_fire(Vector2.RIGHT.rotated(actual_aim_angle)):
				fire_input_buffer = 0.0
			elif gun.ammo <= 0 and not gun.is_reloading:
				fire_input_buffer = 0.0
	if Input.is_action_just_pressed("reload"): reload_input_buffer = INPUT_BUFFER_DURATION
	if reload_input_buffer > 0.0 and not cleanup_mode and equipped_mode == "gun" and not gun.is_reloading and gun.ammo < gun.max_ammo:
		gun.reload()
		if gun.is_reloading: reload_input_buffer = 0.0
	if Input.is_action_just_pressed("throw_weapon"): throw_input_buffer = INPUT_BUFFER_DURATION
	if throw_input_buffer > 0.0 and throw_equipped_gun(Vector2.RIGHT.rotated(actual_aim_angle)):
		throw_input_buffer = 0.0

func _update_aim_solution(delta: float) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.24:
		using_controller_aim = true
		last_controller_aim = stick.normalized()
	if using_controller_aim:
		var assisted := AIM_CONTROLLER.resolve_controller_direction(self, last_controller_aim, Settings.aim_assist_strength)
		last_controller_aim = assisted
		aim_target_world = global_position + assisted * 90.0
	else:
		aim_target_world = get_global_mouse_position()
	var aim := aim_target_world - global_position
	if aim.length_squared() > 0.001:
		aim_intent_angle = aim.angle()
		var turn_response: float = gun.aim_follow_speed if equipped_mode == "gun" and gun.gun_data != null else 22.0
		actual_aim_angle = lerp_angle(actual_aim_angle, aim_intent_angle, 1.0 - exp(-turn_response * delta))
		rotation = actual_aim_angle
		previous_aim_angle = actual_aim_angle
	_update_aim_lane()

func _update_aim_lane() -> void:
	if cleanup_mode or equipped_mode != "gun" or not is_instance_valid(gun) or gun.gun_data == null:
		aim_lane_blocked = false
		aim_lane_has_target = false
		return
	var origin: Vector2 = gun.muzzle.global_position
	var distance := clampf(origin.distance_to(aim_target_world), 8.0, AIM_CONTROLLER.MAX_AIM_DISTANCE)
	var solution := AIM_CONTROLLER.solve_fire_lane(self, origin, Vector2.RIGHT.rotated(actual_aim_angle), distance)
	aim_lane_point = solution.point
	aim_lane_blocked = bool(solution.blocked) or gun.is_muzzle_blocked()
	var lane_target := solution.target as Node
	aim_lane_has_target = is_instance_valid(lane_target) and lane_target.is_in_group("enemy")
	queue_redraw()

func get_aim_world_position() -> Vector2:
	return aim_target_world

func get_aim_feedback() -> Dictionary:
	var feedback: Dictionary = gun.get_aim_feedback() if is_instance_valid(gun) else {}
	var canvas := get_viewport().get_canvas_transform()
	var cursor_screen: Vector2 = canvas * aim_target_world
	var aim_distance := clampf(global_position.distance_to(aim_target_world), 8.0, AIM_CONTROLLER.MAX_AIM_DISTANCE)
	var actual_world: Vector2 = gun.muzzle.global_position + Vector2.RIGHT.rotated(actual_aim_angle) * aim_distance if is_instance_valid(gun) else global_position
	var actual_screen: Vector2 = canvas * actual_world
	var world_spread := AIM_CONTROLLER.spread_radius_at_distance(float(feedback.get("spread_degrees", 0.0)), aim_distance)
	var screen_scale := maxf(0.1, canvas.x.length())
	feedback.merge({
		"cursor_position": cursor_screen,
		"actual_offset": actual_screen - cursor_screen,
		"spread_pixels": world_spread * screen_scale,
		"blocked": aim_lane_blocked,
		"targeted": aim_lane_has_target,
		"controller": using_controller_aim,
	}, true)
	return feedback

func _ensure_gamepad_inputs() -> void:
	_add_joy_motion("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_motion("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_motion("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_motion("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_motion("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button("reload", JOY_BUTTON_X)
	_add_joy_button("interact", JOY_BUTTON_A)
	_add_joy_button("execute", JOY_BUTTON_B)
	_add_joy_button("throw_weapon", JOY_BUTTON_RIGHT_SHOULDER)

func _add_joy_motion(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action, 0.22)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _add_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _update_procedural_motion(delta: float) -> void:
	var movement_ratio := clampf(velocity.length() / maxf(1.0, move_speed), 0.0, 1.2)
	var local_motion := velocity.rotated(-rotation)
	# LifecycleRig owns the visible legs. Avoid animating the hidden compatibility
	# sprite every frame; it otherwise rebuilds a draw list nobody can see.
	if legs_visual.visible:
		legs_visual.rotation = local_motion.angle() if local_motion.length_squared() > 0.5 else legs_visual.rotation
		legs_visual.update_pose(delta, local_motion, move_speed)
	if previous_move_velocity.length() > move_speed * 0.55 and velocity.length() < move_speed * 0.12:
		stop_pose_time = 0.11
	stop_pose_time = maxf(0.0, stop_pose_time - delta)
	previous_move_velocity = velocity
	stride_time += delta * lerpf(5.0, 13.0, movement_ratio)
	var target_bob := sin(stride_time * 2.0) * 0.65 * movement_ratio
	visual_aim_lag = lerpf(visual_aim_lag, 0.0, 1.0 - exp(-11.0 * delta))
	var upper_turn_target := 0.0 if equipped_mode == "gun" and not cleanup_mode else visual_aim_lag
	upper_body.rotation = lerp_angle(upper_body.rotation, upper_turn_target, 1.0 - exp(-18.0 * delta))
	var stop_lean := 1.5 * clampf(stop_pose_time / 0.11, 0.0, 1.0)
	upper_body.position.y = lerpf(upper_body.position.y, target_bob, 1.0 - exp(-14.0 * delta))
	upper_body.position.x = lerpf(upper_body.position.x, stop_lean, 1.0 - exp(-20.0 * delta))
	if not is_melee_attacking and not is_executing:
		var pose_rotation := 0.0
		var pose_position := Vector2.ZERO
		if gun.is_reloading and not cleanup_mode:
			pose_rotation = -0.18
			pose_position = Vector2(-1.5, 1.0)
		elif is_instance_valid(dragged_corpse) or is_instance_valid(dragged_restoration_prop):
			pose_rotation = -0.13
			pose_position = Vector2(-1.2, 0.8)
		elif cleanup_mode and cleanup_action_pulse > 0.0:
			var stroke_phase := 1.0 - cleanup_action_pulse / 0.13
			pose_rotation = sin(stroke_phase * PI) * (0.24 if current_cleanup_tool == "mop" else 0.12) * cleanup_sweep_sign
			pose_position = Vector2(2.0 * sin(stroke_phase * PI), 0.0)
		body_sprite.rotation = lerp_angle(body_sprite.rotation, pose_rotation, 1.0 - exp(-22.0 * delta))
		body_sprite.position = body_sprite.position.lerp(pose_position, 1.0 - exp(-22.0 * delta))
	if equipped_mode == "gun" and not is_melee_attacking:
		var reload_drop := Vector2(-2.0, 3.0) if gun.is_reloading else Vector2.ZERO
		gun.position = gun.position.lerp(reload_drop, 1.0 - exp(-18.0 * delta))
		var gun_pose := -0.42 if gun.is_reloading else sin(stride_time) * 0.025 * movement_ratio
		gun.rotation = lerpf(gun.rotation, gun_pose, 1.0 - exp(-14.0 * delta))
	else:
		gun.position = gun.position.lerp(Vector2.ZERO, 1.0 - exp(-18.0 * delta))
		gun.rotation = lerpf(gun.rotation, 0.0, 1.0 - exp(-14.0 * delta))
	var lifecycle_action := "idle"
	var lifecycle_amount := 0.0
	if is_melee_attacking: lifecycle_action = "attack"; lifecycle_amount = 1.0
	elif is_executing: lifecycle_action = "execute"; lifecycle_amount = 1.0
	elif cleanup_mode and cleanup_action_pulse > 0.0: lifecycle_action = "attack"; lifecycle_amount = clampf(cleanup_action_pulse / 0.13, 0.0, 1.0)
	var visual_stance := "cleanup" if cleanup_mode else ("gun" if equipped_mode == "gun" else current_melee_type)
	lifecycle_rig.set_weapon_stance(visual_stance)
	lifecycle_rig.update_lifecycle(delta, velocity.rotated(-rotation), move_speed, upper_body.position + body_sprite.position, upper_body.rotation + body_sprite.rotation, lifecycle_action, lifecycle_amount)
	# Only the weapon keeps continuous 360-degree aim. The body changes among
	# authored eight-way silhouettes, with correct front/back occlusion.
	upper_body.z_index = -1 if lifecycle_rig.weapon_should_render_behind() else 2

func _handle_weapon_selection() -> void:
	if cleanup_mode or is_executing or is_melee_attacking: return
	if Input.is_action_just_pressed("equip_gun"):
		if equipped_mode == "gun": _cycle_gun()
		elif not owned_gun_indices.is_empty(): _equip_weapon("gun")
	elif Input.is_action_just_pressed("equip_fist"): _equip_weapon("fist")
	elif Input.is_action_just_pressed("equip_knife"): _equip_weapon("knife")
	elif Input.is_action_just_pressed("equip_bat"): _equip_weapon("bat")

func configure_field_kit(kit: Dictionary) -> void:
	owned_gun_indices.clear()
	for index in kit.get("guns", [0]):
		var gun_slot := clampi(int(index), 0, PLAYER_GUNS.size() - 1)
		if gun_slot not in owned_gun_indices: owned_gun_indices.append(gun_slot)
	if owned_gun_indices.is_empty(): owned_gun_indices.append(0)
	# A field kit is a fresh mission issue, not an inventory restore. Initialize
	# every authorized weapon explicitly so an old zero-round cache can never
	# turn a newly selected briefing loadout into an empty gun.
	var reserve_magazines := maxi(0, int(kit.get("reserve_magazines", 1)))
	for slot in owned_gun_indices:
		var data: GunData = PLAYER_GUNS[slot]
		gun.set_weapon_ammo(data.weapon_id, data.ammo_capacity)
		gun.set_reserve_ammo(data.weapon_id, data.ammo_capacity * reserve_magazines)
	gun_index = owned_gun_indices[0]
	gun.set_gun_data(PLAYER_GUNS[gun_index], false)
	cleaner_charges = maxi(1, cleaner_charges + int(kit.get("cleaner_bonus", 0)))
	field_movement_multiplier = clampf(float(kit.get("move", 1.0)), 0.85, 1.12)
	gun.field_noise_multiplier = clampf(float(kit.get("noise", 1.0)), 0.4, 1.2)
	queue_redraw()

func _equip_weapon(mode: String) -> void:
	if mode == "gun" and owned_gun_indices.is_empty(): return
	equipped_mode = "gun" if mode == "gun" else "melee"
	if mode != "gun": current_melee_type = mode
	gun.visible = equipped_mode == "gun" and not cleanup_mode and not is_executing
	melee_weapon_visual.visible = equipped_mode == "melee" and not cleanup_mode and not is_executing
	if mode != "gun": melee_weapon_visual.set_weapon(current_melee_type)
	queue_redraw()

func _cycle_gun() -> void:
	if owned_gun_indices.is_empty(): return
	var owned_position := owned_gun_indices.find(gun_index)
	gun_index = owned_gun_indices[(owned_position + 1) % owned_gun_indices.size()]
	gun.set_gun_data(PLAYER_GUNS[gun_index], false)
	queue_redraw()

func acquire_gun(weapon_id: String, rounds: int) -> bool:
	var found_index := -1
	for index in range(PLAYER_GUNS.size()):
		if PLAYER_GUNS[index].weapon_id == weapon_id:
			found_index = index
			break
	if found_index < 0: return false
	if found_index not in owned_gun_indices: owned_gun_indices.append(found_index)
	if not gun.reserve_by_weapon.has(weapon_id): gun.set_reserve_ammo(weapon_id, 0)
	var capacity: int = int(PLAYER_GUNS[found_index].ammo_capacity)
	var current_rounds: int = int(gun.get_weapon_ammo(weapon_id))
	var magazine_rounds: int = mini(capacity, current_rounds + maxi(0, rounds))
	var overflow_rounds: int = maxi(0, current_rounds + maxi(0, rounds) - magazine_rounds)
	gun.set_weapon_ammo(weapon_id, magazine_rounds)
	if overflow_rounds > 0: gun.add_reserve_ammo(weapon_id, overflow_rounds)
	gun_index = found_index
	equipped_mode = "gun"
	gun.set_gun_data(PLAYER_GUNS[gun_index], false)
	gun.visible = true
	melee_weapon_visual.visible = false
	queue_redraw()
	return true

func _is_inside_extraction_zone() -> bool:
	for zone in get_tree().get_nodes_in_group("extraction_zone"):
		if zone.has_method("contains_position") and zone.contains_position(global_position): return true
	return false

func attempt_weapon_pickup() -> bool:
	if cleanup_mode or is_dead or is_executing: return false
	var nearest = get_nearby_weapon_pickup()
	return is_instance_valid(nearest) and nearest.collect(self)

func get_nearby_weapon_pickup() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := 18.0 * 18.0
	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		if not node is Node2D: continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance <= nearest_distance:
			nearest = node
			nearest_distance = distance
	return nearest

func get_equipped_weapon_name() -> String:
	return str(gun.gun_data.display_name) if equipped_mode == "gun" and gun.gun_data != null else current_melee_type.to_upper()

func get_equipped_movement_multiplier() -> float:
	if cleanup_mode or equipped_mode != "gun" or gun.gun_data == null: return 1.0
	return gun.reload_movement_multiplier if gun.is_reloading else gun.movement_speed_multiplier

func _handle_cleanup_tool_selection() -> void:
	if Input.is_action_just_pressed("equip_gun"): select_cleanup_tool("mop")
	elif Input.is_action_just_pressed("equip_fist"): select_cleanup_tool("pressure_washer")

func _handle_cleanup_stroke() -> void:
	var raw_cursor := get_global_mouse_position()
	var to_cursor := raw_cursor - global_position
	var cursor_distance := to_cursor.length()
	var washer := current_cleanup_tool == "pressure_washer"
	var cursor := get_cleanup_contact_position(raw_cursor)
	if washer: cursor_distance = minf(cursor_distance, CLEANUP_REACH)
	pressure_washer_distance = cursor_distance
	if last_cleanup_cursor == Vector2.INF: last_cleanup_cursor = cursor
	if not Input.is_action_pressed("shoot"):
		last_cleanup_cursor = cursor
		return
	var stroke := cursor - last_cleanup_cursor
	var stroke_length := stroke.length()
	if (not washer and stroke_length < 1.25) or cleanup_stroke_cooldown > 0.0: return
	cleanup_stroke_cooldown = 0.052 if washer else 0.065
	var stroke_direction := stroke.normalized() if stroke_length >= 0.35 else (to_cursor.normalized() if cursor_distance > 0.01 else Vector2.RIGHT.rotated(rotation))
	var continuity := 1.0
	if cleanup_last_stroke_direction.length_squared() > 0.01:
		continuity = clampf((cleanup_last_stroke_direction.dot(stroke_direction) + 1.0) * 0.5, 0.0, 1.0)
	if washer:
		cleanup_stroke_quality = 1.0
	else:
		# A deliberate 4-9 px sample is the one-pass sweet spot. Faster or slower
		# movement still cleans, but it will leave more visible density behind.
		var speed_quality := 1.0 - clampf(absf(stroke_length - 6.5) / 7.5, 0.0, 1.0)
		cleanup_stroke_quality = clampf(speed_quality * lerpf(0.82, 1.0, continuity), 0.42, 1.0)
	cleanup_sweep_sign = -1.0 if Vector2.RIGHT.rotated(rotation).cross(stroke_direction) < 0.0 else 1.0
	cleanup_action_pulse = 0.13
	queue_redraw()
	var profile := get_cleanup_stroke_profile(cursor_distance, cleanup_stroke_quality)
	clean_requested.emit(cursor, stroke_direction, float(profile.strength), last_cleanup_cursor, float(profile.radius), float(profile.power), cleanup_stroke_quality)
	cleanup_last_stroke_direction = stroke_direction
	last_cleanup_cursor = cursor

func get_cleanup_contact_position(raw_cursor: Vector2) -> Vector2:
	var to_cursor := raw_cursor - global_position
	var aim_direction := to_cursor.normalized() if to_cursor.length_squared() > 0.01 else Vector2.RIGHT.rotated(rotation)
	if current_cleanup_tool == "mop":
		# Cursor controls the handle angle only. Cleaning happens under the visible
		# mop head at a fixed physical reach from the player's hands.
		return global_position + Vector2.RIGHT.rotated(rotation) * MOP_HEAD_REACH
	if to_cursor.length() > CLEANUP_REACH: return global_position + aim_direction * CLEANUP_REACH
	return raw_cursor

func get_cleanup_stroke_profile(cursor_distance: float, quality := 1.0) -> Dictionary:
	if current_cleanup_tool == "pressure_washer":
		var distance_ratio := clampf((cursor_distance - 10.0) / 27.0, 0.0, 1.0)
		var washer_level := clampi(Progression.get_upgrade_level("pressure_washer"), 0, 3)
		var coverage_scale := lerpf(1.0, 1.2, distance_ratio) if washer_level >= 2 else 1.0
		return {
			"radius": lerpf(3.2, 8.0, distance_ratio) * coverage_scale,
			"power": lerpf(1.42, 0.68, distance_ratio),
			"strength": lerpf(1.22, 0.78, distance_ratio),
			"mode": "NARROW" if distance_ratio < 0.48 else "WIDE",
			"focus": 1.0 - distance_ratio,
		}
	var flow_bonus := cleanup_flow * 0.18
	var mop_level := clampi(Progression.get_upgrade_level("mop"), 0, 3)
	return {
		"radius": 4.0 + float(mop_level) * 0.35 + (0.45 if Progression.has_upgrade_perk("wide_finish") else 0.0) + floorf(cleanup_flow * 3.0) * 0.5,
		"power": lerpf(0.66, 1.12, clampf(quality, 0.0, 1.0)) + flow_bonus,
		"strength": lerpf(0.58, 1.12, clampf(quality, 0.0, 1.0)),
		"mode": "FLOW",
		"focus": cleanup_flow,
	}

func report_cleanup_stroke_result(cleaned: bool, quality: float, stroke_direction: Vector2) -> void:
	if current_cleanup_tool != "mop": return
	if not cleaned:
		cleanup_flow = move_toward(cleanup_flow, 0.0, 0.055)
		return
	var continuity := 1.0
	if cleanup_last_stroke_direction.length_squared() > 0.01 and stroke_direction.length_squared() > 0.01:
		continuity = clampf((cleanup_last_stroke_direction.dot(stroke_direction.normalized()) + 1.0) * 0.5, 0.0, 1.0)
	cleanup_flow = clampf(cleanup_flow + lerpf(0.045, 0.105, clampf(quality, 0.0, 1.0)) * lerpf(0.72, 1.0, continuity), 0.0, 1.0)
	cleanup_flow_grace = CLEANUP_FLOW_GRACE
	queue_redraw()

func get_cleanup_flow_ratio() -> float:
	return clampf(cleanup_flow, 0.0, 1.0)

func get_pressure_washer_mode() -> String:
	return str(get_cleanup_stroke_profile(pressure_washer_distance).mode)

func get_pressure_washer_focus() -> float:
	return float(get_cleanup_stroke_profile(pressure_washer_distance).focus)

func set_pressure_washer_stability(value: float) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_value, pressure_washer_stability): return
	pressure_washer_stability = next_value
	queue_redraw()

func get_pressure_washer_stability() -> float:
	return clampf(pressure_washer_stability, 0.0, 1.0)

func select_cleanup_tool(tool_name: String) -> bool:
	if tool_name not in CLEANUP_TOOLS: return false
	if current_cleanup_tool != tool_name:
		cleanup_flow = 0.0
		pressure_washer_stability = 0.0
		cleanup_flow_grace = 0.0
		cleanup_last_stroke_direction = Vector2.ZERO
		last_cleanup_cursor = Vector2.INF
	current_cleanup_tool = tool_name
	queue_redraw()
	return true

func add_reserve_ammo(weapon_id: String, rounds: int) -> bool:
	if rounds <= 0: return false
	gun.add_reserve_ammo(weapon_id, rounds)
	return true

func throw_equipped_gun(direction: Vector2) -> bool:
	if cleanup_mode or is_dead or is_executing or equipped_mode != "gun" or gun.gun_data == null or direction.length_squared() < 0.001: return false
	var thrown_weapon_id: String = gun.weapon_id
	var thrown_rounds: int = gun.ammo
	var thrown_index := gun_index
	owned_gun_indices.erase(thrown_index)
	gun.ammo_by_weapon.erase(thrown_weapon_id)
	weapon_throw_requested.emit(global_position + direction.normalized() * 9.0, direction.normalized(), thrown_weapon_id, thrown_rounds)
	if owned_gun_indices.is_empty():
		equipped_mode = "melee"
		current_melee_type = "fist"
		gun.visible = false
		melee_weapon_visual.visible = true
		melee_weapon_visual.set_weapon(current_melee_type)
		Events.publish_ammo(0, 0, false)
		gun.clear_equipped_weapon()
	else:
		gun_index = owned_gun_indices[0]
		gun.set_gun_data(PLAYER_GUNS[gun_index], false)
	queue_redraw()
	return true

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if enabled: return
	velocity = Vector2.ZERO
	melee_animation_generation += 1
	is_melee_attacking = false
	_reset_melee_pose()
	if is_instance_valid(dragged_corpse):
		dragged_corpse.end_drag(self)
		dragged_corpse = null
	if is_instance_valid(dragged_restoration_prop):
		dragged_restoration_prop.end_drag(self)
		dragged_restoration_prop = null

func get_cleanup_efficiency(cleanup_type: String) -> int:
	if current_cleanup_tool == "mop" and cleanup_type in ["blood", "blood_pool", "blood_footprint", "gore", "spill"]:
		var base_efficiency := 4 + Progression.get_upgrade_level("mop") + Progression.get_specialization_level("cleaner")
		return maxi(1, roundi(base_efficiency * lerpf(1.0, 0.6, get_mop_saturation_ratio())))
	if current_cleanup_tool == "pressure_washer" and cleanup_type in ["blood", "blood_pool", "blood_footprint", "spill"]: return 9 + Progression.get_upgrade_level("pressure_washer") * 2 + Progression.get_specialization_level("cleaner")
	if current_cleanup_tool == "evidence_bag" and cleanup_type in ["shell", "dropped_weapon", "debris"]: return 3
	if current_cleanup_tool == "body_bag" and cleanup_type == "corpse": return 1
	return 0

func get_nearby_draggable_corpse() -> Node2D:
	var nearest: Node2D
	var nearest_distance := 20.0 * 20.0
	for node in get_tree().get_nodes_in_group("corpse"):
		if not node is Node2D or not node.has_method("begin_drag"): continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance <= nearest_distance:
			nearest = node
			nearest_distance = distance
	return nearest

func attempt_corpse_drag() -> bool:
	if not cleanup_mode or is_dead: return false
	if is_instance_valid(dragged_restoration_prop): return false
	if is_instance_valid(dragged_corpse):
		dragged_corpse.end_drag(self)
		dragged_corpse = null
		return true
	var corpse := get_nearby_draggable_corpse()
	if not is_instance_valid(corpse) or not corpse.has_method("is_bagged") or not corpse.is_bagged() or not corpse.begin_drag(self): return false
	dragged_corpse = corpse
	return true

func get_nearby_restoration_prop() -> Node2D:
	var nearest: Node2D
	var nearest_distance := 20.0 * 20.0
	for node in get_tree().get_nodes_in_group("displaced_prop"):
		if not node is Node2D or not node.has_method("begin_drag"): continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance <= nearest_distance:
			nearest = node
			nearest_distance = distance
	return nearest

func attempt_restoration_prop_drag() -> bool:
	if not cleanup_mode or is_dead or is_instance_valid(dragged_corpse): return false
	if is_instance_valid(dragged_restoration_prop):
		dragged_restoration_prop.end_drag(self)
		dragged_restoration_prop = null
		return true
	var prop := get_nearby_restoration_prop()
	if not is_instance_valid(prop) or not prop.begin_drag(self): return false
	dragged_restoration_prop = prop
	return true

func clear_dragged_restoration_prop(prop: Node2D) -> void:
	if dragged_restoration_prop == prop: dragged_restoration_prop = null

func _start_melee_attack() -> void:
	if is_melee_attacking or melee_cooldown > 0.0 or is_dead or cleanup_mode: return
	var data: Dictionary = MELEE_DATA[current_melee_type]
	is_melee_attacking = true
	melee_cooldown = float(data.cooldown)
	_perform_melee_attack(data)

func _perform_melee_attack(data: Dictionary) -> void:
	melee_animation_generation += 1
	var generation := melee_animation_generation
	var windup_rotation := -0.20 if current_melee_type == "bat" else -0.05
	body_sprite.position = Vector2(-1.0, 0.0)
	body_sprite.rotation = windup_rotation * 0.35
	var windup_tween := create_tween().set_parallel(true)
	windup_tween.tween_property(body_sprite, "position", Vector2(-3.0, 0.0), float(data.windup)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	windup_tween.tween_property(body_sprite, "rotation", windup_rotation, float(data.windup)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(float(data.windup)).timeout
	if generation != melee_animation_generation or is_dead or cleanup_mode or equipped_mode == "gun":
		_reset_melee_pose()
		is_melee_attacking = false
		return
	var thrust_distance := 6.0 if current_melee_type == "bat" else 4.0
	var strike_rotation := 0.40 if current_melee_type == "bat" else 0.15
	var strike_tween := create_tween().set_parallel(true)
	strike_tween.tween_property(body_sprite, "position", Vector2(thrust_distance, 0.0), 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	strike_tween.tween_property(body_sprite, "rotation", strike_rotation, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	melee_tip.position = Vector2(6.0 if current_melee_type == "fist" else (8.0 if current_melee_type == "knife" else 10.0), 0.0)
	if melee_shape.shape is CircleShape2D:
		(melee_shape.shape as CircleShape2D).radius = float(data.range)
	melee_shape.position = Vector2(14.0, 0.0)
	var forward := Vector2.RIGHT.rotated(rotation)
	var half_angle := deg_to_rad(float(data.angle) * 0.5)
	var valid_targets: Array[CharacterBody2D] = []
	for body in MeleeController.query_bodies(self, melee_shape):
		if not body is CharacterBody2D or not body.is_in_group("enemy") or body.is_dead: continue
		if body.has_method("is_knocked_down") and body.is_knocked_down(): continue
		var offset: Vector2 = body.global_position - global_position
		if offset.length() > float(data.range) or absf(forward.angle_to(offset.normalized())) > half_angle: continue
		if MeleeController.blocked_by_geometry(self, body): continue
		valid_targets.append(body)
	valid_targets.sort_custom(func(a: CharacterBody2D, b: CharacterBody2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	var hit_limit: int = mini(3, valid_targets.size()) if current_melee_type == "bat" else mini(1, valid_targets.size())
	var prop_hit := false
	for body in MeleeController.query_bodies(self, melee_shape, 4):
		if not body is CollisionObject2D or not body.is_in_group("destructible_prop") or not body.has_method("take_damage"): continue
		var prop_offset: Vector2 = body.global_position - global_position
		if prop_offset.length() > float(data.range) or absf(forward.angle_to(prop_offset.normalized())) > half_angle: continue
		if MeleeController.blocked_by_geometry(self, body): continue
		if body.has_method("receive_melee_impact"):
			body.receive_melee_impact(forward, current_melee_type)
		else:
			body.take_damage(1, global_position)
		prop_hit = true
		if current_melee_type != "bat": break
	_spawn_melee_trail(data, hit_limit > 0 or prop_hit)
	for index in range(hit_limit):
		var target: CharacterBody2D = valid_targets[index]
		melee_impact.emit(target, target.global_position, forward, current_melee_type, bool(data.lethal))
	if hit_limit == 0 and not prop_hit:
		var miss_penalty := 0.08 if current_melee_type == "fist" else (0.12 if current_melee_type == "knife" else 0.18)
		melee_cooldown += miss_penalty
	else:
		var noise_radius := 48.0 if current_melee_type == "fist" else (62.0 if current_melee_type == "knife" else 90.0)
		Events.publish_combat_noise(global_position, noise_radius, "melee")
	await get_tree().create_timer(0.04).timeout
	if generation != melee_animation_generation:
		return
	var impact_recovery := 0.055 if hit_limit > 0 and current_melee_type == "bat" else (0.025 if hit_limit > 0 else 0.0)
	var recover_time := maxf(0.06, float(data.cooldown) - float(data.windup) - 0.04 + impact_recovery)
	var recover_tween := create_tween().set_parallel(true)
	recover_tween.tween_property(body_sprite, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	recover_tween.tween_property(body_sprite, "rotation", 0.0, recover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await recover_tween.finished
	if generation == melee_animation_generation:
		_reset_melee_pose()
		is_melee_attacking = false
		if melee_input_buffer > 0.0 and melee_cooldown <= 0.0:
			melee_input_buffer = 0.0
			call_deferred("_start_melee_attack")

func _reset_melee_pose() -> void:
	if is_instance_valid(body_sprite):
		body_sprite.position = Vector2.ZERO
		body_sprite.rotation = 0.0

func _spawn_melee_trail(data: Dictionary, connected_hit := false) -> void:
	var trail = MELEE_TRAIL_SCENE.instantiate()
	if not RuntimeBudget.try_add("transient_fx", trail, get_tree().current_scene): return
	trail.global_position = melee_tip.global_position
	trail.global_rotation = snappedf(melee_tip.global_rotation, PI / 8.0)
	var tip_distance := global_position.distance_to(melee_tip.global_position)
	var remaining_visual_reach := maxf(2.0, float(data.range) - tip_distance)
	trail.setup(current_melee_type, remaining_visual_reach, deg_to_rad(float(data.angle)), float(data.duration), data.color, connected_hit)

func get_shoe_contamination_ratio() -> float:
	if not has_node("BloodFootprintEmitter"): return 0.0
	return $BloodFootprintEmitter.get_contamination_ratio()

func get_mop_saturation_ratio() -> float:
	return clampf(mop_saturation / get_mop_capacity(), 0.0, 1.0)

func get_mop_capacity() -> float:
	return MOP_MAX_SATURATION + float(Progression.get_upgrade_level("capacity")) * 4.0

func can_mop() -> bool:
	# Dirt affects efficiency and color, but never disables the player's main tool.
	return true

func record_mop_use(amount := 1.0) -> void:
	mop_saturation = clampf(mop_saturation + maxf(0.0, amount), 0.0, get_mop_capacity())
	queue_redraw()

func rinse_mop() -> bool:
	if mop_saturation <= 0.0: return false
	mop_saturation = 0.0
	queue_redraw()
	return true

func attempt_ground_execution() -> bool:
	if is_executing or cleanup_mode or is_dead: return false
	var nearest := get_nearby_execution_target()
	if not is_instance_valid(nearest): return false
	return _start_execution_sequence(nearest)

func get_nearby_execution_target() -> CharacterBody2D:
	cached_execution_target = _query_execution_target()
	execution_query_cooldown = 0.12
	return cached_execution_target

func peek_nearby_execution_target() -> CharacterBody2D:
	return cached_execution_target if is_instance_valid(cached_execution_target) else null

func _query_execution_target() -> CharacterBody2D:
	if is_executing or cleanup_mode or is_dead: return null
	return ExecutionController.query_target(self)

func _find_safe_execution_position(target: CharacterBody2D, approach: Vector2) -> Dictionary:
	return ExecutionController.find_safe_position(self, target, approach)

func _start_execution_sequence(target: CharacterBody2D) -> bool:
	var approach := global_position.direction_to(target.global_position)
	if approach.length_squared() < 0.001: approach = Vector2.RIGHT.rotated(rotation)
	var placement := _find_safe_execution_position(target, approach)
	if not placement.found: return false
	is_executing = true
	execution_target = target
	velocity = Vector2.ZERO
	gun.visible = false
	melee_weapon_visual.visible = false
	global_position = placement.position
	var impact_direction := global_position.direction_to(target.global_position)
	rotation = impact_direction.angle()
	_run_execution_sequence(impact_direction)
	return true

func _run_execution_sequence(impact_direction: Vector2) -> void:
	var execution_type := "execution_knife" if equipped_mode == "melee" and current_melee_type == "knife" else ("execution_bat" if equipped_mode == "melee" and current_melee_type == "bat" else "execution")
	for strike in range(3):
		var windup_rotation := -0.30 if execution_type == "execution_bat" else (-0.12 if execution_type == "execution_knife" else -0.22)
		var strike_rotation := 0.48 if execution_type == "execution_bat" else (0.18 if execution_type == "execution_knife" else 0.28)
		var windup := create_tween().set_parallel(true)
		windup.tween_property(body_sprite, "position", Vector2(-2.0, 0.0), 0.08)
		windup.tween_property(body_sprite, "rotation", windup_rotation, 0.08)
		await windup.finished
		if not is_executing or not is_instance_valid(execution_target):
			_finish_execution()
			return
		var strike_tween := create_tween().set_parallel(true)
		strike_tween.tween_property(body_sprite, "position", Vector2(5.0 if execution_type == "execution_bat" else 3.5, 0.0), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		strike_tween.tween_property(body_sprite, "rotation", strike_rotation, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await strike_tween.finished
		execution_pulse = 0.11
		queue_redraw()
		var lethal := strike == 2
		execution_impact.emit(execution_target.global_position, impact_direction, lethal, execution_type)
		Events.publish_combat_noise(execution_target.global_position, 95.0 if lethal else 58.0, "execution")
		if lethal: execution_target.execute_ground(global_position)
		var reset := create_tween().set_parallel(true)
		reset.tween_property(body_sprite, "position", Vector2.ZERO, 0.07)
		reset.tween_property(body_sprite, "rotation", 0.0, 0.07)
		await reset.finished
	await get_tree().create_timer(0.08).timeout
	_finish_execution()

func _finish_execution() -> void:
	is_executing = false
	execution_target = null
	gun.visible = equipped_mode == "gun" and not cleanup_mode
	melee_weapon_visual.visible = equipped_mode == "melee" and not cleanup_mode
	queue_redraw()

func set_cleanup_mode(enabled: bool) -> void:
	cleanup_mode = enabled
	ultraviolet_active = false
	ultraviolet_lamp_active = false
	ultraviolet_scan_time = 0.0
	ultraviolet_scan_cooldown = 0.0
	scan_button_was_down = false
	last_cleanup_cursor = Vector2.INF
	cleanup_flow = 0.0
	cleanup_flow_grace = 0.0
	cleanup_last_stroke_direction = Vector2.ZERO
	cleanup_stroke_quality = 0.0
	pressure_washer_stability = 0.0
	if has_node("BloodFootprintEmitter"):
		$BloodFootprintEmitter.set_generation_enabled(not enabled)
	if not enabled and is_instance_valid(dragged_corpse):
		dragged_corpse.end_drag(self)
		dragged_corpse = null
	if not enabled and is_instance_valid(dragged_restoration_prop):
		dragged_restoration_prop.end_drag(self)
		dragged_restoration_prop = null
	if enabled:
		melee_animation_generation += 1
		is_melee_attacking = false
		_reset_melee_pose()
	gun.visible = not enabled and equipped_mode == "gun"
	melee_weapon_visual.visible = not enabled and equipped_mode == "melee"
	queue_redraw()

func _on_gun_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	if is_instance_valid(lifecycle_rig): lifecycle_rig.trigger_weapon_recoil(1.0)
	projectile_requested.emit(origin, direction, enemy_owned, damage, weapon_id, self)

func _on_actor_died(source_position: Vector2) -> void:
	melee_animation_generation += 1
	_reset_melee_pose()
	if source_position != Vector2.ZERO:
		velocity = (global_position - source_position).normalized() * 70.0
	died.emit(source_position)

func _on_hit_received(_amount: int, source_position: Vector2) -> void:
	var direction := source_position.direction_to(global_position)
	if direction.length_squared() < 0.001: direction = -Vector2.RIGHT.rotated(rotation)
	if is_instance_valid(lifecycle_rig) and lifecycle_context_impact_frame != Engine.get_physics_frames(): lifecycle_rig.apply_hit(direction, 24.0, "torso")
	var flash_tween := create_tween()
	body_sprite.modulate = Color(1.8, 0.35, 0.35, 1.0)
	flash_tween.tween_property(body_sprite, "modulate", Color(1.15, 1.15, 1.22, 1.0), 0.09)
	var hit_tween := create_tween()
	hit_tween.tween_property(body_sprite, "position", direction.rotated(-rotation) * 2.2, 0.035)
	hit_tween.tween_property(body_sprite, "position", Vector2.ZERO, 0.08)
	queue_redraw()

func get_lifecycle_pose() -> Dictionary:
	return lifecycle_rig.get_pose_snapshot() if is_instance_valid(lifecycle_rig) else {}

func apply_lifecycle_impact(direction: Vector2, power: float, hit_zone := "torso") -> void:
	lifecycle_context_impact_frame = Engine.get_physics_frames()
	if is_instance_valid(lifecycle_rig): lifecycle_rig.apply_hit(direction, power, hit_zone)

func _draw() -> void:
	_draw_aim_laser()
	if not is_dead:
		var identity := Color(0.39, 1.0, 0.88, 0.78)
		PIXEL_PAINTER.line(self, Vector2(-7, -6), Vector2(-4, -6), identity)
		PIXEL_PAINTER.line(self, Vector2(-7, -6), Vector2(-7, -3), identity)
		PIXEL_PAINTER.line(self, Vector2(-7, 6), Vector2(-4, 6), identity)
	if is_dead:
		PIXEL_PAINTER.material_rect(self, Rect2(-5, -6, 10, 12), Color(0.2, 0.18, 0.22, 0.75), Color(0.26, 0.23, 0.28, 0.75), Color(0.1, 0.08, 0.12, 0.75), 17, &"fabric")
	if cleanup_mode:
		PIXEL_PAINTER.line(self, Vector2(3, 0), Vector2(11, 0), Color("d7e8ef"))
		var mop_dirty := clampf(visual_mop_saturation, 0.0, 1.0)
		var eased_dirt := smoothstep(0.0, 1.0, mop_dirty)
		var mop_color := Color("81d4de").lerp(Color("c24a52"), minf(eased_dirt * 1.35, 1.0))
		if mop_dirty > 0.62:
			mop_color = mop_color.lerp(Color("730019"), smoothstep(0.62, 1.0, mop_dirty))
		if current_cleanup_tool == "pressure_washer":
			PIXEL_PAINTER.material_block(self, Vector2(10, 0), Vector2(4, 4), Color("5bc8e8"), 19, &"metal")
			# The old full-length cone was only a preview and made the washer look like
			# an instant eraser. Keep a tiny nozzle glint; PixelLiquidSystem now renders
			# every water pixel actually travelling through the room.
			PIXEL_PAINTER.line(self, Vector2(12, 0), Vector2(14, 0), Color(0.76, 0.96, 1.0, 0.88))
		else:
			var mop_visual_width := 6 + clampi(Progression.get_upgrade_level("mop"), 0, 3)
			PIXEL_PAINTER.material_block(self, Vector2(9, 0), Vector2(2, mop_visual_width), mop_color, 23, &"fabric")
		if mop_dirty >= 0.75:
			PIXEL_PAINTER.material_circle(self, Vector2(9, 4), 1, Color(0.65, 0.0, 0.08, 0.85), Color(0.85, 0.04, 0.12, 0.85), Color(0.3, 0.0, 0.04, 0.85), 29)
		if ultraviolet_lamp_active:
			var cone_color := Color(0.58, 0.2, 1.0, 0.12)
			PIXEL_PAINTER.line(self, Vector2(7, 0), Vector2(66, -29), Color(0.75, 0.45, 1.0, 0.3))
			PIXEL_PAINTER.line(self, Vector2(7, 0), Vector2(66, 29), Color(0.75, 0.45, 1.0, 0.3))
			for distance in range(14, 66, 6):
				PIXEL_PAINTER.pixel(self, Vector2(distance, roundi(sin(float(distance)) * 0.3 * distance)), cone_color)
		if ultraviolet_scan_time > 0.0:
			var scan_progress := 1.0 - ultraviolet_scan_time / ULTRAVIOLET_SCAN_DURATION
			var scan_alpha := sin(scan_progress * PI) * (0.48 + 0.18 * absf(sin(scan_progress * PI * 4.0)))
			PIXEL_PAINTER.arc(self, Vector2.ZERO, 82, 0.0, TAU, Color(0.76, 0.42, 1.0, scan_alpha), 64)
	if is_executing:
		PIXEL_PAINTER.arc(self, Vector2(6, -3), 3, -1.2, 1.2, Color("ffd6c2"), 6)
		PIXEL_PAINTER.arc(self, Vector2(6, 3), 3, -1.2, 1.2, Color("ffd6c2"), 6)
	if execution_pulse > 0.0:
		PIXEL_PAINTER.circle(self, Vector2(9, 0), 3, Color(1.0, 0.18, 0.25, execution_pulse / 0.11), true)

func _draw_aim_laser() -> void:
	if not Settings.aim_laser_enabled or cleanup_mode or is_dead or equipped_mode != "gun" or not is_instance_valid(gun) or gun.gun_data == null: return
	var start_world: Vector2 = gun.muzzle.global_position
	var available_distance: float = start_world.distance_to(aim_lane_point)
	var visible_distance := minf(available_distance, 52.0 if aim_lane_has_target else 28.0)
	var end_world: Vector2 = start_world + Vector2.RIGHT.rotated(actual_aim_angle) * visible_distance
	var start_local := to_local(start_world)
	var end_local := to_local(end_world)
	var laser_color := Color("ff536e") if aim_lane_blocked else (Color("ffe56b") if aim_lane_has_target else Color(0.3, 1.0, 0.88, 0.46))
	for segment in range(4):
		var from_t := float(segment) / 4.0
		var to_t := minf(1.0, from_t + 0.16)
		PIXEL_PAINTER.line(self, start_local.lerp(end_local, from_t), start_local.lerp(end_local, to_t), laser_color)
	if gun.pellet_count > 1:
		var cone := deg_to_rad(gun.get_total_spread_degrees())
		for side in [-1.0, 1.0]:
			var fan_end: Vector2 = start_world + Vector2.RIGHT.rotated(actual_aim_angle + cone * side) * 24.0
			PIXEL_PAINTER.line(self, start_local, to_local(fan_end), Color(laser_color, 0.32))
