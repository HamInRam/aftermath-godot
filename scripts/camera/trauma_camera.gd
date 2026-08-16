class_name TraumaCamera
extends Camera2D

@export_range(0.1, 5.0, 0.05) var trauma_decay := 1.65
@export_range(0.0, 12.0, 0.1) var max_offset := 3.6
@export_range(0.0, 0.2, 0.001) var max_rotation := 0.028
@export_range(0.1, 30.0, 0.1) var noise_speed := 12.0
@export_range(1, 8, 1) var noise_octaves := 3

var trauma := 0.0
var noise_time := 0.0
var noise := FastNoiseLite.new()

func _ready() -> void:
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.085
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = noise_octaves
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	noise_time += delta * noise_speed
	var shake := trauma * trauma
	if shake <= 0.0001:
		offset = offset.lerp(Vector2.ZERO, 1.0 - exp(-18.0 * delta))
		rotation = lerp_angle(rotation, 0.0, 1.0 - exp(-18.0 * delta))
		return
	offset = Vector2(noise.get_noise_1d(noise_time), noise.get_noise_1d(noise_time + 71.7)) * max_offset * shake
	rotation = noise.get_noise_1d(noise_time + 143.4) * max_rotation * shake
