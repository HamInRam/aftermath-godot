extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal clean_requested(world_position: Vector2)
signal died
signal execution_impact(world_position: Vector2, direction: Vector2, lethal: bool)
signal melee_impact(target: CharacterBody2D, world_position: Vector2, direction: Vector2, melee_type: String, lethal: bool)

const MELEE_TRAIL_SCENE := preload("res://scenes/effects/melee_trail.tscn")
const MELEE_DATA := {
	"fist": {"range": 12.0, "angle": 35.0, "windup": 0.03, "cooldown": 0.18, "duration": 0.06, "lethal": false, "color": Color("ffffff")},
	"knife": {"range": 16.0, "angle": 45.0, "windup": 0.02, "cooldown": 0.22, "duration": 0.05, "lethal": true, "color": Color("00ffff")},
	"bat": {"range": 28.0, "angle": 120.0, "windup": 0.08, "cooldown": 0.42, "duration": 0.12, "lethal": true, "color": Color("ff007f")},
}

@onready var gun = $Gun
@onready var melee_shape: CollisionShape2D = $MeleeArea/CollisionShape2D
var cleanup_mode := false
var is_executing := false
var execution_target: CharacterBody2D
var execution_pulse := 0.0
var equipped_mode := "gun"
var current_melee_type := "fist"
var melee_cooldown := 0.0
var is_melee_attacking := false

func _ready() -> void:
	super._ready()
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	queue_redraw()

func _physics_process(delta: float) -> void:
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	execution_pulse = maxf(0.0, execution_pulse - delta)
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
	if Input.is_action_just_pressed("equip_gun"): _equip_weapon("gun")
	elif Input.is_action_just_pressed("equip_fist"): _equip_weapon("fist")
	elif Input.is_action_just_pressed("equip_knife"): _equip_weapon("knife")
	elif Input.is_action_just_pressed("equip_bat"): _equip_weapon("bat")

func _equip_weapon(mode: String) -> void:
	equipped_mode = "gun" if mode == "gun" else "melee"
	if mode != "gun": current_melee_type = mode
	gun.visible = equipped_mode == "gun" and not cleanup_mode and not is_executing
	queue_redraw()

func _start_melee_attack() -> void:
	if is_melee_attacking or melee_cooldown > 0.0 or is_dead or cleanup_mode: return
	var data: Dictionary = MELEE_DATA[current_melee_type]
	is_melee_attacking = true
	melee_cooldown = float(data.cooldown)
	_perform_melee_attack(data)

func _perform_melee_attack(data: Dictionary) -> void:
	await get_tree().create_timer(float(data.windup)).timeout
	if is_dead or cleanup_mode or equipped_mode == "gun":
		is_melee_attacking = false
		return
	_spawn_melee_trail(data)
	if melee_shape.shape is CircleShape2D:
		(melee_shape.shape as CircleShape2D).radius = float(data.range)
	melee_shape.position = Vector2(14.0, 0.0)
	var forward := Vector2.RIGHT.rotated(rotation)
	var half_angle := deg_to_rad(float(data.angle) * 0.5)
	for body in _query_melee_bodies():
		if not body is CharacterBody2D or not body.is_in_group("enemy") or body.is_dead: continue
		var offset: Vector2 = body.global_position - global_position
		if offset.length() > float(data.range) or absf(forward.angle_to(offset.normalized())) > half_angle: continue
		if _melee_blocked_by_geometry(body): continue
		melee_impact.emit(body, body.global_position, forward, current_melee_type, bool(data.lethal))
	is_melee_attacking = false

func _query_melee_bodies() -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = melee_shape.shape
	query.transform = melee_shape.global_transform
	query.collision_mask = 2
	query.exclude = [get_rid()]
	var bodies: Array = []
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		bodies.append(result.collider)
	return bodies

func _melee_blocked_by_geometry(target: CollisionObject2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 44)
	query.exclude = [get_rid(), target.get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _spawn_melee_trail(data: Dictionary) -> void:
	var trail = MELEE_TRAIL_SCENE.instantiate()
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position
	trail.global_rotation = rotation
	trail.setup(current_melee_type, float(data.range), deg_to_rad(float(data.angle)), float(data.duration), data.color)

func attempt_ground_execution() -> bool:
	if is_executing or cleanup_mode or is_dead: return false
	var nearest := get_nearby_execution_target()
	if not is_instance_valid(nearest): return false
	_start_execution_sequence(nearest)
	return true

func get_nearby_execution_target() -> CharacterBody2D:
	if is_executing or cleanup_mode or is_dead: return null
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = global_transform
	query.collision_mask = 2
	query.exclude = [get_rid()]
	var nearest: CharacterBody2D = null
	var nearest_distance := INF
	for result in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var candidate = result.collider
		if candidate is CharacterBody2D and candidate.has_method("is_knocked_down") and candidate.is_knocked_down():
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < nearest_distance:
				nearest = candidate
				nearest_distance = distance
	return nearest

func _start_execution_sequence(target: CharacterBody2D) -> void:
	is_executing = true
	execution_target = target
	velocity = Vector2.ZERO
	gun.visible = false
	var approach := global_position.direction_to(target.global_position)
	if approach.length_squared() < 0.001: approach = Vector2.RIGHT.rotated(rotation)
	global_position = target.global_position - approach * 6.0
	rotation = approach.angle()
	_run_execution_sequence(approach)

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
		if lethal: execution_target.execute_ground(global_position)
	await get_tree().create_timer(0.18).timeout
	_finish_execution()

func _finish_execution() -> void:
	is_executing = false
	execution_target = null
	gun.visible = equipped_mode == "gun" and not cleanup_mode
	queue_redraw()

func set_cleanup_mode(enabled: bool) -> void:
	cleanup_mode = enabled
	gun.visible = not enabled and equipped_mode == "gun"
	queue_redraw()

func _on_gun_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	projectile_requested.emit(origin, direction, enemy_owned, damage, weapon_id)

func _on_actor_died(source_position: Vector2) -> void:
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
	if equipped_mode == "melee" and not cleanup_mode:
		var tint: Color = MELEE_DATA[current_melee_type].color
		if current_melee_type == "fist":
			draw_circle(Vector2(7, -2), 1.7, tint)
			draw_circle(Vector2(7, 2), 1.7, tint)
		elif current_melee_type == "knife":
			draw_line(Vector2(4, 0), Vector2(12, 0), tint, 2.0)
			draw_line(Vector2(4, 0), Vector2(2, 2), Color("412e46"), 2.0)
		else:
			draw_line(Vector2(3, 0), Vector2(13, 0), tint, 3.0)
