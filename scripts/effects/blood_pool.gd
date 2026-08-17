extends Node2D

var growth := 0.08
var target_scale := 1.0
var growth_duration := 5.5
var amount := 1.0
var lobes: Array[Dictionary] = []

func _ready() -> void:
	CleanupRegistry.register_target(self)

func setup(intensity: float) -> void:
	target_scale = lerpf(0.82, 1.42, clampf((intensity - 0.7) / 1.5, 0.0, 1.0))
	growth_duration = lerpf(7.5, 4.2, clampf(intensity / 2.2, 0.0, 1.0))
	var lobe_count := clampi(roundi(12.0 + intensity * 5.0), 14, 24)
	for index in range(lobe_count):
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(1.0, 8.5) * target_scale
		lobes.append({
			"position": Vector2.RIGHT.rotated(angle) * distance,
			"radius": randf_range(1.4, 4.2) * target_scale,
			"dark": index % 4 == 0,
		})
	queue_redraw()

func _process(delta: float) -> void:
	if growth < 1.0:
		growth = move_toward(growth, 1.0, 1.0 / growth_duration * delta)
		queue_redraw()

func clean_step() -> void:
	amount -= 0.1
	if amount <= 0.02: queue_free()
	else: queue_redraw()

func get_cleanup_type() -> String:
	return "blood"

func get_cleanup_cost() -> int:
	return 10

func _draw() -> void:
	var blood := Color(0.48, 0.003, 0.025, 0.88 * amount)
	var dark := Color(0.19, 0.002, 0.01, 0.94 * amount)
	for lobe in lobes:
		draw_circle(lobe.position * growth, lobe.radius * growth, dark if lobe.dark else blood)
	draw_circle(Vector2.ZERO, 5.2 * growth * target_scale, blood)
