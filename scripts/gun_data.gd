class_name GunData
extends Resource

@export var weapon_id := "pistol"
@export var display_name := "PISTOL"
@export var automatic := false
@export var weapon_texture: Texture2D
@export var shot_stream: AudioStream
@export var reload_stream: AudioStream
@export var dry_fire_stream: AudioStream
@export var death_style := "firearm"
@export_range(-30.0, 6.0, 0.5) var shot_volume_db := -10.0
@export_range(0.4, 1.6, 0.01) var mechanical_pitch := 1.0
@export_range(0.4, 1.6, 0.01) var punch_pitch := 0.73
@export_range(1, 999, 1) var ammo_capacity := 12
@export_range(1, 100, 1) var damage := 1
@export_range(0.03, 2.0, 0.01) var fire_interval := 0.1
@export_range(0.0, 0.2, 0.001) var fire_interval_variance := 0.018
@export_range(0.0, 12.0, 0.1) var spread_degrees := 0.0
@export_range(0.0, 4.0, 0.05) var spread_growth_per_shot := 0.0
@export_range(0.0, 12.0, 0.1) var maximum_spread_bonus := 0.0
@export_range(0.1, 12.0, 0.1) var spread_recovery := 4.0
@export_range(0.1, 5.0, 0.05) var reload_duration := 1.05
@export_range(0.4, 1.2, 0.01) var movement_speed_multiplier := 1.0
@export_range(0.3, 1.0, 0.01) var reload_movement_multiplier := 0.8
@export_range(0.5, 1.5, 0.01) var pitch_min := 0.91
@export_range(0.5, 1.5, 0.01) var pitch_max := 1.09
@export_range(0.1, 3.0, 0.05) var blood_power := 1.0
@export_range(16.0, 240.0, 1.0) var blood_range := 150.0
@export_range(8.0, 96.0, 1.0) var blood_wall_reach := 48.0
@export_enum("line", "fan", "radial") var blood_pattern := "line"
@export_range(0.05, 1.5, 0.01) var blood_cone := 0.24
@export_range(0.0, 3.0, 0.05) var recoil_strength := 0.7
@export_range(0.0, 3.0, 0.05) var camera_shake := 0.7
@export_range(8.0, 48.0, 1.0) var muzzle_flash_size := 26.0
@export_range(0.01, 0.1, 0.005) var muzzle_flash_duration := 0.045
@export_range(300.0, 1000.0, 10.0) var bullet_speed := 650.0
@export_range(0.0, 80.0, 1.0) var knockback := 24.0
@export_range(0.0, 800.0, 5.0) var hearing_radius := 190.0
@export_range(0.0, 0.1, 0.005) var hit_stop := 0.035
