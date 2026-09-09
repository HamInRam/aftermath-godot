extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

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
var casing_tint := Color("ffc800")
static var next_clink_ms := 0
var simulated_position := Vector2.ZERO
var simulated_rotation := 0.0

@onready var clink_audio: AudioStreamPlayer2D = $ClinkAudio

func _ready() -> void:
	add_to_group("siphon_scrap")
	z_index = 3
	var brass_material := CanvasItemMaterial.new()
	brass_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = brass_material
	CleanupRegistry.register_target(self)
	clink_audio.stream = CLINK_STREAMS.pick_random()
	simulated_position = position
	simulated_rotation = rotation
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	var axis := Vector2.RIGHT.rotated(simulated_rotation)
	draw_set_transform_matrix(global_transform.affine_inverse())
	PIXELS.pixel(self, (global_position + Vector2.ONE).round(), Color(0, 0, 0, 0.42))
	PIXELS.pixel(self, global_position.round(), casing_tint)
	PIXELS.pixel(self, (global_position + axis).round(), Color("d99a00"))
	PIXELS.pixel(self, (global_position + Vector2.DOWN).round(), Color("d99a00"))
	PIXELS.pixel(self, (global_position + axis + Vector2.DOWN).round(), casing_tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func setup(shot_direction: Vector2, _enemy_owned: bool) -> void:
	var side := shot_direction.normalized().rotated(-PI * 0.5)
	velocity = side.rotated(randf_range(-0.45, 0.45)) * randf_range(18.0, 31.0)
	velocity += -shot_direction.normalized() * randf_range(2.0, 7.0)
	spin = randf_range(-18.0, 18.0)
	launch_speed = velocity.length()
	allow_bounce = randf() < 0.38
	# Main positions the casing after add_child/_ready. Capture the true ejection
	# point now; otherwise its first frame jumps back to the scene origin.
	simulated_position = position
	simulated_rotation = rotation
	rotation = 0.0
	casing_tint = Color("ffc800")
	queue_redraw()

func _process(delta: float) -> void:
	if settled: return
	var destination := simulated_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, get_parent().to_global(destination), 4)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): simulated_position = destination
	else:
		simulated_position = get_parent().to_local(hit.position + hit.normal)
		velocity = velocity.bounce(hit.normal) * 0.25
	simulated_rotation += spin * delta
	position = simulated_position.round()
	rotation = 0.0
	queue_redraw()
	velocity *= exp(-8.5 * delta)
	spin *= exp(-7.0 * delta)
	if allow_bounce and not played_bounce and velocity.length() < 8.5:
		played_bounce = true
		_play_clink(-18.5, 1.08, 1.28)
	if velocity.length_squared() < 0.3:
		settled = true
		set_process(false)
		position = position.round()
		simulated_rotation = snappedf(simulated_rotation, PI * 0.5)
		simulated_position = position
		var impact_volume := remap(clampf(launch_speed, 16.0, 34.0), 16.0, 34.0, -16.0, -8.0)
		_play_clink(impact_volume, 0.88, 1.18)

func _play_clink(volume: float, pitch_low: float, pitch_high: float) -> void:
	var now := Time.get_ticks_msec()
	if now < next_clink_ms: return
	next_clink_ms = now + 45
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

func siphon_toward(target: Vector2) -> void:
	var offset := target - global_position
	if offset.length() <= 10.0: return
	settled = false
	simulated_position = position
	velocity = offset.normalized() * minf(125.0, offset.length() * 5.0)
	spin = 12.0
	set_process(true)

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
