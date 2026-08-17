class_name TileWorld
extends Node2D

const TILE_SIZE := Vector2i(8, 8)
const MAP_SIZE := Vector2i(48, 28)
const ATLAS_TEXTURE := preload("res://assets/tiles/environment_tiles_8x8.png")
const GLASS_SHARDS_SCENE := preload("res://scenes/effects/glass_shards.tscn")

enum Tile { CONCRETE, WOOD, RED_CARPET, WALL, WINDOW, DARK_TILE, GRASS, STAIRS, CHECKER, BLACK_PLANK, TEAL_CARPET, CREAM, MAGENTA_STAGE, RED_BRICK, BATH_TILE, BRIGHT_WALL, SOFA, TABLE, TOILET, SINK, BED, TV, VENDING, PLANT }

@export_enum("nightclub", "sandwich_shop", "tactical_lab") var layout_id := "nightclub"

@onready var exterior_layer: TileMapLayer = $ExteriorBackdrop
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var wall_shadow_layer: TileMapLayer = $WallShadows
@onready var decoration_layer: TileMapLayer = $Decoration
@onready var object_shadow_layer: TileMapLayer = $ObjectShadows
@onready var object_layer: TileMapLayer = $Objects
var path_grid := AStarGrid2D.new()

func _ready() -> void:
	floor_layer.tile_set = _create_tile_set(false)
	exterior_layer.tile_set = floor_layer.tile_set
	wall_layer.tile_set = _create_tile_set(true)
	wall_shadow_layer.tile_set = wall_layer.tile_set
	decoration_layer.tile_set = floor_layer.tile_set
	object_shadow_layer.tile_set = floor_layer.tile_set
	object_layer.tile_set = wall_layer.tile_set
	_build_exterior()
	_build_floor()
	_build_walls()
	_build_wall_shadows()
	_build_decorations()
	_build_objects()
	_build_object_shadows()
	_build_path_grid()

func _create_tile_set(with_physics: bool) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	if with_physics:
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 4)
		tile_set.set_physics_layer_collision_mask(0, 0)
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(1, 8)
		tile_set.set_physics_layer_collision_mask(1, 0)
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(2, 32)
		tile_set.set_physics_layer_collision_mask(2, 0)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ATLAS_TEXTURE
	atlas.texture_region_size = TILE_SIZE
	for tile_index in range(24):
		var atlas_coordinate := Vector2i(tile_index, 0)
		atlas.create_tile(atlas_coordinate)
	tile_set.add_source(atlas, 0)
	for tile_index in [Tile.WALL, Tile.WINDOW, Tile.BRIGHT_WALL] if with_physics else []:
		var atlas_coordinate := Vector2i(int(tile_index), 0)
		var tile_data := atlas.get_tile_data(atlas_coordinate, 0)
		var physical_layer := 1 if tile_index == Tile.WINDOW else 0
		tile_data.add_collision_polygon(physical_layer)
		tile_data.set_collision_polygon_points(physical_layer, 0, PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
		]))
		if tile_index != Tile.WINDOW:
			tile_data.add_collision_polygon(2)
			tile_data.set_collision_polygon_points(2, 0, PackedVector2Array([
				Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
			]))
	for tile_index in [Tile.SOFA, Tile.TABLE, Tile.TOILET, Tile.SINK, Tile.BED, Tile.TV, Tile.VENDING] if with_physics else []:
		var tile_data := atlas.get_tile_data(Vector2i(int(tile_index), 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
		]))
		tile_data.add_collision_polygon(2)
		tile_data.set_collision_polygon_points(2, 0, PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
		]))
	return tile_set

func _set_tile(layer: TileMapLayer, cell: Vector2i, tile: Tile) -> void:
	layer.set_cell(cell, 0, Vector2i(int(tile), 0), 0)

func _build_exterior() -> void:
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var tile := Tile.DARK_TILE if (x + y) % 2 == 0 else Tile.BLACK_PLANK
			_set_tile(exterior_layer, Vector2i(x, y), tile)

func _build_floor() -> void:
	for y in range(1, MAP_SIZE.y - 1):
		for x in range(1, MAP_SIZE.x - 1):
			var tile := Tile.CONCRETE
			if layout_id == "sandwich_shop":
				if y >= 15: tile = Tile.WOOD
				elif x >= 28: tile = Tile.RED_CARPET
				elif y <= 5: tile = Tile.DARK_TILE
			elif layout_id == "tactical_lab":
				if x < 24 and y < 14: tile = Tile.CHECKER
				elif x >= 24 and y < 14: tile = Tile.BLACK_PLANK
				elif x < 24: tile = Tile.RED_BRICK
				else: tile = Tile.TEAL_CARPET
			else:
				tile = Tile.BLACK_PLANK
				if x <= 10 and y <= 15: tile = Tile.CHECKER
				elif x >= 25 and y <= 8: tile = Tile.MAGENTA_STAGE
				elif x >= 39 and y >= 9: tile = Tile.CREAM
				elif x >= 25 and y >= 9: tile = Tile.TEAL_CARPET
				elif x >= 19 and y >= 16: tile = Tile.RED_BRICK
				elif x <= 10 and y >= 16: tile = Tile.BATH_TILE
			_set_tile(floor_layer, Vector2i(x, y), tile)

func _build_walls() -> void:
	var edge_wall := Tile.BRIGHT_WALL if layout_id in ["nightclub", "tactical_lab"] else Tile.WALL
	for x in range(1, MAP_SIZE.x - 1):
		_set_tile(wall_layer, Vector2i(x, 1), Tile.WINDOW if x in range(26, 31) else edge_wall)
		_set_tile(wall_layer, Vector2i(x, MAP_SIZE.y - 2), edge_wall)
	for y in range(2, MAP_SIZE.y - 2):
		_set_tile(wall_layer, Vector2i(1, y), edge_wall)
		_set_tile(wall_layer, Vector2i(MAP_SIZE.x - 2, y), Tile.WINDOW if y in range(12, 16) else edge_wall)
	if layout_id == "sandwich_shop":
		for x in range(6, 31):
			if x not in [17, 18]: _set_tile(wall_layer, Vector2i(x, 7), Tile.WALL)
		for y in range(8, 15):
			if y not in [11, 12]: _set_tile(wall_layer, Vector2i(30, y), Tile.WALL)
		for x in range(9, 39):
			if x not in [23, 24]: _set_tile(wall_layer, Vector2i(x, 15), Tile.WALL)
		for y in range(16, 24):
			if y != 20: _set_tile(wall_layer, Vector2i(9, y), Tile.WALL)
		return
	if layout_id == "tactical_lab":
		for y in range(2, MAP_SIZE.y - 2):
			if y in [7, 8, 19, 20]: continue
			_set_tile(wall_layer, Vector2i(24, y), Tile.WINDOW if y in range(10, 14) else Tile.BRIGHT_WALL)
		for x in range(2, MAP_SIZE.x - 2):
			if x in [10, 11, 35, 36]: continue
			_set_tile(wall_layer, Vector2i(x, 14), Tile.WINDOW if x in range(27, 33) else Tile.BRIGHT_WALL)
		return
	for y in range(4, 20):
		if y not in [11, 12]: _set_tile(wall_layer, Vector2i(11, y), Tile.BRIGHT_WALL)
	for x in range(24, 35):
		if x not in [29, 30]: _set_tile(wall_layer, Vector2i(x, 9), Tile.BRIGHT_WALL)
	for y in range(10, 17):
		if y != 14: _set_tile(wall_layer, Vector2i(24, y), Tile.BRIGHT_WALL)
	for y in range(16, 22):
		if y != 19: _set_tile(wall_layer, Vector2i(18, y), Tile.BRIGHT_WALL)

func _build_decorations() -> void:
	if layout_id == "sandwich_shop":
		for x in range(12, 27): _set_tile(decoration_layer, Vector2i(x, 12), Tile.RED_CARPET)
		for x in range(34, 39):
			for y in range(18, 21): _set_tile(decoration_layer, Vector2i(x, y), Tile.STAIRS)
		return
	for x in range(19, 23):
		for y in range(18, 21):
			_set_tile(decoration_layer, Vector2i(x, y), Tile.STAIRS)

func _build_wall_shadows() -> void:
	for cell in wall_layer.get_used_cells():
		var atlas_coordinates := wall_layer.get_cell_atlas_coords(cell)
		if atlas_coordinates.x == Tile.WINDOW: continue
		wall_shadow_layer.set_cell(cell, 0, atlas_coordinates, 0)

func _build_objects() -> void:
	if layout_id == "tactical_lab":
		for cell in [Vector2i(7, 6), Vector2i(8, 6), Vector2i(39, 7), Vector2i(40, 7)]: _set_tile(object_layer, cell, Tile.SOFA)
		for cell in [Vector2i(15, 18), Vector2i(16, 18), Vector2i(30, 20), Vector2i(31, 20)]: _set_tile(object_layer, cell, Tile.TABLE)
		_set_tile(object_layer, Vector2i(19, 5), Tile.TV)
		_set_tile(object_layer, Vector2i(42, 22), Tile.VENDING)
		return
	if layout_id != "nightclub": return
	for cell in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]: _set_tile(object_layer, cell, Tile.SOFA)
	for cell in [Vector2i(14, 4), Vector2i(15, 4)]: _set_tile(object_layer, cell, Tile.TABLE)
	_set_tile(object_layer, Vector2i(20, 6), Tile.TV)
	for cell in [Vector2i(26, 2), Vector2i(27, 2), Vector2i(28, 2)]: _set_tile(object_layer, cell, Tile.SOFA)
	_set_tile(object_layer, Vector2i(36, 5), Tile.PLANT)
	_set_tile(object_layer, Vector2i(3, 23), Tile.BED)
	_set_tile(object_layer, Vector2i(4, 23), Tile.BED)
	_set_tile(object_layer, Vector2i(7, 21), Tile.TOILET)
	_set_tile(object_layer, Vector2i(10, 23), Tile.SINK)
	_set_tile(object_layer, Vector2i(15, 21), Tile.VENDING)
	_set_tile(object_layer, Vector2i(26, 22), Tile.SINK)
	_set_tile(object_layer, Vector2i(29, 22), Tile.TOILET)
	for cell in [Vector2i(33, 23), Vector2i(34, 23)]: _set_tile(object_layer, cell, Tile.TABLE)
	_set_tile(object_layer, Vector2i(43, 18), Tile.PLANT)

func _build_object_shadows() -> void:
	for cell in object_layer.get_used_cells():
		object_shadow_layer.set_cell(cell, 0, object_layer.get_cell_atlas_coords(cell), 0)

func _build_path_grid() -> void:
	path_grid.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	path_grid.cell_size = Vector2(TILE_SIZE)
	path_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	path_grid.update()
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			if floor_layer.get_cell_source_id(cell) < 0: path_grid.set_point_solid(cell, true)
	for cell in wall_layer.get_used_cells(): path_grid.set_point_solid(cell, true)
	for cell in object_layer.get_used_cells():
		if object_layer.get_cell_atlas_coords(cell).x != Tile.PLANT: path_grid.set_point_solid(cell, true)
	_apply_navigation_clearance_cost()

func _apply_navigation_clearance_cost() -> void:
	var neighbor_offsets := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			if path_grid.is_point_solid(cell): continue
			var nearby_obstacles := 0
			for offset in neighbor_offsets:
				var neighbor: Vector2i = cell + offset
				if path_grid.is_in_boundsv(neighbor) and path_grid.is_point_solid(neighbor): nearby_obstacles += 1
			if nearby_obstacles > 0:
				path_grid.set_point_weight_scale(cell, 1.0 + minf(2.4, nearby_obstacles * 0.45))

func get_navigation_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var from_cell := floor_layer.local_to_map(floor_layer.to_local(from_world))
	var to_cell := floor_layer.local_to_map(floor_layer.to_local(to_world))
	from_cell = from_cell.clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
	to_cell = to_cell.clamp(Vector2i.ZERO, MAP_SIZE - Vector2i.ONE)
	if path_grid.is_point_solid(from_cell) or path_grid.is_point_solid(to_cell): return PackedVector2Array()
	var id_path := path_grid.get_id_path(from_cell, to_cell)
	var world_path := PackedVector2Array()
	for index in range(1, id_path.size()):
		world_path.append(floor_layer.to_global(floor_layer.map_to_local(id_path[index])))
	return world_path

func is_navigation_position_walkable(world_position: Vector2) -> bool:
	var cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	return path_grid.is_in_boundsv(cell) and not path_grid.is_point_solid(cell)

func shatter_glass_at(hit_position: Vector2, flight_direction: Vector2) -> bool:
	var cell := wall_layer.local_to_map(wall_layer.to_local(hit_position + flight_direction.normalized()))
	if wall_layer.get_cell_atlas_coords(cell).x != Tile.WINDOW:
		var found := false
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + Vector2i(offset)
			if wall_layer.get_cell_atlas_coords(neighbor).x == Tile.WINDOW:
				cell = neighbor
				found = true
				break
		if not found: return false
	wall_layer.erase_cell(cell)
	path_grid.set_point_solid(cell, false)
	var shards = GLASS_SHARDS_SCENE.instantiate()
	shards.global_position = hit_position
	shards.setup(flight_direction)
	var effect_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	effect_parent.add_child(shards)
	Events.glass_shattered.emit(hit_position)
	return true
