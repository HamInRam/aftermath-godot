extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal clean_requested(world_position: Vector2)
signal died
signal execution_impact(world_position: Vector2, direction: Vector2, lethal: bool)

@onready var gun = $Gun
var cleanup_mode := false
var is_executing := false
var execution_target: CharacterBody2D
var execution_pulse := 0.0

func _ready() -> void:
	super._ready()
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	queue_redraw()

func _physics_process(delta: float) -> void:
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
	if Input.is_action_just_pressed("interact"):
		attempt_door_slam(velocity)
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() > 0.001:
		rotation = aim.angle()
	var wants_to_fire := Input.is_action_pressed("shoot") if gun.automatic else Input.is_action_just_pressed("shoot")
	if wants_to_fire:
		if cleanup_mode:
			clean_requested.emit(get_global_mouse_position())
		else:
			gun.try_fire(Vector2.RIGHT.rotated(rotation))
	if Input.is_action_just_pressed("reload") and not cleanup_mode:
		gun.reload()

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

func get_nearby_slam_door() -> RigidBody2D:
	if is_executing or cleanup_mode or is_dead: return null
	var nearest: RigidBody2D = null
	var nearest_distance := 26.0 * 26.0
	for door_node in get_tree().get_nodes_in_group("swing_door"):
		if not door_node is RigidBody2D: continue
		var panel_center: Vector2 = door_node.global_position + Vector2(0, 8).rotated(door_node.global_rotation)
		var distance := global_position.distance_squared_to(panel_center)
		if distance <= nearest_distance:
			nearest = door_node
			nearest_distance = distance
	return nearest

func attempt_door_slam(current_velocity: Vector2) -> bool:
	var door := get_nearby_slam_door()
	if not is_instance_valid(door): return false
	door.slam_door(global_position, current_velocity, Vector2.RIGHT.rotated(rotation))
	return true

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
	gun.visible = not cleanup_mode
	queue_redraw()

func set_cleanup_mode(enabled: bool) -> void:
	cleanup_mode = enabled
	gun.visible = not enabled
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
