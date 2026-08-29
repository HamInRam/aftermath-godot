extends Node2D

const CLINK_STREAMS := [
	preload("res://assets/audio/sfx/casing_01.wav"),
	preload("res://assets/audio/sfx/casing_02.wav"),
	preload("res://assets/audio/sfx/casing_03.wav"),
	preload("res://assets/audio/sfx/casing_04.wav"),
	preload("res://assets/audio/sfx/casing_05.wav"),
]

var velocity := Vector2.ZERO
var spin := 0.0
var settled := false
var launch_speed := 0.0
var played_bounce := false
var allow_bounce := false
var cleanup_amount := 1.0
var bloodied := false

@onready var clink_audio: AudioStreamPlayer2D = $ClinkAudio

func _ready() -> void:
	CleanupRegistry.register_target(self)
	clink_audio.stream = CLINK_STREAMS.pick_random()

func setup(shot_direction: Vector2, enemy_owned: bool) -> void:
	var side := shot_direction.normalized().rotated(-PI * 0.5)
	velocity = side.rotated(randf_range(-0.45, 0.45)) * randf_range(18.0, 31.0)
	velocity += -shot_direction.normalized() * randf_range(2.0, 7.0)
	spin = randf_range(-18.0, 18.0)
	launch_speed = velocity.length()
	allow_bounce = randf() < 0.38
	modulate = Color("c87558") if enemy_owned else Color("ffe06b")

func _process(delta: float) -> void:
	if settled: return
	position += velocity * delta
	rotation += spin * delta
	velocity *= exp(-8.5 * delta)
	spin *= exp(-7.0 * delta)
	if allow_bounce and not played_bounce and velocity.length() < 8.5:
		played_bounce = true
		_play_clink(-18.5, 1.08, 1.28)
	if velocity.length_squared() < 0.3:
		settled = true
		position = position.round()
		rotation = snappedf(rotation, PI * 0.5)
		var impact_volume := remap(clampf(launch_speed, 16.0, 34.0), 16.0, 34.0, -16.0, -8.0)
		_check_blood_contact()
		_play_clink(impact_volume - (4.0 if bloodied else 0.0), 0.82 if bloodied else 0.88, 1.02 if bloodied else 1.18)

func _check_blood_contact() -> void:
	for source in get_tree().get_nodes_in_group("blood_source"):
		if source is Node2D and global_position.distance_squared_to(source.global_position) <= 49.0:
			bloodied = true
			modulate = modulate.lerp(Color("7f1731"), 0.58)
			return

func _play_clink(volume: float, pitch_low: float, pitch_high: float) -> void:
	var surface_volume := 0.0
	var surface_pitch := 1.0
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	if is_instance_valid(world) and world.has_method("get_blood_surface_profile"):
		var profile: Dictionary = world.get_blood_surface_profile(global_position)
		var spread := float(profile.get("spread", 1.0))
		if spread >= 1.3:
			surface_volume = -5.0 if float(profile.get("darken", 0.0)) > 0.22 else -2.2
			surface_pitch = 0.88 if surface_volume < -4.0 else 0.95
		elif spread <= 0.9:
			surface_volume = 1.4
			surface_pitch = 1.08
	clink_audio.volume_db = volume + surface_volume + randf_range(-1.5, 1.0)
	clink_audio.pitch_scale = randf_range(pitch_low, pitch_high) * surface_pitch
	if DisplayServer.get_name() != "headless": clink_audio.play()

func _exit_tree() -> void:
	if not is_instance_valid(clink_audio): return
	clink_audio.stop()
	clink_audio.stream = null

func clean_step() -> void:
	cleanup_amount -= 0.5
	modulate.a = clampf(cleanup_amount, 0.15, 1.0)
	if cleanup_amount <= 0.02:
		CleanupRegistry.unregister_target(self)
		queue_free()

func get_cleanup_type() -> String:
	return "shell"

func get_cleanup_cost() -> int:
	return 2
