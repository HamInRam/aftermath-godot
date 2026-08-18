extends Node2D

const SPLAT_STREAM := preload("res://assets/audio/sfx/blood_splat.wav")

var amount := 1.0
var lobes: Array[Dictionary] = []
var streaks: Array[Dictionary] = []
var configured := false
var wall_stain := false
var base_intensity := 1.0
var pattern_id := "fan"

func _ready() -> void:
	CleanupRegistry.register_target(self)
	if not configured:
		setup(Vector2.RIGHT.rotated(randf_range(0.0, TAU)), 1.0, false, false)

func setup(spray_direction: Vector2, intensity: float, on_wall: bool, play_splat := false, pattern := "fan", cone := 0.72) -> void:
	configured = true
	wall_stain = on_wall
	base_intensity = clampf(intensity, 0.5, 2.8)
	pattern_id = pattern
	var direction := spray_direction.normalized()
	rotation = direction.angle()
	var lobe_count := clampi(roundi(9.0 + base_intensity * 7.0), 10, 28)
	for i in range(lobe_count):
		var position := Vector2.ZERO
		if pattern_id == "radial":
			var radial_angle := randf_range(-cone, cone)
			position = Vector2.RIGHT.rotated(radial_angle) * pow(randf(), 0.48) * (14.0 + base_intensity * 10.0)
		elif pattern_id == "line":
			position = Vector2(pow(randf(), 0.48) * (18.0 + base_intensity * 10.0), randfn(0.0, 1.1 + cone * 2.0))
		else:
			var fan_angle := randf_range(-cone, cone)
			position = Vector2.RIGHT.rotated(fan_angle) * pow(randf(), 0.58) * (11.0 + base_intensity * 9.0)
		if wall_stain: position.y *= 0.55
		var radius := randf_range(0.45, 1.45) * lerpf(0.75, 1.35, base_intensity / 2.8)
		lobes.append({"position": position, "radius": radius, "dark": i % 5 == 0})
		if i % 3 == 0:
			streaks.append({"start": position * randf_range(0.15, 0.5), "end": position, "width": maxf(0.4, radius * 0.55)})
	if play_splat:
		$SplatAudio.stream = SPLAT_STREAM
		$SplatAudio.pitch_scale = randf_range(0.88, 1.08)
		$SplatAudio.volume_db = lerpf(-13.0, -7.0, clampf(base_intensity / 2.8, 0.0, 1.0))
		if is_inside_tree(): _play_splat()
		else: call_deferred("_play_splat")
	queue_redraw()

func _play_splat() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless": return
	$SplatAudio.play()

func clean_step() -> void:
	amount -= 0.12
	if amount <= 0.02: queue_free()
	else: queue_redraw()

func get_cleanup_type() -> String:
	return "blood"

func get_cleanup_cost() -> int:
	return 9

func _draw() -> void:
	var blood := Color(0.62, 0.005, 0.035, 0.82 * amount)
	var dark := Color(0.24, 0.002, 0.012, 0.9 * amount)
	for streak in streaks:
		draw_line(streak.start * amount, streak.end * amount, dark, streak.width * amount)
	for lobe in lobes:
		draw_circle(lobe.position * amount, lobe.radius * amount, dark if lobe.dark else blood)
	var core_radius := (3.2 if wall_stain else 4.6) * minf(1.35, base_intensity) * amount
	draw_circle(Vector2.ZERO, core_radius, blood)
