class_name Gun
extends Node2D

signal fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)

const DRY_FIRE_STREAM := preload("res://assets/audio/sfx/dry_fire.wav")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

@export var gun_data: Resource
@export var enemy_owned := false
var automatic := false

var fire_interval := 0.1
var fire_interval_variance := 0.018
var spread_degrees := 0.0
var pellet_count := 1
var pellet_spread_degrees := 0.0
var spread_growth_per_shot := 0.0
var maximum_spread_bonus := 0.0
var spread_recovery := 4.0
var movement_spread_degrees := 2.0
var turn_spread_degrees := 1.5
var aim_follow_speed := 12.0
var max_ammo := 12
var projectile_damage := 1
var weapon_id := "pistol"
var reload_duration := 1.05
var pitch_min := 0.91
var pitch_max := 1.09
var recoil_strength := 0.7
var camera_shake := 0.7
var muzzle_flash_size := 26.0
var muzzle_flash_duration := 0.045
var bullet_speed := 650.0
var knockback := 24.0
var hearing_radius := 190.0
var hit_stop := 0.035
var shot_volume_db := -10.0
var mechanical_pitch := 1.0
var punch_pitch := 0.73
var movement_speed_multiplier := 1.0
var reload_movement_multiplier := 0.8

@onready var reload_timer: Timer = $ReloadTimer
@onready var shot_audio: AudioStreamPlayer = $ShotAudio
@onready var reload_audio: AudioStreamPlayer = $ReloadAudio
@onready var dry_fire_audio: AudioStreamPlayer = $DryFireAudio
@onready var mechanical_audio: AudioStreamPlayer = $MechanicalAudio
@onready var punch_audio: AudioStreamPlayer = $PunchAudio
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite
@onready var weapon_shadow: Sprite2D = $WeaponPivot/FakeShadow
@onready var muzzle: Marker2D = $WeaponPivot/Muzzle
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var weapon_pivot: Node2D = $WeaponPivot

var ammo := 12
var reserve_ammo := -1
var cooldown := 0.0
var recoil := 0.0
var shot_heat := 0.0
var is_reloading := false
var ammo_by_weapon: Dictionary = {}
var reserve_by_weapon: Dictionary = {}
var aim_turn_instability := 0.0
var last_requested_angle := 0.0
var has_requested_angle := false
var field_noise_multiplier := 1.0
var current_shot_id := 0
var precision_streak := 0
var precision_primed := false
var perfect_reload_active := false
var active_reload_duration := 1.05
var combat_time_scale := 1.0

func _ready() -> void:
	set_gun_data(gun_data, true)
	weapon_sprite.visible = false
	weapon_shadow.visible = false
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
	if not enemy_owned: Events.publish_ammo_reserve(reserve_ammo)
	queue_redraw()

func _apply_gun_data() -> void:
	if gun_data == null: return
	automatic = gun_data.automatic
	weapon_id = gun_data.weapon_id
	max_ammo = gun_data.ammo_capacity
	projectile_damage = gun_data.damage
	fire_interval = gun_data.fire_interval
	fire_interval_variance = gun_data.fire_interval_variance
	spread_degrees = gun_data.spread_degrees
	pellet_count = gun_data.pellet_count
	pellet_spread_degrees = gun_data.pellet_spread_degrees
	spread_growth_per_shot = gun_data.spread_growth_per_shot
	maximum_spread_bonus = gun_data.maximum_spread_bonus
	spread_recovery = gun_data.spread_recovery
	movement_spread_degrees = gun_data.movement_spread_degrees
	turn_spread_degrees = gun_data.turn_spread_degrees
	aim_follow_speed = gun_data.aim_follow_speed
	reload_duration = gun_data.reload_duration
	pitch_min = gun_data.pitch_min
	pitch_max = gun_data.pitch_max
	recoil_strength = gun_data.recoil_strength
	camera_shake = gun_data.camera_shake
	muzzle_flash_size = gun_data.muzzle_flash_size
	muzzle_flash_duration = gun_data.muzzle_flash_duration
	bullet_speed = gun_data.bullet_speed
	knockback = gun_data.knockback
	hearing_radius = gun_data.hearing_radius
	hit_stop = gun_data.hit_stop
	shot_volume_db = gun_data.shot_volume_db
	mechanical_pitch = gun_data.mechanical_pitch
	punch_pitch = gun_data.punch_pitch
	movement_speed_multiplier = gun_data.movement_speed_multiplier
	reload_movement_multiplier = gun_data.reload_movement_multiplier

func clear_equipped_weapon() -> void:
	if is_reloading:
		reload_timer.stop()
		is_reloading = false
	gun_data = null
	weapon_id = ""
	ammo = 0
	max_ammo = 0
	automatic = false
	cooldown = 0.0
	shot_heat = 0.0
	queue_redraw()

func set_gun_data(data: Resource, refill := true) -> void:
	if data == null: return
	if gun_data != null and not weapon_id.is_empty():
		ammo_by_weapon[weapon_id] = ammo
		reserve_by_weapon[weapon_id] = reserve_ammo
	gun_data = data
	_apply_gun_data()
	if ammo_by_weapon.has(weapon_id):
		ammo = clampi(int(ammo_by_weapon[weapon_id]), 0, max_ammo)
	elif refill:
		ammo = max_ammo
	else:
		ammo = 0
	reserve_ammo = int(reserve_by_weapon.get(weapon_id, -1))
	ammo_by_weapon[weapon_id] = ammo
	is_reloading = false
	shot_heat = 0.0
	precision_streak = 0
	precision_primed = false
	perfect_reload_active = false
	active_reload_duration = reload_duration
	if is_instance_valid(reload_timer): reload_timer.stop()
	if is_instance_valid(shot_audio):
		shot_audio.stream = ProceduralAudioLibrary.get_sfx("shotgun_shot") if weapon_id == "shotgun" else gun_data.shot_stream
		shot_audio.volume_db = shot_volume_db
		reload_audio.stream = ProceduralAudioLibrary.get_sfx("shotgun_reload") if weapon_id == "shotgun" else gun_data.reload_stream
		dry_fire_audio.stream = gun_data.dry_fire_stream if gun_data.dry_fire_stream != null else DRY_FIRE_STREAM
		mechanical_audio.stream = dry_fire_audio.stream
		punch_audio.stream = shot_audio.stream
		var weapon_length := _weapon_visual_length()
		weapon_sprite.position.x = weapon_length * 0.5
		weapon_shadow.position.x = weapon_length * 0.5
		muzzle.position.x = weapon_length + 1.0
		weapon_sprite.visible = false
		weapon_shadow.visible = false
		if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
		if not enemy_owned: Events.publish_ammo_reserve(reserve_ammo)
	queue_redraw()

func _weapon_visual_length() -> float:
	match weapon_id:
		"smg": return 12.0
		"shotgun": return 15.0
		"lmg": return 14.0
		_: return 9.0

func set_weapon_ammo(target_weapon_id: String, rounds: int) -> void:
	ammo_by_weapon[target_weapon_id] = maxi(0, rounds)
	if weapon_id == target_weapon_id:
		ammo = clampi(rounds, 0, max_ammo)
		if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)

func get_weapon_ammo(target_weapon_id: String) -> int:
	if target_weapon_id == weapon_id: return ammo
	return int(ammo_by_weapon.get(target_weapon_id, 0))

func set_reserve_ammo(target_weapon_id: String, rounds: int) -> void:
	reserve_by_weapon[target_weapon_id] = rounds if rounds < 0 else maxi(0, rounds)
	if weapon_id == target_weapon_id:
		reserve_ammo = int(reserve_by_weapon[target_weapon_id])
		if not enemy_owned: Events.publish_ammo_reserve(reserve_ammo)

func get_reserve_ammo(target_weapon_id: String) -> int:
	if target_weapon_id == weapon_id: return reserve_ammo
	return int(reserve_by_weapon.get(target_weapon_id, 0))

func add_reserve_ammo(target_weapon_id: String, rounds: int) -> int:
	var current := get_reserve_ammo(target_weapon_id)
	if current < 0: return current
	set_reserve_ammo(target_weapon_id, current + maxi(0, rounds))
	return get_reserve_ammo(target_weapon_id)

func _process(delta: float) -> void:
	delta *= combat_time_scale
	cooldown = maxf(0.0, cooldown - delta)
	recoil = move_toward(recoil, 0.0, 24.0 * delta)
	shot_heat = move_toward(shot_heat, 0.0, spread_recovery * delta)
	aim_turn_instability = move_toward(aim_turn_instability, 0.0, aim_follow_speed * delta)
	if is_reloading and reload_duration > 0.0:
		var reload_progress := 1.0 - reload_timer.time_left / maxf(0.001, active_reload_duration)
		var reload_arc := sin(clampf(reload_progress, 0.0, 1.0) * PI)
		weapon_pivot.rotation = snappedf(lerpf(weapon_pivot.rotation, -0.62 * reload_arc, 1.0 - exp(-24.0 * delta)), PI / 16.0)
		weapon_pivot.scale = Vector2.ONE
	else:
		var recoil_angle := -0.035 * recoil * recoil_strength
		weapon_pivot.rotation = snappedf(lerpf(weapon_pivot.rotation, recoil_angle, 1.0 - exp(-28.0 * delta)), PI / 32.0)
		weapon_pivot.scale = Vector2.ONE
	queue_redraw()

func set_combat_time_scale(value: float) -> void:
	combat_time_scale = clampf(value, 0.2, 1.0) if enemy_owned else 1.0
	if is_instance_valid(animation_player): animation_player.speed_scale = combat_time_scale

func _draw() -> void:
	if weapon_id.is_empty(): return
	# Render the weapon from native one-world-pixel cells. Texture resources stay
	# available as metadata/preview art but never enter the live world renderer.
	var local_angle := snappedf(global_rotation + weapon_pivot.rotation, PI / 8.0) - global_rotation
	var direction := Vector2.RIGHT.rotated(local_angle)
	var side := direction.orthogonal()
	var length := 9
	var body_color := Color("d8e2df")
	var accent := Color("27c9ca")
	match weapon_id:
		"smg": length = 12; body_color = Color("6f7f86"); accent = Color("ff3d84")
		"shotgun": length = 15; body_color = Color("9b5b36"); accent = Color("ffe06b")
		"lmg": length = 14; body_color = Color("59666b"); accent = Color("ff6a3d")
		_: length = 9
	var start := direction * 3.0
	var finish := direction * float(length)
	PIXEL_PAINTER.material_line(self, start, finish, Color("17141b"), 3 if weapon_id in ["shotgun", "lmg"] else 2, weapon_id.hash(), &"metal")
	PIXEL_PAINTER.line(self, start + side, finish + side, body_color)
	PIXEL_PAINTER.pixel(self, finish.round(), accent)
	var grip := (start + direction * 2.0 - side * 2.0).round()
	PIXEL_PAINTER.line(self, grip, grip - direction + side * 2.0, Color("38222a"))

func try_fire(direction: Vector2, accuracy_spread_multiplier := 1.0) -> bool:
	if is_reloading or direction.length_squared() < 0.001: return false
	if cooldown > 0.0: return false
	var requested_angle := direction.angle()
	if has_requested_angle:
		aim_turn_instability = minf(1.0, aim_turn_instability + absf(angle_difference(last_requested_angle, requested_angle)) / 0.55)
	last_requested_angle = requested_angle
	has_requested_angle = true
	if _is_muzzle_obstructed():
		cooldown = 0.08
		mechanical_audio.pitch_scale = 0.72
		mechanical_audio.play()
		return false
	if ammo <= 0:
		cooldown = 0.13
		dry_fire_audio.pitch_scale = randf_range(0.92, 1.08)
		dry_fire_audio.play()
		if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
		return false
	cooldown = maxf(0.035, fire_interval + randf_range(-fire_interval_variance, fire_interval_variance))
	ammo -= 1
	ammo_by_weapon[weapon_id] = ammo
	recoil = 2.0
	shot_audio.pitch_scale = randf_range(pitch_min, pitch_max)
	shot_audio.play()
	mechanical_audio.pitch_scale = mechanical_pitch * randf_range(0.98, 1.03)
	mechanical_audio.play()
	punch_audio.pitch_scale = punch_pitch * randf_range(0.97, 1.03)
	punch_audio.play()
	animation_player.stop()
	animation_player.play("kick", -1.0, 0.85 + recoil_strength * 0.45)
	var dynamic_spread := minf(maximum_spread_bonus, shot_heat * spread_growth_per_shot)
	var movement_ratio := _get_actor_movement_ratio()
	var current_spread := (spread_degrees + dynamic_spread + movement_ratio * movement_spread_degrees + aim_turn_instability * turn_spread_degrees) * maxf(0.1, accuracy_spread_multiplier)
	# A triangular distribution keeps most rounds near the intended center while
	# preserving readable edge misses. Uniform random spread made mastery feel
	# like a coin toss because edge shots were as likely as center shots.
	var centered_random := randf() + randf() - 1.0
	var spread_radians := deg_to_rad(centered_random * current_spread)
	shot_heat += 1.0
	var normalized_direction := direction.normalized().rotated(spread_radians)
	var origin := muzzle.global_position
	current_shot_id += 1
	# Register the trigger pull before spawning projectiles so the level can bind
	# every pellet to this exact shot for precision scoring.
	Events.weapon_fired.emit(origin, normalized_direction, enemy_owned, weapon_id)
	for pellet_index in range(pellet_count):
		var pellet_offset := 0.0
		if pellet_count > 1:
			var pellet_t := inverse_lerp(0.0, float(pellet_count - 1), float(pellet_index)) * 2.0 - 1.0
			var stratum := pellet_spread_degrees * 2.0 / float(pellet_count - 1)
			var jitter := 0.0 if pellet_index == pellet_count / 2 else randf_range(-stratum * 0.12, stratum * 0.12)
			pellet_offset = deg_to_rad(pellet_t * pellet_spread_degrees + jitter)
		fired.emit(origin, normalized_direction.rotated(pellet_offset), enemy_owned, projectile_damage, weapon_id)
	var noise_multiplier := 1.0 if enemy_owned else maxf(0.45, (1.0 - Progression.get_specialization_level("ghost") * 0.08) * field_noise_multiplier)
	Events.publish_combat_noise(origin, hearing_radius * noise_multiplier, "gunshot")
	if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
	return true

func _get_actor() -> CharacterBody2D:
	var owner_node := get_parent()
	while is_instance_valid(owner_node) and owner_node is not CharacterBody2D: owner_node = owner_node.get_parent()
	return owner_node as CharacterBody2D

func _get_actor_movement_ratio() -> float:
	var actor := _get_actor()
	if not is_instance_valid(actor): return 0.0
	var speed_value = actor.get("move_speed")
	var reference_speed := maxf(1.0, float(speed_value) if speed_value != null else 100.0)
	return clampf(actor.velocity.length() / reference_speed, 0.0, 1.25)

func get_current_spread_degrees() -> float:
	var dynamic_spread := minf(maximum_spread_bonus, shot_heat * spread_growth_per_shot)
	return spread_degrees + dynamic_spread + _get_actor_movement_ratio() * movement_spread_degrees + aim_turn_instability * turn_spread_degrees

func get_spread_feedback_ratio() -> float:
	var readable_max := maxf(1.0, spread_degrees + maximum_spread_bonus + movement_spread_degrees + turn_spread_degrees)
	return clampf(get_current_spread_degrees() / readable_max, 0.0, 1.0)

func get_total_spread_degrees() -> float:
	return get_current_spread_degrees() + pellet_spread_degrees

func get_reload_progress() -> float:
	if not is_reloading: return 0.0
	return clampf(1.0 - reload_timer.time_left / maxf(0.001, active_reload_duration), 0.0, 1.0)

func get_precision_threshold() -> int:
	match weapon_id:
		"shotgun": return 3
		"smg": return 6
		"lmg": return 8
	return 4

func report_shot_result(hit_enemy: bool, lethal: bool = false) -> void:
	if enemy_owned: return
	if hit_enemy:
		precision_streak += 1
		if precision_streak >= get_precision_threshold() and not precision_primed:
			precision_primed = true
			Events.precision_reward.emit(weapon_id, precision_streak)
	else:
		precision_streak = 0
		precision_primed = false
	Events.precision_chain_updated.emit(precision_streak, precision_primed)
	if precision_primed and ammo <= 0 and not is_reloading:
		call_deferred("_start_perfect_reload")
	if lethal: recoil = maxf(recoil, 1.2)

func get_aim_feedback() -> Dictionary:
	return {
		"spread_degrees": get_total_spread_degrees(),
		"ammo": ammo,
		"maximum": max_ammo,
		"reloading": is_reloading,
		"reload_progress": get_reload_progress(),
		"precision_streak": precision_streak,
		"precision_primed": precision_primed,
		"shotgun": pellet_count > 1,
	}

func _is_muzzle_obstructed() -> bool:
	var actor := _get_actor()
	if not is_instance_valid(actor) or not is_inside_tree(): return false
	var query := PhysicsRayQueryParameters2D.create(actor.global_position, muzzle.global_position + Vector2.RIGHT.rotated(global_rotation) * 2.0, 4)
	query.exclude = [actor.get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func is_muzzle_blocked() -> bool:
	return _is_muzzle_obstructed()

func reload() -> void:
	if is_reloading or ammo >= max_ammo or reserve_ammo == 0: return
	is_reloading = true
	perfect_reload_active = false
	active_reload_duration = reload_duration
	reload_timer.start(active_reload_duration)
	reload_audio.pitch_scale = randf_range(0.97, 1.03)
	reload_audio.play()
	if not enemy_owned:
		Events.reload_started.emit(reload_duration)
		Events.publish_ammo(ammo, max_ammo, true)

func _on_reload_timer_timeout() -> void:
	var required := max_ammo - ammo
	var loaded := required if reserve_ammo < 0 else mini(required, reserve_ammo)
	ammo += loaded
	if reserve_ammo >= 0:
		reserve_ammo -= loaded
		reserve_by_weapon[weapon_id] = reserve_ammo
	ammo_by_weapon[weapon_id] = ammo
	is_reloading = false
	var completed_perfect_reload := perfect_reload_active
	perfect_reload_active = false
	active_reload_duration = reload_duration
	if completed_perfect_reload:
		precision_streak = 0
		precision_primed = false
		Events.precision_chain_updated.emit(0, false)
	if not enemy_owned:
		Events.reload_finished.emit(ammo, max_ammo)
		Events.publish_ammo(ammo, max_ammo, false)
		Events.publish_ammo_reserve(reserve_ammo)

func _start_perfect_reload() -> void:
	if enemy_owned or is_reloading or ammo > 0 or reserve_ammo == 0 or not precision_primed: return
	is_reloading = true
	perfect_reload_active = true
	active_reload_duration = 0.28
	reload_timer.start(active_reload_duration)
	reload_audio.pitch_scale = 1.16
	reload_audio.play()
	Events.reload_started.emit(active_reload_duration)
	Events.publish_ammo(ammo, max_ammo, true)
