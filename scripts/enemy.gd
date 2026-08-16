extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal died_at(world_position: Vector2, facing: float)

@export var preferred_distance := 65.0
@export var shoot_range := 152.0
@export var detection_range := 205.0
@export_range(30.0, 160.0, 1.0) var vision_fov_degrees := 90.0
@onready var gun = $Gun

enum State { IDLE, INVESTIGATE, CHASE, STAGGERED }

var player: CharacterBody2D
var alertness := 0.0
var strafe_sign := 1.0
var path_points := PackedVector2Array()
var path_refresh := 0.0
var tile_world: Node
var state := State.IDLE
var investigation_target := Vector2.ZERO
var investigation_wait := 0.0
var stagger_time := 0.0

func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	tile_world = get_tree().get_first_node_in_group("pathfinding_world")
	strafe_sign = [-1.0, 1.0].pick_random()
	gun.cooldown = randf_range(0.25, 0.9)
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	Events.combat_noise.connect(_on_combat_noise)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or player.is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 125.0 * delta)
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance < 0.001: return
	if state == State.STAGGERED:
		stagger_time -= delta
		var stagger_velocity := velocity
		move_and_slide()
		push_contact_bodies(stagger_velocity)
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		if stagger_time <= 0.0:
			state = State.INVESTIGATE
			investigation_target = global_position
		return
	var sees_player := _can_see_player(distance, to_player)
	if sees_player:
		state = State.CHASE
		alertness = 1.0
		investigation_target = player.global_position
	elif state == State.CHASE:
		state = State.INVESTIGATE
		investigation_wait = 0.0
	if state == State.IDLE:
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		move_and_slide()
		return
	var target_position := player.global_position if state == State.CHASE else investigation_target
	var to_target := target_position - global_position
	var target_distance := to_target.length()
	if state == State.INVESTIGATE and target_distance < 7.0:
		investigation_wait += delta
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		move_and_slide()
		if investigation_wait >= 0.7:
			state = State.IDLE
			alertness = 0.0
			investigation_wait = 0.0
		return
	var direction := to_target.normalized()
	var aim_direction := to_player.normalized()
	rotation = lerp_angle(rotation, direction.angle(), 1.0 - exp(-10.0 * delta))
	path_refresh -= delta
	if path_refresh <= 0.0 and is_instance_valid(tile_world):
		path_refresh = 0.22 + randf_range(0.0, 0.08)
		path_points = tile_world.get_navigation_path(global_position, target_position)
	if not path_points.is_empty():
		while not path_points.is_empty() and global_position.distance_to(path_points[0]) < 5.0:
			path_points.remove_at(0)
		if not path_points.is_empty(): direction = global_position.direction_to(path_points[0])
	if state == State.INVESTIGATE or distance > preferred_distance:
		velocity = direction * move_speed
	elif distance < preferred_distance * 0.62:
		velocity = -direction * move_speed * 0.72
	else:
		velocity = direction.rotated(PI * 0.5) * move_speed * 0.32 * strafe_sign
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	if state == State.CHASE and sees_player and distance <= shoot_range:
		if gun.ammo <= 0 and not gun.is_reloading: gun.reload()
		if gun.try_fire(aim_direction): gun.cooldown += randf_range(0.35, 0.75)

func _can_see_player(distance: float, to_player: Vector2) -> bool:
	if distance > detection_range: return false
	var facing := Vector2.RIGHT.rotated(rotation)
	if absf(rad_to_deg(facing.angle_to(to_player.normalized()))) > vision_fov_degrees * 0.5: return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 2)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _on_combat_noise(world_position: Vector2, radius: float, _source_kind: String) -> void:
	if is_dead or state == State.CHASE: return
	if global_position.distance_to(world_position) > radius: return
	state = State.INVESTIGATE
	investigation_target = world_position
	investigation_wait = 0.0
	alertness = 0.55
	path_refresh = 0.0

func apply_stagger(push_direction: Vector2, duration: float) -> void:
	if is_dead: return
	state = State.STAGGERED
	stagger_time = duration
	velocity = push_direction.normalized() * 62.0
	gun.cooldown = maxf(gun.cooldown, duration)

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
