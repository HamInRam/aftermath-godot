class_name TraumaCamera
extends Camera2D

signal impact_flash_requested(color: Color)

@export_range(0.1, 5.0, 0.05) var trauma_decay := 1.65
@export_range(0.0, 12.0, 0.1) var max_offset := 3.6
@export_range(0.0, 0.2, 0.001) var max_rotation := 0.0
@export_range(0.1, 30.0, 0.1) var noise_speed := 12.0
@export_range(1, 8, 1) var noise_octaves := 3
@export_range(0.0, 120.0, 1.0) var max_look_ahead := 58.0
@export_range(0.0, 200.0, 1.0) var extended_look_ahead := 125.0
@export_range(0.0, 1.0, 0.05) var normal_look_weight := 0.25
@export_range(0.0, 1.0, 0.05) var extended_look_weight := 0.55
@export_range(1.0, 20.0, 0.5) var follow_speed_x := 7.5
@export_range(1.0, 20.0, 0.5) var follow_speed_y := 6.5
@export_range(1.0, 2.0, 0.05) var exploration_zoom := 1.35
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

func configure_world_bounds(world_rect: Rect2) -> void:
	# Derive legal camera centres from the actual visible footprint. At 320x180
	# and 1.35x zoom the player sees roughly 237x133 world pixels: enough to read
	# the current room and a connected sightline, never the whole building.
	var viewport_size := get_viewport_rect().size
	var half_visible := viewport_size / maxf(1.0, exploration_zoom) * 0.5
	var minimum := world_rect.position + half_visible
	var maximum := world_rect.end - half_visible
	if maximum.x < minimum.x: minimum.x = world_rect.get_center().x; maximum.x = minimum.x
	if maximum.y < minimum.y: minimum.y = world_rect.get_center().y; maximum.y = minimum.y
	camera_center_bounds = Rect2(minimum, maximum - minimum)
	tilt_room_center_x = world_rect.get_center().x

func add_trauma(amount: float) -> void:
	# Repeated impacts should intensify the shake without pinning the camera at its
	# maximum for an entire automatic burst.
	var headroom := 1.0 - trauma * 0.72
	trauma = clampf(trauma + amount * headroom, 0.0, 1.0)

func trigger_kill_effect(shake_power := 0.42, flash_type := "red") -> void:
	add_trauma(shake_power)
	var flash_color := Color(0.8, 0.0, 0.2, 0.24) if flash_type == "red" else Color(1.0, 1.0, 1.0, 0.34)
	impact_flash_requested.emit(flash_color)

func get_follow_position(player_position: Vector2, mouse_position: Vector2) -> Vector2:
	return get_follow_position_for_mode(player_position, mouse_position, Input.is_action_pressed("look_ahead"))

func get_follow_position_for_mode(player_position: Vector2, mouse_position: Vector2, peeking: bool) -> Vector2:
	var mouse_delta := mouse_position - player_position
	var distance_limit := extended_look_ahead if peeking else max_look_ahead
	var weight := extended_look_weight if peeking else normal_look_weight
	var desired := player_position + mouse_delta.limit_length(distance_limit) * weight
	desired.x = clampf(desired.x, camera_center_bounds.position.x, camera_center_bounds.end.x)
	desired.y = clampf(desired.y, camera_center_bounds.position.y, camera_center_bounds.end.y)
	return desired

func get_tilt_target(player_x: float) -> float:
	var signed_distance := player_x - tilt_room_center_x
	var distance_outside_buffer := maxf(0.0, absf(signed_distance) - tilt_dead_zone)
	var usable_distance := maxf(1.0, tilt_full_distance - tilt_dead_zone)
	var percentage := clampf(distance_outside_buffer / usable_distance, 0.0, 1.0)
	# Moving right tilts clockwise; moving left mirrors the angle.
	return deg_to_rad(tilt_max_degrees) * Settings.camera_tilt_strength * -signf(signed_distance) * percentage

func _physics_process(delta: float) -> void:
	drift_time += delta
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
		offset = smooth_shake_offset.round() + Vector2(drift_pixel, tilt_pixel)
		rotation = 0.0
		return
	smooth_shake_offset = Vector2(noise.get_noise_1d(noise_time), noise.get_noise_1d(noise_time + 71.7)) * max_offset * shake * shake_strength
	var tilt_pixel := roundi(rad_to_deg(smooth_tilt) * 1.8)
	var drift_pixel := roundi(sin(drift_time * drift_speed)) if ambient_drift_enabled else 0
	offset = smooth_shake_offset.round() + Vector2(drift_pixel, tilt_pixel)
	rotation = 0.0
