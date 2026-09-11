extends Node2D
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var field := MicroDebrisField.new()
	add_child(field)
	field.set_physics_process(false)
	for i in 100: field.emit_impact(Vector2(30, 0), Vector2.RIGHT, "paper", 1)
	check(field.fragments.size() == 256, "micro fragments have bounded storage")
	for f in field.fragments:
		check(f.paper and f.color == Color("eeeeee"), "paper uses grayscale slow-fall profile")
	field.fragments.clear()
	field.emit_impact(Vector2(30, 0), Vector2.RIGHT, "metal", 1)
	check(field.fragments[1].spark, "metal emits bright short trails")
	var actor := Node2D.new()
	add_child(actor)
	field.set_magnet(actor, true)
	check(field.captures(Vector2(20, 0)), "blind proximity capture")
	check(not field.captures(Vector2(300, 0)), "capture range bounded")
	field.fragments = [{"p": Vector2(6, 0), "v": Vector2.ZERO, "color": Color.WHITE, "air": 0.0, "paper": false, "spark": false, "collected": false}]
	field._physics_process(0.016)
	check(field.fragments[0].collected and field.fragments[0].v == Vector2.ZERO, "scrap stops at feet without resource conversion")
	field.set_magnet(actor, false)
	check(not field.captures(Vector2.ZERO), "release disables magnet")
	var shell = preload("res://scenes/effects/shell_casing.tscn").instantiate()
	add_child(shell)
	shell.position = Vector2(40, 0)
	shell.setup(Vector2.RIGHT, false)
	check(shell.casing_tint == Color("ffc800"), "player and enemy casing palette is brass")
	shell.settled = true
	shell.siphon_toward(Vector2.ZERO)
	check(not shell.settled and shell.velocity.x < 0, "magnet wakes settled casing")
	var debris := PhysicalDebris.new()
	add_child(debris)
	debris.position = Vector2(35, 0)
	debris.siphon_toward(Vector2.ZERO)
	check(debris.impact_spent, "magnetized rigid debris cannot deal free damage")
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		shell.set_process(false)
		shell.position = Vector2(100, 80)
		shell.queue_redraw()
		var grade := NoirPresenterLayer.new()
		add_child(grade)
		grade.set_effects_enabled(false)
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var gold := 0
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.r > 0.55 and c.g > 0.35 and c.r > c.g + 0.1 and c.b < 0.2: gold += 1
		check(gold > 0, "real GPU noir pass preserves brass")
		image.save_png("/tmp/aftermath-micro-debris-review.png")
	print("MICRO_DEBRIS_OK" if failures == 0 else "MICRO_DEBRIS_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
