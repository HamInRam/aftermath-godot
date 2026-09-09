extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String, shooter: CollisionObject2D)
signal died(source_position: Vector2)
signal execution_impact(world_position: Vector2, direction: Vector2, lethal: bool, execution_type: String)
signal melee_impact(target: CharacterBody2D, world_position: Vector2, direction: Vector2, melee_type: String, lethal: bool)
signal weapon_throw_requested(origin: Vector2, direction: Vector2, weapon_id: String, rounds: int, attachment_ids: PackedStringArray)
signal world_interaction_requested
signal blood_stance_changed(active: bool)
signal blood_skill_requested(skill_id: String)
signal blood_heal_requested

const MELEE_TRAIL_SCENE := preload("res://scenes/effects/melee_trail.tscn")
const AIM_CONTROLLER := preload("res://scripts/controllers/aim_controller.gd")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const PIXEL_ACTOR_FRAMES := preload("res://utility/pixel_actor_texture_factory.gd")
var PLAYER_GUNS: Array[GunData] = []
const MELEE_DATA := {
	"fist": {"range": 12.0, "angle": 35.0, "windup": 0.03, "cooldown": 0.18, "duration": 0.06, "lethal": false, "color": Color("ffffff")},
	"knife": {"range": 16.0, "angle": 45.0, "windup": 0.02, "cooldown": 0.22, "duration": 0.05, "lethal": true, "color": Color("ffffff")},
	"bat": {"range": 28.0, "angle": 120.0, "windup": 0.08, "cooldown": 0.42, "duration": 0.12, "lethal": true, "color": Color("cfcfcf")},
}

@onready var upper_body: Node2D = $UpperBody
@onready var legs_visual: PixelActorPart = $Legs
@onready var body_sprite: Sprite2D = $UpperBody/BodySprite
@onready var lifecycle_rig = $UpperBody/LifecycleRig
@onready var melee_tip: Marker2D = $UpperBody/BodySprite/MeleeTip
@onready var melee_weapon_visual: Node2D = $UpperBody/BodySprite/MeleeWeaponVisual
@onready var gun = $UpperBody/Gun
@onready var melee_shape: CollisionShape2D = $MeleeArea/CollisionShape2D
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
var weapon_build_overrides: Dictionary = {}
var cached_execution_target: CharacterBody2D
var execution_query_cooldown := 0.0
var controls_enabled := true
var predeployment_mode := false
var melee_input_buffer := 0.0
var execution_input_buffer := 0.0
var stride_time := 0.0
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
var aim_lane_target_kind := ""
var targeting_mode_active := false
var blood_stance_active := false
var blood_stance_movement_multiplier := 1.0
var blood_guard_points := 0
var blood_siphon_visual_amount := 0.0
var blood_action_mode := false
var blood_terrain_canvas: Node2D
var blood_terrain_multiplier := 1.0

func refresh_blood_terrain() -> void:
	var previous_roll_multiplier := roll_speed_multiplier
	blood_terrain_multiplier = 1.0
	if blood_action_mode and is_instance_valid(blood_terrain_canvas):
		var terrain: int = blood_terrain_canvas.terrain_at(global_position)
		blood_terrain_multiplier = 0.6 if terrain < 0 else (1.3 if terrain > 0 else 1.0)
	# Sample the actual 1px cell, not whether its 32px storage chunk has blood.
	# Re-evaluated before each movement step, including an ongoing roll.
	roll_speed_multiplier = 1.35 if blood_terrain_multiplier > 1.0 else 1.0
	if roll_time > 0.0 or previous_roll_multiplier != roll_speed_multiplier:
		queue_redraw()
var roll_time := 0.0
var roll_cooldown := 0.0
var roll_direction := Vector2.RIGHT
var roll_speed_multiplier := 1.0
const ROLL_DURATION := 0.28
const ROLL_IFRAMES := 0.18

func start_roll(direction: Vector2) -> bool:
	refresh_blood_terrain()
	if blood_terrain_multiplier < 1.0: return false
	if not blood_action_mode or is_dead or is_executing or not controls_enabled or predeployment_mode or roll_cooldown > 0.0 or roll_time > 0.0: return false
	roll_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT.rotated(actual_aim_angle)
	roll_speed_multiplier = 1.35 if blood_terrain_multiplier > 1.0 else 1.0
	roll_time = ROLL_DURATION
	roll_cooldown = 0.7
	return true

func is_roll_invulnerable() -> bool:
	return roll_time > ROLL_DURATION - ROLL_IFRAMES

func apply_ballistic_hit(result: Dictionary, source_position := Vector2.ZERO) -> void:
	if is_roll_invulnerable(): return
	super.apply_ballistic_hit(result, source_position)
var fire_input_buffer := 0.0
var reload_input_buffer := 0.0
var throw_input_buffer := 0.0
var primary_requires_release := false
const INPUT_BUFFER_DURATION := 0.14
const WEAPON_PICKUP_RADIUS := 26.0
var last_presented_shot_id := -1

func _ready() -> void:
	super._ready()
	_refresh_weapon_catalog()
	_ensure_gamepad_inputs()
	gun.set_gun_data(_weapon_data_for_slot(0), true)
	gun.set_reserve_ammo("glock_17_gen5_mos", 34)
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	hit_received.connect(_on_hit_received)
	previous_aim_angle = rotation
	aim_intent_angle = rotation
	actual_aim_angle = rotation
	aim_target_world = global_position + Vector2.RIGHT.rotated(rotation) * 90.0
	# The authored sprite remains as an invisible animation carrier for weapon
	# anchors. Visible locomotion and the upper-body physics rig are independent
	# scene layers, matching a twin-stick top-down character pipeline.
	body_sprite.texture = PIXEL_ACTOR_FRAMES.get_frame("player")
	$FakeShadow.texture = body_sprite.texture
	legs_visual.configure("player", Color("202426"), Color("f7f7f2"))
	legs_visual.visible = true
	body_sprite.self_modulate = Color(1, 1, 1, 0)
	$FakeShadow.visible = false
	lifecycle_rig.configure("player", Color("d8e2df"), Color("27c9ca"), "player")
	queue_redraw()

func _refresh_weapon_catalog() -> void:
	PLAYER_GUNS.clear()
	for weapon_class in WeaponPlatformCatalog.CLASS_ORDER:
		for weapon_id in WeaponPlatformCatalog.get_class_weapon_ids(weapon_class):
			PLAYER_GUNS.append(AttackCatalog.get_gun_data(weapon_id))

func _weapon_data_for_slot(slot: int) -> GunData:
	if PLAYER_GUNS.is_empty(): return AttackCatalog.get_gun_data("glock_17_gen5_mos")
	var base: GunData = PLAYER_GUNS[clampi(slot, 0, PLAYER_GUNS.size() - 1)]
	var build := PackedStringArray(weapon_build_overrides.get(base.weapon_id, Progression.get_weapon_build(base.weapon_id)))
	return AttackCatalog.get_gun_data(base.weapon_id, build)

func _find_weapon_slot(weapon_id: String) -> int:
	var resolved := WeaponPlatformCatalog.canonical_id(weapon_id)
	for index in range(PLAYER_GUNS.size()):
		if PLAYER_GUNS[index].weapon_id == resolved: return index
	return -1

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
	if predeployment_mode:
		_handle_predeployment_movement(delta)
		return
	var was_rolling := roll_time > 0.0
	roll_time = maxf(0.0, roll_time - delta)
	if was_rolling and roll_time == 0.0: queue_redraw()
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	_update_targeting_mode()
	if not blood_action_mode and execution_query_cooldown <= 0.0 and not is_executing and not is_dead:
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
	if Input.is_action_just_pressed("execute"):
		if blood_action_mode: start_roll(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		else: execution_input_buffer = INPUT_BUFFER_DURATION
	if execution_input_buffer > 0.0:
		if attempt_ground_execution(): execution_input_buffer = 0.0
		if is_executing: return
	if Input.is_action_just_pressed("interact") and (not blood_stance_active or blood_action_mode):
		if not attempt_weapon_pickup(): world_interaction_requested.emit()
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	refresh_blood_terrain()
	var executioner_mobility := 1.0 + Progression.get_specialization_level("executioner") * 0.03
	velocity = input_direction * move_speed * get_equipped_movement_multiplier() * executioner_mobility * field_movement_multiplier * blood_stance_movement_multiplier * blood_terrain_multiplier
	if roll_time > 0.0: velocity = roll_direction * move_speed * 2.6 * roll_speed_multiplier
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	_handle_weapon_selection()
	_update_aim_solution(delta)
	_update_procedural_motion(delta)
	if roll_time > 0.0: return
	if not blood_action_mode and equipped_mode != "gun" and Input.is_action_just_pressed("targeting_mode"):
		_start_kick_attack()
	_handle_primary_input(Input.is_action_just_pressed("shoot"), Input.is_action_pressed("shoot"))
	if blood_stance_active and not blood_action_mode:
		if Input.is_action_just_pressed("throw_weapon"): blood_skill_requested.emit("q")
		if Input.is_action_just_pressed("interact"): blood_skill_requested.emit("e")
		if Input.is_action_just_pressed("reload"): blood_skill_requested.emit("r")
	if not blood_action_mode and Input.is_action_just_pressed("blood_heal"): blood_heal_requested.emit()
	if not blood_action_mode and Input.is_action_just_pressed("reload") and not blood_stance_active: reload_input_buffer = INPUT_BUFFER_DURATION
	if blood_action_mode: reload_input_buffer = 0.0
	if not blood_action_mode and reload_input_buffer > 0.0 and equipped_mode == "gun" and not gun.is_reloading and gun.ammo < gun.max_ammo:
		gun.reload()
		if gun.is_reloading: reload_input_buffer = 0.0
	if Input.is_action_just_pressed("throw_weapon") and (not blood_stance_active or blood_action_mode): throw_input_buffer = INPUT_BUFFER_DURATION
	if throw_input_buffer > 0.0 and throw_equipped_gun(Vector2.RIGHT.rotated(actual_aim_angle)):
		throw_input_buffer = 0.0

func _handle_primary_input(just_pressed: bool, held: bool) -> void:
	if not controls_enabled or predeployment_mode or is_dead or is_executing: return
	if not held: primary_requires_release = false
	if primary_requires_release: return
	if equipped_mode != "gun":
		if just_pressed:
			if is_melee_attacking or melee_cooldown > 0.0: melee_input_buffer = INPUT_BUFFER_DURATION
			else: _start_melee_attack()
		return
	if gun.gun_data == null: return
	# Empty-magazine actions only consume a fresh trigger pull. Holding an
	# automatic through its last round must not reload, click repeatedly or throw.
	if gun.ammo <= 0 and not gun.blood_fire_payment.is_valid():
		fire_input_buffer = 0.0
		if just_pressed and not gun.is_reloading:
			if gun.reserve_ammo != 0: gun.reload()
			else: gun.play_dry_fire()
		return
	if just_pressed: fire_input_buffer = INPUT_BUFFER_DURATION
	if (gun.automatic and held) or fire_input_buffer > 0.0:
		if gun.try_fire(Vector2.RIGHT.rotated(actual_aim_angle)):
			fire_input_buffer = 0.0

func _reset_primary_input() -> void:
	fire_input_buffer = 0.0
	reload_input_buffer = 0.0
	melee_input_buffer = 0.0
	primary_requires_release = Input.is_action_pressed("shoot")

func _handle_predeployment_movement(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * move_speed * field_movement_multiplier
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	_update_aim_solution(delta)
	_update_procedural_motion(delta)

func set_predeployment_mode(enabled: bool) -> void:
	predeployment_mode = enabled
	_reset_primary_input()
	if enabled: targeting_mode_active = false
	fire_input_buffer = 0.0
	melee_input_buffer = 0.0
	reload_input_buffer = 0.0
	throw_input_buffer = 0.0
	gun.visible = not enabled and equipped_mode == "gun"
	melee_weapon_visual.visible = not enabled and equipped_mode == "melee"
	queue_redraw()

func _process(_delta: float) -> void:
	# Aim is a display-rate input, not a mass that must accelerate. This remains
	# responsive during the short global hit-stop and on high-refresh displays.
	if controls_enabled and is_physics_processing() and not using_controller_aim and not is_dead and not is_executing and not get_tree().paused:
		_update_aim_solution(0.0, false)

func _update_aim_solution(_delta: float, refresh_lane := true) -> void:
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
		actual_aim_angle = aim_intent_angle
		rotation = actual_aim_angle
		previous_aim_angle = actual_aim_angle
	if refresh_lane: _update_aim_lane()

func _update_aim_lane() -> void:
	if equipped_mode != "gun" or not is_instance_valid(gun) or gun.gun_data == null:
		aim_lane_blocked = false
		aim_lane_has_target = false
		aim_lane_target_kind = ""
		return
	var origin: Vector2 = gun.muzzle.global_position
	var distance := clampf(origin.distance_to(aim_target_world), 8.0, AIM_CONTROLLER.MAX_AIM_DISTANCE)
	var solution := AIM_CONTROLLER.solve_fire_lane(self, origin, Vector2.RIGHT.rotated(actual_aim_angle), distance, targeting_mode_active)
	aim_lane_point = solution.point
	aim_lane_blocked = bool(solution.blocked) or gun.is_muzzle_blocked()
	var lane_target := solution.target as Node
	aim_lane_has_target = AIM_CONTROLLER.is_targetable(lane_target, targeting_mode_active)
	aim_lane_target_kind = _classify_aim_target(lane_target) if aim_lane_has_target else ""
	queue_redraw()

func _classify_aim_target(target: Node) -> String:
	if not is_instance_valid(target): return ""
	if target.is_in_group("security_device"): return "device"
	if target.is_in_group("corpse"): return "low"
	if target.is_in_group("destructible_prop"): return "object"
	if target.is_in_group("enemy") and target.has_method("is_knocked_down") and target.is_knocked_down(): return "low"
	return "hostile"

func _update_targeting_mode() -> void:
	var next_active := not is_dead and equipped_mode == "gun" and Input.is_action_pressed("targeting_mode")
	if targeting_mode_active == next_active and blood_stance_active == next_active: return
	targeting_mode_active = next_active
	blood_stance_active = next_active
	blood_stance_changed.emit(next_active)
	queue_redraw()

func set_blood_stance_movement_multiplier(value: float) -> void:
	blood_stance_movement_multiplier = clampf(value, 0.35, 1.0)

func set_blood_siphon_visual(value: float) -> void:
	blood_siphon_visual_amount = clampf(value, 0.0, 1.0)
	var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.026) * 0.28
	var strength := blood_siphon_visual_amount * pulse
	var tint := Color(1.0 + strength * 0.35, 1.0 - strength * 0.82, 1.0 - strength * 0.82, 1.0)
	if is_roll_invulnerable(): tint = Color(1.6, 1.6, 1.6, 1.0)
	if is_instance_valid(lifecycle_rig): lifecycle_rig.modulate = tint

func perform_blood_dash(distance: float) -> void:
	if is_dead: return
	var direction := Vector2.RIGHT.rotated(actual_aim_angle)
	move_and_collide(direction * maxf(0.0, distance))
	apply_lifecycle_impact(direction, 14.0, "torso")

func grant_blood_guard(points: int) -> void:
	blood_guard_points = maxi(blood_guard_points, points)
	queue_redraw()

func take_damage(amount: int, source_position := Vector2.ZERO) -> void:
	if is_roll_invulnerable(): return
	if blood_guard_points > 0 and amount > 0:
		var absorbed := mini(amount, blood_guard_points)
		blood_guard_points -= absorbed
		amount -= absorbed
		queue_redraw()
	if amount > 0: super.take_damage(amount, source_position)

func is_targeting_mode_active() -> bool:
	return targeting_mode_active

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
		"targeting_mode": targeting_mode_active,
		"target_kind": aim_lane_target_kind,
		"controller": using_controller_aim,
	}, true)
	return feedback

func _ensure_gamepad_inputs() -> void:
	_add_joy_motion("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_motion("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_motion("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_motion("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_motion("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_motion("targeting_mode", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_button("combat_focus", JOY_BUTTON_LEFT_SHOULDER)
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
	# Legs face movement independently. Player/UpperBody remains locked to the
	# mouse or right-stick aim angle, so strafing and retreating read correctly.
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
	var upper_turn_target := 0.0 if equipped_mode == "gun" else visual_aim_lag
	upper_body.rotation = 0.0 if equipped_mode == "gun" else lerp_angle(upper_body.rotation, upper_turn_target, 1.0 - exp(-18.0 * delta))
	var stop_lean := 1.5 * clampf(stop_pose_time / 0.11, 0.0, 1.0)
	upper_body.position.y = lerpf(upper_body.position.y, target_bob, 1.0 - exp(-14.0 * delta))
	upper_body.position.x = lerpf(upper_body.position.x, stop_lean, 1.0 - exp(-20.0 * delta))
	if not is_melee_attacking and not is_executing:
		var pose_rotation := 0.0
		var pose_position := Vector2.ZERO
		# Reload articulation comes from the same gun presentation used by the
		# hands. A second torso rotation would move the grip away from the gun.
		body_sprite.rotation = lerp_angle(body_sprite.rotation, pose_rotation, 1.0 - exp(-22.0 * delta))
		body_sprite.position = body_sprite.position.lerp(pose_position, 1.0 - exp(-22.0 * delta))
	# The gun owns its complete recoil/reload presentation. Moving or turning the
	# ballistic carrier here would aim a just-reloaded shot along its old pose.
	gun.position = Vector2.ZERO
	gun.rotation = 0.0
	var lifecycle_action := "idle"
	var lifecycle_amount := 0.0
	if is_melee_attacking: lifecycle_action = "attack"; lifecycle_amount = 1.0
	elif is_executing: lifecycle_action = "execute"; lifecycle_amount = 1.0
	var visual_stance := "gun" if equipped_mode == "gun" else current_melee_type
	if equipped_mode == "gun" and gun.gun_data != null:
		visual_stance = gun.gun_data.weapon_class
		if gun.is_reloading:
			lifecycle_action = "reload"
			lifecycle_amount = 1.0 - gun.reload_timer.time_left / maxf(gun.active_reload_duration, 0.01)
	lifecycle_rig.set_weapon_stance(visual_stance)
	lifecycle_rig.set_weapon_presentation(gun.visual_offset, gun.visual_angle, gun.magazine_offset)
	# UpperBody is now the rig's real parent, therefore only the local carrier
	# offset is forwarded. Passing the container transform again would apply bob
	# and attack rotation twice.
	lifecycle_rig.update_lifecycle(delta, velocity.rotated(-rotation), move_speed, body_sprite.position, body_sprite.rotation, lifecycle_action, lifecycle_amount)
	var roll_pose := sin((1.0 - roll_time / ROLL_DURATION) * PI) if roll_time > 0.0 else 0.0
	lifecycle_rig.scale = Vector2(1.0 - roll_pose * 0.15, 1.0 - roll_pose * 0.4)
	# Only the weapon changes depth when aiming north. UpperBody itself must stay
	# above Legs; moving the whole container behind would let the feet cover the
	# head and torso now that the lifecycle rig is a real UpperBody child.
	upper_body.z_index = 1
	gun.z_index = -1 if lifecycle_rig.weapon_should_render_behind() else 2

func _handle_weapon_selection() -> void:
	if is_executing or is_melee_attacking: return
	if Input.is_action_just_pressed("equip_gun"):
		if equipped_mode == "gun": _cycle_gun()
		elif not owned_gun_indices.is_empty(): _equip_weapon("gun")
	elif Input.is_action_just_pressed("equip_fist"): _equip_weapon("fist")
	elif Input.is_action_just_pressed("equip_knife"): _equip_weapon("knife")
	elif Input.is_action_just_pressed("equip_bat"): _equip_weapon("bat")

func configure_field_kit(kit: Dictionary) -> void:
	owned_gun_indices.clear()
	for entry in kit.get("guns", ["glock_17_gen5_mos"]):
		var gun_slot := clampi(int(entry), 0, PLAYER_GUNS.size() - 1) if entry is int else _find_weapon_slot(str(entry))
		if gun_slot < 0: continue
		if gun_slot not in owned_gun_indices: owned_gun_indices.append(gun_slot)
	if owned_gun_indices.is_empty(): owned_gun_indices.append(0)
	# A field kit is a fresh mission issue, not an inventory restore. Initialize
	# every authorized weapon explicitly so an old zero-round cache can never
	# turn a newly selected briefing loadout into an empty gun.
	var reserve_magazines := maxi(0, int(kit.get("reserve_magazines", 1)))
	for slot in owned_gun_indices:
		var data: GunData = _weapon_data_for_slot(slot)
		gun.set_weapon_ammo(data.weapon_id, data.ammo_capacity)
		gun.set_reserve_ammo(data.weapon_id, data.ammo_capacity * reserve_magazines)
	gun_index = owned_gun_indices[0]
	gun.set_gun_data(_weapon_data_for_slot(gun_index), false)
	field_movement_multiplier = clampf(float(kit.get("move", 1.0)), 0.85, 1.12)
	gun.field_noise_multiplier = clampf(float(kit.get("noise", 1.0)), 0.4, 1.2)
	var armor: Array = kit.get("armor", [1.0, 0.18, 34.0, false])
	configure_armor(float(armor[0]), float(armor[1]), float(armor[2]), bool(armor[3]), true)
	queue_redraw()

func capture_run_loadout() -> Dictionary:
	var weapons: Array[Dictionary] = []
	for slot in owned_gun_indices:
		var data := _weapon_data_for_slot(slot)
		weapons.append({
			"weapon_id": data.weapon_id,
			"rounds": gun.get_weapon_ammo(data.weapon_id),
			"attachments": Array(data.installed_attachments),
		})
	var reserves: Dictionary = {}
	for id in gun.reserve_by_weapon:
		var canonical := WeaponPlatformCatalog.canonical_id(str(id))
		# Legacy scene aliases such as "pistol" can coexist with the live Glock
		# cache. The live canonical entry always owns its carried reserve count.
		if str(id) != canonical and gun.reserve_by_weapon.has(canonical): continue
		reserves[canonical] = int(gun.reserve_by_weapon[id])
	if not gun.weapon_id.is_empty(): reserves[gun.weapon_id] = gun.reserve_ammo
	return {
		"weapons": weapons,
		"reserves": reserves,
		"equipped_weapon": gun.weapon_id,
		"mode": equipped_mode,
		"melee": current_melee_type,
		"movement": field_movement_multiplier,
		"noise": gun.field_noise_multiplier,
	}

func restore_run_loadout(snapshot: Dictionary) -> void:
	# Restore exact carried state at room boundaries/retries. Detach the starter
	# first so set_gun_data cannot overwrite restored ammunition with its cache.
	gun.clear_equipped_weapon()
	gun.ammo_by_weapon.clear()
	gun.reserve_by_weapon.clear()
	owned_gun_indices.clear()
	weapon_build_overrides.clear()
	var reserves: Dictionary = snapshot.get("reserves", {})
	for id in reserves:
		gun.set_reserve_ammo(WeaponPlatformCatalog.canonical_id(str(id)), int(reserves[id]))
	for entry in snapshot.get("weapons", []):
		if not entry is Dictionary: continue
		var weapon_id := WeaponPlatformCatalog.canonical_id(str(entry.get("weapon_id", "")))
		var slot := _find_weapon_slot(weapon_id)
		if slot < 0 or slot in owned_gun_indices: continue
		weapon_build_overrides[weapon_id] = Array(entry.get("attachments", []))
		var data := _weapon_data_for_slot(slot)
		owned_gun_indices.append(slot)
		gun.set_weapon_ammo(weapon_id, clampi(int(entry.get("rounds", 0)), 0, data.ammo_capacity))
		if not gun.reserve_by_weapon.has(weapon_id): gun.set_reserve_ammo(weapon_id, 0)
	field_movement_multiplier = clampf(float(snapshot.get("movement", 1.0)), 0.85, 1.12)
	gun.field_noise_multiplier = clampf(float(snapshot.get("noise", 1.0)), 0.4, 1.2)
	current_melee_type = str(snapshot.get("melee", "fist"))
	if not MELEE_DATA.has(current_melee_type): current_melee_type = "fist"
	if owned_gun_indices.is_empty():
		gun_index = -1
		_equip_weapon(current_melee_type)
		Events.publish_ammo(0, 0, false)
		Events.publish_ammo_reserve(0)
	else:
		var preferred := _find_weapon_slot(str(snapshot.get("equipped_weapon", "")))
		gun_index = preferred if preferred in owned_gun_indices else owned_gun_indices[0]
		gun.set_gun_data(_weapon_data_for_slot(gun_index), false)
		_equip_weapon("gun" if str(snapshot.get("mode", "gun")) == "gun" else current_melee_type)
	throw_input_buffer = 0.0
	_reset_primary_input()
	queue_redraw()

func _equip_weapon(mode: String) -> void:
	if mode == "gun" and owned_gun_indices.is_empty(): return
	_reset_primary_input()
	if mode != "gun": gun.cancel_reload()
	equipped_mode = "gun" if mode == "gun" else "melee"
	if mode != "gun": current_melee_type = mode
	gun.visible = equipped_mode == "gun" and not is_executing
	melee_weapon_visual.visible = equipped_mode == "melee" and not is_executing
	if mode != "gun": melee_weapon_visual.set_weapon(current_melee_type)
	queue_redraw()

func _cycle_gun() -> void:
	if owned_gun_indices.is_empty(): return
	_reset_primary_input()
	var owned_position := owned_gun_indices.find(gun_index)
	gun_index = owned_gun_indices[(owned_position + 1) % owned_gun_indices.size()]
	gun.set_gun_data(_weapon_data_for_slot(gun_index), false)
	queue_redraw()

func acquire_gun(weapon_id: String, rounds: int, attachment_ids := PackedStringArray()) -> bool:
	weapon_id = WeaponPlatformCatalog.canonical_id(weapon_id)
	var found_index := _find_weapon_slot(weapon_id)
	if found_index < 0: return false
	# An empty build is meaningful: a stock world gun must not silently inherit
	# attachments from an older gun of the same model or the armory loadout.
	weapon_build_overrides[weapon_id] = Array(attachment_ids)
	if found_index not in owned_gun_indices: owned_gun_indices.append(found_index)
	if not gun.reserve_by_weapon.has(weapon_id): gun.set_reserve_ammo(weapon_id, 0)
	var capacity: int = _weapon_data_for_slot(found_index).ammo_capacity
	var current_rounds: int = int(gun.get_weapon_ammo(weapon_id))
	var magazine_rounds: int = mini(capacity, current_rounds + maxi(0, rounds))
	var overflow_rounds: int = maxi(0, current_rounds + maxi(0, rounds) - magazine_rounds)
	gun_index = found_index
	_reset_primary_input()
	equipped_mode = "gun"
	gun.set_gun_data(_weapon_data_for_slot(gun_index), false)
	# Apply the incoming magazine/attachment capacity before transferring rounds;
	# otherwise the old magazine's limit silently discards extended-mag ammo.
	gun.set_weapon_ammo(weapon_id, magazine_rounds)
	if overflow_rounds > 0: gun.add_reserve_ammo(weapon_id, overflow_rounds)
	gun.visible = true
	melee_weapon_visual.visible = false
	queue_redraw()
	return true

func attempt_weapon_pickup() -> bool:
	if is_dead or is_executing: return false
	var nearest = get_nearby_weapon_pickup()
	return is_instance_valid(nearest) and nearest.collect(self)

func get_nearby_weapon_pickup() -> Node2D:
	var nearest: Node2D = null
	var nearest_score := INF
	var forward := Vector2.RIGHT.rotated(actual_aim_angle)
	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		if not node is Node2D or node.is_queued_for_deletion(): continue
		var offset: Vector2 = node.global_position - global_position
		var distance := offset.length()
		if distance > WEAPON_PICKUP_RADIUS: continue
		# Aim gently breaks ties in a pile; touching a weapon never auto-equips it.
		var score := distance + (1.0 - forward.dot(offset.normalized())) * 4.0
		if score >= nearest_score: continue
		var query := PhysicsRayQueryParameters2D.create(global_position, node.global_position, 4)
		query.exclude = [get_rid()]
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): continue
		nearest = node
		nearest_score = score
	return nearest

func get_equipped_weapon_name() -> String:
	return str(gun.gun_data.display_name) if equipped_mode == "gun" and gun.gun_data != null else current_melee_type.to_upper()

func get_equipped_movement_multiplier() -> float:
	if equipped_mode != "gun" or gun.gun_data == null: return 1.0
	return gun.reload_movement_multiplier if gun.is_reloading else gun.movement_speed_multiplier

func get_camera_look_ahead_multiplier() -> float:
	if equipped_mode != "gun" or gun.gun_data == null: return 1.0
	return gun.gun_data.camera_look_ahead_multiplier * (1.18 if targeting_mode_active else 1.0)

func add_reserve_ammo(weapon_id: String, rounds: int) -> bool:
	if rounds <= 0: return false
	gun.add_reserve_ammo(weapon_id, rounds)
	return true

func throw_equipped_gun(direction: Vector2) -> bool:
	if not controls_enabled or predeployment_mode or is_dead or is_executing or equipped_mode != "gun" or gun.gun_data == null or direction.length_squared() < 0.001: return false
	var thrown_weapon_id: String = gun.weapon_id
	var thrown_rounds: int = gun.ammo
	var thrown_build: PackedStringArray = gun.gun_data.installed_attachments.duplicate() if gun.gun_data != null else PackedStringArray()
	var thrown_index := gun_index
	_reset_primary_input()
	# Reserve cartridges stay with the player. The loaded magazine travels with
	# the gun, and must be detached before set_gun_data can cache the old weapon.
	gun.reserve_by_weapon[thrown_weapon_id] = gun.reserve_ammo
	gun.clear_equipped_weapon()
	owned_gun_indices.erase(thrown_index)
	gun.ammo_by_weapon.erase(thrown_weapon_id)
	weapon_throw_requested.emit(global_position, direction.normalized(), thrown_weapon_id, thrown_rounds, thrown_build)
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
		gun.set_gun_data(_weapon_data_for_slot(gun_index), false)
	queue_redraw()
	return true

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	_reset_primary_input()
	if enabled: return
	targeting_mode_active = false
	if blood_stance_active:
		blood_stance_active = false
		blood_stance_changed.emit(false)
	velocity = Vector2.ZERO
	melee_animation_generation += 1
	is_melee_attacking = false
	_reset_melee_pose()

func _start_melee_attack() -> void:
	if is_melee_attacking or melee_cooldown > 0.0 or is_dead: return
	var data: Dictionary = MELEE_DATA[current_melee_type]
	is_melee_attacking = true
	melee_cooldown = float(data.cooldown)
	_perform_melee_attack(data)

func _start_kick_attack() -> void:
	if is_melee_attacking or melee_cooldown > 0.0 or is_dead or equipped_mode == "gun": return
	is_melee_attacking = true
	melee_cooldown = 0.36
	_perform_kick_attack()

func _perform_kick_attack() -> void:
	melee_animation_generation += 1
	var generation := melee_animation_generation
	body_sprite.position = Vector2(-2.0, 0.0)
	body_sprite.rotation = -0.08
	await get_tree().create_timer(0.045).timeout
	if generation != melee_animation_generation or is_dead or equipped_mode == "gun":
		_reset_melee_pose()
		is_melee_attacking = false
		return
	body_sprite.position = Vector2(5.0, 0.0)
	body_sprite.rotation = 0.10
	var forward := Vector2.RIGHT.rotated(rotation)
	var kick_range := 18.0
	var kick_half_angle := deg_to_rad(28.0)
	if melee_shape.shape is CircleShape2D: (melee_shape.shape as CircleShape2D).radius = kick_range
	melee_shape.position = Vector2(11.0, 0.0)
	var nearest: CharacterBody2D
	var nearest_distance := INF
	for body in MeleeController.query_bodies(self, melee_shape):
		if not body is CharacterBody2D or not body.is_in_group("enemy") or body.is_dead: continue
		if body.has_method("is_knocked_down") and body.is_knocked_down(): continue
		var offset: Vector2 = body.global_position - global_position
		if offset.length() > kick_range or absf(forward.angle_to(offset.normalized())) > kick_half_angle: continue
		if MeleeController.blocked_by_geometry(self, body): continue
		if offset.length_squared() < nearest_distance:
			nearest = body
			nearest_distance = offset.length_squared()
	if is_instance_valid(nearest):
		melee_impact.emit(nearest, nearest.global_position, forward, "fist", false)
		Events.publish_combat_noise(global_position, 52.0, "melee")
	await get_tree().create_timer(0.06).timeout
	if generation != melee_animation_generation: return
	var recover := create_tween().set_parallel(true)
	recover.tween_property(body_sprite, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	recover.tween_property(body_sprite, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await recover.finished
	if generation == melee_animation_generation:
		_reset_melee_pose()
		is_melee_attacking = false

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
	if generation != melee_animation_generation or is_dead or equipped_mode == "gun":
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

func attempt_ground_execution() -> bool:
	if is_executing or is_dead: return false
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
	if is_executing or is_dead: return null
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
	gun.visible = equipped_mode == "gun"
	melee_weapon_visual.visible = equipped_mode == "melee"
	queue_redraw()

func _on_gun_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	# The fired signal is per projectile: a shotgun must kick the body once, not
	# stack nine independent shoulder impulses for one trigger pull.
	if last_presented_shot_id != gun.current_shot_id:
		last_presented_shot_id = gun.current_shot_id
		if is_instance_valid(lifecycle_rig): lifecycle_rig.trigger_weapon_recoil(clampf(gun.recoil_strength * 0.55, 0.25, 0.85))
	projectile_requested.emit(origin, direction, enemy_owned, damage, weapon_id, self)

func _on_actor_died(source_position: Vector2) -> void:
	melee_animation_generation += 1
	targeting_mode_active = false
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

func classify_hit_zone(world_hit_position: Vector2) -> String:
	var local_hit := to_local(world_hit_position)
	if local_hit.x >= 3.0: return "head"
	if absf(local_hit.y) >= 3.2 or local_hit.x <= -4.0: return "limb"
	return "torso"

func get_lifecycle_pose() -> Dictionary:
	return lifecycle_rig.get_pose_snapshot() if is_instance_valid(lifecycle_rig) else {}

func apply_lifecycle_impact(direction: Vector2, power: float, hit_zone := "torso") -> void:
	lifecycle_context_impact_frame = Engine.get_physics_frames()
	if is_instance_valid(lifecycle_rig): lifecycle_rig.apply_hit(direction, power, hit_zone)

func _draw() -> void:
	_draw_aim_laser()
	if not is_dead and roll_time > 0.0 and roll_speed_multiplier > 1.0:
		var progress := 1.0 - roll_time / ROLL_DURATION
		var local_back := (-roll_direction).rotated(-global_rotation)
		for index in range(8):
			var side := (float(index) - 3.5) * 0.18
			var point := local_back.rotated(side) * (5.0 + progress * 13.0 + float(index % 3))
			PIXEL_PAINTER.pixel(self, point.round(), NeonPalette.BLOOD_CRIMSON)
	if is_dead:
		PIXEL_PAINTER.material_rect(self, Rect2(-5, -6, 10, 12), Color(0.2, 0.18, 0.22, 0.75), Color(0.26, 0.23, 0.28, 0.75), Color(0.1, 0.08, 0.12, 0.75), 17, &"fabric")
	if is_executing:
		PIXEL_PAINTER.arc(self, Vector2(6, -3), 3, -1.2, 1.2, Color("ffd6c2"), 6)
		PIXEL_PAINTER.arc(self, Vector2(6, 3), 3, -1.2, 1.2, Color("ffd6c2"), 6)
	if execution_pulse > 0.0:
		PIXEL_PAINTER.circle(self, Vector2(9, 0), 3, Color(1.0, 0.18, 0.25, execution_pulse / 0.11), true)

func _draw_aim_laser() -> void:
	if not Settings.aim_laser_enabled or is_dead or equipped_mode != "gun" or not is_instance_valid(gun) or gun.gun_data == null: return
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
