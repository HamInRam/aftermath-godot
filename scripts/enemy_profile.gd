class_name EnemyProfile
extends Resource

@export var archetype_id := "gunner"
@export_enum("gunner", "melee") var combat_type := "gunner"
@export_enum("human", "dog") var actor_type := "human"
@export var default_weapon_id := ""
@export var display_name := "GUNNER"
@export var move_speed := 42.0
@export var chase_speed_multiplier := 1.35
@export var preferred_distance := 68.0
@export var detection_range := 205.0
@export var vision_fov_degrees := 90.0
@export var reaction_time_min := 0.2
@export var reaction_time_max := 0.4
@export var melee_range := 17.0
@export var melee_interval := 0.7
@export_range(0.5, 2.0, 0.05) var attack_windup_multiplier := 1.0
@export_range(0.0, 0.5, 0.01) var aim_tracking_strength := 0.15
@export_range(1.0, 4.0, 0.05) var enemy_spread_multiplier := 2.4
@export_range(0.0, 2.0, 0.05) var distance_spread_multiplier := 1.0
@export_range(0.0, 0.2, 0.01) var aim_prediction_seconds := 0.07
@export_range(0.0, 1.0, 0.05) var knockdown_resistance := 0.0
@export var sprite_modulate := Color(1.18, 0.92, 1.06, 1.0)
