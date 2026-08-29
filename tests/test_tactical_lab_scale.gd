extends Node

const LEVEL_SCENE := preload("res://scenes/levels/tactical_lab.tscn")
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var level = LEVEL_SCENE.instantiate()
	level.record_progress = false
	add_child(level)
	await get_tree().physics_frame
	var tile_world := level.get_node("TileMap") as TileWorld
	_expect(tile_world.map_size == Vector2i(64, 36), "tactical test map should use the expanded 64x36 tile footprint")
	_expect(level.started_enemy_count >= 16, "expanded tactical test map should contain a high-density enemy roster")
	_expect(level.ammo_pickup_weapon_ids.count("shotgun") >= 2, "expanded test map should provide repeatable shotgun ammunition")
	_expect(level.trauma_camera.camera_center_bounds.end.x >= 352.0 and level.trauma_camera.camera_center_bounds.end.y >= 198.0, "camera bounds must cover the expanded test map")
	_expect(tile_world.is_navigation_position_walkable(Vector2(460, 248)), "new south-east test sector must be navigable")
	_expect(tile_world.get_tactical_room_id(Vector2(420, 60)) != tile_world.get_tactical_room_id(Vector2(420, 180)), "separated east-side sectors need distinct tactical room identities")
	_expect(tile_world.get_tactical_room_id(Vector2(300, 180)) != tile_world.get_tactical_room_id(Vector2(300, 250)), "expanded south sector needs its own tactical room identity")
	_expect(tile_world.destructible_cells.any(func(cell: Vector2i) -> bool: return cell.x >= 48 or cell.y >= 27), "expanded sectors should contain authored destructible environmental props")
	_expect(level.get_node("Lighting").get_child_count() >= 8, "expanded sectors should receive dedicated atmospheric lights")
	level.blood_system.spawn_micro_drop(Vector2(192, 100), 0.8, Vector2.RIGHT)
	await get_tree().process_frame
	var projected_floor := tile_world.get_nearest_walkable_position(Vector2(192, 100))
	_expect(projected_floor != Vector2.INF and level.blood_system.ground_canvas.has_blood_near(projected_floor, 4.0), "blood pixels inside walls must project onto reachable floor")
	var splatter_pixels_before := int(level.blood_system.ground_canvas.get_debug_pixel_count())
	level.blood_system._spawn_ground_splatter(Vector2(192, 100), Vector2.RIGHT, 1.0, "fan", 0.7)
	await get_tree().process_frame
	_expect(int(level.blood_system.ground_canvas.get_debug_pixel_count()) > splatter_pixels_before, "primary ground splatter inside walls must paint projected floor pixels")
	var has_walkable_splatter := false
	for pixel_position in level.blood_system.ground_canvas.get_debug_occupied_positions():
		if tile_world.is_navigation_position_walkable(pixel_position):
			has_walkable_splatter = true
			break
	_expect(has_walkable_splatter, "projected pixel splatter must remain on reachable floor")
	var trauma_before_projectiles: float = level.trauma_camera.trauma
	for pellet in range(7): level._on_projectile_requested(level.player.global_position, Vector2.RIGHT, false, 1, "shotgun")
	_expect(is_equal_approx(level.trauma_camera.trauma, trauma_before_projectiles), "individual shotgun pellets must not each add camera trauma")
	level._on_weapon_fired(level.player.global_position, Vector2.RIGHT, false, "shotgun")
	_expect(level.trauma_camera.trauma > trauma_before_projectiles, "one shotgun trigger pull should add camera trauma exactly once")
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	for audio_node in level.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if failures == 0: print("tactical lab scale regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
