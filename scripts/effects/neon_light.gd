extends PointLight2D

@export_range(0.1, 10.0, 0.1) var pulse_speed := 3.0
@export_range(0.0, 4.0, 0.05) var base_energy := 0.8
@export_range(0.0, 1.0, 0.01) var wave_amplitude := 0.12
@export var is_flickering := false

var pulse_time := 0.0

func _ready() -> void:
	pulse_time = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	pulse_time += delta
	var next_energy := base_energy + sin(pulse_time * pulse_speed) * wave_amplitude
	if is_flickering and randf() > 0.94:
		next_energy += randf_range(-0.38, 0.2)
	energy = maxf(0.08, next_energy)
