extends Node2D
var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	await check_rotated_sectors()
	var blood := BloodSystem.new()
	add_child(blood)
	var canvas: PixelBloodCanvas = blood.ground_canvas
	var front := Vector2(120, 10)
	var behind := Vector2(-90, 0)
	var near_back := Vector2(-24, 0)
	var side := Vector2(0, 100)
	for point in [front, behind, near_back, side]: canvas.add_blood_pixel(point, 80)
	canvas.stamp_pollution(Vector2(90, -20), 4)
	var result := blood.absorb_siphon_sector(Vector2.ZERO, Vector2.RIGHT, 224, deg_to_rad(43), 48, 8000)
	check(int(result.amount) == 160, "front cone and rear proximity share one pass; side/back excluded")
	check(canvas.terrain_at(front) == 0 and canvas.terrain_at(near_back) == 0, "valid ground disappears")
	check(canvas.terrain_at(behind) == 1 and canvas.terrain_at(side) == 1, "outside cone retained")
	check(canvas.terrain_at(Vector2(90, -20)) == -1, "pollution excluded")
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.position = Vector2(60, 0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4, 120)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	canvas.add_blood_pixel(front, 100)
	blood.absorb_siphon_sector(Vector2.ZERO, Vector2.RIGHT, 224, deg_to_rad(43), 48, 8000)
	check(canvas.terrain_at(front) == 1, "solid wall occludes suction")
	wall.queue_free()
	await get_tree().physics_frame
	var resource := BloodResourceController.new()
	resource.blood_ammo_mode = true
	resource.reserve = 0
	resource.set_build("balanced")
	add_child(resource)
	var player := Node2D.new()
	add_child(player)
	resource.set_stance_active(true)
	for x in range(10, 180):
		for y in range(-20, 21): canvas.add_blood_pixel(Vector2(x, y), 255)
	resource.update_system(0.04, player, blood)
	check(resource.reserve <= 2.4001 and resource.reserve > 0, "global gain ceiling, not per chunk")
	check(resource.particles.size() > 1 and resource.particles.size() <= 96, "bounded distributed motes")
	check(BloodResourceController.siphon_duration(12) < BloodResourceController.siphon_duration(200), "near blood arrives before far blood")
	check(resource.get_siphon_visual_amount() > 0, "real absorption lights indicator")
	resource.set_stance_active(false)
	resource.update_system(1, player, blood)
	check(resource.particles.is_empty() and resource.get_siphon_visual_amount() == 0, "motes and halo expire")
	resource.reserve = resource.capacity
	resource.set_stance_active(true)
	var before := canvas.get_debug_pixel_count()
	resource.update_system(0.04, player, blood)
	check(before == canvas.get_debug_pixel_count(), "full reserve does not destroy ground")
	resource.update_system(10.0, player, blood)
	resource.reserve = 0.0
	resource.update_system(0.04, player, blood)
	check(resource.reserve <= 2.4001, "full/empty time cannot bank an instant refill")
	for node in [resource, player, blood]: node.queue_free()
	await get_tree().process_frame
	print("SIPHON_SECTOR_OK" if failures == 0 else "SIPHON_SECTOR_FAILED")
	get_tree().quit(failures)

func check_rotated_sectors() -> void:
	var open_rays := PackedFloat32Array()
	open_rays.resize(96)
	open_rays.fill(224.0)
	for direction_index in range(8):
		var canvas := PixelBloodCanvas.new()
		add_child(canvas)
		var origin := Vector2(-500.5, -300.5)
		var forward := Vector2.RIGHT.rotated(direction_index * PI / 4.0)
		var inside := origin + forward.rotated(deg_to_rad(44.0)) * 150.0
		var outside := origin + forward.rotated(deg_to_rad(46.0)) * 150.0
		var rear := origin - forward * 35.0
		var too_far := origin + forward * 226.0
		for point in [inside, outside, rear, too_far]: canvas.add_blood_pixel(point, 80)
		var result := canvas.absorb_sector(origin, forward * 9.0, 224.0, PI / 4.0, 48.0, open_rays, 8000)
		check(int(result.amount) == 160, "eight-way sector union drains each valid pixel once: %d" % direction_index)
		check(canvas.terrain_at(inside) == 0 and canvas.terrain_at(rear) == 0, "rotated front and blind circle cover negative coordinates")
		check(canvas.terrain_at(outside) == 1 and canvas.terrain_at(too_far) == 1, "angle/range boundaries retain outside pixels")
		canvas.queue_free()
	await get_tree().process_frame
