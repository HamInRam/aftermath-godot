extends Node2D

const AUDIO_FACTORY := preload("res://utility/scripts/audio_factory.gd")

var amount := 1.0
var lobes: Array[Dictionary] = []
var streaks: Array[Dictionary] = []
var configured := false
var wall_stain := false
var base_intensity := 1.0

func _ready() -> void:
	if not configured:
		setup(Vector2.RIGHT.rotated(randf_range(0.0, TAU)), 1.0, false, false)

func setup(spray_direction: Vector2, intensity: float, on_wall: bool, play_splat := false) -> void:
	configured = true
	wall_stain = on_wall
	base_intensity = clampf(intensity, 0.5, 2.8)
	var direction := spray_direction.normalized()
	rotation = direction.angle()
	var lobe_count := clampi(roundi(9.0 + base_intensity * 7.0), 10, 28)
	for i in range(lobe_count):
		var forward := pow(randf(), 0.62) * (8.0 + base_intensity * 8.0)
		var side := randfn(0.0, 2.0 + base_intensity * 1.9) * (0.55 if wall_stain else 1.0)
		var position := Vector2(forward, side)
		var radius := randf_range(0.45, 1.45) * lerpf(0.75, 1.35, base_intensity / 2.8)
		lobes.append({"position": position, "radius": radius, "dark": i % 5 == 0})
		if i % 3 == 0:
			streaks.append({"start": position * randf_range(0.15, 0.5), "end": position, "width": maxf(0.4, radius * 0.55)})
	if play_splat:
		$SplatAudio.stream = AUDIO_FACTORY.create_splat()
		$SplatAudio.pitch_scale = randf_range(0.88, 1.08)
		$SplatAudio.volume_db = lerpf(-13.0, -7.0, clampf(base_intensity / 2.8, 0.0, 1.0))
		$SplatAudio.play()
	queue_redraw()

func clean_step() -> void:
	amount -= 0.12
	if amount <= 0.02: queue_free()
	else: queue_redraw()

func _draw() -> void:
	var blood := Color(0.62, 0.005, 0.035, 0.82 * amount)
	var dark := Color(0.24, 0.002, 0.012, 0.9 * amount)
	for streak in streaks:
		draw_line(streak.start * amount, streak.end * amount, dark, streak.width * amount)
	for lobe in lobes:
		draw_circle(lobe.position * amount, lobe.radius * amount, dark if lobe.dark else blood)
	var core_radius := (3.2 if wall_stain else 4.6) * minf(1.35, base_intensity) * amount
	draw_circle(Vector2.ZERO, core_radius, blood)
