extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal died_at(world_position: Vector2, facing: float)

@export var preferred_distance := 65.0
@export var shoot_range := 152.0
@export var detection_range := 205.0
@onready var gun = $Gun

var player: CharacterBody2D
var alertness := 0.0
var strafe_sign := 1.0
var path_points := PackedVector2Array()
var path_refresh := 0.0
var tile_world: Node

func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	tile_world = get_tree().get_first_node_in_group("pathfinding_world")
	strafe_sign = [-1.0, 1.0].pick_random()
	gun.cooldown = randf_range(0.25, 0.9)
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or player.is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 125.0 * delta)
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance < 0.001: return
	if distance > detection_range and alertness <= 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		move_and_slide()
		return
	alertness = minf(1.0, alertness + delta * 0.8)
	rotation = lerp_angle(rotation, to_player.angle(), 1.0 - exp(-8.0 * delta))
	var direction := to_player.normalized()
	path_refresh -= delta
	if path_refresh <= 0.0 and is_instance_valid(tile_world):
		path_refresh = 0.22 + randf_range(0.0, 0.08)
		path_points = tile_world.get_navigation_path(global_position, player.global_position)
	if not path_points.is_empty():
		while not path_points.is_empty() and global_position.distance_to(path_points[0]) < 5.0:
			path_points.remove_at(0)
		if not path_points.is_empty(): direction = global_position.direction_to(path_points[0])
	if distance > preferred_distance:
		velocity = direction * move_speed
	elif distance < preferred_distance * 0.62:
		velocity = -direction * move_speed * 0.72
	else:
		velocity = direction.rotated(PI * 0.5) * move_speed * 0.32 * strafe_sign
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	if distance <= shoot_range and alertness >= 0.8:
		if gun.ammo <= 0 and not gun.is_reloading: gun.reload()
		if gun.try_fire(direction): gun.cooldown += randf_range(0.35, 0.75)

func _on_gun_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	projectile_requested.emit(origin, direction, enemy_owned, damage, weapon_id)

func _on_actor_died(source_position: Vector2) -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	var death_particles: GPUParticles2D = $DeathBloodParticles
	var spray_direction := (global_position - source_position).normalized()
	if spray_direction.length_squared() < 0.001: spray_direction = Vector2.RIGHT.rotated(rotation)
	death_particles.rotation = spray_direction.angle()
	death_particles.reparent(get_tree().current_scene, true)
	death_particles.restart()
	death_particles.emitting = true
	get_tree().create_timer(death_particles.lifetime + 0.4).timeout.connect(death_particles.queue_free)
	died_at.emit(global_position, rotation)
	queue_free()

func _draw() -> void:
	if alertness > 0.65: draw_circle(Vector2(-1, -7), 1.0, Color("ff385f"))
