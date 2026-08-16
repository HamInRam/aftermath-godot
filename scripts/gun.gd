class_name Gun
extends Node2D

signal fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)

const AUDIO_FACTORY := preload("res://utility/scripts/audio_factory.gd")

@export var fire_interval := 0.1
@export var fire_interval_variance := 0.018
@export var max_ammo := 12
@export var projectile_damage := 1
@export var enemy_owned := false
@export var automatic := true
@export var weapon_id := "pistol"
@export var reload_duration := 1.05

@onready var reload_timer: Timer = $ReloadTimer
@onready var shot_audio: AudioStreamPlayer = $ShotAudio
@onready var reload_audio: AudioStreamPlayer = $ReloadAudio
@onready var dry_fire_audio: AudioStreamPlayer = $DryFireAudio

var ammo := 12
var cooldown := 0.0
var recoil := 0.0
var is_reloading := false

func _ready() -> void:
	ammo = max_ammo
	shot_audio.stream = AUDIO_FACTORY.create_gunshot()
	reload_audio.stream = AUDIO_FACTORY.create_reload()
	dry_fire_audio.stream = AUDIO_FACTORY.create_dry_fire()
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	if not enemy_owned: Events.publish_ammo(ammo, max_ammo, false)
	queue_redraw()

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = move_toward(recoil, 0.0, 24.0 * delta)
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
	recoil = 2.0
	shot_audio.pitch_scale = randf_range(0.91, 1.09)
	shot_audio.play()
	var normalized_direction := direction.normalized()
	var origin := global_position + normalized_direction * 8.0
	fired.emit(origin, normalized_direction, enemy_owned, projectile_damage, weapon_id)
	Events.weapon_fired.emit(origin, normalized_direction, enemy_owned)
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
	is_reloading = false
	if not enemy_owned:
		Events.reload_finished.emit(ammo, max_ammo)
		Events.publish_ammo(ammo, max_ammo, false)

func _draw() -> void:
	var gun_color := Color("181820") if not enemy_owned else Color("28151f")
	draw_rect(Rect2(1.0 - recoil, -1.0, 9.0, 3.0), gun_color)
	draw_rect(Rect2(3.0 - recoil, 2.0, 2.0, 2.0), Color("34313b"))
