class_name TraumaCamera
extends Camera2D

@export_range(0.1, 5.0, 0.05) var trauma_decay := 1.65
@export_range(0.0, 12.0, 0.1) var max_offset := 3.6
@export_range(0.0, 0.2, 0.001) var max_rotation := 0.0
@export_range(0.1, 30.0, 0.1) var noise_speed := 12.0
@export_range(1, 8, 1) var noise_octaves := 3
@export_range(0.0, 120.0, 1.0) var max_look_ahead := 58.0
@export_range(1.0, 20.0, 0.5) var follow_speed := 7.5
@export var camera_center_bounds := Rect2(160.0, 90.0, 64.0, 44.0)
@export_group("Position Tilt")
@export_range(0.0, 4.0, 0.1) var tilt_max_degrees := 1.4
@export_range(0.0, 96.0, 1.0) var tilt_dead_zone := 24.0
@export_range(32.0, 256.0, 1.0) var tilt_full_distance := 160.0
@export_range(1.0, 20.0, 0.5) var tilt_smoothing := 6.5
@export var tilt_room_center_x := 192.0

var trauma := 0.0
var noise_time := 0.0
var noise := FastNoiseLite.new()
var follow_target: Node2D
var smooth_follow_position := Vector2.ZERO
var smooth_shake_offset := Vector2.ZERO
var smooth_tilt := 0.0

func _ready() -> void:
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.085
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = noise_octaves
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	follow_target = get_tree().get_first_node_in_group("player") as Node2D
	smooth_follow_position = global_position

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func get_follow_position(player_position: Vector2, mouse_position: Vector2) -> Vector2:
	var mouse_delta := mouse_position - player_position
	var desired := player_position + mouse_delta.limit_length(max_look_ahead) * 0.5
	desired.x = clampf(desired.x, camera_center_bounds.position.x, camera_center_bounds.end.x)
	desired.y = clampf(desired.y, camera_center_bounds.position.y, camera_center_bounds.end.y)
	return desired

func get_tilt_target(player_x: float) -> float:
	var signed_distance := player_x - tilt_room_center_x
	var distance_outside_buffer := maxf(0.0, absf(signed_distance) - tilt_dead_zone)
	var usable_distance := maxf(1.0, tilt_full_distance - tilt_dead_zone)
	var percentage := clampf(distance_outside_buffer / usable_distance, 0.0, 1.0)
	# Moving right tilts clockwise; moving left mirrors the angle.
	return deg_to_rad(tilt_max_degrees) * -signf(signed_distance) * percentage

func _physics_process(delta: float) -> void:
	if not is_instance_valid(follow_target):
		follow_target = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(follow_target):
		var desired := get_follow_position(follow_target.global_position, get_global_mouse_position())
		smooth_follow_position = smooth_follow_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
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
		offset = smooth_shake_offset.round()
		rotation = smooth_tilt
		return
	smooth_shake_offset = Vector2(noise.get_noise_1d(noise_time), noise.get_noise_1d(noise_time + 71.7)) * max_offset * shake
	offset = smooth_shake_offset.round()
	rotation = smooth_tilt
