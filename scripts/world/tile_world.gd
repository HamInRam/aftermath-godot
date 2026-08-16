class_name TileWorld
extends Node2D

const TILE_SIZE := Vector2i(8, 8)
const MAP_SIZE := Vector2i(48, 28)
const ATLAS_TEXTURE := preload("res://assets/tiles/environment_tiles_8x8.png")

enum Tile { CONCRETE, WOOD, RED_CARPET, WALL, WINDOW, DARK_TILE, GRASS, STAIRS }

@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var decoration_layer: TileMapLayer = $Decoration

func _ready() -> void:
	floor_layer.tile_set = _create_tile_set(false)
	wall_layer.tile_set = _create_tile_set(true)
	decoration_layer.tile_set = floor_layer.tile_set
	_build_floor()
	_build_walls()
	_build_decorations()

func _create_tile_set(with_physics: bool) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	if with_physics:
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 2)
		tile_set.set_physics_layer_collision_mask(0, 5)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ATLAS_TEXTURE
	atlas.texture_region_size = TILE_SIZE
	for tile_index in range(8):
		var atlas_coordinate := Vector2i(tile_index, 0)
		atlas.create_tile(atlas_coordinate)
	tile_set.add_source(atlas, 0)
	for tile_index in [Tile.WALL, Tile.WINDOW] if with_physics else []:
		var atlas_coordinate := Vector2i(int(tile_index), 0)
		var tile_data := atlas.get_tile_data(atlas_coordinate, 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
		]))
	return tile_set

func _set_tile(layer: TileMapLayer, cell: Vector2i, tile: Tile) -> void:
	layer.set_cell(cell, 0, Vector2i(int(tile), 0), 0)

func _build_floor() -> void:
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var tile := Tile.CONCRETE
			if x < 11 and y >= 4: tile = Tile.WOOD
			elif x >= 24 and y < 10: tile = Tile.RED_CARPET
			elif x >= 24 and y >= 10: tile = Tile.GRASS
			elif y >= 16: tile = Tile.DARK_TILE
			_set_tile(floor_layer, Vector2i(x, y), tile)

func _build_walls() -> void:
	for x in range(MAP_SIZE.x):
		_set_tile(wall_layer, Vector2i(x, 0), Tile.WINDOW if x in range(26, 31) else Tile.WALL)
		_set_tile(wall_layer, Vector2i(x, MAP_SIZE.y - 1), Tile.WALL)
	for y in range(1, MAP_SIZE.y - 1):
		_set_tile(wall_layer, Vector2i(0, y), Tile.WALL)
		_set_tile(wall_layer, Vector2i(MAP_SIZE.x - 1, y), Tile.WINDOW if y in range(12, 16) else Tile.WALL)
	for y in range(4, 20):
		if y not in [11, 12]: _set_tile(wall_layer, Vector2i(11, y), Tile.WALL)
	for x in range(24, 35):
		if x != 29: _set_tile(wall_layer, Vector2i(x, 9), Tile.WALL)
	for y in range(10, 17):
		if y != 14: _set_tile(wall_layer, Vector2i(24, y), Tile.WALL)
	for y in range(16, 22):
		if y != 19: _set_tile(wall_layer, Vector2i(18, y), Tile.WALL)

func _build_decorations() -> void:
	for x in range(19, 23):
		for y in range(18, 21):
			_set_tile(decoration_layer, Vector2i(x, y), Tile.STAIRS)
