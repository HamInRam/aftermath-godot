extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal clean_requested(world_position: Vector2)
signal died

@onready var gun = $Gun
var cleanup_mode := false

func _ready() -> void:
	super._ready()
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		var death_velocity := velocity
		move_and_slide()
		push_contact_bodies(death_velocity)
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = velocity.lerp(input_direction * move_speed, 1.0 - exp(-18.0 * delta))
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() > 0.001:
		rotation = aim.angle()
	if Input.is_action_pressed("shoot"):
		if cleanup_mode:
			clean_requested.emit(get_global_mouse_position())
		else:
			gun.try_fire(Vector2.RIGHT.rotated(rotation))
	if Input.is_action_just_pressed("reload") and not cleanup_mode:
		gun.reload()

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
