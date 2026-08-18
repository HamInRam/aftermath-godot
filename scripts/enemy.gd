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
@export_range(8.0, 48.0, 1.0) var search_radius := 22.0
@export_range(0.2, 1.5, 0.05) var search_point_pause := 0.55
@export_range(2.0, 12.0, 0.5) var search_duration_limit := 6.0
@export_range(0.4, 2.0, 0.1) var stuck_timeout := 1.0
@export_range(0.5, 6.0, 0.5) var stuck_minimum_progress := 2.0
@export_group("Combat")
@export_enum("gunner", "melee") var enemy_type := "gunner"
@export_range(8.0, 40.0, 1.0) var melee_range := 17.0
@export_range(0.1, 2.0, 0.05) var melee_interval := 0.7
@export_range(0.2, 4.0, 0.1) var chase_memory_duration := 1.5
@export_group("Alert Memory")
@export_range(1.0, 20.0, 0.5) var suspicious_memory_duration := 5.0
@export_range(2.0, 30.0, 0.5) var alert_memory_duration := 10.0
@onready var gun = $Gun

enum State { IDLE, INVESTIGATE, SEARCH, RETURN, CHASE, ATTACK, STAGGERED, KNOCKED_DOWN }
enum PatrolMode { MOVING, WAITING, SENTRY }
enum AlertLevel { NORMAL, SUSPICIOUS, ALERT }

var player: CharacterBody2D
var alertness := 0.0
var visual_exposure := 0.0
var reaction_time := 0.3
var strafe_sign := 1.0
var path_points := PackedVector2Array()
var path_refresh := 0.0
var tile_world: Node
var state := State.IDLE
var alert_level := AlertLevel.NORMAL
var alert_memory_time := 0.0
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
var last_seen_direction := Vector2.RIGHT
var search_points := PackedVector2Array()
var search_index := 0
var search_wait := 0.0
var search_time_remaining := 0.0
var search_timer_started := false
var claimed_corpse: Node2D
var attack_windup_time := 0.0
var melee_cooldown := 0.0
var melee_swing_time := 0.0
var is_fixed_sentry := false
var knockdown_time := 0.0
var progress_anchor := Vector2.ZERO
var progress_elapsed := 0.0
var stuck_recovery_attempts := 0
var tactical_role := "none"
var guard_alert_time := 0.0
var guard_facing := 0.0
var blocked_shot_time := 0.0
var reposition_time := 0.0
var reposition_sign := 1.0
var home_position := Vector2.ZERO
var return_target := Vector2.ZERO
var archetype_id := "gunner"
var default_weapon_id := ""
var attack_windup_multiplier := 1.0
var knockdown_resistance := 0.0
const KNOCKDOWN_DURATION := 4.0

func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	tile_world = get_tree().get_first_node_in_group("pathfinding_world")
	home_position = global_position
	strafe_sign = [-1.0, 1.0].pick_random()
	sentry_base_rotation = rotation
	_pick_sentry_angle()
	reaction_time = randf_range(reaction_time_min, maxf(reaction_time_min, reaction_time_max))
	if actor_type == "dog": reaction_time *= 0.55
	corpse_scan_time = randf_range(0.0, corpse_scan_interval)
	gun.cooldown = randf_range(0.25, 0.9)
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	progress_anchor = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	melee_swing_time = maxf(0.0, melee_swing_time - delta)
	reposition_time = maxf(0.0, reposition_time - delta)
	guard_alert_time = maxf(0.0, guard_alert_time - delta)
	_update_alert_memory(delta)
	if tactical_role == "guard" and guard_alert_time <= 0.0: tactical_role = "none"
	queue_redraw()
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
	if state == State.KNOCKED_DOWN:
		knockdown_time -= delta
		var knockdown_velocity := velocity
		move_and_slide()
		push_contact_bodies(knockdown_velocity)
		velocity = velocity.move_toward(Vector2.ZERO, 260.0 * delta)
		if knockdown_time <= 0.0:
			_set_knockdown_visual(false)
			_begin_search(global_position, Vector2.RIGHT.rotated(rotation))
		return
	var has_visual_contact := _can_see_player(distance, to_player)
	player_in_sight = has_visual_contact
	var sees_player := _update_visual_reaction(has_visual_contact, delta)
	if debug_draw_vision: queue_redraw()
	# Initial acquisition requires the reaction delay. Once alerted, raw visual
	# contact is enough to keep tracking, but a clear ray outside the FOV is not.
	if sees_player or (state in [State.CHASE, State.ATTACK] and has_visual_contact):
		_release_corpse_claim()
		if tactical_role == "none": tactical_role = "push"
		if state not in [State.CHASE, State.ATTACK]:
			state = State.CHASE
			_reset_movement_progress()
		alertness = 1.0
		_raise_alert(AlertLevel.ALERT, alert_memory_duration)
		investigation_target = player.global_position
		last_seen_direction = player.velocity.normalized() if player.velocity.length_squared() > 1.0 else to_player.normalized()
		chase_lost_time = 0.0
	elif state in [State.CHASE, State.ATTACK]:
		if state == State.ATTACK:
			state = State.CHASE
			attack_windup_time = 0.0
		chase_lost_time += delta
		if chase_lost_time >= chase_memory_duration:
			_begin_search(investigation_target, last_seen_direction)
	if state in [State.IDLE, State.INVESTIGATE, State.SEARCH, State.RETURN]: _scan_for_corpses(delta)
	if state == State.IDLE:
		_update_patrol(delta)
		return
	if state == State.RETURN:
		_update_return_to_patrol(delta)
		return
	if state == State.ATTACK:
		_update_attack(delta, to_player, distance, has_visual_contact)
		return
	if state == State.SEARCH:
		if search_timer_started:
			search_time_remaining -= delta
			if search_time_remaining <= 0.0:
				_finish_search()
				return
	var target_position := investigation_target
	if state == State.CHASE:
		target_position = player.global_position if has_visual_contact else investigation_target
	elif state == State.SEARCH and search_index < search_points.size():
		target_position = search_points[search_index]
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
			_complete_corpse_investigation()
			_begin_search(investigation_target, Vector2.RIGHT.rotated(rotation))
		return
	if state == State.SEARCH and target_distance < 7.0:
		if not search_timer_started:
			search_timer_started = true
			search_time_remaining = search_duration_limit * (1.25 if alert_level == AlertLevel.ALERT else 1.0)
		search_wait += delta
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		move_and_slide()
		investigation_look_time -= delta
		if investigation_look_time <= 0.0:
			investigation_look_rotation = rotation + randf_range(-1.2, 1.2)
			investigation_look_time = randf_range(0.22, 0.48)
		rotation = lerp_angle(rotation, investigation_look_rotation, 1.0 - exp(-5.0 * delta))
		if search_wait >= search_point_pause:
			_advance_search()
		return
	var direction := to_target.normalized()
	rotation = lerp_angle(rotation, direction.angle(), 1.0 - exp(-10.0 * delta))
	path_refresh -= delta
	var direct_chase := state == State.CHASE and has_visual_contact
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
		var holds_position := is_fixed_sentry or tactical_role == "guard"
		var tactical_distance := distance if has_visual_contact else target_distance
		velocity = EnemyCombatController.chase_velocity(enemy_type, direction, move_speed, chase_speed_multiplier, actor_type, tactical_distance, melee_range, holds_position, reposition_time, reposition_sign, strafe_sign)
	elif state in [State.INVESTIGATE, State.SEARCH] or distance > preferred_distance:
		var speed_multiplier := (1.8 if actor_type == "dog" else chase_speed_multiplier) if state == State.CHASE else 1.0
		velocity = direction * move_speed * speed_multiplier
	elif distance < preferred_distance * 0.62:
		velocity = -direction * move_speed * 0.72
	else:
		velocity = direction.rotated(PI * 0.5) * move_speed * 0.32 * strafe_sign
	if state in [State.CHASE, State.SEARCH, State.INVESTIGATE] and velocity.length_squared() > 1.0:
		var separation := EnemyNavigation.crowd_separation(self)
		velocity = (velocity + separation * move_speed * 0.32).limit_length(velocity.length())
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	_update_movement_progress(delta, intended_velocity.length_squared() > 1.0)
	if state == State.CHASE and has_visual_contact:
		if enemy_type == "gunner" and distance <= shoot_range:
			if gun.ammo <= 0 and not gun.is_reloading: gun.reload()
			elif gun.cooldown <= 0.0 and not gun.is_reloading:
				if _has_clear_shot():
					blocked_shot_time = 0.0
					_begin_attack()
				else:
					blocked_shot_time += delta
					if blocked_shot_time >= 0.18 and not is_fixed_sentry and tactical_role != "guard":
						blocked_shot_time = 0.0
						reposition_time = 0.72
						reposition_sign = EnemyCombatController.choose_reposition_sign(self, player)
		elif enemy_type == "melee" and distance <= melee_range and melee_cooldown <= 0.0:
			_begin_attack()

func _update_patrol(delta: float) -> void:
	if tactical_role == "guard" and guard_alert_time > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
		move_and_slide()
		rotation = lerp_angle(rotation, guard_facing, 1.0 - exp(-8.0 * delta))
		_reset_movement_progress()
		return
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
	_update_movement_progress(delta, intended_velocity.length_squared() > 1.0)

func configure_patrol(points: PackedVector2Array) -> void:
	patrol_waypoints = points
	patrol_index = 0
	patrol_mode = PatrolMode.MOVING if points.size() >= 2 else PatrolMode.SENTRY
	path_points.clear()
	path_refresh = 0.0
	_reset_movement_progress()
	if not points.is_empty(): home_position = points[0]

func configure_combat(type_name: String) -> void:
	var profile := EnemyCatalog.get_profile(type_name)
	archetype_id = profile.archetype_id
	enemy_type = profile.combat_type
	actor_type = profile.actor_type
	default_weapon_id = profile.default_weapon_id
	move_speed = profile.move_speed
	chase_speed_multiplier = profile.chase_speed_multiplier
	preferred_distance = profile.preferred_distance
	detection_range = profile.detection_range
	vision_fov_degrees = profile.vision_fov_degrees
	reaction_time_min = profile.reaction_time_min
	reaction_time_max = profile.reaction_time_max
	reaction_time = randf_range(reaction_time_min, maxf(reaction_time_min, reaction_time_max))
	melee_range = profile.melee_range
	melee_interval = profile.melee_interval
	attack_windup_multiplier = profile.attack_windup_multiplier
	knockdown_resistance = profile.knockdown_resistance
	var uses_gun := enemy_type == "gunner"
	gun.visible = uses_gun
	gun.set_process(uses_gun)
	$Sprite2D.modulate = profile.sprite_modulate

func configure_fixed_sentry() -> void:
	is_fixed_sentry = true
	home_position = global_position
	configure_patrol(PackedVector2Array())

func _execute_melee_attack() -> void:
	if melee_cooldown > 0.0 or not is_instance_valid(player) or player.is_dead: return
	melee_cooldown = melee_interval
	melee_swing_time = 0.14
	queue_redraw()
	player.take_damage(1, global_position)

func _begin_attack() -> void:
	if state == State.ATTACK: return
	state = State.ATTACK
	attack_windup_time = EnemyCombatController.attack_windup(enemy_type) * attack_windup_multiplier
	velocity = Vector2.ZERO
	_reset_movement_progress()
	queue_redraw()

func _update_attack(delta: float, to_player: Vector2, distance: float, has_visual_contact: bool) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 240.0 * delta)
	move_and_slide()
	if not has_visual_contact:
		state = State.CHASE
		attack_windup_time = 0.0
		return
	rotation = lerp_angle(rotation, to_player.angle(), 1.0 - exp(-18.0 * delta))
	attack_windup_time -= delta
	queue_redraw()
	if attack_windup_time > 0.0: return
	if enemy_type == "gunner":
		if distance <= shoot_range and _has_clear_shot() and gun.try_fire(to_player.normalized()):
			gun.cooldown += randf_range(0.35, 0.75)
	elif distance <= melee_range:
		_execute_melee_attack()
	state = State.CHASE
	attack_windup_time = 0.0

func _has_clear_shot() -> bool:
	return EnemyCombatController.has_clear_shot(self, gun, player)

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
	var reaction_multiplier := 1.0
	if alert_level == AlertLevel.SUSPICIOUS: reaction_multiplier = 0.72
	elif alert_level == AlertLevel.ALERT: reaction_multiplier = 0.48
	var effective_reaction_time := reaction_time * reaction_multiplier
	if has_visual_contact:
		visual_exposure = minf(effective_reaction_time, visual_exposure + delta)
		alertness = maxf(alertness, visual_exposure / effective_reaction_time)
	else:
		visual_exposure = 0.0
		alertness = move_toward(alertness, 0.0, delta * 0.8)
	return has_visual_contact and visual_exposure >= effective_reaction_time

func _scan_for_corpses(delta: float) -> void:
	if is_fixed_sentry or is_instance_valid(claimed_corpse): return
	corpse_scan_time -= delta
	if corpse_scan_time > 0.0: return
	corpse_scan_time = corpse_scan_interval
	for corpse_node in get_tree().get_nodes_in_group("corpse"):
		if not is_instance_valid(corpse_node): continue
		var corpse_id := corpse_node.get_instance_id()
		if discovered_corpses.has(corpse_id): continue
		if not EnemyPerception.can_see_position(self, corpse_node.global_position, detection_range * 0.8, vision_fov_degrees, 32): continue
		if not corpse_node.has_method("try_claim_investigation") or not corpse_node.try_claim_investigation(self):
			if corpse_node.has_method("is_investigation_complete") and corpse_node.is_investigation_complete():
				discovered_corpses[corpse_id] = true
			continue
		discovered_corpses[corpse_id] = true
		claimed_corpse = corpse_node
		_raise_alert(AlertLevel.ALERT, alert_memory_duration)
		_begin_investigation(corpse_node.global_position, 0.78, true)
		Events.publish_tactical_alert(corpse_node.global_position, Vector2.RIGHT.rotated(corpse_node.rotation), "corpse", self)
		return

func _begin_investigation(target: Vector2, new_alertness: float, keep_corpse_claim := false) -> void:
	if not keep_corpse_claim: _release_corpse_claim()
	state = State.INVESTIGATE
	investigation_target = target
	investigation_wait = 0.0
	investigation_look_rotation = rotation
	investigation_look_time = 0.0
	alertness = maxf(alertness, new_alertness)
	search_points.clear()
	search_index = 0
	search_wait = 0.0
	search_time_remaining = 0.0
	search_timer_started = false
	attack_windup_time = 0.0
	path_points.clear()
	path_refresh = 0.0
	_reset_movement_progress()

func _begin_search(origin: Vector2, likely_direction: Vector2) -> void:
	if is_fixed_sentry:
		state = State.IDLE
		alertness = 0.0
		return
	state = State.SEARCH
	search_points.clear()
	search_index = 0
	search_wait = 0.0
	search_time_remaining = 0.0
	search_timer_started = false
	attack_windup_time = 0.0
	var direction := likely_direction.normalized()
	if direction.length_squared() < 0.001: direction = Vector2.RIGHT.rotated(rotation)
	var distance_scale := 0.85 + float(get_instance_id() % 4) * 0.1
	for point in EnemyNavigation.build_directional_search(tile_world, origin, direction, search_radius, distance_scale, strafe_sign):
		search_points.append(point)
	if search_points.is_empty():
		_begin_return_to_patrol()
		return
	investigation_target = search_points[0]
	investigation_look_time = 0.0
	path_points.clear()
	path_refresh = 0.0
	_reset_movement_progress()

func _begin_sector_search(origin: Vector2, likely_direction: Vector2, sector_sign: float) -> void:
	if is_fixed_sentry: return
	state = State.SEARCH
	search_points = EnemyNavigation.build_sector_search(tile_world, origin, likely_direction, search_radius, sector_sign)
	search_index = 0
	search_wait = 0.0
	search_time_remaining = 0.0
	search_timer_started = false
	attack_windup_time = 0.0
	if search_points.is_empty():
		_begin_return_to_patrol()
		return
	investigation_target = search_points[0]
	investigation_look_time = 0.0
	path_points.clear()
	path_refresh = 0.0
	_reset_movement_progress()

func _advance_search() -> void:
	search_index += 1
	search_wait = 0.0
	investigation_look_time = 0.0
	path_points.clear()
	path_refresh = 0.0
	_reset_movement_progress()
	if search_index >= search_points.size():
		_finish_search()
		return
	investigation_target = search_points[search_index]

func _finish_search() -> void:
	search_points.clear()
	search_index = 0
	search_wait = 0.0
	search_time_remaining = 0.0
	search_timer_started = false
	path_points.clear()
	path_refresh = 0.0
	_begin_return_to_patrol()

func _begin_return_to_patrol() -> void:
	_release_corpse_claim()
	tactical_role = "none"
	state = State.RETURN
	return_target = home_position
	if not patrol_waypoints.is_empty():
		var nearest_index := 0
		var nearest_distance := INF
		for index in range(patrol_waypoints.size()):
			var waypoint_distance := global_position.distance_squared_to(patrol_waypoints[index])
			if waypoint_distance < nearest_distance:
				nearest_distance = waypoint_distance
				nearest_index = index
		patrol_index = nearest_index
		return_target = patrol_waypoints[nearest_index]
	path_points.clear()
	path_refresh = 0.0
	_reset_movement_progress()

func _update_return_to_patrol(delta: float) -> void:
	if global_position.distance_to(return_target) < 6.0:
		state = State.IDLE
		patrol_mode = PatrolMode.WAITING if patrol_waypoints.size() >= 2 else PatrolMode.SENTRY
		patrol_wait_time = randf_range(patrol_wait_min, maxf(patrol_wait_min, patrol_wait_max))
		sentry_base_rotation = rotation
		_pick_sentry_angle()
		velocity = Vector2.ZERO
		_reset_movement_progress()
		return
	var direction := global_position.direction_to(return_target)
	path_refresh -= delta
	if path_refresh <= 0.0 and is_instance_valid(tile_world):
		path_refresh = 0.3
		path_points = tile_world.get_navigation_path(global_position, return_target)
	while not path_points.is_empty() and global_position.distance_to(path_points[0]) < 5.0:
		path_points.remove_at(0)
	if not path_points.is_empty(): direction = global_position.direction_to(path_points[0])
	rotation = lerp_angle(rotation, direction.angle(), 1.0 - exp(-8.0 * delta))
	velocity = direction * move_speed * 0.72
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	_update_movement_progress(delta, true)

func _complete_corpse_investigation() -> void:
	if not is_instance_valid(claimed_corpse):
		claimed_corpse = null
		return
	if claimed_corpse.has_method("complete_investigation"):
		claimed_corpse.complete_investigation(self)
	claimed_corpse = null

func _release_corpse_claim() -> void:
	if not is_instance_valid(claimed_corpse):
		claimed_corpse = null
		return
	if claimed_corpse.has_method("release_investigation"):
		claimed_corpse.release_investigation(self)
	claimed_corpse = null

func _reset_movement_progress() -> void:
	progress_anchor = global_position
	progress_elapsed = 0.0
	stuck_recovery_attempts = 0

func _update_movement_progress(delta: float, expected_to_move: bool) -> void:
	if not expected_to_move:
		progress_anchor = global_position
		progress_elapsed = 0.0
		stuck_recovery_attempts = 0
		return
	if global_position.distance_to(progress_anchor) >= stuck_minimum_progress:
		_reset_movement_progress()
		return
	progress_elapsed += delta
	if progress_elapsed < stuck_timeout: return
	progress_anchor = global_position
	progress_elapsed = 0.0
	stuck_recovery_attempts += 1
	path_points.clear()
	path_refresh = 0.0
	if stuck_recovery_attempts < 2: return
	stuck_recovery_attempts = 0
	match state:
		State.SEARCH:
			_advance_search()
		State.INVESTIGATE:
			_release_corpse_claim()
			_begin_return_to_patrol()
		State.RETURN:
			state = State.IDLE
			tactical_role = "none"
		State.CHASE:
			strafe_sign *= -1.0
			reposition_sign *= -1.0
		State.IDLE:
			if patrol_waypoints.size() >= 2:
				patrol_index = (patrol_index + 1) % patrol_waypoints.size()

func _can_see_player(distance: float, to_player: Vector2) -> bool:
	var range_multiplier := 1.0 if alert_level == AlertLevel.NORMAL else (1.08 if alert_level == AlertLevel.SUSPICIOUS else 1.16)
	var effective_range := detection_range * range_multiplier
	if distance > effective_range or to_player.length_squared() < 0.001: return false
	return EnemyPerception.can_see_target(self, player, effective_range, vision_fov_degrees, 32)

func get_noise_response_priority(world_position: Vector2, radius: float) -> float:
	var response := evaluate_noise_response(world_position, radius)
	return float(response.priority) if bool(response.eligible) else INF

func evaluate_noise_response(world_position: Vector2, radius: float) -> Dictionary:
	if is_dead or state in [State.CHASE, State.ATTACK, State.STAGGERED, State.KNOCKED_DOWN] or is_fixed_sentry:
		return {"eligible": false, "priority": INF, "occluded": false}
	return EnemyPerception.evaluate_noise(self, world_position, radius, 32)

func receive_combat_noise(world_position: Vector2, radius: float, _source_kind: String, role: String) -> bool:
	return receive_combat_noise_result(world_position, radius, _source_kind, role, evaluate_noise_response(world_position, radius))

func receive_combat_noise_result(world_position: Vector2, radius: float, _source_kind: String, role: String, response: Dictionary) -> bool:
	if not bool(response.get("eligible", false)): return false
	var effective_distance := float(response.priority)
	tactical_role = role
	_raise_alert(AlertLevel.ALERT if _source_kind == "gunshot" else AlertLevel.SUSPICIOUS, alert_memory_duration if _source_kind == "gunshot" else suspicious_memory_duration)
	if role == "guard":
		guard_alert_time = 3.5
		guard_facing = global_position.direction_to(world_position).angle()
		alertness = maxf(alertness, 0.48)
		queue_redraw()
		return true
	var occluded := bool(response.get("occluded", false))
	var distance_ratio := clampf(effective_distance / maxf(radius, 1.0), 0.0, 1.0)
	var uncertainty := lerpf(2.0, 15.0, distance_ratio) + (9.0 if occluded else 0.0)
	var perceived_position := world_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(0.0, uncertainty)
	if role == "sweep":
		var approach := global_position.direction_to(world_position)
		perceived_position += approach.rotated(PI * 0.5 * strafe_sign) * search_radius * 1.4
	if is_instance_valid(tile_world) and tile_world.has_method("is_navigation_position_walkable"):
		if not tile_world.is_navigation_position_walkable(perceived_position): perceived_position = world_position
	_begin_investigation(perceived_position, 0.55)
	return true

func evaluate_tactical_assignment(world_position: Vector2) -> Dictionary:
	if is_dead or is_instance_valid(claimed_corpse) or state in [State.CHASE, State.ATTACK, State.STAGGERED, State.KNOCKED_DOWN] or is_fixed_sentry:
		return {"eligible": false, "priority": INF}
	return {"eligible": true, "priority": global_position.distance_to(world_position)}

func receive_tactical_assignment(world_position: Vector2, likely_direction: Vector2, _source_kind: String, role: String) -> bool:
	var response := evaluate_tactical_assignment(world_position)
	if not bool(response.get("eligible", false)): return false
	_raise_alert(AlertLevel.ALERT, alert_memory_duration)
	tactical_role = role
	match role:
		"sweep_left":
			_begin_sector_search(world_position, likely_direction, -1.0)
		"sweep_right":
			_begin_sector_search(world_position, likely_direction, 1.0)
		"guard":
			guard_alert_time = minf(alert_memory_duration, 6.0)
			guard_facing = global_position.direction_to(world_position).angle()
			state = State.IDLE
			path_points.clear()
		"observe":
			if state == State.IDLE:
				guard_facing = global_position.direction_to(world_position).angle()
	queue_redraw()
	return true

func _raise_alert(level: AlertLevel, duration: float) -> void:
	alert_level = maxi(alert_level, level)
	alert_memory_time = maxf(alert_memory_time, duration)
	alertness = maxf(alertness, 0.5 if level == AlertLevel.SUSPICIOUS else 1.0)

func _update_alert_memory(delta: float) -> void:
	if alert_level == AlertLevel.NORMAL: return
	if state in [State.CHASE, State.ATTACK]:
		alert_memory_time = maxf(alert_memory_time, alert_memory_duration)
		return
	alert_memory_time = maxf(0.0, alert_memory_time - delta)
	if alert_memory_time > 0.0: return
	if alert_level == AlertLevel.ALERT:
		alert_level = AlertLevel.SUSPICIOUS
		alert_memory_time = suspicious_memory_duration
		alertness = minf(alertness, 0.62)
	else:
		alert_level = AlertLevel.NORMAL
		alertness = 0.0
		if tactical_role == "observe": tactical_role = "none"

func apply_stagger(push_direction: Vector2, duration: float) -> void:
	if is_dead: return
	_release_corpse_claim()
	state = State.STAGGERED
	_reset_movement_progress()
	stagger_time = duration
	velocity = push_direction.normalized() * 62.0
	gun.cooldown = maxf(gun.cooldown, duration)

func take_door_hit(hit_direction: Vector2, hit_type: String) -> void:
	if is_dead: return
	_release_corpse_claim()
	if hit_type == "kill":
		take_damage(1, global_position - hit_direction)
		return
	if knockdown_resistance >= 1.0:
		apply_stagger(hit_direction, 0.24)
		return
	state = State.KNOCKED_DOWN
	_reset_movement_progress()
	knockdown_time = KNOCKDOWN_DURATION
	velocity = hit_direction.normalized() * 150.0
	gun.cooldown = maxf(gun.cooldown, knockdown_time)
	_set_knockdown_visual(true)

func is_knocked_down() -> bool:
	return not is_dead and state == State.KNOCKED_DOWN

func is_actively_engaging_player() -> bool:
	return not is_dead and state in [State.CHASE, State.ATTACK]

func execute_ground(source_position: Vector2) -> void:
	if not is_knocked_down(): return
	_set_knockdown_visual(false)
	take_damage(maxi(1, hp), source_position)

func _set_knockdown_visual(enabled: bool) -> void:
	$Sprite2D.rotation = PI * 0.5 if enabled else 0.0
	$FakeShadow.rotation = PI * 0.5 if enabled else 0.0
	gun.visible = false if enabled else enemy_type == "gunner"
	queue_redraw()

func _on_gun_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	projectile_requested.emit(origin, direction, enemy_owned, damage, weapon_id)

func _on_actor_died(source_position: Vector2) -> void:
	_release_corpse_claim()
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
	if state == State.ATTACK and attack_windup_time > 0.0:
		draw_arc(Vector2.ZERO, 9.0, -0.48, 0.48, 8, Color("ffe56b"), 1.5)
		draw_circle(Vector2(7, 0), 1.2, Color("fff3b0"))
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
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	if state == State.INVESTIGATE:
		draw_arc(Vector2(0, -10), 2.4, -PI * 0.85, PI * 0.35, 7, Color("ffd166"), 1.0)
		draw_circle(Vector2(0, -6.5), 0.8, Color("ffd166"))
	elif state == State.SEARCH:
		draw_arc(Vector2(0, -9), 3.0, -PI * 0.2, PI * 1.3, 9, Color("66e0ff"), 1.0)
		draw_line(Vector2(2, -7), Vector2(4, -5), Color("66e0ff"), 1.0)
	elif state == State.RETURN:
		draw_line(Vector2(-3, -9), Vector2(3, -9), Color("9cc8ff"), 1.0)
		draw_line(Vector2(-3, -9), Vector2(-1, -11), Color("9cc8ff"), 1.0)
	elif state in [State.CHASE, State.ATTACK]:
		draw_line(Vector2(0, -12), Vector2(0, -8), Color("ff385f"), 1.5)
		draw_circle(Vector2(0, -6.5), 0.9, Color("ff385f"))
	elif tactical_role == "guard" and guard_alert_time > 0.0:
		draw_line(Vector2(-3, -9), Vector2(3, -9), Color("9cf7c8"), 1.0)
		draw_line(Vector2(-3, -9), Vector2(0, -6), Color("9cf7c8"), 1.0)
		draw_line(Vector2(3, -9), Vector2(0, -6), Color("9cf7c8"), 1.0)
