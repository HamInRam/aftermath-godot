extends Node

const LEVEL := preload("res://scenes/main.tscn")
var failures := 0

func _ready() -> void:
	var level = LEVEL.instantiate()
	level.record_progress = false
	add_child(level)
	await get_tree().process_frame
	var tile_world := level.get_node("TileMap") as TileWorld
	var glass_cell := Vector2i(-1, -1)
	for cell in tile_world.wall_layer.get_used_cells():
		if tile_world.wall_layer.get_cell_atlas_coords(cell).x == TileWorld.Tile.WINDOW:
			glass_cell = cell
			break
	_expect(glass_cell != Vector2i(-1, -1), "campaign maps should contain breakable window glass")
	if glass_cell != Vector2i(-1, -1):
		_expect(tile_world.wall_cap_layer.get_cell_atlas_coords(glass_cell).x == TileWorld.Tile.WINDOW, "intact glass should have a matching pseudo-3D cap")
		var glass_position := tile_world.wall_layer.to_global(tile_world.wall_layer.map_to_local(glass_cell))
		_expect(tile_world.shatter_glass_at(glass_position, Vector2.RIGHT), "window impact should shatter the glass")
		_expect(tile_world.wall_layer.get_cell_source_id(glass_cell) == -1, "shattered glass should disappear from the collision wall layer")
		_expect(tile_world.wall_cap_layer.get_cell_source_id(glass_cell) == -1, "shattered glass should disappear from the visible wall-cap layer")
		_expect(not tile_world.path_grid.is_point_solid(glass_cell), "shattered glass should open its navigation cell")
	var props := level.get_tree().get_nodes_in_group("destructible_prop")
	_expect(props.size() >= 10, "rebuilt levels should contain a meaningful density of destructible low-pixel props")
	var prop: DestructibleProp
	for candidate in props:
		if candidate is DestructibleProp and not candidate.is_movable():
			prop = candidate
			break
	_expect(is_instance_valid(prop), "campaign maps should retain heavy fixtures that partially break before collapsing")
	if not is_instance_valid(prop):
		get_tree().quit(failures)
		return
	var original_cell := tile_world.floor_layer.local_to_map(prop.position)
	prop.take_damage(1, prop.global_position - Vector2.RIGHT)
	_expect(prop.state == DestructibleProp.PropState.DAMAGED, "first impact should expose a readable damaged state")
	prop.take_damage(1, prop.global_position - Vector2.RIGHT)
	await get_tree().process_frame
	_expect(prop.state == DestructibleProp.PropState.DESTROYED, "second impact should collapse the prop into low-pixel debris")
	_expect(tile_world.path_grid.is_point_solid(original_cell) == false, "destroyed furniture should open its navigation cell")
	_expect(level.mission_tracker.property_damage >= 1, "destroyed props should count as forensic property damage")
	_expect(not prop.has_method("interact") and not prop.has_method("enter_cleanup_restore_state"), "destroyed furniture must not expose retired restoration actions")
	prop.take_damage(10, prop.global_position - Vector2.RIGHT)
	await get_tree().process_frame
	_expect(prop.state == DestructibleProp.PropState.DESTROYED and not tile_world.path_grid.is_point_solid(original_cell), "repeated impacts must not restore solidity")
	level.queue_free()
	await get_tree().process_frame
	if failures == 0: print("destructible environment regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
