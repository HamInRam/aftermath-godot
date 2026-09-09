class_name Gun
extends Node2D

signal fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)

const DRY_FIRE_STREAM := preload("res://assets/audio/sfx/dry_fire.wav")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const WEAPON_ART := preload("res://utility/weapon_pixel_art.gd")
const PRESENTATION := preload("res://utility/weapon_presentation_profile.gd")

@export var gun_data: Resource
@export var enemy_owned := false
var blood_fire_payment: Callable:
	set(value):
		blood_fire_payment = value
		if value.is_valid() and is_node_ready(): cancel_reload()
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
var penetration_power := 0.8
var property_damage := 0.8
var cleanup_burden := 1.0
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
var presentation_profile: Dictionary = {}
var presentation_cells: Array[Dictionary] = []
var shot_age := 999.0
var visual_offset := Vector2.ZERO
var visual_angle := 0.0
var magazine_offset := Vector2.ZERO
var mechanism_amount := 0.0
var reload_phase := "idle"
var reload_feed_click := -1
var last_render_transform := Transform2D.IDENTITY

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
	penetration_power = gun_data.penetration_power
	property_damage = gun_data.property_damage
	cleanup_burden = gun_data.cleanup_burden
	shot_volume_db = gun_data.shot_volume_db
	mechanical_pitch = gun_data.mechanical_pitch
	punch_pitch = gun_data.punch_pitch
	movement_speed_multiplier = gun_data.movement_speed_multiplier
	reload_movement_multiplier = gun_data.reload_movement_multiplier
	presentation_profile = PRESENTATION.for_weapon(gun_data)
	presentation_cells = WEAPON_ART.get_shape(gun_data)

func clear_equipped_weapon() -> void:
	cancel_reload(false)
	gun_data = null
	weapon_id = ""
	ammo = 0
	reserve_ammo = 0
	max_ammo = 0
	automatic = false
	cooldown = 0.0
	shot_heat = 0.0
	_reset_presentation()
	presentation_cells = []
	queue_redraw()

func set_gun_data(data: Resource, refill := true) -> void:
	if data == null: return
	cancel_reload(false)
	if gun_data != null and not weapon_id.is_empty():
		ammo_by_weapon[weapon_id] = ammo
		reserve_by_weapon[weapon_id] = reserve_ammo
	gun_data = data
	_apply_gun_data()
	cooldown = 0.0
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
	_reset_presentation()
	if is_instance_valid(reload_timer): reload_timer.stop()
	if is_instance_valid(shot_audio):
		shot_audio.stream = ProceduralAudioLibrary.get_sfx("shotgun_shot" if gun_data.weapon_class == "shotgun" else "weapon_" + gun_data.weapon_class)
		shot_audio.volume_db = shot_volume_db
		reload_audio.stream = ProceduralAudioLibrary.get_sfx("shotgun_reload") if gun_data.weapon_class == "shotgun" else gun_data.reload_stream
		dry_fire_audio.stream = gun_data.dry_fire_stream if gun_data.dry_fire_stream != null else DRY_FIRE_STREAM
		mechanical_audio.stream = dry_fire_audio.stream
		punch_audio.stream = shot_audio.stream
		# Keep the attack's main transient intelligible during automatic bursts.
		# A quiet, class-pitched mechanical layer is texture, not a second loud gun.
		mechanical_audio.volume_db = -27.0 if automatic else -22.0
		punch_audio.volume_db = shot_volume_db - (15.0 if automatic else 10.0)
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
	return float(gun_data.visual_length_pixels) * gun_data.weapon_length_multiplier if gun_data != null else 9.0

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
	# At most one frame of cadence credit; never accumulate an idle burst.
	cooldown = maxf(-minf(delta, fire_interval * 0.5), cooldown - delta)
	recoil = move_toward(recoil, 0.0, 24.0 * delta)
	shot_heat = move_toward(shot_heat, 0.0, spread_recovery * delta)
	aim_turn_instability = move_toward(aim_turn_instability, 0.0, aim_follow_speed * delta)
	_update_weapon_presentation(delta)

func _reset_presentation() -> void:
	shot_age = 999.0
	visual_offset = Vector2.ZERO
	visual_angle = 0.0
	magazine_offset = Vector2.ZERO
	mechanism_amount = 0.0
	reload_phase = "idle"
	reload_feed_click = -1
	if is_instance_valid(animation_player): animation_player.stop()
	if is_instance_valid(weapon_pivot):
		weapon_pivot.position = Vector2(3, 0)
		weapon_pivot.rotation = 0.0
		weapon_pivot.scale = Vector2.ONE
	queue_redraw()

func _update_weapon_presentation(delta: float) -> void:
	if presentation_profile.is_empty() or gun_data == null: return
	shot_age += delta
	var previous_offset := visual_offset
	var previous_angle := visual_angle
	var previous_magazine := magazine_offset
	var previous_mechanism := mechanism_amount
	var pose := PRESENTATION.recoil_pose(presentation_profile, shot_age, clampf(0.75 + recoil_strength * 0.25, 0.7, 1.3))
	visual_offset = pose.offset
	visual_angle = float(pose.angle)
	magazine_offset = Vector2.ZERO
	var cycle_time := float(presentation_profile.cycle)
	mechanism_amount = sin(clampf(shot_age / cycle_time, 0.0, 1.0) * PI)
	if is_reloading:
		var progress := get_reload_progress()
		var feed := str(gun_data.feed_type)
		var reload_pose := PRESENTATION.reload_pose(presentation_profile, progress, feed, str(gun_data.action_type), max_ammo - ammo)
		visual_offset = reload_pose.offset
		visual_angle = float(reload_pose.angle)
		magazine_offset = reload_pose.magazine_offset
		mechanism_amount = float(reload_pose.chamber)
		var new_phase := str(reload_pose.phase)
		if new_phase != reload_phase:
			reload_phase = new_phase
			if new_phase in ["exchange", "feed", "chamber", "ready"]:
				_play_reload_mechanism(new_phase == "ready")
		if feed == "tube" and new_phase == "feed":
			var next_click := floori(inverse_lerp(0.16, 0.70, progress) * float(clampi(max_ammo - ammo, 1, 8)))
			if next_click != reload_feed_click:
				reload_feed_click = next_click
				_play_reload_mechanism(false)
	else:
		reload_phase = "idle"
	if previous_offset != visual_offset or not is_equal_approx(previous_angle, visual_angle) or previous_magazine != magazine_offset or not is_equal_approx(previous_mechanism, mechanism_amount) or last_render_transform != global_transform:
		last_render_transform = global_transform
		queue_redraw()

func _play_reload_mechanism(seated: bool) -> void:
	if not is_instance_valid(mechanical_audio) or DisplayServer.get_name() == "headless": return
	mechanical_audio.pitch_scale = float(presentation_profile.get("sound", 1.0)) * (1.16 if seated else 0.86)
	mechanical_audio.play()

func get_presentation_state() -> Dictionary:
	return {"phase": reload_phase, "offset": visual_offset, "angle": visual_angle, "magazine_offset": magazine_offset, "mechanism": mechanism_amount, "class": gun_data.weapon_class if gun_data != null else ""}

func set_combat_time_scale(value: float) -> void:
	combat_time_scale = clampf(value, 0.2, 1.0) if enemy_owned else 1.0
	if is_instance_valid(animation_player): animation_player.speed_scale = combat_time_scale

func _draw() -> void:
	if weapon_id.is_empty() or not is_instance_valid(weapon_pivot): return
	var direction := Vector2.RIGHT.rotated(global_rotation + visual_angle)
	var origin := to_global(weapon_pivot.position + visual_offset)
	WEAPON_ART.draw_cells(self, presentation_cells, origin, direction, magazine_offset, mechanism_amount)
	if is_reloading and gun_data.feed_type == "tube" and reload_phase == "feed":
		# A shell moving into the receiver, not a fake detached box magazine.
		draw_set_transform_matrix(global_transform.affine_inverse())
		var shell_position := origin + direction * magazine_offset.x + direction.orthogonal() * magazine_offset.y
		PIXEL_PAINTER.pixel(self, shell_position.round(), Color("f1f1f1"))
		PIXEL_PAINTER.pixel(self, (shell_position + direction).round(), Color("929292"))
		draw_set_transform_matrix(Transform2D.IDENTITY)

func try_fire(direction: Vector2, accuracy_spread_multiplier := 1.0) -> bool:
	if blood_fire_payment.is_valid() and is_reloading: cancel_reload()
	if gun_data == null or is_reloading or direction.length_squared() < 0.001: return false
	if cooldown > 0.0: return false
	if ammo <= 0 and not blood_fire_payment.is_valid():
		play_dry_fire()
		return false
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
	# Pay exactly once per successful trigger, never once per shotgun pellet.
	if blood_fire_payment.is_valid() and not blood_fire_payment.call(gun_data):
		play_dry_fire()
		cooldown = 0.2
		return false
	# Preserve overshoot from the previous frame so a 750 RPM weapon does not
	# quantize down to 600 RPM at 60 Hz. Idle time cannot bank catch-up bullets.
	cooldown = maxf(0.001, maxf(0.035, fire_interval + randf_range(-fire_interval_variance, fire_interval_variance)) + minf(0.0, cooldown))
	if not blood_fire_payment.is_valid(): ammo -= 1
	ammo_by_weapon[weapon_id] = ammo
	recoil = 2.0
	shot_age = 0.0
	_update_weapon_presentation(0.0)
	_update_fire_mix()
	shot_audio.pitch_scale = randf_range(pitch_min, pitch_max) * float(presentation_profile.sound)
	shot_audio.play()
	mechanical_audio.pitch_scale = mechanical_pitch * float(presentation_profile.get("sound", 1.0)) * randf_range(0.99, 1.01)
	mechanical_audio.play()
	punch_audio.pitch_scale = punch_pitch * randf_range(0.97, 1.03)
	punch_audio.play()
	animation_player.stop()
	var dynamic_spread := minf(maximum_spread_bonus, shot_heat * spread_growth_per_shot)
	var movement_ratio := _get_actor_movement_ratio()
	# AFTERMATH is an arcade room shooter now: weapon identity remains in base
	# spread and recoil, while sprinting and fast target swaps no longer turn the
	# reticle into a realism tax.
	var current_spread := (spread_degrees * 0.82 + dynamic_spread * 0.72 + movement_ratio * movement_spread_degrees * 0.38 + aim_turn_instability * turn_spread_degrees * 0.34) * maxf(0.1, accuracy_spread_multiplier)
	# A triangular distribution keeps most rounds near the intended center while
	# preserving readable edge misses. Uniform random spread made mastery feel
	# like a coin toss because edge shots were as likely as center shots.
	var centered_random := randf() + randf() - 1.0
	var spread_radians := deg_to_rad(centered_random * current_spread)
	shot_heat += 1.0
	var normalized_direction := direction.normalized().rotated(spread_radians)
	var origin := _get_safe_projectile_origin()
	current_shot_id += 1
	# Register the trigger pull before spawning projectiles so the level can bind
	# every pellet to this exact shot for precision scoring.
	# Art stays at the visible barrel tip, even when a close body/wall forces the
	# physical projectile to begin before that surface instead of behind it.
	Events.weapon_fired.emit(muzzle.global_position, normalized_direction, enemy_owned, weapon_id)
	for pellet_index in range(pellet_count):
		var pellet_offset := 0.0
		if pellet_count > 1:
			var pellet_t := inverse_lerp(0.0, float(pellet_count - 1), float(pellet_index)) * 2.0 - 1.0
			var stratum := pellet_spread_degrees * 2.0 / float(pellet_count - 1)
			var jitter := 0.0 if pellet_index == pellet_count / 2 else randf_range(-stratum * 0.12, stratum * 0.12)
			pellet_offset = deg_to_rad(pellet_t * pellet_spread_degrees + jitter)
		fired.emit(origin, normalized_direction.rotated(pellet_offset), enemy_owned, projectile_damage, weapon_id)
	var noise_multiplier := 1.0 if enemy_owned else maxf(0.45, (1.0 - Progression.get_specialization_level("ghost") * 0.08) * field_noise_multiplier)
	# Preserve weapon identity for room-based acoustic propagation. Enemy fire is
	# tagged separately so an ongoing firefight does not recruit a fresh wave on
	# every automatic round.
	var noise_kind := ("enemy_gunshot_" if enemy_owned else "gunshot_") + weapon_id
	Events.publish_combat_noise(origin, hearing_radius * noise_multiplier, noise_kind)
	if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
	return true

func play_dry_fire() -> void:
	if gun_data == null or is_reloading or cooldown > 0.0: return
	cooldown = 0.13
	dry_fire_audio.pitch_scale = randf_range(0.92, 1.08)
	dry_fire_audio.play()
	if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)

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

func _update_fire_mix() -> void:
	var attenuation := 0.0
	if enemy_owned:
		var listener := get_tree().get_first_node_in_group("player") as Node2D
		var distance := global_position.distance_to(listener.global_position) if is_instance_valid(listener) else 0.0
		attenuation = -4.0 - 14.0 * clampf(distance / 500.0, 0.0, 1.0)
	shot_audio.volume_db = shot_volume_db + attenuation
	punch_audio.volume_db = shot_volume_db - (15.0 if automatic else 10.0) + attenuation
	mechanical_audio.volume_db = (-27.0 if automatic else -22.0) + attenuation

func get_current_spread_degrees() -> float:
	var dynamic_spread := minf(maximum_spread_bonus, shot_heat * spread_growth_per_shot)
	return spread_degrees * 0.82 + dynamic_spread * 0.72 + _get_actor_movement_ratio() * movement_spread_degrees * 0.38 + aim_turn_instability * turn_spread_degrees * 0.34

func get_spread_feedback_ratio() -> float:
	var readable_max := maxf(1.0, spread_degrees + maximum_spread_bonus + movement_spread_degrees + turn_spread_degrees)
	return clampf(get_current_spread_degrees() / readable_max, 0.0, 1.0)

func get_total_spread_degrees() -> float:
	return get_current_spread_degrees() + pellet_spread_degrees

func get_reload_progress() -> float:
	if not is_reloading: return 0.0
	return clampf(1.0 - reload_timer.time_left / maxf(0.001, active_reload_duration), 0.0, 1.0)

func get_precision_threshold() -> int:
	var weapon_class: String = gun_data.weapon_class if gun_data != null else "handgun"
	match weapon_class:
		"shotgun": return 3
		"pdw", "smg": return 6
		"lmg": return 8
		"dmr", "sniper": return 3
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

func _get_safe_projectile_origin() -> Vector2:
	var visual_origin := muzzle.global_position
	var actor := _get_actor()
	if not is_instance_valid(actor) or not is_inside_tree(): return visual_origin
	var barrel := visual_origin - actor.global_position
	var barrel_length := barrel.length()
	if barrel_length < 0.001: return visual_origin
	var barrel_direction := barrel / barrel_length
	# A 19px barrel can extend entirely past a radius-5 enemy at touching range.
	# Sweep the barrel ONCE per shell, not once per pellet. Include doors/walls
	# and glass so a close opponent behind cover can never cause a bypass.
	var query_mask := (1 if enemy_owned else 2) | 4 | 8
	var query := PhysicsRayQueryParameters2D.create(actor.global_position, visual_origin + barrel_direction * 2.0, query_mask)
	query.exclude = [actor.get_rid()]
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return visual_origin
	# Bullet's 2x2 collision square has a sqrt(2) diagonal radius. Starting clear
	# of the surface keeps move_and_collide from recovering to its far side.
	var contact: Vector2 = hit.position
	var clear_distance := clampf(actor.global_position.distance_to(contact) - 1.6, 0.0, barrel_length)
	return actor.global_position + barrel_direction * clear_distance

func is_muzzle_blocked() -> bool:
	return _is_muzzle_obstructed()

func reload() -> void:
	if blood_fire_payment.is_valid(): return
	if gun_data == null or is_reloading or ammo >= max_ammo or reserve_ammo == 0: return
	if not enemy_owned and ammo <= 0 and precision_primed:
		_start_perfect_reload()
		return
	is_reloading = true
	perfect_reload_active = false
	active_reload_duration = reload_duration
	reload_timer.start(active_reload_duration)
	reload_audio.pitch_scale = randf_range(0.97, 1.03) * float(presentation_profile.sound)
	reload_audio.play()
	if not enemy_owned:
		Events.reload_started.emit(reload_duration)
		Events.publish_ammo(ammo, max_ammo, true)

func cancel_reload(publish := true) -> void:
	var was_reloading := is_reloading
	is_reloading = false
	perfect_reload_active = false
	active_reload_duration = reload_duration
	if is_instance_valid(reload_timer): reload_timer.stop()
	if is_instance_valid(reload_audio): reload_audio.stop()
	_reset_presentation()
	if was_reloading and publish and not enemy_owned:
		Events.publish_ammo(ammo, max_ammo, false)

func _on_reload_timer_timeout() -> void:
	if blood_fire_payment.is_valid():
		cancel_reload()
		return
	# A weapon switch/throw may cancel a timer on the same frame it expires.
	# Such stale completions must never load the newly equipped weapon.
	if not is_reloading or gun_data == null: return
	var required := max_ammo - ammo
	var loaded := required if reserve_ammo < 0 else mini(required, reserve_ammo)
	ammo += loaded
	if reserve_ammo >= 0:
		reserve_ammo -= loaded
		reserve_by_weapon[weapon_id] = reserve_ammo
	ammo_by_weapon[weapon_id] = ammo
	is_reloading = false
	_reset_presentation()
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
