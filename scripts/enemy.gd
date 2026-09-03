extends "res://scripts/actor.gd"

signal projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String, shooter: CollisionObject2D)
signal died_at(world_position: Vector2, facing: float)

const RAGDOLL_IMPACT := preload("res://scripts/combat/ragdoll_impact_resolver.gd")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const PIXEL_ACTOR_FRAMES := preload("res://utility/pixel_actor_texture_factory.gd")

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
@onready var legs_visual: PixelActorPart = $LegsVisual
@onready var lifecycle_rig = $LifecycleRig

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
var noise_reaction_delay := 0.0
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
var discovered_blood_clues := {}
static var blood_clue_cache_bucket := -1
static var blood_clue_region_cache: Dictionary = {}
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
var attack_windup_duration := 0.0
var committed_aim_position := Vector2.ZERO
var aim_tracking_strength := 0.15
var enemy_spread_multiplier := 2.4
var distance_spread_multiplier := 1.0
var aim_prediction_seconds := 0.07
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
var tactical_move_mode := ""
var tactical_cover_position := Vector2.ZERO
var tactical_peek_position := Vector2.ZERO
var tactical_move_time := 0.0
var tactical_hold_time := 0.0
var vision_scan_cooldown := 0.0
var cached_visual_contact := false
var alert_transition_pulse := 0.0
var tactical_player_anchor := Vector2.ZERO
var tactical_decision_cooldown := 0.0
var weapon_pickup_target: Node2D
var weapon_pickup_scan_time := 0.0
var archetype_id := "gunner"
var default_weapon_id := ""
var attack_windup_multiplier := 1.0
var knockdown_resistance := 0.0
var previous_visual_state := State.IDLE
var state_pose_pulse := 0.0
var knockdown_pose_phase := 0.0
var lifecycle_context_impact_frame := -1
var combat_time_scale := 1.0
const KNOCKDOWN_DURATION := 4.0

static func clear_shared_caches() -> void:
	blood_clue_cache_bucket = -1
	blood_clue_region_cache.clear()

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
	vision_scan_cooldown = randf_range(0.0, 0.055)
	gun.cooldown = randf_range(0.25, 0.9)
	gun.fired.connect(_on_gun_fired)
	actor_died.connect(_on_actor_died)
	hit_received.connect(_on_hit_received)
	progress_anchor = global_position
	_apply_compatibility_frame()
	legs_visual.visible = false
	$Sprite2D.visible = false
	$FakeShadow.visible = false
	lifecycle_rig.configure("hound" if actor_type == "dog" else "enemy", Color("6e4a37") if actor_type == "dog" else Color("7c235b"), Color("e8d8c8") if actor_type == "dog" else Color("f23d78"), "hound" if actor_type == "dog" else archetype_id)
	queue_redraw()

func _physics_process(delta: float) -> void:
	# Focus is hostile-local. Scaling AI time here keeps player input, aim and the
	# camera on the real clock while enemy decisions and rotations advance slowly.
	delta *= combat_time_scale
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	melee_swing_time = maxf(0.0, melee_swing_time - delta)
	reposition_time = maxf(0.0, reposition_time - delta)
	tactical_decision_cooldown = maxf(0.0, tactical_decision_cooldown - delta)
	if not tactical_move_mode.is_empty():
		tactical_move_time = maxf(0.0, tactical_move_time - delta)
		if tactical_move_time <= 0.0 or (is_instance_valid(player) and player.global_position.distance_to(tactical_player_anchor) > 52.0):
			_clear_tactical_move()
	guard_alert_time = maxf(0.0, guard_alert_time - delta)
	alert_transition_pulse = maxf(0.0, alert_transition_pulse - delta)
	state_pose_pulse = maxf(0.0, state_pose_pulse - delta)
	if is_instance_valid(legs_visual) and legs_visual.visible:
		var local_motion := velocity.rotated(-rotation)
		if local_motion.length_squared() > 0.5: legs_visual.rotation = local_motion.angle()
		legs_visual.update_pose(delta, local_motion, move_speed, "attack" if state == State.ATTACK else "idle", clampf(state_pose_pulse / 0.22, 0.0, 1.0))
	if is_instance_valid(lifecycle_rig):
		var rig_action := "attack" if state == State.ATTACK or melee_swing_time > 0.0 else "idle"
		var rig_amount := clampf(state_pose_pulse / 0.22, 0.0, 1.0) if rig_action == "attack" else 0.0
		lifecycle_rig.set_weapon_stance("hound" if actor_type == "dog" else ("gun" if enemy_type == "gunner" else "melee"))
		lifecycle_rig.update_lifecycle(delta, velocity.rotated(-rotation), move_speed, Vector2.ZERO, 0.0, rig_action, rig_amount)
		gun.z_index = 0 if lifecycle_rig.weapon_should_render_behind() else 2
	if state != previous_visual_state:
		state_pose_pulse = 0.22
		previous_visual_state = state
		queue_redraw()
	_update_alert_memory(delta)
	if tactical_role == "guard" and guard_alert_time <= 0.0: tactical_role = "none"
	# The root only draws static compatibility/debug marks. State changes and
	# explicit hit events request redraws; ordinary AI ticks do not need one.
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
	vision_scan_cooldown -= delta
	if vision_scan_cooldown <= 0.0:
		vision_scan_cooldown = 0.060 if state in [State.CHASE, State.ATTACK] else (0.095 if alert_level != AlertLevel.NORMAL else 0.140)
		cached_visual_contact = _can_see_player(distance, to_player)
	var has_visual_contact := cached_visual_contact
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
		if tactical_move_mode.is_empty(): chase_lost_time += delta
		if chase_lost_time >= chase_memory_duration:
			_clear_tactical_move()
			_begin_search(investigation_target, last_seen_direction)
	if _update_weapon_scavenge(delta): return
	# Heard threats first orient and parse the imperfect sound location. Distant or
	# wall-muted events take a fraction longer, while direct visual contact above
	# still interrupts this delay immediately.
	if state == State.INVESTIGATE and noise_reaction_delay > 0.0:
		noise_reaction_delay = maxf(0.0, noise_reaction_delay - delta)
		velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		rotation = lerp_angle(rotation, global_position.direction_to(investigation_target).angle(), 1.0 - exp(-12.0 * delta))
		move_and_slide()
		return
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
		if tactical_move_mode in ["to_cover", "hold"]: target_position = tactical_cover_position
		elif tactical_move_mode in ["to_peek", "at_peek", "flank"]: target_position = tactical_peek_position
		else: target_position = player.global_position if has_visual_contact else investigation_target
	elif state == State.SEARCH and search_index < search_points.size():
		target_position = search_points[search_index]
	var to_target := target_position - global_position
	var target_distance := to_target.length()
	if state == State.CHASE and not tactical_move_mode.is_empty():
		if tactical_move_mode == "hold":
			tactical_hold_time -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 260.0 * delta)
			move_and_slide()
			rotation = lerp_angle(rotation, global_position.direction_to(player.global_position).angle(), 1.0 - exp(-10.0 * delta))
			if tactical_hold_time <= 0.0: tactical_move_mode = "to_peek"
			return
		if target_distance < 5.0:
			if tactical_move_mode == "to_cover":
				tactical_move_mode = "hold"
				tactical_hold_time = randf_range(0.18, 0.34)
				return
			if tactical_move_mode == "to_peek": tactical_move_mode = "at_peek"
			elif tactical_move_mode == "flank": _clear_tactical_move()
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
	var direct_chase := state == State.CHASE and has_visual_contact and tactical_move_mode.is_empty()
	if direct_chase:
		path_points.clear()
	elif path_refresh <= 0.0 and is_instance_valid(tile_world):
		path_refresh = (0.12 + randf_range(0.0, 0.04)) if actor_type == "dog" else (0.22 + randf_range(0.0, 0.06))
		path_points = tile_world.get_navigation_path(global_position, target_position)
	if not path_points.is_empty():
		while not path_points.is_empty() and global_position.distance_to(path_points[0]) < 5.0:
			path_points.remove_at(0)
		if not path_points.is_empty(): direction = global_position.direction_to(path_points[0])
	if state == State.CHASE:
		var holds_position := is_fixed_sentry or tactical_role == "guard" or tactical_move_mode == "at_peek"
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
			if gun.ammo > 0 and gun.cooldown <= 0.0 and not gun.is_reloading:
				if _has_clear_shot():
					blocked_shot_time = 0.0
					_begin_attack()
				else:
					blocked_shot_time += delta
					if blocked_shot_time >= 0.18 and not is_fixed_sentry and tactical_role != "guard":
						blocked_shot_time = 0.0
						_begin_tactical_reposition()
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
		path_points = tile_world.get_navigation_path(global_position, patrol_target) if tile_world.has_method("get_navigation_path") else PackedVector2Array([patrol_target])
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
	aim_tracking_strength = profile.aim_tracking_strength
	enemy_spread_multiplier = profile.enemy_spread_multiplier
	distance_spread_multiplier = profile.distance_spread_multiplier
	aim_prediction_seconds = profile.aim_prediction_seconds
	knockdown_resistance = profile.knockdown_resistance
	var uses_gun := enemy_type == "gunner"
	gun.visible = uses_gun
	gun.set_process(uses_gun)
	# Strict top-down bodies and weapons remain separate layers so aim rotation
	# never turns a baked three-quarter weapon into a sideways silhouette.
	gun.get_node("WeaponPivot/WeaponSprite").visible = false
	gun.get_node("WeaponPivot/FakeShadow").visible = false
	# Identity colors are authored into the limited-palette sprites. Runtime
	# tinting previously collapsed gunner, melee and heavy silhouettes together.
	$Sprite2D.modulate = Color.WHITE
	_apply_compatibility_frame()
	if is_instance_valid(legs_visual):
		var role_color := Color("7c235b")
		var role_accent := Color("f23d78")
		match archetype_id:
			"assault": role_color = Color("9a5719"); role_accent = Color("ff9a45")
			"heavy": role_color = Color("41306e"); role_accent = Color("a59cff")
			"melee": role_color = Color("7d163f"); role_accent = Color("ff4f91")
		legs_visual.configure("dog" if actor_type == "dog" else "enemy", role_color, role_accent)
		if is_instance_valid(lifecycle_rig): lifecycle_rig.configure("hound" if actor_type == "dog" else "enemy", Color("6e4a37") if actor_type == "dog" else role_color, Color("e8d8c8") if actor_type == "dog" else role_accent, "hound" if actor_type == "dog" else archetype_id)

func set_combat_time_scale(value: float) -> void:
	var next_scale := clampf(value, 0.2, 1.0)
	if is_equal_approx(next_scale, combat_time_scale): return
	var ratio := next_scale / maxf(0.001, combat_time_scale)
	# CharacterBody2D consumes velocity in real physics time, so authored movement
	# speed is rescaled in addition to AI timer deltas. Do not rescale the current
	# velocity: it may be a hit/door impulse and scaling it back up on release would
	# launch an enemy through a wall.
	move_speed *= ratio
	combat_time_scale = next_scale
	if is_instance_valid(gun) and gun.has_method("set_combat_time_scale"):
		gun.set_combat_time_scale(next_scale)

func _apply_compatibility_frame() -> void:
	var frame_role := "hound" if actor_type == "dog" else archetype_id
	var texture := PIXEL_ACTOR_FRAMES.get_frame(frame_role)
	$Sprite2D.texture = texture
	$FakeShadow.texture = texture

func configure_fixed_sentry() -> void:
	is_fixed_sentry = true
	aim_tracking_strength = maxf(aim_tracking_strength, 0.20)
	enemy_spread_multiplier *= 0.72
	home_position = global_position
	configure_patrol(PackedVector2Array())

func _execute_melee_attack() -> void:
	if melee_cooldown > 0.0 or not is_instance_valid(player) or player.is_dead: return
	melee_cooldown = melee_interval
	melee_swing_time = 0.14
	queue_redraw()
	if player.has_method("apply_lifecycle_impact"):
		var attack_id := "hound_bite" if actor_type == "dog" else "fist"
		var physical := RAGDOLL_IMPACT.resolve(attack_id, global_position.distance_to(player.global_position), "torso", "human")
		player.apply_lifecycle_impact(global_position.direction_to(player.global_position), float(physical.limb_force) * 0.72, "torso")
	player.take_damage(1, global_position)

func _begin_attack() -> void:
	if state == State.ATTACK: return
	if enemy_type == "gunner" and not CombatDirector.request_fire_token(self):
		tactical_decision_cooldown = maxf(tactical_decision_cooldown, randf_range(0.08, 0.16))
		return
	state = State.ATTACK
	attack_windup_time = EnemyCombatController.attack_windup(enemy_type) * attack_windup_multiplier
	attack_windup_duration = attack_windup_time
	if enemy_type == "gunner": committed_aim_position = EnemyCombatController.committed_target(player, aim_prediction_seconds)
	velocity = Vector2.ZERO
	_reset_movement_progress()
	queue_redraw()

func _update_attack(delta: float, to_player: Vector2, distance: float, has_visual_contact: bool) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 240.0 * delta)
	move_and_slide()
	if not has_visual_contact:
		CombatDirector.release_fire_token(self)
		state = State.CHASE
		attack_windup_time = 0.0
		return
	var committed_direction := global_position.direction_to(committed_aim_position) if enemy_type == "gunner" else to_player.normalized()
	rotation = lerp_angle(rotation, committed_direction.angle(), 1.0 - exp(-12.0 * delta))
	attack_windup_time -= delta
	queue_redraw()
	if attack_windup_time > 0.0: return
	if enemy_type == "gunner":
		var live_target := global_position + to_player
		var final_target := committed_aim_position.lerp(live_target, aim_tracking_strength)
		var fire_direction := global_position.direction_to(final_target)
		var accuracy_multiplier := enemy_spread_multiplier * EnemyCombatController.distance_accuracy_multiplier(distance, shoot_range, distance_spread_multiplier)
		if distance <= shoot_range and _has_clear_shot() and gun.try_fire(fire_direction, accuracy_multiplier):
			gun.cooldown += randf_range(0.35, 0.75)
			if tactical_move_mode == "at_peek": tactical_move_mode = "to_cover"
			elif tactical_decision_cooldown <= 0.0 and not is_fixed_sentry and tactical_role != "guard":
				_begin_tactical_reposition(false)
		CombatDirector.release_fire_token(self)
	elif distance <= melee_range:
		_execute_melee_attack()
	state = State.CHASE
	attack_windup_time = 0.0

func _has_clear_shot() -> bool:
	return EnemyCombatController.has_clear_shot(self, gun, player)

func _begin_tactical_reposition(allow_flank := true) -> void:
	var plan := EnemyCombatController.choose_cover_plan(self, player, tile_world, preferred_distance, reposition_sign)
	if plan.is_empty() or (not allow_flank and str(plan.get("mode", "")) != "cover"):
		tactical_decision_cooldown = 0.9
		if not allow_flank: return
		reposition_time = 0.72
		reposition_sign = EnemyCombatController.choose_reposition_sign(self, player)
		return
	tactical_cover_position = plan.cover
	tactical_peek_position = plan.peek
	tactical_player_anchor = player.global_position
	tactical_move_time = 3.2
	tactical_decision_cooldown = 1.4
	tactical_move_mode = "to_cover" if str(plan.mode) == "cover" else "flank"
	path_points.clear()
	path_refresh = 0.0

func _clear_tactical_move() -> void:
	tactical_move_mode = ""
	tactical_move_time = 0.0
	tactical_hold_time = 0.0
	path_points.clear()
	path_refresh = 0.0

func _update_weapon_scavenge(delta: float) -> bool:
	if enemy_type != "gunner" or gun.ammo > 0:
		weapon_pickup_target = null
		return false
	weapon_pickup_scan_time -= delta
	if weapon_pickup_scan_time <= 0.0:
		weapon_pickup_scan_time = 0.25
		weapon_pickup_target = _find_weapon_pickup()
	if not is_instance_valid(weapon_pickup_target): return false
	var distance := global_position.distance_to(weapon_pickup_target.global_position)
	if distance <= 9.0:
		weapon_pickup_target.collect_enemy(self)
		weapon_pickup_target = null
		path_points.clear()
		return false
	var direction := global_position.direction_to(weapon_pickup_target.global_position)
	path_refresh -= delta
	if path_refresh <= 0.0 and is_instance_valid(tile_world):
		path_refresh = 0.18
		path_points = tile_world.get_navigation_path(global_position, weapon_pickup_target.global_position)
	while not path_points.is_empty() and global_position.distance_to(path_points[0]) < 5.0:
		path_points.remove_at(0)
	if not path_points.is_empty(): direction = global_position.direction_to(path_points[0])
	rotation = lerp_angle(rotation, direction.angle(), 1.0 - exp(-10.0 * delta))
	velocity = direction * move_speed * 1.08
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)
	return true

func _find_weapon_pickup() -> Node2D:
	var nearest: Node2D
	var nearest_distance := 120.0 * 120.0
	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		if not node is Node2D or int(node.get("rounds")) <= 0: continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance >= nearest_distance: continue
		if is_instance_valid(tile_world) and tile_world.get_navigation_path(global_position, node.global_position).is_empty(): continue
		nearest = node
		nearest_distance = distance
	return nearest

func equip_dropped_weapon(weapon_id: String, rounds: int) -> bool:
	if enemy_type != "gunner" or rounds <= 0: return false
	gun.set_gun_data(AttackCatalog.get_gun_data(weapon_id), true)
	gun.set_weapon_ammo(weapon_id, mini(rounds, gun.max_ammo))
	default_weapon_id = weapon_id
	gun.visible = true
	gun.set_process(true)
	return true

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
	if alert_level == AlertLevel.SUSPICIOUS: reaction_multiplier = 0.82
	elif alert_level == AlertLevel.ALERT: reaction_multiplier = 0.65
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
	_scan_for_blood_clue()

func _scan_for_blood_clue() -> void:
	if state not in [State.IDLE, State.RETURN] or is_fixed_sentry: return
	var nearest: Node2D
	var nearest_distance := INF
	var nearest_region := Vector2i.ZERO
	var nearest_generation := 0
	for clue_region in _get_blood_clue_regions():
		var region_data: Dictionary = blood_clue_region_cache[clue_region]
		var node_ref = region_data.get("node")
		var node = node_ref.get_ref() if node_ref is WeakRef else null
		var generation := int(region_data.get("generation", 0))
		if not node is Node2D or not is_instance_valid(node): continue
		if int(discovered_blood_clues.get(clue_region, -1)) >= generation: continue
		if is_instance_valid(tile_world) and tile_world.has_method("is_navigation_position_walkable") and not tile_world.is_navigation_position_walkable(node.global_position): continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance >= nearest_distance or distance > detection_range * detection_range * 0.55: continue
		if not EnemyPerception.can_see_position(self, node.global_position, detection_range * 0.74, vision_fov_degrees, 32): continue
		nearest = node
		nearest_distance = distance
		nearest_region = clue_region
		nearest_generation = generation
	if not is_instance_valid(nearest): return
	discovered_blood_clues[nearest_region] = nearest_generation
	_begin_investigation(nearest.global_position, 0.56)
	Events.publish_tactical_alert(nearest.global_position, Vector2.RIGHT.rotated(nearest.rotation), "blood_trail", self)

func _get_blood_clue_regions() -> Dictionary:
	# All enemies share one short-lived spatial snapshot. This changes the hot path
	# from scanning hundreds of permanent footprints per enemy to one scan per 0.1 s.
	var current_bucket := int(Time.get_ticks_msec() / 100)
	if blood_clue_cache_bucket == current_bucket: return blood_clue_region_cache
	blood_clue_cache_bucket = current_bucket
	blood_clue_region_cache = {}
	for clue in get_tree().get_nodes_in_group("blood_clue"):
		if not clue is Node2D or not is_instance_valid(clue): continue
		var region := Vector2i(floori(clue.global_position.x / 24.0), floori(clue.global_position.y / 24.0))
		var generation := int(clue.get_instance_id())
		if not blood_clue_region_cache.has(region) or generation > int((blood_clue_region_cache[region] as Dictionary).get("generation", 0)):
			blood_clue_region_cache[region] = {"node": weakref(clue), "generation": generation}
	return blood_clue_region_cache

func _begin_investigation(target: Vector2, new_alertness: float, keep_corpse_claim := false) -> void:
	_clear_tactical_move()
	if not keep_corpse_claim: _release_corpse_claim()
	state = State.INVESTIGATE
	investigation_target = target
	investigation_wait = 0.0
	noise_reaction_delay = 0.0
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
	_clear_tactical_move()
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
	_clear_tactical_move()
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
	_clear_tactical_move()
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
	if state != State.KNOCKED_DOWN:
		var movement_ratio := clampf(velocity.length() / maxf(1.0, move_speed), 0.0, 1.5)
		$Sprite2D.position.y = lerpf($Sprite2D.position.y, sin(Time.get_ticks_msec() * 0.018 + get_instance_id() * 0.1) * 0.45 * movement_ratio, 1.0 - exp(-14.0 * delta))
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
	var urgency := 0.65 if _source_kind == "gunshot" else 1.0
	noise_reaction_delay = (0.04 + distance_ratio * 0.20 + (0.12 if occluded else 0.0)) * urgency
	return true

func evaluate_tactical_assignment(world_position: Vector2) -> Dictionary:
	if is_dead or is_instance_valid(claimed_corpse) or state in [State.CHASE, State.ATTACK, State.STAGGERED, State.KNOCKED_DOWN] or is_fixed_sentry:
		return {"eligible": false, "priority": INF}
	return {"eligible": true, "priority": global_position.distance_to(world_position)}

func get_tactical_room_id() -> String:
	if is_instance_valid(tile_world) and tile_world.has_method("get_tactical_room_id"):
		return str(tile_world.get_tactical_room_id(global_position))
	return "open_floor"

func receive_tactical_assignment(world_position: Vector2, likely_direction: Vector2, _source_kind: String, role: String) -> bool:
	var response := evaluate_tactical_assignment(world_position)
	if not bool(response.get("eligible", false)): return false
	_raise_alert(AlertLevel.ALERT, alert_memory_duration)
	tactical_role = role
	if _source_kind == "ambush" and role in ["sweep_left", "sweep_right"]:
		var safe_approach := CombatDirector.get_safe_ambush_approach(world_position, global_position, role)
		if safe_approach != Vector2.INF:
			_begin_investigation(safe_approach, 0.82)
			queue_redraw()
			return true
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
	var previous_level := alert_level
	alert_level = maxi(alert_level, level)
	alert_memory_time = maxf(alert_memory_time, duration)
	alertness = maxf(alertness, 0.5 if level == AlertLevel.SUSPICIOUS else 1.0)
	if alert_level > previous_level:
		alert_transition_pulse = 0.32
		queue_redraw()

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
		queue_redraw()
	else:
		alert_level = AlertLevel.NORMAL
		alertness = 0.0
		if tactical_role == "observe": tactical_role = "none"
		queue_redraw()

func apply_stagger(push_direction: Vector2, duration: float) -> void:
	if is_dead: return
	_clear_tactical_move()
	_release_corpse_claim()
	state = State.STAGGERED
	_reset_movement_progress()
	stagger_time = duration
	velocity = push_direction.normalized() * 62.0
	if is_instance_valid(lifecycle_rig): lifecycle_rig.apply_hit(push_direction, 19.0, "torso")
	gun.cooldown = maxf(gun.cooldown, duration)

func take_door_hit(hit_direction: Vector2, hit_type: String) -> void:
	if is_dead: return
	_clear_tactical_move()
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
	if is_instance_valid(lifecycle_rig): lifecycle_rig.enter_knockdown(hit_direction, 46.0)
	gun.cooldown = maxf(gun.cooldown, knockdown_time)
	_set_knockdown_visual(true)

func is_knocked_down() -> bool:
	return not is_dead and state == State.KNOCKED_DOWN

func classify_hit_zone(world_hit_position: Vector2) -> String:
	var local_hit := to_local(world_hit_position)
	if local_hit.x >= 3.0: return "head"
	if absf(local_hit.y) >= 3.2 or local_hit.x <= -4.0: return "limb"
	return "torso"

func is_actively_engaging_player() -> bool:
	return not is_dead and state in [State.CHASE, State.ATTACK]

func execute_ground(source_position: Vector2) -> void:
	if not is_knocked_down(): return
	_set_knockdown_visual(false)
	take_damage(maxi(1, hp), source_position)

func _set_knockdown_visual(enabled: bool) -> void:
	$Sprite2D.rotation = 0.0
	$Sprite2D.position = Vector2.ZERO
	$Sprite2D.visible = false
	if is_instance_valid(legs_visual): legs_visual.visible = false
	$FakeShadow.visible = false
	$FakeShadow.rotation = 0.0
	gun.visible = false if enabled else enemy_type == "gunner"
	if not enabled and is_instance_valid(lifecycle_rig): lifecycle_rig.begin_recovery()
	queue_redraw()

func _on_gun_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	if is_instance_valid(lifecycle_rig): lifecycle_rig.trigger_weapon_recoil(0.85)
	projectile_requested.emit(origin, direction, enemy_owned, damage, weapon_id, self)

func _on_actor_died(source_position: Vector2) -> void:
	_release_corpse_claim()
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	var spray_direction := (global_position - source_position).normalized()
	if spray_direction.length_squared() < 0.001: spray_direction = Vector2.RIGHT.rotated(rotation)
	# Blood particles are presentation-only. Asset hot reloads, low-VFX variants,
	# or future enemy scenes may omit the node; that must never abort the gameplay
	# death signal that creates the persistent corpse and its ragdoll.
	var death_particles := get_node_or_null("DeathBloodParticles") as GPUParticles2D
	if is_instance_valid(death_particles):
		death_particles.rotation = spray_direction.angle()
		var death_parent := get_tree().current_scene
		if is_instance_valid(death_parent):
			death_particles.reparent(death_parent, true)
			death_particles.restart()
			death_particles.emitting = true
			get_tree().create_timer(death_particles.lifetime + 0.4).timeout.connect(death_particles.queue_free)
	died_at.emit(global_position, rotation)
	queue_free()

func _on_hit_received(_amount: int, source_position: Vector2) -> void:
	var direction := source_position.direction_to(global_position)
	if direction.length_squared() < 0.001: direction = -Vector2.RIGHT.rotated(rotation)
	if is_instance_valid(lifecycle_rig) and lifecycle_context_impact_frame != Engine.get_physics_frames(): lifecycle_rig.apply_hit(direction, 22.0, classify_hit_zone(global_position))
	if hp > 1:
		apply_stagger(direction, 0.09)

func get_lifecycle_pose() -> Dictionary:
	return lifecycle_rig.get_pose_snapshot() if is_instance_valid(lifecycle_rig) else {}

func apply_lifecycle_impact(direction: Vector2, power: float, hit_zone := "torso") -> void:
	lifecycle_context_impact_frame = Engine.get_physics_frames()
	if is_instance_valid(lifecycle_rig): lifecycle_rig.apply_hit(direction, power, hit_zone)

func _draw() -> void:
	# Tiny authored role badges survive blood and debris without becoming large
	# floating HUD markers: cyan gunner, pink rusher, orange assault, violet heavy.
	if not is_dead:
		match archetype_id:
			"melee":
				draw_line(Vector2(-3, -7), Vector2(0, -9), Color("ff4f91"), 1.0)
				draw_line(Vector2(0, -9), Vector2(3, -7), Color("ff4f91"), 1.0)
			"assault":
				draw_rect(Rect2(-4, -9, 3, 2), Color("ff9a45"))
				draw_rect(Rect2(1, -9, 3, 2), Color("ff9a45"))
			"heavy":
				draw_rect(Rect2(-3, -10, 6, 3), Color("a59cff"), false, 1.0)
			"gunner":
				draw_line(Vector2(-2, -8), Vector2(2, -8), Color("62e8ff"), 1.0)
	if not is_dead and (Settings.high_contrast_enemies or state in [State.CHASE, State.ATTACK]):
		var threat_color := Color(1.0, 0.16, 0.28, 0.92) if state in [State.CHASE, State.ATTACK] else Color(1.0, 0.78, 0.18, 0.72)
		draw_line(Vector2(-8, -7), Vector2(-4, -7), threat_color, 1.0)
		draw_line(Vector2(-8, -7), Vector2(-8, -3), threat_color, 1.0)
		draw_line(Vector2(-8, 7), Vector2(-4, 7), threat_color, 1.0)
		draw_line(Vector2(8, -7), Vector2(5, -7), threat_color, 1.0)
	if melee_swing_time > 0.0:
		PIXEL_PAINTER.arc(self, Vector2.ZERO, roundi(melee_range), -0.65, 0.65, Color("ffd0a8"), 10)
	if state == State.ATTACK and attack_windup_time > 0.0:
		var charge := 1.0 - clampf(attack_windup_time / maxf(0.001, attack_windup_duration), 0.0, 1.0)
		PIXEL_PAINTER.arc(self, Vector2.ZERO, 9, -0.48, lerpf(-0.48, 0.48, charge), Color("ffe56b"), 8)
		PIXEL_PAINTER.pixel(self, Vector2(7, 0), Color("fff3b0"))
		# A short two-pixel tell communicates the committed firing lane without
		# turning combat into a full laser-sight overlay.
		draw_line(Vector2(9, -1), Vector2(13 + charge * 3.0, -1), Color(1.0, 0.38, 0.2, 0.35 + charge * 0.45), 1.0)
		draw_line(Vector2(9, 1), Vector2(12 + charge * 2.0, 1), Color(1.0, 0.75, 0.28, 0.28 + charge * 0.38), 1.0)
	if debug_draw_vision:
		var half_fov := deg_to_rad(vision_fov_degrees * 0.5)
		var vision_color := Color(0.2, 1.0, 0.45, 0.16) if player_in_sight else Color(1.0, 0.2, 0.32, 0.09)
		var points := PackedVector2Array([Vector2.ZERO])
		for index in range(17):
			var angle := lerpf(-half_fov, half_fov, float(index) / 16.0)
			points.append(Vector2.RIGHT.rotated(angle) * detection_range)
		PIXEL_PAINTER.arc(self, Vector2.ZERO, roundi(detection_range), -half_fov, half_fov, Color(vision_color, 0.5), 24)
		PIXEL_PAINTER.line(self, Vector2.ZERO, Vector2.RIGHT.rotated(-half_fov) * detection_range, Color(vision_color, 0.5))
		PIXEL_PAINTER.line(self, Vector2.ZERO, Vector2.RIGHT.rotated(half_fov) * detection_range, Color(vision_color, 0.5))
		for angle_step in range(-3, 4):
			var ray_angle := half_fov * float(angle_step) / 3.0
			for distance in range(16, roundi(detection_range), 16):
				PIXEL_PAINTER.pixel(self, (Vector2.RIGHT.rotated(ray_angle) * distance).round(), vision_color)
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	if alert_transition_pulse > 0.0:
		var pulse_alpha := clampf(alert_transition_pulse / 0.32, 0.0, 1.0)
		var pulse_color := Color("ff385f", pulse_alpha) if alert_level == AlertLevel.ALERT else Color("ffd166", pulse_alpha)
		PIXEL_PAINTER.circle(self, Vector2(0, -9), roundi(4.0 + (1.0 - pulse_alpha) * 3.0), pulse_color, true)
	if state == State.INVESTIGATE:
		if is_instance_valid(claimed_corpse):
			# A compact body silhouette distinguishes corpse discovery from an
			# ordinary sound investigation without adding floating text.
			PIXEL_PAINTER.pixel(self, Vector2(0, -11), Color("82d8ff"))
			PIXEL_PAINTER.line(self, Vector2(-3, -9), Vector2(3, -9), Color("82d8ff"))
			draw_line(Vector2(-2, -8), Vector2(-3, -6), Color("82d8ff"), 1.0)
			draw_line(Vector2(2, -8), Vector2(3, -6), Color("82d8ff"), 1.0)
		else:
			PIXEL_PAINTER.arc(self, Vector2(0, -10), 2, -PI * 0.85, PI * 0.35, Color("ffd166"), 7)
			PIXEL_PAINTER.pixel(self, Vector2(0, -7), Color("ffd166"))
	elif state == State.SEARCH:
		PIXEL_PAINTER.arc(self, Vector2(0, -9), 3, -PI * 0.2, PI * 1.3, Color("66e0ff"), 9)
		draw_line(Vector2(2, -7), Vector2(4, -5), Color("66e0ff"), 1.0)
	elif state == State.RETURN:
		draw_line(Vector2(-3, -9), Vector2(3, -9), Color("9cc8ff"), 1.0)
		draw_line(Vector2(-3, -9), Vector2(-1, -11), Color("9cc8ff"), 1.0)
	elif state in [State.CHASE, State.ATTACK]:
		PIXEL_PAINTER.line(self, Vector2(0, -12), Vector2(0, -8), Color("ff385f"))
		PIXEL_PAINTER.pixel(self, Vector2(0, -7), Color("ff385f"))
	elif tactical_role == "guard" and guard_alert_time > 0.0:
		draw_line(Vector2(-3, -9), Vector2(3, -9), Color("9cf7c8"), 1.0)
		draw_line(Vector2(-3, -9), Vector2(0, -6), Color("9cf7c8"), 1.0)
		draw_line(Vector2(3, -9), Vector2(0, -6), Color("9cf7c8"), 1.0)
