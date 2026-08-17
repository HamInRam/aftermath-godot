extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal clean_requested(world_position: Vector2)
signal died
signal execution_impact(world_position: Vector2, direction: Vector2, lethal: bool)
signal melee_impact(target: CharacterBody2D, world_position: Vector2, direction: Vector2, melee_type: String, lethal: bool)

const MELEE_TRAIL_SCENE := preload("res://scenes/effects/melee_trail.tscn")
const PLAYER_GUNS := [
	preload("res://resources/weapons/pistol.tres"),
	preload("res://resources/weapons/smg.tres"),
	preload("res://resources/weapons/lmg.tres"),
]
const MELEE_DATA := {
	"fist": {"range": 12.0, "angle": 35.0, "windup": 0.03, "cooldown": 0.18, "duration": 0.06, "lethal": false, "color": Color("ffffff")},
	"knife": {"range": 16.0, "angle": 45.0, "windup": 0.02, "cooldown": 0.22, "duration": 0.05, "lethal": true, "color": Color("00ffff")},
	"bat": {"range": 28.0, "angle": 120.0, "windup": 0.08, "cooldown": 0.42, "duration": 0.12, "lethal": true, "color": Color("ff007f")},
}

@onready var upper_body: Node2D = $UpperBody
@onready var body_sprite: Sprite2D = $UpperBody/BodySprite
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
var cached_execution_target: CharacterBody2D
var execution_query_cooldown := 0.0

func _ready() -> void:
	super._ready()
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	queue_redraw()

func _physics_process(delta: float) -> void:
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	execution_pulse = maxf(0.0, execution_pulse - delta)
	execution_query_cooldown -= delta
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
	if Input.is_action_just_pressed("execute"):
		attempt_ground_execution()
		if is_executing: return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * move_speed
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() > 0.001:
		rotation = aim.angle()
	_handle_weapon_selection()
	var wants_to_fire := Input.is_action_pressed("shoot") if equipped_mode == "gun" and gun.automatic else Input.is_action_just_pressed("shoot")
	if wants_to_fire:
		if cleanup_mode:
			clean_requested.emit(get_global_mouse_position())
		elif equipped_mode != "gun":
			_start_melee_attack()
		else:
			gun.try_fire(Vector2.RIGHT.rotated(rotation))
	if Input.is_action_just_pressed("reload") and not cleanup_mode and equipped_mode == "gun":
		gun.reload()

func _handle_weapon_selection() -> void:
	if cleanup_mode or is_executing or is_melee_attacking: return
	if Input.is_action_just_pressed("equip_gun"):
		if equipped_mode == "gun": _cycle_gun()
		else: _equip_weapon("gun")
	elif Input.is_action_just_pressed("equip_fist"): _equip_weapon("fist")
	elif Input.is_action_just_pressed("equip_knife"): _equip_weapon("knife")
	elif Input.is_action_just_pressed("equip_bat"): _equip_weapon("bat")

func _equip_weapon(mode: String) -> void:
	equipped_mode = "gun" if mode == "gun" else "melee"
	if mode != "gun": current_melee_type = mode
	gun.visible = equipped_mode == "gun" and not cleanup_mode and not is_executing
	melee_weapon_visual.visible = equipped_mode == "melee" and not cleanup_mode and not is_executing
	if mode != "gun": melee_weapon_visual.set_weapon(current_melee_type)
	queue_redraw()

func _cycle_gun() -> void:
	gun_index = (gun_index + 1) % PLAYER_GUNS.size()
	gun.set_gun_data(PLAYER_GUNS[gun_index], true)
	queue_redraw()

func get_equipped_weapon_name() -> String:
	return str(gun.gun_data.display_name) if equipped_mode == "gun" and gun.gun_data != null else current_melee_type.to_upper()

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
	_spawn_melee_trail(data)
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
	for index in range(hit_limit):
		var target: CharacterBody2D = valid_targets[index]
		melee_impact.emit(target, target.global_position, forward, current_melee_type, bool(data.lethal))
	if hit_limit == 0:
		var miss_penalty := 0.08 if current_melee_type == "fist" else (0.12 if current_melee_type == "knife" else 0.18)
		melee_cooldown += miss_penalty
	else:
		var noise_radius := 48.0 if current_melee_type == "fist" else (62.0 if current_melee_type == "knife" else 90.0)
		Events.publish_combat_noise(global_position, noise_radius, "melee")
	await get_tree().create_timer(0.04).timeout
	if generation != melee_animation_generation:
		return
	var recover_time := maxf(0.06, float(data.cooldown) - float(data.windup) - 0.04)
	var recover_tween := create_tween().set_parallel(true)
	recover_tween.tween_property(body_sprite, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	recover_tween.tween_property(body_sprite, "rotation", 0.0, recover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await recover_tween.finished
	if generation == melee_animation_generation:
		_reset_melee_pose()
		is_melee_attacking = false

func _reset_melee_pose() -> void:
	if is_instance_valid(body_sprite):
		body_sprite.position = Vector2.ZERO
		body_sprite.rotation = 0.0

func _spawn_melee_trail(data: Dictionary) -> void:
	var trail = MELEE_TRAIL_SCENE.instantiate()
	get_tree().current_scene.add_child(trail)
	trail.global_position = melee_tip.global_position
	trail.global_rotation = melee_tip.global_rotation
	var tip_distance := global_position.distance_to(melee_tip.global_position)
	var remaining_visual_reach := maxf(2.0, float(data.range) - tip_distance)
	trail.setup(current_melee_type, remaining_visual_reach, deg_to_rad(float(data.angle)), float(data.duration), data.color)

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
	for strike in range(3):
		await get_tree().create_timer(0.18).timeout
		if not is_executing or not is_instance_valid(execution_target):
			_finish_execution()
			return
		execution_pulse = 0.11
		queue_redraw()
		var lethal := strike == 2
		execution_impact.emit(execution_target.global_position, impact_direction, lethal)
		Events.publish_combat_noise(execution_target.global_position, 95.0 if lethal else 58.0, "execution")
		if lethal: execution_target.execute_ground(global_position)
	await get_tree().create_timer(0.18).timeout
	_finish_execution()

func _finish_execution() -> void:
	is_executing = false
	execution_target = null
	gun.visible = equipped_mode == "gun" and not cleanup_mode
	melee_weapon_visual.visible = equipped_mode == "melee" and not cleanup_mode
	queue_redraw()

func set_cleanup_mode(enabled: bool) -> void:
	cleanup_mode = enabled
	if enabled:
		melee_animation_generation += 1
		is_melee_attacking = false
		_reset_melee_pose()
	gun.visible = not enabled and equipped_mode == "gun"
	melee_weapon_visual.visible = not enabled and equipped_mode == "melee"
	queue_redraw()

func _on_gun_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	projectile_requested.emit(origin, direction, enemy_owned, damage, weapon_id)

func _on_actor_died(source_position: Vector2) -> void:
	melee_animation_generation += 1
	_reset_melee_pose()
	if source_position != Vector2.ZERO:
		velocity = (global_position - source_position).normalized() * 70.0
	died.emit()
	queue_redraw()

func _draw() -> void:
	if is_dead:
		draw_rect(Rect2(-5, -6, 10, 12), Color(0.2, 0.18, 0.22, 0.75))
	if cleanup_mode:
		draw_rect(Rect2(-4, -5, 8, 9), Color(0.95, 0.85, 0.36, 0.55))
		draw_line(Vector2(3, 0), Vector2(9, 0), Color("d7e8ef"), 1.0)
		draw_rect(Rect2(8, -3, 2, 6), Color("81d4de"))
	if is_executing:
		draw_arc(Vector2(6, -3), 3.0, -1.2, 1.2, 6, Color("ffd6c2"), 2.0)
		draw_arc(Vector2(6, 3), 3.0, -1.2, 1.2, 6, Color("ffd6c2"), 2.0)
	if execution_pulse > 0.0:
		draw_circle(Vector2(9, 0), 3.5, Color(1.0, 0.18, 0.25, execution_pulse / 0.11))
