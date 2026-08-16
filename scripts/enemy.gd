extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal died_at(world_position: Vector2, facing: float)

@export var preferred_distance := 65.0
@export var shoot_range := 152.0
@export var detection_range := 205.0
@export_range(30.0, 160.0, 1.0) var vision_fov_degrees := 90.0
@export_range(0.05, 1.0, 0.01) var reaction_time_min := 0.2
@export_range(0.05, 1.0, 0.01) var reaction_time_max := 0.4
@export var debug_draw_vision := false
@export_enum("human", "dog") var actor_type := "human"
@export var patrol_waypoints := PackedVector2Array()
@export_range(0.1, 3.0, 0.1) var patrol_wait_min := 0.5
@export_range(0.1, 3.0, 0.1) var patrol_wait_max := 1.5
@export_range(5.0, 90.0, 1.0) var sentry_look_degrees := 45.0
@export_range(0.5, 8.0, 0.1) var sentry_turn_speed := 2.4
@export_range(1.0, 2.0, 0.05) var chase_speed_multiplier := 1.25
@export_range(0.5, 5.0, 0.1) var investigation_scan_duration := 2.2
@export_range(0.05, 1.0, 0.05) var corpse_scan_interval := 0.2
@export_group("Combat")
@export_enum("gunner", "melee") var enemy_type := "gunner"
@export_range(8.0, 40.0, 1.0) var melee_range := 17.0
@export_range(0.1, 2.0, 0.05) var melee_interval := 0.7
@export_range(0.2, 4.0, 0.1) var chase_memory_duration := 1.5
@onready var gun = $Gun

enum State { IDLE, INVESTIGATE, CHASE, STAGGERED }
enum PatrolMode { MOVING, WAITING, SENTRY }

var player: CharacterBody2D
var alertness := 0.0
var visual_exposure := 0.0
var reaction_time := 0.3
var strafe_sign := 1.0
var path_points := PackedVector2Array()
var path_refresh := 0.0
var tile_world: Node
var state := State.IDLE
var investigation_target := Vector2.ZERO
var investigation_wait := 0.0
var stagger_time := 0.0
var patrol_index := 0
var patrol_mode := PatrolMode.SENTRY
var patrol_wait_time := 0.0
var sentry_base_rotation := 0.0
var sentry_target_rotation := 0.0
var sentry_look_time := 0.0
var investigation_look_rotation := 0.0
var investigation_look_time := 0.0
var corpse_scan_time := 0.0
var discovered_corpses := {}
var player_in_sight := false
var chase_lost_time := 0.0
var melee_cooldown := 0.0
var melee_swing_time := 0.0

func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	tile_world = get_tree().get_first_node_in_group("pathfinding_world")
	strafe_sign = [-1.0, 1.0].pick_random()
	sentry_base_rotation = rotation
	_pick_sentry_angle()
	reaction_time = randf_range(reaction_time_min, maxf(reaction_time_min, reaction_time_max))
	if actor_type == "dog": reaction_time *= 0.55
	corpse_scan_time = randf_range(0.0, corpse_scan_interval)
	gun.cooldown = randf_range(0.25, 0.9)
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	Events.combat_noise.connect(_on_combat_noise)
	queue_redraw()

func _physics_process(delta: float) -> void:
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	melee_swing_time = maxf(0.0, melee_swing_time - delta)
	if melee_swing_time > 0.0: queue_redraw()
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
			_begin_investigation(global_position, 0.6)
		return
	var has_visual_contact := _can_see_player(distance, to_player)
	var has_direct_line := _has_direct_line_to_player()
	player_in_sight = has_visual_contact
	var sees_player := _update_visual_reaction(has_visual_contact, delta)
	if debug_draw_vision: queue_redraw()
	if sees_player or (state == State.CHASE and has_direct_line):
		state = State.CHASE
		alertness = 1.0
		investigation_target = player.global_position
		chase_lost_time = 0.0
	elif state == State.CHASE:
		chase_lost_time += delta
		if chase_lost_time >= chase_memory_duration or distance > detection_range * 1.5:
			_begin_investigation(investigation_target, 0.8)
	if state == State.IDLE: _scan_for_corpses(delta)
	if state == State.IDLE:
		_update_patrol(delta)
		return
	var target_position := player.global_position if state == State.CHASE else investigation_target
	var to_target := target_position - global_position
	var target_distance := to_target.length()
	if state == State.INVESTIGATE and target_distance < 7.0:
		investigation_wait += delta
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		move_and_slide()
		investigation_look_time -= delta
		if investigation_look_time <= 0.0:
			investigation_look_rotation = rotation + randf_range(-1.05, 1.05)
			investigation_look_time = randf_range(0.35, 0.7)
		rotation = lerp_angle(rotation, investigation_look_rotation, 1.0 - exp(-3.2 * delta))
		if investigation_wait >= investigation_scan_duration:
			state = State.IDLE
			alertness = 0.0
			investigation_wait = 0.0
		return
	var direction := to_target.normalized()
	var aim_direction := to_player.normalized()
	rotation = lerp_angle(rotation, direction.angle(), 1.0 - exp(-10.0 * delta))
	path_refresh -= delta
	var direct_chase := state == State.CHASE and has_direct_line
	if direct_chase:
		path_points.clear()
	elif path_refresh <= 0.0 and is_instance_valid(tile_world):
		path_refresh = (0.07 + randf_range(0.0, 0.035)) if actor_type == "dog" else (0.12 + randf_range(0.0, 0.05))
		path_points = tile_world.get_navigation_path(global_position, target_position)
	if not path_points.is_empty():
		while not path_points.is_empty() and global_position.distance_to(path_points[0]) < 5.0:
			path_points.remove_at(0)
		if not path_points.is_empty(): direction = global_position.direction_to(path_points[0])
	if state == State.CHASE:
		velocity = direction * move_speed * (1.9 if actor_type == "dog" else chase_speed_multiplier)
		if enemy_type == "melee" and distance <= melee_range * 0.7:
			velocity = Vector2.ZERO
		elif enemy_type == "gunner" and distance < 28.0:
			velocity = direction.rotated(PI * 0.5) * move_speed * 0.4 * strafe_sign
	elif state == State.INVESTIGATE or distance > preferred_distance:
		var speed_multiplier := (1.8 if actor_type == "dog" else chase_speed_multiplier) if state == State.CHASE else 1.0
		velocity = direction * move_speed * speed_multiplier
	elif distance < preferred_distance * 0.62:
		velocity = -direction * move_speed * 0.72
	else:
		velocity = direction.rotated(PI * 0.5) * move_speed * 0.32 * strafe_sign
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	if state == State.CHASE and has_direct_line:
		if enemy_type == "gunner" and distance <= shoot_range:
			if gun.ammo <= 0 and not gun.is_reloading: gun.reload()
			if gun.try_fire(aim_direction): gun.cooldown += randf_range(0.35, 0.75)
		elif enemy_type == "melee" and distance <= melee_range:
			_execute_melee_attack()

func _update_patrol(delta: float) -> void:
	if patrol_waypoints.size() < 2:
		patrol_mode = PatrolMode.SENTRY
		_update_sentry(delta)
		return
	if patrol_mode == PatrolMode.SENTRY:
		_update_sentry(delta)
		return
	if patrol_mode == PatrolMode.WAITING:
		patrol_wait_time -= delta
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
		move_and_slide()
		if patrol_wait_time <= 0.0:
			patrol_index = (patrol_index + 1) % patrol_waypoints.size()
			patrol_mode = PatrolMode.MOVING
			path_points.clear()
			path_refresh = 0.0
		return
	var patrol_target := patrol_waypoints[patrol_index]
	if global_position.distance_to(patrol_target) < 6.0:
		patrol_mode = PatrolMode.WAITING
		patrol_wait_time = randf_range(patrol_wait_min, maxf(patrol_wait_min, patrol_wait_max))
		velocity = Vector2.ZERO
		return
	if (path_points.is_empty() or path_refresh <= 0.0) and is_instance_valid(tile_world):
		path_refresh = 0.5
		path_points = tile_world.get_navigation_path(global_position, patrol_target)
		if path_points.is_empty():
			patrol_mode = PatrolMode.SENTRY
			sentry_base_rotation = rotation
			_pick_sentry_angle()
			return
	path_refresh -= delta
	while not path_points.is_empty() and global_position.distance_to(path_points[0]) < 5.0:
		path_points.remove_at(0)
	if path_points.is_empty(): return
	var patrol_direction := global_position.direction_to(path_points[0])
	rotation = lerp_angle(rotation, patrol_direction.angle(), 1.0 - exp(-8.0 * delta))
	velocity = patrol_direction * move_speed * 0.62
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)

func configure_patrol(points: PackedVector2Array) -> void:
	patrol_waypoints = points
	patrol_index = 0
	patrol_mode = PatrolMode.MOVING if points.size() >= 2 else PatrolMode.SENTRY
	path_points.clear()
	path_refresh = 0.0

func configure_combat(type_name: String) -> void:
	enemy_type = type_name if type_name in ["gunner", "melee"] else "gunner"
	var uses_gun := enemy_type == "gunner"
	gun.visible = uses_gun
	gun.set_process(uses_gun)

func _execute_melee_attack() -> void:
	if melee_cooldown > 0.0 or not is_instance_valid(player) or player.is_dead: return
	melee_cooldown = melee_interval
	melee_swing_time = 0.14
	queue_redraw()
	player.take_damage(1, global_position)

func _update_sentry(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
	move_and_slide()
	rotation = lerp_angle(rotation, sentry_target_rotation, 1.0 - exp(-sentry_turn_speed * delta))
	sentry_look_time -= delta
	if sentry_look_time <= 0.0: _pick_sentry_angle()

func _pick_sentry_angle() -> void:
	var range_radians := deg_to_rad(sentry_look_degrees)
	sentry_target_rotation = sentry_base_rotation + randf_range(-range_radians, range_radians)
	sentry_look_time = randf_range(2.0, 4.0)

func _update_visual_reaction(has_visual_contact: bool, delta: float) -> bool:
	if has_visual_contact:
		visual_exposure = minf(reaction_time, visual_exposure + delta)
		alertness = maxf(alertness, visual_exposure / reaction_time)
	else:
		visual_exposure = 0.0
		alertness = move_toward(alertness, 0.0, delta * 0.8)
	return has_visual_contact and visual_exposure >= reaction_time

func _scan_for_corpses(delta: float) -> void:
	corpse_scan_time -= delta
	if corpse_scan_time > 0.0: return
	corpse_scan_time = corpse_scan_interval
	for corpse_node in get_tree().get_nodes_in_group("corpse"):
		if not is_instance_valid(corpse_node): continue
		var corpse_id := corpse_node.get_instance_id()
		if discovered_corpses.has(corpse_id): continue
		var to_corpse: Vector2 = corpse_node.global_position - global_position
		if to_corpse.length() > detection_range * 0.8: continue
		var facing := Vector2.RIGHT.rotated(rotation)
		if absf(rad_to_deg(facing.angle_to(to_corpse.normalized()))) > vision_fov_degrees * 0.5: continue
		var query := PhysicsRayQueryParameters2D.create(global_position, corpse_node.global_position, 32)
		query.exclude = [get_rid()]
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): continue
		discovered_corpses[corpse_id] = true
		_begin_investigation(corpse_node.global_position, 0.78)
		return

func _begin_investigation(target: Vector2, new_alertness: float) -> void:
	state = State.INVESTIGATE
	investigation_target = target
	investigation_wait = 0.0
	investigation_look_rotation = rotation
	investigation_look_time = 0.0
	alertness = maxf(alertness, new_alertness)
	path_points.clear()
	path_refresh = 0.0

func _can_see_player(distance: float, to_player: Vector2) -> bool:
	if distance > detection_range: return false
	var facing := Vector2.RIGHT.rotated(rotation)
	if absf(rad_to_deg(facing.angle_to(to_player.normalized()))) > vision_fov_degrees * 0.5: return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 32)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _has_direct_line_to_player() -> bool:
	if not is_instance_valid(player): return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 32)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _on_combat_noise(world_position: Vector2, radius: float, _source_kind: String) -> void:
	if is_dead or state == State.CHASE: return
	var effective_distance := global_position.distance_to(world_position)
	if effective_distance > radius: return
	var query := PhysicsRayQueryParameters2D.create(global_position, world_position, 32)
	query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): effective_distance *= 1.5
	if effective_distance > radius: return
	_begin_investigation(world_position, 0.55)

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
	var death_parent := get_tree().current_scene
	if is_instance_valid(death_parent):
		death_particles.reparent(death_parent, true)
		death_particles.restart()
		death_particles.emitting = true
		get_tree().create_timer(death_particles.lifetime + 0.4).timeout.connect(death_particles.queue_free)
	died_at.emit(global_position, rotation)
	queue_free()

func _draw() -> void:
	if melee_swing_time > 0.0:
		draw_arc(Vector2.ZERO, melee_range, -0.65, 0.65, 10, Color("ffd0a8"), 2.0)
	if debug_draw_vision:
		var half_fov := deg_to_rad(vision_fov_degrees * 0.5)
		var vision_color := Color(0.2, 1.0, 0.45, 0.16) if player_in_sight else Color(1.0, 0.2, 0.32, 0.09)
		var points := PackedVector2Array([Vector2.ZERO])
		for index in range(17):
			var angle := lerpf(-half_fov, half_fov, float(index) / 16.0)
			points.append(Vector2.RIGHT.rotated(angle) * detection_range)
		draw_colored_polygon(points, vision_color)
		draw_arc(Vector2.ZERO, detection_range, -half_fov, half_fov, 24, Color(vision_color, 0.5), 1.0)
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(-half_fov) * detection_range, Color(vision_color, 0.5), 1.0)
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(half_fov) * detection_range, Color(vision_color, 0.5), 1.0)
	if alertness > 0.65: draw_circle(Vector2(-1, -7), 1.0, Color("ff385f"))
