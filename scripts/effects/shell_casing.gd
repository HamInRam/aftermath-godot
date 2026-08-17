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
		_play_clink(impact_volume, 0.88, 1.18)

func _play_clink(volume: float, pitch_low: float, pitch_high: float) -> void:
	clink_audio.volume_db = volume + randf_range(-1.5, 1.0)
	clink_audio.pitch_scale = randf_range(pitch_low, pitch_high)
	clink_audio.play()

func clean_step() -> void:
	cleanup_amount -= 0.5
	modulate.a = clampf(cleanup_amount, 0.15, 1.0)
	if cleanup_amount <= 0.02: queue_free()

func get_cleanup_type() -> String:
	return "shell"

func get_cleanup_cost() -> int:
	return 2
