extends Node

const RIG_SCRIPT := preload("res://scripts/visuals/lifecycle_physics_rig_2d.gd")
const GUN_SCENE := preload("res://scenes/gun.tscn")
const OUTPUT_PATH := "/tmp/aftermath_eight_way_debug.png"

var failures := 0

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 420)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("100d14")
	background.size = Vector2(640, 420)
	viewport.add_child(background)
	var world := Node2D.new()
	viewport.add_child(world)
	_add_headers(world)
	_add_row(world, 58.0, "player", "player", "gun", Color("d8e2df"), Color("27c9ca"))
	_add_row(world, 132.0, "enemy", "gunner", "gun", Color("7c235b"), Color("f23d78"))
	_add_row(world, 206.0, "enemy", "melee", "melee", Color("7d163f"), Color("ff4f91"))
	_add_row(world, 280.0, "enemy", "heavy", "gun", Color("41306e"), Color("a59cff"))
	_add_row(world, 354.0, "hound", "hound", "hound", Color("6e4a37"), Color("e8d8c8"))
	_validate_direction_boundaries()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var rendered := DisplayServer.get_name() != "headless"
	if rendered:
		var image := viewport.get_texture().get_image()
		var save_error := image.save_png(OUTPUT_PATH)
		_expect(save_error == OK, "eight-way debug contact sheet must be writable")
	if failures == 0: print("eight-way visual regression: PASS%s" % (" // %s" % OUTPUT_PATH if rendered else " // geometry-only headless pass"))
	else: push_error("eight-way visual regression: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _add_headers(world: Node2D) -> void:
	for index in range(8):
		var marker := Label.new()
		marker.text = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"][index]
		marker.position = Vector2(65.0 + index * 72.0, 6.0)
		marker.add_theme_font_size_override("font_size", 11)
		marker.modulate = Color("79f2dc")
		world.add_child(marker)

func _add_row(world: Node2D, y: float, kind: String, role: String, stance: String, color: Color, accent: Color) -> void:
	var row_label := Label.new()
	row_label.text = role.to_upper()
	row_label.position = Vector2(5, y - 9)
	row_label.add_theme_font_size_override("font_size", 9)
	row_label.modulate = accent
	world.add_child(row_label)
	for sector in range(8):
		var rig = RIG_SCRIPT.new()
		rig.position = Vector2(82.0 + sector * 72.0, y)
		rig.scale = Vector2(3, 3)
		rig.rotation = float(sector) * PI / 4.0
		world.add_child(rig)
		rig.configure(kind, color, accent, role)
		rig.set_weapon_stance(stance)
		rig.update_lifecycle(1.0 / 60.0, Vector2.ZERO, 100.0)
		if stance == "gun":
			var gun = GUN_SCENE.instantiate()
			gun.position = Vector2(3.5, 0)
			gun.scale = Vector2(0.8, 0.8)
			gun.z_index = -1 if rig.weapon_should_render_behind() else 2
			rig.add_child(gun)
			gun.set_process(false)
		_validate_hands(rig, sector, stance, role)

func _validate_hands(rig, sector: int, stance: String, role: String) -> void:
	if role == "hound": return
	var forward: Vector2 = Vector2.RIGHT.rotated(float(sector) * PI / 4.0)
	var side := Vector2(-forward.y, forward.x)
	var hands: Array[Vector2] = rig._standing_hand_positions(Vector2.ZERO, forward, side, 0.0)
	var away_hand_drop := clampf(-forward.y, 0.0, 1.0) * 1.2 if stance == "gun" else 0.0
	var hand_height := Vector2(0, -2.0 + away_hand_drop)
	var hand_a_ground := hands[0] - hand_height
	var hand_b_ground := hands[1] - hand_height
	var minimum_forward := 2.5 if stance == "gun" else 1.0
	_expect(hand_a_ground.dot(forward) > minimum_forward, "%s sector %d primary hand must remain in front" % [role, sector])
	_expect(hand_b_ground.dot(forward) > minimum_forward, "%s sector %d support hand must remain in front" % [role, sector])
	if stance == "gun":
		_expect(hand_a_ground.dot(side) > 0.2 and hand_b_ground.dot(side) < -0.2, "%s sector %d gun hands must straddle the barrel" % [role, sector])
		if forward.y < -0.35:
			var head_center := forward * 2.2 + Vector2(0, -4.0)
			var distance_a := hands[0].distance_to(head_center)
			var distance_b := hands[1].distance_to(head_center)
			if sector == 6:
				_expect(distance_a >= 2.6 and distance_b >= 2.6, "%s north-facing hands must remain visible on both sides of the head" % role)
			else:
				_expect(maxf(distance_a, distance_b) >= 3.0, "%s sector %d needs at least one readable near hand beside the head" % [role, sector])
	_expect(rig.weapon_should_render_behind() == (forward.y < -0.35), "%s sector %d weapon depth must match facing" % [role, sector])

func _validate_direction_boundaries() -> void:
	var rig = RIG_SCRIPT.new()
	add_child(rig)
	rig.configure("player", Color.WHITE, Color.CYAN, "player")
	for degrees in [0.0, 20.0, 25.0, 28.0]:
		rig.rotation = deg_to_rad(degrees)
		rig.update_lifecycle(1.0 / 60.0, Vector2.ZERO, 100.0)
		_expect(rig.get_facing_sector() == 0, "direction hysteresis must hold the east pose through 28 degrees")
	rig.rotation = deg_to_rad(30.0)
	rig.update_lifecycle(1.0 / 60.0, Vector2.ZERO, 100.0)
	_expect(rig.get_facing_sector() == 1, "direction pose must advance after the hysteresis threshold")
	rig.queue_free()

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
