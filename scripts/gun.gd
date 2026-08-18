class_name Gun
extends Node2D

signal fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)

const DRY_FIRE_STREAM := preload("res://assets/audio/sfx/dry_fire.wav")
const PISTOL_TEXTURE := preload("res://assets/weapons/pistol_10x4.png")

@export var gun_data: Resource
@export var enemy_owned := false
var automatic := false

var fire_interval := 0.1
var fire_interval_variance := 0.018
var spread_degrees := 0.0
var spread_growth_per_shot := 0.0
var maximum_spread_bonus := 0.0
var spread_recovery := 4.0
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

var ammo := 12
var cooldown := 0.0
var recoil := 0.0
var shot_heat := 0.0
var is_reloading := false
var ammo_by_weapon: Dictionary = {}

func _ready() -> void:
	set_gun_data(gun_data, true)
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
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
	spread_growth_per_shot = gun_data.spread_growth_per_shot
	maximum_spread_bonus = gun_data.maximum_spread_bonus
	spread_recovery = gun_data.spread_recovery
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

func set_gun_data(data: Resource, refill := true) -> void:
	if data == null: return
	if gun_data != null and not weapon_id.is_empty():
		ammo_by_weapon[weapon_id] = ammo
	gun_data = data
	_apply_gun_data()
	if ammo_by_weapon.has(weapon_id):
		ammo = clampi(int(ammo_by_weapon[weapon_id]), 0, max_ammo)
	elif refill:
		ammo = max_ammo
	else:
		ammo = 0
	ammo_by_weapon[weapon_id] = ammo
	is_reloading = false
	shot_heat = 0.0
	if is_instance_valid(reload_timer): reload_timer.stop()
	if is_instance_valid(shot_audio):
		shot_audio.stream = gun_data.shot_stream
		shot_audio.volume_db = shot_volume_db
		reload_audio.stream = gun_data.reload_stream
		dry_fire_audio.stream = gun_data.dry_fire_stream if gun_data.dry_fire_stream != null else DRY_FIRE_STREAM
		mechanical_audio.stream = dry_fire_audio.stream
		punch_audio.stream = shot_audio.stream
		weapon_sprite.texture = gun_data.weapon_texture if gun_data.weapon_texture != null else PISTOL_TEXTURE
		weapon_shadow.texture = weapon_sprite.texture
		muzzle.position.x = weapon_sprite.texture.get_width() * 0.5 + 1.0
		if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
	queue_redraw()

func set_weapon_ammo(target_weapon_id: String, rounds: int) -> void:
	ammo_by_weapon[target_weapon_id] = maxi(0, rounds)
	if weapon_id == target_weapon_id:
		ammo = clampi(rounds, 0, max_ammo)
		if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)

func get_weapon_ammo(target_weapon_id: String) -> int:
	if target_weapon_id == weapon_id: return ammo
	return int(ammo_by_weapon.get(target_weapon_id, 0))

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = move_toward(recoil, 0.0, 24.0 * delta)
	shot_heat = move_toward(shot_heat, 0.0, spread_recovery * delta)
	queue_redraw()

func try_fire(direction: Vector2) -> bool:
	if is_reloading or direction.length_squared() < 0.001: return false
	if cooldown > 0.0: return false
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
	var current_spread := spread_degrees + dynamic_spread
	var spread_radians := deg_to_rad(randf_range(-current_spread, current_spread))
	shot_heat += 1.0
	var normalized_direction := direction.normalized().rotated(spread_radians)
	var origin := muzzle.global_position
	fired.emit(origin, normalized_direction, enemy_owned, projectile_damage, weapon_id)
	Events.weapon_fired.emit(origin, normalized_direction, enemy_owned, weapon_id)
	Events.publish_combat_noise(origin, hearing_radius, "gunshot")
	if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
	return true

func reload() -> void:
	if is_reloading or ammo >= max_ammo: return
	is_reloading = true
	reload_timer.start(reload_duration)
	reload_audio.pitch_scale = randf_range(0.97, 1.03)
	reload_audio.play()
	if not enemy_owned:
		Events.reload_started.emit(reload_duration)
		Events.publish_ammo(ammo, max_ammo, true)

func _on_reload_timer_timeout() -> void:
	ammo = max_ammo
	ammo_by_weapon[weapon_id] = ammo
	is_reloading = false
	if not enemy_owned:
		Events.reload_finished.emit(ammo, max_ammo)
		Events.publish_ammo(ammo, max_ammo, false)
