class_name GunData
extends Resource

@export var weapon_id := "pistol"
@export var display_name := "PISTOL"
@export var manufacturer := ""
@export var weapon_class := "handgun"
@export var caliber := "9x19mm"
@export_category("Blood Cycle Economy")
## One trigger pull, including all shotgun pellets.
@export_range(0.1, 30.0, 0.1) var caliber_blood_cost := 1.0
## World pixels, not storage chunks. 32 pixels equal one chunk-width.
@export_range(4.0, 320.0, 1.0) var blood_stain_radius := 24.0
@export_category("Ballistics & Handling")
@export var action_type := "semi_auto"
@export var feed_type := "detachable_magazine"
@export var magazine_family := "generic"
@export var fire_modes := PackedStringArray(["semi"])
@export var interface_tags := PackedStringArray()
@export var signature_trait := ""
@export var installed_attachments := PackedStringArray()
@export_range(100.0, 15000.0, 10.0) var empty_weight_grams := 700.0
@export_range(100.0, 1600.0, 1.0) var overall_length_mm := 200.0
@export_range(6, 30, 1) var visual_length_pixels := 9
@export var visual_profile := "handgun"
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
@export_range(1, 200, 1) var damage := 43
@export_range(0.0, 500.0, 1.0) var damage_falloff_start := 65.0
@export_range(1.0, 700.0, 1.0) var damage_falloff_end := 170.0
@export_range(0.2, 1.0, 0.01) var minimum_damage_ratio := 0.62
@export_range(0.03, 2.0, 0.01) var fire_interval := 0.1
@export_range(0.0, 0.2, 0.001) var fire_interval_variance := 0.018
@export_range(0.0, 12.0, 0.1) var spread_degrees := 0.0
@export_range(1, 12, 1) var pellet_count := 1
@export_range(0.0, 24.0, 0.5) var pellet_spread_degrees := 0.0
@export_range(0.0, 4.0, 0.05) var spread_growth_per_shot := 0.0
@export_range(0.0, 12.0, 0.1) var maximum_spread_bonus := 0.0
@export_range(0.1, 12.0, 0.1) var spread_recovery := 4.0
@export_range(0.0, 10.0, 0.1) var movement_spread_degrees := 2.0
@export_range(0.0, 8.0, 0.1) var turn_spread_degrees := 1.5
@export_range(1.0, 20.0, 0.5) var aim_follow_speed := 12.0
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
@export_range(0.0, 3.0, 0.05) var penetration_power := 0.8
@export_range(0.0, 3.0, 0.05) var property_damage := 0.8
@export_range(0.0, 3.0, 0.05) var cleanup_burden := 1.0
@export_range(0.2, 2.0, 0.01) var aim_convergence_multiplier := 1.0
@export_range(0.2, 2.0, 0.01) var weapon_length_multiplier := 1.0
@export_range(0.75, 1.75, 0.01) var camera_look_ahead_multiplier := 1.0
