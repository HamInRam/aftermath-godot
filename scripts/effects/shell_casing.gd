extends Node2D

const AUDIO_FACTORY := preload("res://utility/scripts/audio_factory.gd")

var velocity := Vector2.ZERO
var spin := 0.0
var settled := false
var launch_speed := 0.0
var played_bounce := false
var allow_bounce := false

@onready var clink_audio: AudioStreamPlayer2D = $ClinkAudio

func _ready() -> void:
	clink_audio.stream = AUDIO_FACTORY.create_casing_clink()

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
		_play_clink(-24.0, 1.12, 1.34)
	if velocity.length_squared() < 0.3:
		settled = true
		position = position.round()
		rotation = snappedf(rotation, PI * 0.5)
		var impact_volume := remap(clampf(launch_speed, 16.0, 34.0), 16.0, 34.0, -21.0, -13.5)
		_play_clink(impact_volume, 0.88, 1.18)

func _play_clink(volume: float, pitch_low: float, pitch_high: float) -> void:
	clink_audio.volume_db = volume + randf_range(-1.5, 1.0)
	clink_audio.pitch_scale = randf_range(pitch_low, pitch_high)
	clink_audio.play()
