class_name TraumaCamera
extends Camera2D

signal impact_flash_requested(color: Color)

@export_range(0.1, 5.0, 0.05) var trauma_decay := 1.65
@export_range(0.0, 12.0, 0.1) var max_offset := 3.6
@export_range(0.0, 0.2, 0.001) var max_rotation := 0.0
@export_range(0.1, 30.0, 0.1) var noise_speed := 12.0
@export_range(1, 8, 1) var noise_octaves := 3
@export_range(0.0, 180.0, 1.0) var max_look_ahead := 120.0
@export_range(0.0, 240.0, 1.0) var extended_look_ahead := 168.0
@export_range(0.0, 1.0, 0.05) var normal_look_weight := 0.58
@export_range(0.0, 1.0, 0.05) var extended_look_weight := 0.72
@export_range(0.0, 24.0, 1.0) var combat_visibility_margin := 8.0
@export_range(1.0, 20.0, 0.5) var follow_speed_x := 7.5
@export_range(1.0, 20.0, 0.5) var follow_speed_y := 6.5
@export_range(1.0, 2.0, 0.05) var exploration_zoom := 1.18
@export var camera_center_bounds := Rect2(160.0, 90.0, 64.0, 44.0)
@export_group("Position Tilt")
@export_range(0.0, 4.0, 0.05) var tilt_max_degrees := 0.55
@export_range(0.0, 96.0, 1.0) var tilt_dead_zone := 24.0
@export_range(32.0, 256.0, 1.0) var tilt_full_distance := 160.0
@export_range(1.0, 20.0, 0.5) var tilt_smoothing := 6.5
@export var tilt_room_center_x := 192.0
@export_group("Ambient Drift")
@export var ambient_drift_enabled := true
@export_range(0.0, 3.0, 0.05) var drift_speed := 0.42
@export_range(0.0, 0.02, 0.0005) var max_drift_angle := 0.007

var trauma := 0.0
var noise_time := 0.0
var noise := FastNoiseLite.new()
var follow_target: Node2D
var smooth_follow_position := Vector2.ZERO
var smooth_shake_offset := Vector2.ZERO
var smooth_tilt := 0.0
var drift_time := 0.0
var shake_strength := 1.0
var directional_offset := Vector2.ZERO
var last_player_shot_direction := Vector2.RIGHT
var impact_frame := -1
var frame_impact_peak := 0.0
var frame_trauma_start := 0.0
const PRESENTATION := preload("res://utility/weapon_presentation_profile.gd")
const MAX_DIRECTIONAL_OFFSET := 2.6

func _ready() -> void:
	zoom = Vector2.ONE * exploration_zoom
	shake_strength = Settings.screen_shake_strength
	ambient_drift_enabled = ambient_drift_enabled and Settings.ambient_camera_motion_enabled
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.085
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = noise_octaves
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	follow_target = get_tree().get_first_node_in_group("player") as Node2D
	smooth_follow_position = global_position
	Events.weapon_fired.connect(_on_presented_weapon_fire)

func configure_world_bounds(world_rect: Rect2) -> void:
	# The wider arcade framing shows roughly 271x153 world pixels at 320x180:
	# enough floor for fast lateral movement while the building still unfolds one
	# chamber at a time rather than becoming a full-map tactical overview.
	var viewport_size := get_viewport_rect().size
	var half_visible := viewport_size / maxf(1.0, exploration_zoom) * 0.5
	var minimum := world_rect.position + half_visible
	var maximum := world_rect.end - half_visible
	if maximum.x < minimum.x: minimum.x = world_rect.get_center().x; maximum.x = minimum.x
	if maximum.y < minimum.y: minimum.y = world_rect.get_center().y; maximum.y = minimum.y
	camera_center_bounds = Rect2(minimum, maximum - minimum)
	tilt_room_center_x = world_rect.get_center().x

func add_trauma(amount: float) -> void:
	# Simultaneous pellets, kills and debris share one peak instead of multiplying
	# camera motion by the number of objects. A stronger impact still wins.
	var frame := Engine.get_process_frames()
	if frame != impact_frame:
		impact_frame = frame
		frame_impact_peak = 0.0
		frame_trauma_start = trauma
	frame_impact_peak = maxf(frame_impact_peak, maxf(0.0, amount))
	var headroom := 1.0 - frame_trauma_start * 0.72
	trauma = clampf(frame_trauma_start + frame_impact_peak * headroom, 0.0, 1.0)

func trigger_kill_effect(shake_power := 0.42, flash_type := "red") -> void:
	add_trauma(shake_power * 0.45)
	add_directional_impulse(-last_player_shot_direction, clampf(shake_power, 0.3, 0.9))
	var flash_color := Color(0.82, 0.0, 0.1, 0.12) if flash_type == "red" else Color(1.0, 1.0, 1.0, 0.15)
	impact_flash_requested.emit(flash_color)

func _on_presented_weapon_fire(_origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String) -> void:
	# Enemy fire is already legible as world-space flash/projectile movement.
	# Only the player's trigger pulls kick the camera away from the firing axis.
	if enemy_owned: return
	last_player_shot_direction = direction.normalized()
	var platform := WeaponPlatformCatalog.get_platform(weapon_id)
	var profile := PRESENTATION.for_class(str(platform.get("class", "handgun")))
	add_directional_impulse(-last_player_shot_direction, float(profile.camera))

func add_directional_impulse(direction: Vector2, strength: float) -> void:
	if direction.length_squared() < 0.001: return
	directional_offset = (directional_offset * 0.35 + direction.normalized() * clampf(strength, 0.0, MAX_DIRECTIONAL_OFFSET)).limit_length(MAX_DIRECTIONAL_OFFSET)

func get_follow_position(player_position: Vector2, mouse_position: Vector2) -> Vector2:
	var weapon_multiplier := 1.0
	if is_instance_valid(follow_target) and follow_target.has_method("get_camera_look_ahead_multiplier"):
		weapon_multiplier = float(follow_target.get_camera_look_ahead_multiplier())
	var context_targeting: bool = is_instance_valid(follow_target) and follow_target.has_method("is_targeting_mode_active") and bool(follow_target.is_targeting_mode_active())
	return get_follow_position_for_mode(player_position, mouse_position, Input.is_action_pressed("look_ahead") or context_targeting, weapon_multiplier)

func get_follow_position_for_mode(player_position: Vector2, mouse_position: Vector2, peeking: bool, weapon_multiplier := 1.0) -> Vector2:
	var mouse_delta := mouse_position - player_position
	var distance_limit := (extended_look_ahead if peeking else max_look_ahead) * clampf(weapon_multiplier, 0.75, 1.55)
	var weight := extended_look_weight if peeking else normal_look_weight
	var desired := player_position + mouse_delta.limit_length(distance_limit) * weight
	desired.x = clampf(desired.x, camera_center_bounds.position.x, camera_center_bounds.end.x)
	desired.y = clampf(desired.y, camera_center_bounds.position.y, camera_center_bounds.end.y)
	return desired

func is_world_position_combat_visible(world_position: Vector2) -> bool:
	# Hostiles may track and reposition outside the frame, but they may only
	# complete a shot once their body has entered the player's readable view.
	# This keeps long sightlines dangerous without allowing invisible deaths.
	var screen_center := get_screen_center_position()
	var relative := (world_position - screen_center).rotated(-global_rotation)
	var safe_half_extent := get_viewport_rect().size / (zoom * 2.0) - Vector2.ONE * combat_visibility_margin
	return absf(relative.x) <= maxf(1.0, safe_half_extent.x) and absf(relative.y) <= maxf(1.0, safe_half_extent.y)

func get_tilt_target(player_x: float) -> float:
	var signed_distance := player_x - tilt_room_center_x
	var distance_outside_buffer := maxf(0.0, absf(signed_distance) - tilt_dead_zone)
	var usable_distance := maxf(1.0, tilt_full_distance - tilt_dead_zone)
	var percentage := clampf(distance_outside_buffer / usable_distance, 0.0, 1.0)
	# Moving right tilts clockwise; moving left mirrors the angle.
	return deg_to_rad(tilt_max_degrees) * Settings.camera_tilt_strength * -signf(signed_distance) * percentage

func _physics_process(delta: float) -> void:
	drift_time += delta
	directional_offset *= exp(-22.0 * delta)
	if directional_offset.length_squared() < 0.0001: directional_offset = Vector2.ZERO
	if not is_instance_valid(follow_target):
		follow_target = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(follow_target):
		var desired := get_follow_position(follow_target.global_position, get_global_mouse_position())
		# Independent axis damping keeps fast lateral strafes responsive while
		# vertical room transitions retain a slightly heavier cinematic lag.
		smooth_follow_position.x = lerpf(smooth_follow_position.x, desired.x, 1.0 - exp(-follow_speed_x * delta))
		smooth_follow_position.y = lerpf(smooth_follow_position.y, desired.y, 1.0 - exp(-follow_speed_y * delta))
		global_position = smooth_follow_position.round()
		var desired_tilt := get_tilt_target(follow_target.global_position.x)
		smooth_tilt = lerp_angle(smooth_tilt, desired_tilt, 1.0 - exp(-tilt_smoothing * delta))
	else:
		smooth_tilt = lerp_angle(smooth_tilt, 0.0, 1.0 - exp(-tilt_smoothing * delta))
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	noise_time += delta * noise_speed
	var shake := trauma * trauma
	if shake <= 0.0001:
		smooth_shake_offset = smooth_shake_offset.lerp(Vector2.ZERO, 1.0 - exp(-18.0 * delta))
		var tilt_pixel := roundi(rad_to_deg(smooth_tilt) * 1.8)
		var drift_pixel := roundi(sin(drift_time * drift_speed)) if ambient_drift_enabled else 0
		offset = (smooth_shake_offset + directional_offset * shake_strength).round() + Vector2(drift_pixel, tilt_pixel)
		rotation = 0.0
		return
	smooth_shake_offset = Vector2(noise.get_noise_1d(noise_time), noise.get_noise_1d(noise_time + 71.7)) * minf(max_offset, 1.5) * shake * shake_strength
	var tilt_pixel := roundi(rad_to_deg(smooth_tilt) * 1.8)
	var drift_pixel := roundi(sin(drift_time * drift_speed)) if ambient_drift_enabled else 0
	offset = (smooth_shake_offset + directional_offset * shake_strength).round() + Vector2(drift_pixel, tilt_pixel)
	rotation = 0.0
