extends Node

const CANVAS_SCRIPT := preload("res://scripts/effects/pixel_blood_canvas.gd")

var failures := 0

func _ready() -> void:
	CleanupRegistry.reset()
	var canvas = CANVAS_SCRIPT.new()
	add_child(canvas)
	canvas.configure("ground", -2)
	# A gunshot-style broken pixel line must cross a texture-chunk boundary without
	# creating one scene node per droplet.
	canvas.stamp_splatter(Vector2(27, 20), Vector2.RIGHT, 2.2, "line", 0.08, "puncture")
	var initial_pixels := int(canvas.get_debug_pixel_count())
	_expect(initial_pixels > 8, "pixel splatter should deposit a readable broken chain")
	_expect(canvas.chunks.size() <= 4, "sparse blood should allocate only touched 32px chunks")
	# Author a deterministic stripe so the test can verify every point between two
	# cursor samples is modified by one continuous capsule brush.
	for x in range(20, 53): canvas.add_blood_pixel(Vector2(x, 40), 220)
	var before_start := int(canvas.get_blood_amount(Vector2(20, 40)))
	var before_middle := int(canvas.get_blood_amount(Vector2(36, 40)))
	var before_end := int(canvas.get_blood_amount(Vector2(52, 40)))
	_expect(canvas.clean_stroke(Vector2(20, 40), Vector2(52, 40), 2.0, 5, "mop"), "mop stroke should clean pixel blood")
	_expect(int(canvas.get_blood_amount(Vector2(20, 40))) < before_start, "continuous brush must clean its starting pixel")
	_expect(int(canvas.get_blood_amount(Vector2(36, 40))) < before_middle, "continuous brush must clean between cursor samples")
	_expect(int(canvas.get_blood_amount(Vector2(52, 40))) < before_end, "continuous brush must clean its ending pixel")
	_expect(int(canvas.get_wetness(Vector2(36, 40))) > 0, "cleaned pixels should retain a temporary wet trail")
	# Repeated mopping removes visible blood but leaves a faint UV-only forensic
	# channel. The washer can then clear that residue without spawning new blood.
	for pass_index in range(6): canvas.clean_stroke(Vector2(20, 40), Vector2(52, 40), 2.0, 8, "mop")
	_expect(int(canvas.get_blood_amount(Vector2(36, 40))) == 0, "repeated mopping should fully remove visible blood")
	_expect(int(canvas.get_residue_amount(Vector2(36, 40))) > 0, "mopping should preserve UV forensic residue")
	for pass_index in range(6): canvas.clean_stroke(Vector2(20, 40), Vector2(52, 40), 3.0, 8, "pressure_washer")
	_expect(int(canvas.get_residue_amount(Vector2(36, 40))) == 0, "pressure washing should remove UV residue")
	# Pools spread progressively rather than appearing at full size on one frame.
	var pool_center := Vector2(90, 60)
	canvas.start_pool(pool_center, 1.8, Vector2.RIGHT, {"spread": 1.0}, {"pool_bias": 1.0})
	var pool_pixels_before := int(canvas.get_debug_pixel_count())
	for index in range(16): canvas._process(0.15)
	_expect(int(canvas.get_debug_pixel_count()) > pool_pixels_before, "death pool should expand over time through new pixels")
	if DisplayServer.get_name() != "headless":
		canvas.stamp_splatter(Vector2(145, 92), Vector2.RIGHT, 3.0, "radial", 0.9, "blast")
		canvas.clean_stroke(Vector2(129, 92), Vector2(162, 92), 2.2, 10, "mop")
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		_expect(image.save_png("/tmp/aftermath_pixel_blood_visual.png") == OK, "pixel blood visual capture should be writable")
	canvas.queue_free()
	await get_tree().process_frame
	CleanupRegistry.reset()
	if failures == 0:
		print("pixel blood canvas regression: PASS")
		get_tree().quit(0)
	else: get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
