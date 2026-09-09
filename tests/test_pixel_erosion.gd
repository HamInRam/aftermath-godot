extends Node2D
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var mask := PixelErosionMask.new()
	mask.configure(Rect2i(0,0,8,8))
	check(mask.rectangles().size() == 1, "intact mask merges into one collider")
	mask.chip(Vector2(4,4), Vector2.ZERO, 2)
	check(not mask.solid(Vector2i(4,4)) and mask.solid(Vector2i.ZERO), "local hole preserves surrounding material")
	var area := 0
	for rect in mask.rectangles():
		area += rect.get_area()
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x): check(mask.solid(Vector2i(x,y)), "collider never fills removed hole")
	check(area == mask.remaining(), "merged collision exactly covers remaining pixels")
	var prop := DestructibleProp.new()
	prop.setup("sink")
	add_child(prop)
	prop.receive_projectile_impact_context(Vector2.RIGHT * 650, Vector2.ZERO, "pistol", 30)
	await get_tree().process_frame
	check(prop.erosion.remaining() < 64 and prop.erosion.remaining() > 0, "furniture chips instead of disappearing whole")
	check(prop._collision.disabled and prop.erosion_shapes.size() > 0, "furniture switches to merged pixel collision")
	prop.queue_free()
	var level = preload("res://scenes/levels/after_hours.tscn").instantiate()
	var world = level.get_node("TileMap")
	level.remove_child(world)
	level.free()
	add_child(world)
	var cell := Vector2i(-1,-1)
	for candidate in world.wall_layer.get_used_cells():
		if candidate.x > 1 and candidate.y > 1 and world.wall_layer.get_cell_atlas_coords(candidate).x != world.Tile.WINDOW:
			cell = candidate
			break
	check(cell.x > 0, "test has interior wall")
	var point: Vector2 = world.to_global(Vector2(cell * 8) + Vector2(4,4))
	world._chip_wall_deferred(point, Vector2.RIGHT, 30)
	await get_tree().process_frame
	var body: ErodingWallCell = world.eroded_cells[cell]
	check(body.erosion.remaining() > 0 and body.erosion.remaining() < 64, "wall partially erodes")
	check(body.erosion.remaining() <= 40, "30-damage impact removes a substantial bite rather than a tiny pinhole")
	check(world.path_grid.is_point_solid(cell), "partial wall remains conservative AI obstacle")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var probe := PhysicsPointQueryParameters2D.new()
	probe.position = body.to_global(Vector2(4.5,4.5))
	probe.collision_mask = 4
	var hits := get_world_2d().direct_space_state.intersect_point(probe)
	for hit in hits: check(hit.collider != body, "physics query sees the actual pixel hole")
	for y in 8:
		for x in 8: body.receive_projectile_impact_context(Vector2.ZERO, body.to_global(Vector2(x,y)), "pistol", 30)
	await get_tree().process_frame
	check(body.erosion.remaining() == 0, "wall can be fully consumed")
	check(not world.path_grid.is_point_solid(cell), "open wall updates navigation")
	for shape in body.shapes: check(shape.disabled, "no invisible collision after complete removal")
	await get_tree().process_frame
	check(world.wall_layer.get_cell_source_id(cell) < 0 and world.wall_cap_layer.get_cell_source_id(cell) < 0, "no intact overlay remains")
	world.queue_free()
	await get_tree().process_frame
	for file in DirAccess.get_files_at("res://scenes/levels"):
		if not file.ends_with(".tscn") or file == "after_hours.tscn": continue
		var scene = load("res://scenes/levels/" + file).instantiate()
		var venue = scene.get_node("TileMap")
		scene.remove_child(venue)
		scene.free()
		add_child(venue)
		var tested := false
		for tile in venue.wall_layer.get_used_cells():
			if tile.x <= 1 or tile.y <= 1 or tile.x >= venue.world_size.x - 1 or tile.y >= venue.world_size.y - 1 or venue.wall_layer.get_cell_atlas_coords(tile).x == venue.Tile.WINDOW: continue
			venue._chip_wall_deferred(venue.to_global(Vector2(tile * 8) + Vector2(4,4)), Vector2.RIGHT, 25)
			tested = venue.eroded_cells.has(tile)
			break
		check(tested, file + " supports wall erosion")
		await get_tree().process_frame
		venue.queue_free()
		await get_tree().process_frame
	print("PIXEL_EROSION_OK" if failures == 0 else "PIXEL_EROSION_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
