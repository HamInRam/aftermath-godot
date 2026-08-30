class_name TileWorld
extends Node2D

const TILE_SIZE := Vector2i(8, 8)
const DEFAULT_MAP_SIZE := Vector2i(48, 28)
const PIXEL_ENVIRONMENT_ATLAS := preload("res://utility/pixel_environment_atlas.gd")
const GLASS_SHARDS_SCENE := preload("res://scenes/effects/glass_shards.tscn")
const DESTRUCTIBLE_PROP := preload("res://scripts/props/destructible_prop.gd")
const PIXEL_LIQUID_SYSTEM := preload("res://scripts/effects/pixel_liquid_system.gd")

enum Tile { CONCRETE, WOOD, RED_CARPET, WALL, WINDOW, DARK_TILE, GRASS, STAIRS, CHECKER, BLACK_PLANK, TEAL_CARPET, CREAM, MAGENTA_STAGE, RED_BRICK, BATH_TILE, BRIGHT_WALL, SOFA, TABLE, TOILET, SINK, BED, TV, VENDING, PLANT, CRACK, PAPERS, GLASS_BITS, GRIME, NEON_ARROW, HAZARD, CABLE, DRAIN }

@export_enum("nightclub", "sandwich_shop", "tactical_lab", "harbor_exchange", "motel_witness", "penthouse", "cold_storage", "casino_floor", "police_archive", "slaughterhouse", "broadcast_tower", "last_call") var layout_id := "nightclub"
@export var map_size := DEFAULT_MAP_SIZE
var layout_variant := "nightclub"

@onready var exterior_layer: TileMapLayer = $ExteriorBackdrop
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var wall_cap_layer: TileMapLayer = $WallCaps
@onready var wall_shadow_layer: TileMapLayer = $WallShadows
@onready var decoration_layer: TileMapLayer = $Decoration
@onready var object_shadow_layer: TileMapLayer = $ObjectShadows
@onready var object_layer: TileMapLayer = $Objects
var path_grid := AStarGrid2D.new()
var destructible_cells: Array[Vector2i] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layout_variant = layout_id
	layout_id = _get_layout_family(layout_variant)
	floor_layer.tile_set = _create_tile_set(false)
	exterior_layer.tile_set = floor_layer.tile_set
	wall_layer.tile_set = _create_tile_set(true)
	wall_cap_layer.tile_set = wall_layer.tile_set
	wall_shadow_layer.tile_set = wall_layer.tile_set
	decoration_layer.tile_set = floor_layer.tile_set
	object_shadow_layer.tile_set = floor_layer.tile_set
	object_layer.tile_set = wall_layer.tile_set
	_build_exterior()
	_build_floor()
	_build_walls()
	_build_wall_caps()
	_build_wall_shadows()
	_build_decorations()
	_build_objects()
	_clear_authored_door_approaches()
	_build_variant_dressing()
	_materialize_destructible_objects()
	_spawn_signature_props()
	_register_surface_drains()
	_build_object_shadows()
	_build_path_grid()

func _get_layout_family(variant: String) -> String:
	if variant in ["harbor_exchange", "cold_storage", "slaughterhouse"]: return "sandwich_shop"
	if variant in ["motel_witness", "penthouse", "casino_floor", "police_archive", "broadcast_tower", "last_call"]: return "tactical_lab"
	return variant

func _build_variant_dressing() -> void:
	# Legacy variants are now authored as complete maps in the custom builders.
	return

func _clear_authored_door_approaches() -> void:
	# A usable two-cell doorway also needs one collision-free approach cell on
	# either side. This prevents authored furniture from visually fitting near
	# a door while invisibly sealing the route for a 10px-wide actor collider.
	for spec: Dictionary in get_door_specs():
		var opening_cell: Vector2i = spec.opening_cell
		var horizontal_leaf := absf(float(spec.rotation)) > 0.1
		var leaf_step := Vector2i.RIGHT if horizontal_leaf else Vector2i.DOWN
		var normal_step := Vector2i.UP if horizontal_leaf else Vector2i.RIGHT
		for leaf_offset in [Vector2i.ZERO, leaf_step]:
			for normal_offset in [-normal_step, Vector2i.ZERO, normal_step]:
				var cell: Vector2i = opening_cell + leaf_offset + normal_offset
				object_layer.erase_cell(cell)

func _is_custom_layout() -> bool:
	return true

func _paint_floor(rect: Rect2i, tile: Tile) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ONE, map_size - Vector2i(2, 2)))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			_set_tile(floor_layer, Vector2i(x, y), tile)

func _build_custom_floor() -> void:
	_paint_floor(Rect2i(Vector2i.ONE, map_size - Vector2i(2, 2)), Tile.CONCRETE)
	match layout_variant:
		"nightclub":
			_paint_floor(Rect2i(2, 2, 9, 12), Tile.CHECKER)
			_paint_floor(Rect2i(12, 2, 20, 12), Tile.BLACK_PLANK)
			_paint_floor(Rect2i(18, 5, 14, 9), Tile.MAGENTA_STAGE)
			_paint_floor(Rect2i(33, 2, 13, 12), Tile.TEAL_CARPET)
			_paint_floor(Rect2i(2, 15, 9, 11), Tile.BATH_TILE)
			_paint_floor(Rect2i(12, 15, 20, 11), Tile.RED_BRICK)
			_paint_floor(Rect2i(33, 15, 13, 11), Tile.RED_CARPET)
		"sandwich_shop":
			_paint_floor(Rect2i(2, 2, 18, 11), Tile.CHECKER)
			_paint_floor(Rect2i(21, 2, 25, 11), Tile.CREAM)
			_paint_floor(Rect2i(2, 14, 22, 12), Tile.BATH_TILE)
			_paint_floor(Rect2i(25, 14, 13, 12), Tile.WOOD)
			_paint_floor(Rect2i(39, 14, 7, 12), Tile.RED_CARPET)
		"tactical_lab":
			_paint_floor(Rect2i(2, 2, 18, map_size.y - 4), Tile.CONCRETE)
			_paint_floor(Rect2i(21, 2, 19, map_size.y - 4), Tile.CHECKER)
			_paint_floor(Rect2i(41, 2, map_size.x - 43, 15), Tile.BLACK_PLANK)
			_paint_floor(Rect2i(41, 18, map_size.x - 43, map_size.y - 20), Tile.TEAL_CARPET)
		"harbor_exchange":
			_paint_floor(Rect2i(2, 2, 44, 10), Tile.DARK_TILE)
			_paint_floor(Rect2i(2, 15, 44, 11), Tile.WOOD)
			_paint_floor(Rect2i(18, 2, 11, 24), Tile.BLACK_PLANK)
		"motel_witness":
			_paint_floor(Rect2i(2, 2, 44, 8), Tile.RED_CARPET)
			_paint_floor(Rect2i(2, 17, 44, 9), Tile.TEAL_CARPET)
			_paint_floor(Rect2i(2, 11, 44, 5), Tile.CREAM)
		"penthouse":
			_paint_floor(Rect2i(2, 2, 21, 24), Tile.BLACK_PLANK)
			_paint_floor(Rect2i(24, 2, 22, 12), Tile.CREAM)
			_paint_floor(Rect2i(24, 15, 22, 11), Tile.TEAL_CARPET)
			_paint_floor(Rect2i(4, 16, 15, 8), Tile.RED_CARPET)
		"cold_storage":
			_paint_floor(Rect2i(2, 2, 44, 24), Tile.BATH_TILE)
			_paint_floor(Rect2i(3, 3, 12, 22), Tile.CREAM)
			_paint_floor(Rect2i(17, 3, 13, 22), Tile.DARK_TILE)
			_paint_floor(Rect2i(32, 3, 13, 22), Tile.CHECKER)
		"casino_floor":
			_paint_floor(Rect2i(2, 2, 44, 24), Tile.RED_CARPET)
			_paint_floor(Rect2i(11, 5, 25, 20), Tile.BLACK_PLANK)
			_paint_floor(Rect2i(18, 8, 12, 12), Tile.MAGENTA_STAGE)
			_paint_floor(Rect2i(38, 5, 8, 20), Tile.CREAM)
		"police_archive":
			_paint_floor(Rect2i(2, 2, 14, 24), Tile.CHECKER)
			_paint_floor(Rect2i(17, 2, 15, 24), Tile.CONCRETE)
			_paint_floor(Rect2i(33, 2, 13, 24), Tile.BATH_TILE)
		"slaughterhouse":
			_paint_floor(Rect2i(2, 2, 44, 24), Tile.RED_BRICK)
			_paint_floor(Rect2i(3, 3, 42, 6), Tile.CONCRETE)
			_paint_floor(Rect2i(3, 10, 42, 7), Tile.BATH_TILE)
			_paint_floor(Rect2i(3, 18, 42, 7), Tile.DARK_TILE)
		"broadcast_tower":
			_paint_floor(Rect2i(2, 2, 44, 24), Tile.BLACK_PLANK)
			_paint_floor(Rect2i(12, 6, 23, 16), Tile.TEAL_CARPET)
			_paint_floor(Rect2i(36, 2, 10, 24), Tile.DARK_TILE)
			_paint_floor(Rect2i(2, 2, 9, 24), Tile.CHECKER)
		"last_call":
			_paint_floor(Rect2i(2, 2, 44, 24), Tile.BLACK_PLANK)
			_paint_floor(Rect2i(2, 2, 13, 24), Tile.CHECKER)
			_paint_floor(Rect2i(16, 2, 19, 12), Tile.MAGENTA_STAGE)
			_paint_floor(Rect2i(36, 2, 10, 24), Tile.RED_CARPET)
			_paint_floor(Rect2i(16, 15, 19, 11), Tile.RED_BRICK)

func _build_boundary(edge_wall: Tile, top_windows: Array[int] = [], side_windows: Array[int] = []) -> void:
	for x in range(1, map_size.x - 1):
		_set_tile(wall_layer, Vector2i(x, 1), Tile.WINDOW if x in top_windows else edge_wall)
		_set_tile(wall_layer, Vector2i(x, map_size.y - 2), edge_wall)
	for y in range(2, map_size.y - 2):
		_set_tile(wall_layer, Vector2i(1, y), edge_wall)
		_set_tile(wall_layer, Vector2i(map_size.x - 2, y), Tile.WINDOW if y in side_windows else edge_wall)

func _wall_h(y: int, x0: int, x1: int, openings: Array[int] = [], windows: Array[int] = [], tile: Tile = Tile.BRIGHT_WALL) -> void:
	for x in range(x0, x1 + 1):
		if x in openings: continue
		_set_tile(wall_layer, Vector2i(x, y), Tile.WINDOW if x in windows else tile)

func _wall_v(x: int, y0: int, y1: int, openings: Array[int] = [], windows: Array[int] = [], tile: Tile = Tile.BRIGHT_WALL) -> void:
	for y in range(y0, y1 + 1):
		if y in openings: continue
		_set_tile(wall_layer, Vector2i(x, y), Tile.WINDOW if y in windows else tile)

func _build_custom_walls() -> void:
	_build_boundary(Tile.BRIGHT_WALL, [20, 21, 22, 23, 24, 25], [11, 12, 13, 14, 15])
	match layout_variant:
		"nightclub":
			_wall_v(11, 2, 25, [7, 8, 19, 20], [11, 12])
			_wall_v(34, 2, 25, [9, 10, 18, 19], [12, 13, 22, 23])
			_wall_h(15, 12, 33, [20, 21, 28, 29], [15, 16, 31, 32])
		"sandwich_shop":
			_wall_h(13, 2, 45, [8, 9, 24, 25, 40, 41], [15, 16, 33, 34])
			_wall_v(22, 2, 12, [7, 8], [4, 5])
			_wall_v(30, 14, 25, [20, 21], [16, 17])
			_wall_v(39, 14, 25, [17, 18], [22, 23])
		"tactical_lab":
			_wall_v(20, 2, map_size.y - 3, [8, 9, 23, 24], [14, 15, 30, 31])
			_wall_v(42, 2, map_size.y - 3, [7, 8, 20, 21, 30, 31], [12, 13, 26, 27])
			_wall_h(18, 21, 41, [30, 31], [35, 36])
			_wall_h(12, 2, 19, [9, 10], [14, 15])
			_wall_h(26, 21, 41, [31, 32], [36, 37])
			_wall_h(16, 43, map_size.x - 3, [52, 53], [58, 59])
		"harbor_exchange":
			_wall_v(14, 2, 25, [7, 8, 19, 20], [3, 4])
			_wall_v(34, 2, 25, [10, 11, 21, 22], [6, 7, 17, 18])
			_wall_h(14, 2, 45, [8, 9, 24, 25, 40, 41], [29, 30])
		"motel_witness":
			_wall_h(10, 2, 45, [7, 8, 19, 20, 31, 32, 42, 43], [13, 14, 25, 26, 37, 38])
			_wall_h(17, 2, 45, [6, 7, 19, 20, 31, 32, 40, 41], [10, 11, 22, 23, 34, 35])
			for x: int in [12, 24, 36]: _wall_v(x, 2, 9, [], [], Tile.WALL)
			for x: int in [12, 24, 36]: _wall_v(x, 18, 25, [], [], Tile.WALL)
		"penthouse":
			_wall_v(24, 2, 25, [8, 9, 19, 20], [4, 5, 13, 14])
			_wall_h(13, 25, 45, [34, 35], [28, 29, 40, 41])
			_wall_h(16, 2, 23, [10, 11], [17, 18])
		"cold_storage":
			_wall_v(15, 2, 25, [6, 7, 20, 21], [11, 12])
			_wall_v(32, 2, 25, [12, 13], [5, 6, 22, 23])
			_wall_h(13, 2, 14, [8, 9], [], Tile.WALL)
			_wall_h(17, 33, 45, [39, 40], [], Tile.WALL)
		"casino_floor":
			_wall_v(10, 2, 25, [7, 8, 20, 21], [12, 13, 14])
			_wall_v(38, 2, 25, [6, 7, 18, 19], [10, 11, 12, 13])
			_wall_h(17, 11, 37, [24, 25], [16, 17, 32, 33])
		"police_archive":
			_wall_v(16, 2, 25, [6, 7, 19, 20], [11, 12, 13])
			_wall_v(32, 2, 25, [12, 13, 22, 23], [5, 6, 17, 18])
			_wall_h(14, 2, 15, [8, 9], [], Tile.WALL)
			_wall_h(17, 17, 31, [24, 25], [], Tile.WALL)
		"slaughterhouse":
			_wall_h(9, 2, 45, [8, 9, 22, 23, 39, 40], [14, 15, 32, 33])
			_wall_h(18, 2, 45, [5, 6, 19, 20, 35, 36], [11, 12, 28, 29])
			_wall_v(24, 10, 17, [13, 14], [], Tile.WALL)
		"broadcast_tower":
			_wall_v(11, 2, 25, [8, 9, 20, 21], [13, 14, 15])
			_wall_v(36, 2, 25, [6, 7, 18, 19], [11, 12, 13, 14])
			_wall_h(7, 12, 35, [22, 23], [15, 16, 31, 32])
			_wall_h(21, 12, 35, [27, 28], [18, 19])
		"last_call":
			_wall_v(14, 2, 25, [7, 8, 19, 20], [11, 12])
			_wall_v(36, 2, 25, [5, 6, 17, 18], [10, 11, 22, 23])
			_wall_h(15, 15, 35, [24, 25], [18, 19, 31, 32])

func _build_custom_decorations() -> void:
	var accent_by_layout := {
		"nightclub": Tile.MAGENTA_STAGE, "sandwich_shop": Tile.RED_CARPET,
		"tactical_lab": Tile.TEAL_CARPET,
		"harbor_exchange": Tile.WOOD, "motel_witness": Tile.CREAM,
		"penthouse": Tile.MAGENTA_STAGE, "cold_storage": Tile.CREAM,
		"casino_floor": Tile.MAGENTA_STAGE, "police_archive": Tile.CHECKER,
		"slaughterhouse": Tile.RED_CARPET, "broadcast_tower": Tile.TEAL_CARPET,
		"last_call": Tile.RED_CARPET,
	}
	var accent: Tile = accent_by_layout.get(layout_variant, Tile.CONCRETE)
	var stripe_y := 12 if layout_variant in ["nightclub", "harbor_exchange", "motel_witness", "casino_floor"] else mini(24, map_size.y - 4)
	for x in range(3, map_size.x - 3):
		# Sparse wayfinding markers communicate circulation without turning the
		# floor into a noisy obstacle-like pattern at native resolution.
		if x % 4 == 0: _set_tile(decoration_layer, Vector2i(x, stripe_y), accent)
	if layout_variant in ["penthouse", "broadcast_tower"]:
		for x in range(40, 44):
			for y in range(21, 24): _set_tile(decoration_layer, Vector2i(x, y), Tile.STAIRS)
	match layout_variant:
		"nightclub":
			_place_decor([Vector2i(14,3), Vector2i(30,12), Vector2i(38,8)], Tile.GLASS_BITS)
			_place_decor([Vector2i(16,8), Vector2i(25,12), Vector2i(35,18)], Tile.NEON_ARROW)
			_place_decor([Vector2i(20,17), Vector2i(28,20)], Tile.CABLE)
		"sandwich_shop":
			_place_decor([Vector2i(7,7), Vector2i(17,5), Vector2i(42,17)], Tile.PAPERS)
			_place_decor([Vector2i(5,22), Vector2i(18,21), Vector2i(30,18)], Tile.GRIME)
		"tactical_lab":
			_place_decor([Vector2i(8,4), Vector2i(14,22), Vector2i(34,12), Vector2i(44,23)], Tile.CRACK)
			_place_decor([Vector2i(18,16), Vector2i(38,8), Vector2i(53,18)], Tile.HAZARD)
		"harbor_exchange":
			_place_decor([Vector2i(6,10), Vector2i(22,6), Vector2i(40,17)], Tile.GRIME)
			_place_decor([Vector2i(14,12), Vector2i(29,12), Vector2i(43,12)], Tile.HAZARD)
		"motel_witness":
			_place_decor([Vector2i(5,6), Vector2i(18,21), Vector2i(30,5), Vector2i(41,20)], Tile.PAPERS)
			_place_decor([Vector2i(15,13), Vector2i(34,13)], Tile.GLASS_BITS)
		"penthouse":
			_place_decor([Vector2i(7,8), Vector2i(18,20), Vector2i(29,8)], Tile.GLASS_BITS)
			_place_decor([Vector2i(15,5), Vector2i(35,22)], Tile.PAPERS)
		"cold_storage":
			_place_decor([Vector2i(8,8), Vector2i(24,14), Vector2i(40,20)], Tile.DRAIN)
			_place_decor([Vector2i(15,12), Vector2i(30,8), Vector2i(36,18)], Tile.HAZARD)
		"casino_floor":
			_place_decor([Vector2i(13,18), Vector2i(25,6), Vector2i(34,21)], Tile.PAPERS)
			_place_decor([Vector2i(18,12), Vector2i(29,16), Vector2i(40,12)], Tile.GLASS_BITS)
		"police_archive":
			_place_decor([Vector2i(7,12), Vector2i(22,14), Vector2i(29,5), Vector2i(39,20)], Tile.PAPERS)
			_place_decor([Vector2i(14,22), Vector2i(30,23)], Tile.CABLE)
		"slaughterhouse":
			_place_decor([Vector2i(5,7), Vector2i(21,14), Vector2i(38,13)], Tile.DRAIN)
			_place_decor([Vector2i(14,8), Vector2i(31,16), Vector2i(42,22)], Tile.GRIME)
		"broadcast_tower":
			_place_decor([Vector2i(15,12), Vector2i(28,19), Vector2i(41,9)], Tile.CABLE)
			_place_decor([Vector2i(7,18), Vector2i(22,4), Vector2i(33,20)], Tile.PAPERS)
		"last_call":
			_place_decor([Vector2i(7,10), Vector2i(20,7), Vector2i(31,12), Vector2i(41,19)], Tile.GLASS_BITS)
			_place_decor([Vector2i(13,22), Vector2i(25,18), Vector2i(38,6)], Tile.CABLE)
	for drain_cell in _get_surface_drain_cells(): _place_decor([drain_cell], Tile.DRAIN)

func _place_decor(cells: Array[Vector2i], tile: Tile) -> void:
	for cell: Vector2i in cells:
		if cell.x <= 1 or cell.y <= 1 or cell.x >= map_size.x - 1 or cell.y >= map_size.y - 1: continue
		if wall_layer.get_cell_source_id(cell) < 0: _set_tile(decoration_layer, cell, tile)

func _place_objects(cells: Array[Vector2i], tile: Tile) -> void:
	for cell: Vector2i in cells:
		if cell.x <= 1 or cell.y <= 1 or cell.x >= map_size.x - 1 or cell.y >= map_size.y - 1: continue
		if wall_layer.get_cell_source_id(cell) < 0: _set_tile(object_layer, cell, tile)

func _build_custom_objects() -> void:
	match layout_variant:
		"nightclub":
			_place_objects([Vector2i(14, 7), Vector2i(28, 7)], Tile.SOFA)
			_place_objects([Vector2i(16, 11), Vector2i(26, 11), Vector2i(35, 4)], Tile.TABLE)
			_place_objects([Vector2i(22, 6)], Tile.TV)
			_place_objects([Vector2i(4, 20), Vector2i(8, 20)], Tile.TOILET)
			_place_objects([Vector2i(6, 23), Vector2i(30, 22)], Tile.SINK)
			_place_objects([Vector2i(43, 23)], Tile.VENDING)
		"sandwich_shop":
			_place_objects([Vector2i(5, 5), Vector2i(12, 9), Vector2i(27, 5)], Tile.TABLE)
			_place_objects([Vector2i(5, 18), Vector2i(16, 18)], Tile.TABLE)
			_place_objects([Vector2i(3, 23), Vector2i(35, 23)], Tile.SINK)
			_place_objects([Vector2i(42, 20)], Tile.VENDING)
		"tactical_lab":
			_place_objects([Vector2i(5, 5), Vector2i(14, 14), Vector2i(27, 6), Vector2i(48, 8)], Tile.TABLE)
			_place_objects([Vector2i(5, 28), Vector2i(26, 30), Vector2i(49, 25)], Tile.SOFA)
			_place_objects([Vector2i(34, 5)], Tile.TV)
			_place_objects([Vector2i(16, 24), Vector2i(38, 24), Vector2i(58, 31)], Tile.SINK)
		"harbor_exchange":
			_place_objects([Vector2i(5, 5), Vector2i(10, 18), Vector2i(35, 5), Vector2i(39, 20)], Tile.TABLE)
			_place_objects([Vector2i(4, 22), Vector2i(43, 4)], Tile.VENDING)
			_place_objects([Vector2i(27, 23)], Tile.SINK)
		"motel_witness":
			_place_objects([Vector2i(5, 5), Vector2i(17, 5), Vector2i(29, 21), Vector2i(40, 21)], Tile.BED)
			_place_objects([Vector2i(10, 13), Vector2i(38, 13)], Tile.VENDING)
			_place_objects([Vector2i(4, 19), Vector2i(44, 4)], Tile.SINK)
		"penthouse":
			_place_objects([Vector2i(5, 5), Vector2i(6, 5), Vector2i(29, 6), Vector2i(38, 19)], Tile.SOFA)
			_place_objects([Vector2i(10, 20), Vector2i(29, 20)], Tile.TABLE)
			_place_objects([Vector2i(19, 4), Vector2i(43, 23)], Tile.PLANT)
			_place_objects([Vector2i(43, 5)], Tile.SINK)
		"cold_storage":
			_place_objects([Vector2i(5, 5), Vector2i(5, 20), Vector2i(22, 12), Vector2i(39, 6), Vector2i(39, 22)], Tile.TABLE)
			_place_objects([Vector2i(43, 23)], Tile.SINK)
		"casino_floor":
			_place_objects([Vector2i(15, 9), Vector2i(24, 9), Vector2i(32, 15), Vector2i(16, 21)], Tile.TABLE)
			_place_objects([Vector2i(5, 7), Vector2i(42, 8)], Tile.SOFA)
			_place_objects([Vector2i(42, 22)], Tile.VENDING)
			_place_objects([Vector2i(5, 23)], Tile.SINK)
		"police_archive":
			_place_objects([Vector2i(5, 5), Vector2i(13, 5), Vector2i(21, 6), Vector2i(26, 22), Vector2i(42, 7)], Tile.TABLE)
			_place_objects([Vector2i(28, 13)], Tile.TV)
			_place_objects([Vector2i(43, 23)], Tile.SINK)
		"slaughterhouse":
			_place_objects([Vector2i(7, 5), Vector2i(21, 5), Vector2i(35, 5), Vector2i(10, 13), Vector2i(30, 13)], Tile.TABLE)
			_place_objects([Vector2i(43, 22), Vector2i(4, 13)], Tile.SINK)
		"broadcast_tower":
			_place_objects([Vector2i(16, 9), Vector2i(24, 9), Vector2i(31, 17), Vector2i(40, 7)], Tile.TABLE)
			_place_objects([Vector2i(23, 13), Vector2i(40, 20)], Tile.TV)
			_place_objects([Vector2i(5, 22)], Tile.SINK)
		"last_call":
			_place_objects([Vector2i(5, 6), Vector2i(40, 6), Vector2i(20, 20), Vector2i(29, 20)], Tile.SOFA)
			_place_objects([Vector2i(22, 7), Vector2i(27, 10)], Tile.TABLE)
			_place_objects([Vector2i(25, 4)], Tile.TV)
			_place_objects([Vector2i(43, 23)], Tile.SINK)

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
	atlas.texture = PIXEL_ENVIRONMENT_ATLAS.create_texture()
	atlas.texture_region_size = TILE_SIZE
	for tile_index in range(32):
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
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Tile.DARK_TILE if (x + y) % 2 == 0 else Tile.BLACK_PLANK
			_set_tile(exterior_layer, Vector2i(x, y), tile)

func _build_floor() -> void:
	if _is_custom_layout():
		_build_custom_floor()
		return
	for y in range(1, map_size.y - 1):
		for x in range(1, map_size.x - 1):
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
	if _is_custom_layout():
		_build_custom_walls()
		return
	var edge_wall := Tile.BRIGHT_WALL if layout_id in ["nightclub", "tactical_lab"] else Tile.WALL
	for x in range(1, map_size.x - 1):
		_set_tile(wall_layer, Vector2i(x, 1), Tile.WINDOW if x in range(26, 31) else edge_wall)
		_set_tile(wall_layer, Vector2i(x, map_size.y - 2), edge_wall)
	for y in range(2, map_size.y - 2):
		_set_tile(wall_layer, Vector2i(1, y), edge_wall)
		_set_tile(wall_layer, Vector2i(map_size.x - 2, y), Tile.WINDOW if y in range(12, 16) else edge_wall)
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
		for y in range(2, map_size.y - 2):
			if y in [7, 8, 19, 20]: continue
			_set_tile(wall_layer, Vector2i(24, y), Tile.WINDOW if y in range(10, 14) else Tile.BRIGHT_WALL)
		for x in range(2, map_size.x - 2):
			if x in [10, 11, 35, 36]: continue
			_set_tile(wall_layer, Vector2i(x, 14), Tile.WINDOW if x in range(27, 33) else Tile.BRIGHT_WALL)
		if map_size.x > DEFAULT_MAP_SIZE.x:
			for y in range(15, map_size.y - 2):
				if y not in [22, 23]: _set_tile(wall_layer, Vector2i(48, y), Tile.BRIGHT_WALL)
		if map_size.y > DEFAULT_MAP_SIZE.y:
			for x in range(24, map_size.x - 2):
				if x not in [40, 41, 54, 55]: _set_tile(wall_layer, Vector2i(x, 27), Tile.BRIGHT_WALL)
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
	if _is_custom_layout():
		_build_custom_decorations()
		return
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

func _build_wall_caps() -> void:
	# The collision wall remains on the floor plane. A bright duplicate shifted
	# two pixels screen-up exposes a thin dark strip of the original wall below,
	# creating a stable pseudo-3D top surface without changing navigation.
	for cell in wall_layer.get_used_cells():
		wall_cap_layer.set_cell(cell, 0, wall_layer.get_cell_atlas_coords(cell), 0)

func _build_objects() -> void:
	if _is_custom_layout():
		_build_custom_objects()
		return
	if layout_id == "sandwich_shop":
		for cell in [Vector2i(8, 4), Vector2i(9, 4), Vector2i(34, 10), Vector2i(35, 10)]: _set_tile(object_layer, cell, Tile.TABLE)
		_set_tile(object_layer, Vector2i(12, 18), Tile.SINK)
		_set_tile(object_layer, Vector2i(37, 19), Tile.VENDING)
		return
	if layout_id == "tactical_lab":
		for cell in [Vector2i(7, 6), Vector2i(8, 6), Vector2i(39, 7), Vector2i(40, 7)]: _set_tile(object_layer, cell, Tile.SOFA)
		for cell in [Vector2i(15, 18), Vector2i(16, 18), Vector2i(30, 20), Vector2i(31, 20)]: _set_tile(object_layer, cell, Tile.TABLE)
		_set_tile(object_layer, Vector2i(19, 5), Tile.TV)
		_set_tile(object_layer, Vector2i(42, 22), Tile.VENDING)
		_set_tile(object_layer, Vector2i(8, 22), Tile.SINK)
		if map_size.x > DEFAULT_MAP_SIZE.x:
			for cell in [Vector2i(52, 7), Vector2i(53, 7), Vector2i(55, 19), Vector2i(56, 19)]: _set_tile(object_layer, cell, Tile.SOFA)
			for cell in [Vector2i(51, 23), Vector2i(52, 23), Vector2i(58, 10)]: _set_tile(object_layer, cell, Tile.TABLE)
			_set_tile(object_layer, Vector2i(59, 24), Tile.PLANT)
		if map_size.y > DEFAULT_MAP_SIZE.y:
			for cell in [Vector2i(29, 31), Vector2i(30, 31), Vector2i(43, 31), Vector2i(44, 31)]: _set_tile(object_layer, cell, Tile.TABLE)
			_set_tile(object_layer, Vector2i(36, 32), Tile.VENDING)
			_set_tile(object_layer, Vector2i(57, 31), Tile.PLANT)
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

func _materialize_destructible_objects() -> void:
	var kind_by_tile := {
		Tile.SOFA: "sofa", Tile.TABLE: "table", Tile.TOILET: "toilet",
		Tile.SINK: "sink", Tile.BED: "bed", Tile.TV: "tv",
		Tile.VENDING: "vending", Tile.PLANT: "plant",
	}
	var tint_by_layout := {
		"nightclub": Color("d42a78"), "sandwich_shop": Color("b85e32"),
		"tactical_lab": Color("36bfc0"), "harbor_exchange": Color("b7652b"),
		"motel_witness": Color("d94687"), "penthouse": Color("d3aa55"),
		"cold_storage": Color("64cddd"), "casino_floor": Color("c23658"),
		"police_archive": Color("4779b8"), "slaughterhouse": Color("8f3436"),
		"broadcast_tower": Color("3dbb78"), "last_call": Color("c51f62"),
	}
	var tint: Color = tint_by_layout.get(layout_variant, Color("a55745"))
	# Props retain each venue's identity but sit below actors, threats and blood
	# in the visual hierarchy instead of competing at equal saturation.
	tint = tint.lerp(Color(0.34, 0.31, 0.35, 1.0), 0.24)
	var cells: Array[Vector2i] = object_layer.get_used_cells()
	for cell: Vector2i in cells:
		var tile_id := object_layer.get_cell_atlas_coords(cell).x
		if not kind_by_tile.has(tile_id): continue
		var prop := DESTRUCTIBLE_PROP.new() as DestructibleProp
		prop.position = object_layer.map_to_local(cell)
		prop.setup(kind_by_tile[tile_id], tint)
		prop.solidity_changed.connect(_on_prop_solidity_changed.bind(cell))
		add_child(prop)
		destructible_cells.append(cell)
		object_layer.erase_cell(cell)

func _on_prop_solidity_changed(solid: bool, cell: Vector2i) -> void:
	if path_grid.region.size == Vector2i.ZERO: return
	if path_grid.is_in_boundsv(cell): path_grid.set_point_solid(cell, solid)

func set_dynamic_obstacle(world_position: Vector2, solid: bool) -> void:
	var cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	if path_grid.is_in_boundsv(cell): path_grid.set_point_solid(cell, solid)

func _spawn_signature_props() -> void:
	var authored := {
		"nightclub": [["speaker", Vector2i(17, 6)], ["speaker", Vector2i(29, 6)], ["bar", Vector2i(38, 10)], ["alcohol_shelf", Vector2i(25, 7)], ["extinguisher", Vector2i(30, 12)]],
		"sandwich_shop": [["counter", Vector2i(25, 9)], ["freezer", Vector2i(18, 22)], ["crate", Vector2i(32, 22)], ["grease_vat", Vector2i(31, 10)], ["sprinkler", Vector2i(18, 18)]],
		"tactical_lab": [["console", Vector2i(28, 12)], ["crate", Vector2i(12, 22)], ["evidence_cabinet", Vector2i(44, 22)], ["chemical_tank", Vector2i(35, 12)], ["breaker", Vector2i(30, 15)]],
		"harbor_exchange": [["crate", Vector2i(8, 8)], ["crate", Vector2i(36, 8)], ["shelf", Vector2i(41, 23)], ["fuel_drum", Vector2i(27, 12)], ["sprinkler", Vector2i(10, 20)]],
		"motel_witness": [["counter", Vector2i(20, 13)], ["vending", Vector2i(32, 13)], ["shelf", Vector2i(42, 5)], ["breaker", Vector2i(25, 13)], ["sprinkler", Vector2i(19, 20)]],
		"penthouse": [["bar", Vector2i(16, 20)], ["speaker", Vector2i(29, 5)], ["evidence_cabinet", Vector2i(41, 20)], ["glass_rack", Vector2i(39, 10)], ["sprinkler", Vector2i(30, 18)]],
		"cold_storage": [["freezer", Vector2i(8, 14)], ["freezer", Vector2i(23, 14)], ["shelf", Vector2i(39, 14)], ["coolant_pipe", Vector2i(27, 13)], ["breaker", Vector2i(20, 20)]],
		"casino_floor": [["slot_machine", Vector2i(13, 7)], ["slot_machine", Vector2i(34, 7)], ["bar", Vector2i(42, 16)], ["alcohol_shelf", Vector2i(26, 14)], ["sprinkler", Vector2i(16, 20)]],
		"police_archive": [["evidence_cabinet", Vector2i(8, 14)], ["evidence_cabinet", Vector2i(25, 14)], ["console", Vector2i(39, 14)], ["paper_archive", Vector2i(27, 11)], ["sprinkler", Vector2i(38, 20)]],
		"slaughterhouse": [["conveyor", Vector2i(12, 13)], ["conveyor", Vector2i(34, 13)], ["freezer", Vector2i(38, 21)], ["grease_vat", Vector2i(29, 13)], ["gas_line", Vector2i(27, 16)]],
		"broadcast_tower": [["console", Vector2i(20, 13)], ["speaker", Vector2i(31, 8)], ["evidence_cabinet", Vector2i(41, 14)], ["breaker", Vector2i(26, 14)], ["sprinkler", Vector2i(20, 20)]],
		"last_call": [["speaker", Vector2i(19, 7)], ["speaker", Vector2i(31, 7)], ["bar", Vector2i(40, 20)], ["alcohol_shelf", Vector2i(29, 12)], ["gas_line", Vector2i(20, 12)]],
	}
	for entry: Array in authored.get(layout_variant, []):
		var cell: Vector2i = entry[1]
		if cell.x <= 1 or cell.y <= 1 or cell.x >= map_size.x - 1 or cell.y >= map_size.y - 1: continue
		if wall_layer.get_cell_source_id(cell) >= 0 or cell in destructible_cells: continue
		var prop := DESTRUCTIBLE_PROP.new() as DestructibleProp
		prop.position = floor_layer.map_to_local(cell)
		prop.setup(str(entry[0]), Color("b85b45"))
		prop.solidity_changed.connect(_on_prop_solidity_changed.bind(cell))
		add_child(prop)
		destructible_cells.append(cell)

func _get_surface_drain_cells() -> Array[Vector2i]:
	var authored := {
		"nightclub": [Vector2i(9, 22)], "sandwich_shop": [Vector2i(18, 21), Vector2i(30, 18)],
		"tactical_lab": [Vector2i(34, 20)], "harbor_exchange": [Vector2i(29, 20)],
		"motel_witness": [Vector2i(18, 21)], "penthouse": [Vector2i(35, 22)],
		"cold_storage": [Vector2i(8, 8), Vector2i(24, 14), Vector2i(40, 20)],
		"casino_floor": [Vector2i(40, 20)], "police_archive": [Vector2i(39, 20)],
		"slaughterhouse": [Vector2i(5, 7), Vector2i(21, 14), Vector2i(38, 13)],
		"broadcast_tower": [Vector2i(28, 19)], "last_call": [Vector2i(25, 18)],
	}
	var result: Array[Vector2i] = []
	for cell: Vector2i in authored.get(layout_variant, []): result.append(cell)
	return result

func _register_surface_drains() -> void:
	var surface := PIXEL_LIQUID_SYSTEM.get_or_create(get_tree()) as PixelLiquidSystem
	if not is_instance_valid(surface): return
	for cell in _get_surface_drain_cells():
		surface.register_drain(floor_layer.to_global(floor_layer.map_to_local(cell)), 10.0, 1.0)

func _build_path_grid() -> void:
	path_grid.region = Rect2i(Vector2i.ZERO, map_size)
	path_grid.cell_size = Vector2(TILE_SIZE)
	path_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	path_grid.update()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var cell := Vector2i(x, y)
			if floor_layer.get_cell_source_id(cell) < 0: path_grid.set_point_solid(cell, true)
	for cell in wall_layer.get_used_cells(): path_grid.set_point_solid(cell, true)
	for cell: Vector2i in destructible_cells:
		if path_grid.is_in_boundsv(cell): path_grid.set_point_solid(cell, true)
	for cell in object_layer.get_used_cells():
		if object_layer.get_cell_atlas_coords(cell).x != Tile.PLANT: path_grid.set_point_solid(cell, true)
	_apply_navigation_clearance_cost()

func _apply_navigation_clearance_cost() -> void:
	var neighbor_offsets := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for y in range(map_size.y):
		for x in range(map_size.x):
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
	from_cell = from_cell.clamp(Vector2i.ZERO, map_size - Vector2i.ONE)
	to_cell = to_cell.clamp(Vector2i.ZERO, map_size - Vector2i.ONE)
	if path_grid.is_point_solid(from_cell) or path_grid.is_point_solid(to_cell): return PackedVector2Array()
	var id_path := path_grid.get_id_path(from_cell, to_cell)
	var world_path := PackedVector2Array()
	for index in range(1, id_path.size()):
		world_path.append(floor_layer.to_global(floor_layer.map_to_local(id_path[index])))
	return world_path

func get_door_specs() -> Array[Dictionary]:
	var authored := {
		"nightclub": [[Vector2i(11, 7), 0.0], [Vector2i(20, 15), -PI * 0.5], [Vector2i(34, 18), 0.0]],
		"sandwich_shop": [[Vector2i(8, 13), -PI * 0.5], [Vector2i(22, 7), 0.0], [Vector2i(30, 20), 0.0]],
		"tactical_lab": [[Vector2i(20, 8), 0.0], [Vector2i(20, 23), 0.0], [Vector2i(42, 7), 0.0], [Vector2i(30, 18), -PI * 0.5], [Vector2i(9, 12), -PI * 0.5], [Vector2i(31, 26), -PI * 0.5], [Vector2i(52, 16), -PI * 0.5]],
		"harbor_exchange": [[Vector2i(14, 7), 0.0], [Vector2i(24, 14), -PI * 0.5], [Vector2i(34, 21), 0.0]],
		"motel_witness": [[Vector2i(7, 10), -PI * 0.5], [Vector2i(31, 10), -PI * 0.5], [Vector2i(19, 17), -PI * 0.5]],
		"penthouse": [[Vector2i(24, 8), 0.0], [Vector2i(34, 13), -PI * 0.5], [Vector2i(10, 16), -PI * 0.5]],
		"cold_storage": [[Vector2i(15, 6), 0.0], [Vector2i(32, 12), 0.0], [Vector2i(39, 17), -PI * 0.5]],
		"casino_floor": [[Vector2i(10, 7), 0.0], [Vector2i(38, 18), 0.0], [Vector2i(24, 17), -PI * 0.5]],
		"police_archive": [[Vector2i(16, 19), 0.0], [Vector2i(32, 12), 0.0], [Vector2i(24, 17), -PI * 0.5]],
		"slaughterhouse": [[Vector2i(22, 9), -PI * 0.5], [Vector2i(19, 18), -PI * 0.5], [Vector2i(24, 13), 0.0]],
		"broadcast_tower": [[Vector2i(11, 8), 0.0], [Vector2i(36, 18), 0.0], [Vector2i(22, 7), -PI * 0.5], [Vector2i(27, 21), -PI * 0.5]],
		"last_call": [[Vector2i(14, 7), 0.0], [Vector2i(36, 17), 0.0], [Vector2i(24, 15), -PI * 0.5]],
	}
	var result: Array[Dictionary] = []
	for entry: Array in authored.get(layout_variant, []):
		var opening_cell: Vector2i = entry[0]
		var door_rotation := float(entry[1])
		var leaf_axis := Vector2.DOWN.rotated(door_rotation)
		var first_cell_center := floor_layer.map_to_local(opening_cell)
		# Openings span two 8px cells, while the door scene is hinged at the
		# edge of its 16px leaf. The old centre placement shifted the leaf four
		# pixels into the far wall, leaving an invisible blocker after opening.
		var hinge_position := first_cell_center - leaf_axis * (TILE_SIZE.y * 0.5)
		var passage_center := first_cell_center + leaf_axis * (TILE_SIZE.y * 0.5)
		if not _door_has_open_approaches(opening_cell, door_rotation):
			continue
		result.append({
			"position": hinge_position,
			"passage_center": passage_center,
			"opening_cell": opening_cell,
			"rotation": door_rotation,
		})
	return result

func _door_has_open_approaches(opening_cell: Vector2i, door_rotation: float) -> bool:
	var horizontal_leaf := absf(door_rotation) > 0.1
	var leaf_step := Vector2i.RIGHT if horizontal_leaf else Vector2i.DOWN
	var normal_step := Vector2i.UP if horizontal_leaf else Vector2i.RIGHT
	var negative_open := false
	var positive_open := false
	for leaf_offset in [Vector2i.ZERO, leaf_step]:
		var negative_cell: Vector2i = opening_cell + leaf_offset - normal_step
		var positive_cell: Vector2i = opening_cell + leaf_offset + normal_step
		negative_open = negative_open or _is_bare_floor_cell(negative_cell)
		positive_open = positive_open or _is_bare_floor_cell(positive_cell)
	return negative_open and positive_open

func _is_bare_floor_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y: return false
	return floor_layer.get_cell_source_id(cell) >= 0 and wall_layer.get_cell_source_id(cell) < 0

func get_security_specs() -> Array[Dictionary]:
	var authored := {
		"tactical_lab": [[Vector2i(18, 4), 0.35], [Vector2i(42, 20), -2.65]],
		"motel_witness": [[Vector2i(3, 12), 0.0], [Vector2i(44, 14), PI]],
		"penthouse": [[Vector2i(21, 3), 0.75], [Vector2i(44, 23), -2.4]],
		"casino_floor": [[Vector2i(12, 6), 0.4], [Vector2i(35, 22), -2.7]],
		"police_archive": [[Vector2i(14, 3), 0.5], [Vector2i(34, 23), -2.5]],
		"broadcast_tower": [[Vector2i(13, 11), 0.2], [Vector2i(33, 24), -2.9]],
		"last_call": [[Vector2i(17, 3), 0.6], [Vector2i(33, 23), -2.55]],
	}
	var result: Array[Dictionary] = []
	for entry: Array in authored.get(layout_variant, []):
		var cell: Vector2i = entry[0]
		if path_grid.is_in_boundsv(cell) and not path_grid.is_point_solid(cell):
			result.append({"position": floor_layer.map_to_local(cell), "rotation": float(entry[1])})
	return result

func get_light_positions() -> Array[Vector2]:
	var authored := {
		"nightclub": [Vector2(160, 72), Vector2(280, 64), Vector2(212, 184), Vector2(356, 184)],
		"sandwich_shop": [Vector2(76, 60), Vector2(260, 68), Vector2(140, 188), Vector2(332, 188)],
		"tactical_lab": [Vector2(76, 60), Vector2(252, 68), Vector2(124, 188), Vector2(332, 188)],
		"harbor_exchange": [Vector2(76, 56), Vector2(232, 80), Vector2(92, 188), Vector2(340, 188)],
		"motel_witness": [Vector2(68, 52), Vector2(260, 52), Vector2(140, 196), Vector2(340, 196)],
		"penthouse": [Vector2(100, 72), Vector2(300, 68), Vector2(124, 188), Vector2(340, 188)],
		"cold_storage": [Vector2(68, 72), Vector2(196, 120), Vector2(332, 72), Vector2(340, 196)],
		"casino_floor": [Vector2(80, 72), Vector2(192, 104), Vector2(300, 168), Vector2(340, 72)],
		"police_archive": [Vector2(68, 64), Vector2(196, 104), Vector2(284, 176), Vector2(356, 64)],
		"slaughterhouse": [Vector2(76, 52), Vector2(212, 108), Vector2(332, 52), Vector2(276, 196)],
		"broadcast_tower": [Vector2(68, 104), Vector2(196, 92), Vector2(300, 176), Vector2(356, 84)],
		"last_call": [Vector2(68, 64), Vector2(200, 72), Vector2(276, 184), Vector2(356, 104)],
	}
	var result: Array[Vector2] = []
	for position: Vector2 in authored.get(layout_variant, []): result.append(position)
	if layout_variant == "tactical_lab" and map_size.x > DEFAULT_MAP_SIZE.x:
		result.append_array([Vector2(428, 60), Vector2(468, 156), Vector2(300, 252), Vector2(460, 252)])
	return result

func is_navigation_position_walkable(world_position: Vector2) -> bool:
	var cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	return path_grid.is_in_boundsv(cell) and not path_grid.is_point_solid(cell)

func get_nearest_walkable_position(world_position: Vector2, search_radius_cells := 3) -> Vector2:
	var origin_cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	if path_grid.is_in_boundsv(origin_cell) and not path_grid.is_point_solid(origin_cell): return world_position
	var best_cell := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(-search_radius_cells, search_radius_cells + 1):
		for x in range(-search_radius_cells, search_radius_cells + 1):
			var candidate := origin_cell + Vector2i(x, y)
			if not path_grid.is_in_boundsv(candidate) or path_grid.is_point_solid(candidate): continue
			var distance := Vector2(candidate - origin_cell).length_squared()
			if distance < best_distance:
				best_distance = distance
				best_cell = candidate
	if best_cell.x < 0: return Vector2.INF
	return floor_layer.to_global(floor_layer.map_to_local(best_cell))

func get_tactical_room_id(world_position: Vector2) -> String:
	var cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	match layout_variant:
		"nightclub": return ("service" if cell.x < 11 else ("dance_floor" if cell.x < 34 else "vip")) + ("_north" if cell.y < 15 else "_south")
		"sandwich_shop": return ("dining" if cell.x < 22 else "counter") if cell.y < 13 else ("kitchen" if cell.x < 30 else ("storage" if cell.x < 39 else "office"))
		"tactical_lab": return ("west_range" if cell.x < 20 else ("central_range" if cell.x < 42 else "east_range")) + ("_north" if cell.y < 18 else ("_middle" if cell.y < 26 else "_south"))
		"harbor_exchange": return ("warehouse" if cell.x < 14 else ("loading_spine" if cell.x < 34 else "dock")) + ("_north" if cell.y < 14 else "_south")
		"motel_witness": return "motel_%s_%d" % ["north" if cell.y < 10 else ("corridor" if cell.y < 17 else "south"), floori(float(cell.x) / 12.0)]
		"penthouse": return ("lounge" if cell.x < 24 else "suite") + ("_north" if cell.y < (16 if cell.x < 24 else 13) else "_south")
		"cold_storage": return "freezer_west" if cell.x < 15 else ("freezer_core" if cell.x < 32 else "freezer_east")
		"casino_floor": return ("casino_west" if cell.x < 10 else ("gaming_floor" if cell.x < 38 else "vip_cage")) + ("_north" if cell.y < 17 else "_south")
		"police_archive": return "records" if cell.x < 16 else ("archive_hub" if cell.x < 32 else "evidence_lockup")
		"slaughterhouse": return "intake" if cell.y < 9 else ("processing" if cell.y < 18 else "packing")
		"broadcast_tower": return ("service" if cell.x < 11 else ("studio" if cell.x < 36 else "control")) + ("_upper" if cell.y < 7 else ("_floor" if cell.y < 21 else "_lower"))
		"last_call": return ("entry" if cell.x < 14 else ("main_club" if cell.x < 36 else "finale_vip")) + ("_north" if cell.y < 15 else "_south")
	if layout_id == "tactical_lab":
		var column := "west" if cell.x < 24 else ("center" if cell.x < 48 else "east")
		var row := "north" if cell.y < 14 else ("middle" if cell.y < 27 else "south")
		return "%s_%s" % [column, row]
	if layout_id == "sandwich_shop":
		if cell.y < 7: return "front"
		if cell.y >= 15: return "storage_west" if cell.x < 23 else "storage_east"
		return "kitchen" if cell.x < 30 else "dining"
	if cell.x <= 11: return "west_north" if cell.y < 16 else "west_south"
	if cell.x >= 24 and cell.y < 9: return "stage"
	if cell.x >= 24: return "east"
	return "center_north" if cell.y < 16 else "center_south"

func get_blood_surface_profile(world_position: Vector2) -> Dictionary:
	var cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	var tile_id := floor_layer.get_cell_atlas_coords(cell).x
	if tile_id in [Tile.RED_CARPET, Tile.TEAL_CARPET]: return {"kind": "carpet", "spread": 0.72, "darken": 0.30, "absorption": 1.5, "cleanup": 3}
	if tile_id in [Tile.WOOD, Tile.BLACK_PLANK]: return {"kind": "wood", "spread": 1.30, "darken": 0.16, "absorption": 0.75, "grain": true, "cleanup": 3}
	if tile_id in [Tile.CHECKER, Tile.BATH_TILE, Tile.CREAM]: return {"kind": "tile", "spread": 0.92, "darken": 0.0, "absorption": 0.45, "gloss": 0.42, "cleanup": 2}
	return {"kind": "concrete", "spread": 1.0, "darken": 0.10, "absorption": 0.95, "cleanup": 2}

func is_near_object_type(world_position: Vector2, tile_type: int, radius := 20.0) -> bool:
	var prop_kind_by_tile := {Tile.SOFA: "sofa", Tile.TABLE: "table", Tile.TOILET: "toilet", Tile.SINK: "sink", Tile.BED: "bed", Tile.TV: "tv", Tile.VENDING: "vending", Tile.PLANT: "plant"}
	if prop_kind_by_tile.has(tile_type):
		for child in get_children():
			if child is DestructibleProp and child.prop_kind == prop_kind_by_tile[tile_type] and child.state != DestructibleProp.PropState.DESTROYED:
				if child.global_position.distance_to(world_position) <= radius: return true
	var center := object_layer.local_to_map(object_layer.to_local(world_position))
	var cell_radius := ceili(radius / float(TILE_SIZE.x))
	for y in range(-cell_radius, cell_radius + 1):
		for x in range(-cell_radius, cell_radius + 1):
			var cell := center + Vector2i(x, y)
			if object_layer.get_cell_atlas_coords(cell).x != tile_type: continue
			var object_position := object_layer.to_global(object_layer.map_to_local(cell))
			if object_position.distance_to(world_position) <= radius: return true
	return false

func is_near_sink(world_position: Vector2, radius := 20.0) -> bool:
	return is_near_object_type(world_position, Tile.SINK, radius)

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
	var effect_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if RuntimeBudget.try_add("debris", shards, effect_parent):
		shards.global_position = hit_position
		shards.setup(flight_direction)
	Events.glass_shattered.emit(hit_position)
	return true
