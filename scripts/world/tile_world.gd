class_name TileWorld
extends Node2D

const TILE_SIZE := Vector2i(8, 8)
const DOOR_CELL_SPAN := 3
const DEFAULT_MAP_SIZE := Vector2i(48, 28)
const EXTERIOR_MARGIN := Vector2i(8, 7)
const METERS_PER_TILE := 0.5
const ACTOR_SHOULDER_WIDTH_METERS := 0.7
const MIN_CORRIDOR_CELLS := 5
const PRIMARY_CORRIDOR_CELLS := 7
const COMBAT_SPACE_SCALE := 2
const PIXEL_ENVIRONMENT_ATLAS := preload("res://utility/pixel_environment_atlas.gd")
const PIXEL_MATERIAL_CANVAS := preload("res://utility/pixel_material_canvas.gd")
const HANDCRAFTED_ROOMS := preload("res://utility/handcrafted_room_catalog.gd")
const GLASS_SHARDS_SCENE := preload("res://scenes/effects/glass_shards.tscn")
const DESTRUCTIBLE_PROP := preload("res://scripts/props/destructible_prop.gd")

enum Tile { CONCRETE, WOOD, RED_CARPET, WALL, WINDOW, DARK_TILE, GRASS, STAIRS, CHECKER, BLACK_PLANK, TEAL_CARPET, CREAM, MAGENTA_STAGE, RED_BRICK, BATH_TILE, BRIGHT_WALL, SOFA, TABLE, TOILET, SINK, BED, TV, VENDING, PLANT, CRACK, PAPERS, GLASS_BITS, GRIME, NEON_ARROW, HAZARD, CABLE, DRAIN, TERRAZZO, BLUE_TILE, GOLD_CARPET, RUBBER_GRID, WHITE_TILE, MOSAIC, DARK_WALL, SERVICE_WALL }

@export_enum("nightclub", "sandwich_shop", "tactical_lab", "harbor_exchange", "motel_witness", "penthouse", "cold_storage", "casino_floor", "police_archive", "slaughterhouse", "broadcast_tower", "last_call") var layout_id := "nightclub"
@export var map_size := DEFAULT_MAP_SIZE
var layout_variant := "nightclub"
var world_size := Vector2i.ZERO
var building_origin := EXTERIOR_MARGIN

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
var acoustic_sector_by_cell: Dictionary = {}
var acoustic_portals: Array[Dictionary] = []
var acoustic_sector_count := 0
var material_detail_sprite: Sprite2D
var wall_detail_sprite: Sprite2D
var eroded_cells: Dictionary = {}
var erosion_topology_pending := false
var eroded_wall_image: Image

func chip_wall_at(point: Vector2, direction: Vector2, damage: int) -> void:
	# Tile physics updates happen outside the collision callback.
	call_deferred("_chip_wall_deferred", point, direction, damage)

func _chip_wall_deferred(point: Vector2, direction: Vector2, damage: int) -> void:
	var cell := wall_layer.local_to_map(wall_layer.to_local(point + direction.normalized() * 0.8))
	if cell.x <= 0 or cell.y <= 0 or cell.x >= world_size.x - 1 or cell.y >= world_size.y - 1: return
	if eroded_cells.has(cell):
		eroded_cells[cell].receive_projectile_impact_context(direction, point, "pistol", damage)
		return
	if wall_layer.get_cell_source_id(cell) < 0: return
	if eroded_wall_image == null: eroded_wall_image = wall_detail_sprite.texture.get_image()
	var region := Rect2i(cell * 8, Vector2i(8,8))
	var pixels := eroded_wall_image.get_region(region)
	eroded_wall_image.fill_rect(region, Color.TRANSPARENT)
	var body := ErodingWallCell.new()
	body.position = Vector2(cell * 8)
	add_child(body)
	eroded_cells[cell] = body
	body.setup(self, cell, pixels)
	wall_layer.erase_cell(cell)
	wall_cap_layer.erase_cell(cell)
	wall_shadow_layer.erase_cell(cell)
	body.receive_projectile_impact_context(direction, point, "pistol", damage)
	_queue_erosion_topology()

func finish_eroded_cell(cell: Vector2i) -> void:
	if path_grid.is_in_boundsv(cell): path_grid.set_point_solid(cell, false)
	_queue_erosion_topology()

func _queue_erosion_topology() -> void:
	if erosion_topology_pending: return
	erosion_topology_pending = true
	call_deferred("_refresh_eroded_topology")

func _refresh_eroded_topology() -> void:
	erosion_topology_pending = false
	if eroded_wall_image != null: wall_detail_sprite.texture.update(eroded_wall_image)
	if is_instance_valid(light_occluder_container):
		remove_child(light_occluder_container)
		light_occluder_container.queue_free()
	_build_light_occluders()
	_build_acoustic_topology()
var light_occluder_container: Node2D
var room_run_seed_override := -1
var geometry_expanded := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layout_variant = layout_id
	layout_id = _get_layout_family(layout_variant)
	world_size = map_size + EXTERIOR_MARGIN * 2
	floor_layer.tile_set = _create_tile_set(false)
	exterior_layer.tile_set = floor_layer.tile_set
	wall_layer.tile_set = _create_tile_set(true)
	wall_cap_layer.tile_set = wall_layer.tile_set
	wall_shadow_layer.tile_set = wall_layer.tile_set
	decoration_layer.tile_set = floor_layer.tile_set
	object_shadow_layer.tile_set = floor_layer.tile_set
	object_layer.tile_set = wall_layer.tile_set
	_configure_manor_presentation()
	_build_exterior()
	_build_floor()
	_build_walls()
	_expand_authored_door_openings()
	_build_decorations()
	_build_objects()
	_clear_authored_door_approaches()
	_build_variant_dressing()
	_expand_combat_geometry()
	_build_material_detail_canvas()
	_build_wall_detail_canvas()
	_build_light_occluders()
	_build_wall_caps()
	_build_wall_shadows()
	_materialize_destructible_objects()
	_spawn_signature_props()
	_ensure_minimum_destructible_props()
	_build_object_shadows()
	_build_path_grid()
	_build_acoustic_topology()

func _expand_combat_geometry() -> void:
	# Expand navigable world space, never Node2D.scale or the source artwork.
	# Floors remain native 8px tiles with 1px texture detail; actors, furniture,
	# bullets and the 24px door leaves retain their existing physical dimensions.
	# Blueprint coordinates stay stable for scene resources and encounter modules.
	for layer: TileMapLayer in [exterior_layer, floor_layer, wall_layer, decoration_layer, object_layer]:
		var source_cells := {}
		for cell: Vector2i in layer.get_used_cells(): source_cells[cell] = layer.get_cell_atlas_coords(cell)
		layer.clear()
		var is_structure := layer in [exterior_layer, floor_layer, wall_layer]
		for cell: Vector2i in source_cells:
			var target := cell * COMBAT_SPACE_SCALE
			if is_structure:
				for y in COMBAT_SPACE_SCALE:
					for x in COMBAT_SPACE_SCALE:
						layer.set_cell(target + Vector2i(x, y), 0, source_cells[cell])
			else:
				# Furniture and small dressing are single native-sized objects, not
				# four duplicates or an enlarged texture blocking a whole room.
				layer.set_cell(target + Vector2i.ONE, 0, source_cells[cell])
	building_origin *= COMBAT_SPACE_SCALE
	world_size *= COMBAT_SPACE_SCALE
	geometry_expanded = true
	_rebuild_native_door_thresholds()

func _authored_cell_to_world(cell: Vector2i) -> Vector2i:
	if not geometry_expanded: return cell + building_origin
	return cell * COMBAT_SPACE_SCALE + building_origin + Vector2i.ONE

func _door_opening_world_cell(authored_cell: Vector2i, door_rotation: float) -> Vector2i:
	if not geometry_expanded: return authored_cell + building_origin
	var leaf_step := Vector2i.RIGHT if absf(door_rotation) > 0.1 else Vector2i.DOWN
	return authored_cell * COMBAT_SPACE_SCALE + building_origin + leaf_step

func _rebuild_native_door_thresholds() -> void:
	var entries := _get_authored_door_entries()
	entries.append([Vector2i(_get_entrance_authored_x() - 2, map_size.y - 2), -PI * 0.5])
	for entry: Array in entries:
		var rotation_value := float(entry[1])
		var leaf_step := Vector2i.RIGHT if absf(rotation_value) > 0.1 else Vector2i.DOWN
		var depth_step := Vector2i.DOWN if leaf_step == Vector2i.RIGHT else Vector2i.RIGHT
		var original_start: Vector2i = entry[0] * COMBAT_SPACE_SCALE + building_origin
		var opening := _door_opening_world_cell(entry[0], rotation_value)
		# Seal the enlarged source aperture first, then cut the exact panel width
		# through the full wall thickness. Both jambs remain connected to masonry.
		for along in range(-1, DOOR_CELL_SPAN * COMBAT_SPACE_SCALE + 1):
			for depth in COMBAT_SPACE_SCALE:
				_set_world_tile(wall_layer, original_start + leaf_step * along + depth_step * depth, _get_partition_wall_tile())
		for along in DOOR_CELL_SPAN:
			for depth in range(-2, COMBAT_SPACE_SCALE + 2):
				var cell := opening + leaf_step * along + depth_step * depth
				if depth >= 0 and depth < COMBAT_SPACE_SCALE: wall_layer.erase_cell(cell)
				object_layer.erase_cell(cell)

func get_combat_space_profile() -> Dictionary:
	var room_bounds: Array[Dictionary] = []
	for room: Dictionary in get_architectural_rooms():
		var rect: Rect2i = room.rect
		room_bounds.append({"id": room.id, "bounds": Rect2(map_authored_position(Vector2(rect.position * TILE_SIZE)), Vector2(rect.size * TILE_SIZE) * COMBAT_SPACE_SCALE)})
	return {"space_scale": COMBAT_SPACE_SCALE, "native_tile_px": TILE_SIZE.x, "door_width_px": DOOR_CELL_SPAN * TILE_SIZE.x, "rooms": room_bounds}

func _build_material_detail_canvas() -> void:
	# Tile IDs continue to own collision and surface behavior. This one cached
	# texture supplies world-continuous native-pixel variation without adding a
	# per-pixel node, draw call or runtime simulation cost.
	var material_by_cell := {}
	for cell: Vector2i in floor_layer.get_used_cells():
		var atlas_coordinate := floor_layer.get_cell_atlas_coords(cell)
		if atlas_coordinate.x >= 0: material_by_cell[cell] = atlas_coordinate.x
	material_detail_sprite = Sprite2D.new()
	material_detail_sprite.name = "MaterialPixelCanvas"
	material_detail_sprite.centered = false
	material_detail_sprite.position = Vector2.ZERO
	material_detail_sprite.z_index = -9
	material_detail_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material_detail_sprite.texture = PIXEL_MATERIAL_CANVAS.create_texture(world_size, TILE_SIZE, material_by_cell, layout_variant.hash(), layout_variant)
	add_child(material_detail_sprite)

func _build_wall_detail_canvas() -> void:
	eroded_wall_image = null
	var material_by_cell := {}
	for cell: Vector2i in wall_layer.get_used_cells():
		var atlas_coordinate := wall_layer.get_cell_atlas_coords(cell)
		if atlas_coordinate.x >= 0: material_by_cell[cell] = atlas_coordinate.x
	if not is_instance_valid(wall_detail_sprite):
		wall_detail_sprite = Sprite2D.new()
		add_child(wall_detail_sprite)
	wall_detail_sprite.name = "WallPixelCanvas"
	wall_detail_sprite.centered = false
	wall_detail_sprite.position = Vector2.ZERO
	wall_detail_sprite.z_index = 1
	wall_detail_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall_detail_sprite.texture = PIXEL_MATERIAL_CANVAS.create_wall_texture(world_size, TILE_SIZE, material_by_cell)

func _configure_manor_presentation() -> void:
	# Scene resources retain their physics layers and authored offsets. The
	# connected wall canvas replaces only the repeated, tinted cap artwork.
	for layer: TileMapLayer in [exterior_layer, floor_layer, wall_layer, wall_cap_layer, decoration_layer, object_layer]:
		layer.modulate = Color.WHITE
		layer.material = null
	exterior_layer.modulate = Color("555555")
	wall_shadow_layer.modulate = Color(0.02, 0.02, 0.02, 0.35)
	object_shadow_layer.modulate = Color(0.02, 0.02, 0.02, 0.32)
	wall_cap_layer.visible = false

func _build_light_occluders() -> void:
	if layout_variant != "nightclub": return
	light_occluder_container = Node2D.new()
	light_occluder_container.name = "LightOccluders"
	add_child(light_occluder_container)
	var solids := {}
	for cell: Vector2i in wall_layer.get_used_cells():
		if wall_layer.get_cell_atlas_coords(cell).x != int(Tile.WINDOW): solids[cell] = true
	var ordered_cells: Array = solids.keys()
	ordered_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var consumed := {}
	for cell_value: Variant in ordered_cells:
		var cell := cell_value as Vector2i
		if consumed.has(cell): continue
		var width := 1
		while solids.has(cell + Vector2i(width, 0)) and not consumed.has(cell + Vector2i(width, 0)): width += 1
		var height := 1
		while true:
			var complete_row := true
			for offset_x in width:
				var candidate := cell + Vector2i(offset_x, height)
				if not solids.has(candidate) or consumed.has(candidate):
					complete_row = false
					break
			if not complete_row: break
			height += 1
		for offset_y in height:
			for offset_x in width: consumed[cell + Vector2i(offset_x, offset_y)] = true
		_add_light_occluder_rect(cell, Vector2i(width, height))

func _add_light_occluder_rect(first_cell: Vector2i, cell_span: Vector2i) -> void:
	var center := wall_layer.map_to_local(first_cell)
	var top_left := center - Vector2(TILE_SIZE) * 0.5
	var size := Vector2(cell_span * TILE_SIZE)
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		top_left,
		top_left + Vector2(size.x, 0),
		top_left + size,
		top_left + Vector2(0, size.y),
	])
	var occluder := LightOccluder2D.new()
	occluder.occluder = polygon
	light_occluder_container.add_child(occluder)

func _get_layout_family(variant: String) -> String:
	if variant in ["harbor_exchange", "cold_storage", "slaughterhouse"]: return "sandwich_shop"
	if variant in ["motel_witness", "penthouse", "casino_floor", "police_archive", "broadcast_tower", "last_call"]: return "tactical_lab"
	return variant

func _get_room_run_seed() -> int:
	if room_run_seed_override >= 0: return absi((layout_variant + ":preview:" + str(room_run_seed_override)).hash())
	# Child TileWorld._ready runs before Main._ready. Read the active run identity
	# here so cover built now and enemy formations requested later share one seed.
	# Retrying a floor changes neither value; beginning a run advances the serial.
	if is_instance_valid(Progression) and Progression.run_session.active:
		var serial := maxi(1, int(Progression.data.get("roguelike_run_serial", 1)))
		var floor_number := maxi(1, Progression.get_roguelike_floor())
		return absi(("aftermath:rooms:%s:%d:%d" % [layout_variant, serial, floor_number]).hash())
	# Standalone level previews retain their existing mission-attempt seed.
	var attempt := 1
	if is_instance_valid(Progression):
		var attempts: Dictionary = Progression.data.get("mission_attempts", {})
		attempt = maxi(1, int(attempts.get(layout_variant, attempts.get(Progression.current_mission_id, 1))))
	return absi((layout_variant + ":" + str(attempt) + ":" + str(Progression.get_run_mode())).hash())

func get_handcrafted_encounter_layout() -> Dictionary:
	# A seed chooses complete validated modules instead of independent random
	# points. Hostile anchors, role order, patrol intent and cover therefore stay
	# tactically coherent while quarter-turn/mirror variants multiply replay value.
	var mission_order := ["nightclub", "sandwich_shop", "tactical_lab", "harbor_exchange", "motel_witness", "penthouse", "cold_storage", "casino_floor", "police_archive", "slaughterhouse", "broadcast_tower", "last_call"]
	var mission_rank := maxi(0, mission_order.find(layout_variant))
	var seed_value := _get_room_run_seed()
	var rooms := get_architectural_rooms()
	var target_count := rooms.size() * 4
	var assignments: Array[Dictionary] = HANDCRAFTED_ROOMS.get_assignments(seed_value, rooms.size())
	var spawns := PackedVector2Array()
	var patrols := PackedVector2Array()
	var types := PackedStringArray()
	# Round-robin slots guarantee every chamber is populated before later rooms
	# receive their fourth hostile.
	for slot_index in range(4):
		for room_index in range(rooms.size()):
			if spawns.size() >= target_count: break
			var room: Dictionary = rooms[room_index]
			var module: Dictionary = assignments[room_index]
			# The tactical lab remains a dense combat/physics validation venue.
			if layout_variant != "tactical_lab" and str(module.combat_kind) == "skirmish" and slot_index >= 2: continue
			var anchors: Array = module.enemies
			if slot_index >= anchors.size(): continue
			var rect: Rect2i = room.rect
			var uv: Vector2 = anchors[slot_index]
			# Use almost the complete chamber footprint. The former two-cell inset
			# compressed every formation into the centre and made broad rooms play
			# like closets despite their authored dimensions.
			var usable_x := maxi(1, rect.size.x - 3)
			var usable_y := maxi(1, rect.size.y - 3)
			var cell := rect.position + Vector2i(1 + roundi(uv.x * usable_x), 1 + roundi(uv.y * usable_y))
			cell = cell.clamp(rect.position + Vector2i.ONE, rect.end - Vector2i(2,2))
			spawns.append(Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE) * 0.5)
			var patrol_direction: Vector2 = (module.patrols as Array)[slot_index]
			var cardinal := is_zero_approx(patrol_direction.x) or is_zero_approx(patrol_direction.y)
			patrols.append(patrol_direction * (84.0 if cardinal else 72.0))
			var role_order: Array = module.roles
			types.append(str(role_order[slot_index]))
	# Keep hounds deliberate and readable: exactly one selected room contains the
	# fast melee pressure role instead of random runs occasionally becoming dog-heavy.
	if not types.is_empty():
		for index in range(types.size()):
			if types[index] == "dog": types[index] = "melee"
		var dog_index := posmod(seed_value + mission_rank * 3, types.size())
		types[dog_index] = "dog"
	var module_ids := PackedStringArray()
	for module: Dictionary in assignments: module_ids.append("%s:%d" % [str(module.id), int(module.transform)])
	return {"spawns": spawns, "patrols": patrols, "types": types, "seed": seed_value, "modules": module_ids}

func _build_variant_dressing() -> void:
	# Legacy variants are now authored as complete maps in the custom builders.
	return

func _clear_authored_door_approaches() -> void:
	# A usable three-cell doorway also needs one collision-free approach cell on
	# either side. This prevents authored furniture from visually fitting near
	# a door while invisibly sealing the route for a 10px-wide actor collider.
	for spec: Dictionary in get_door_specs():
		var opening_cell: Vector2i = spec.opening_cell
		var horizontal_leaf := absf(float(spec.rotation)) > 0.1
		var leaf_step := Vector2i.RIGHT if horizontal_leaf else Vector2i.DOWN
		var normal_step := Vector2i.UP if horizontal_leaf else Vector2i.RIGHT
		for leaf_index in range(DOOR_CELL_SPAN):
			var leaf_offset := leaf_step * leaf_index
			for normal_offset in [-normal_step, Vector2i.ZERO, normal_step]:
				var cell: Vector2i = opening_cell + leaf_offset + normal_offset
				object_layer.erase_cell(cell)

func _is_custom_layout() -> bool:
	return true

func get_architectural_profile() -> Dictionary:
	return {
		"tile_size_px": TILE_SIZE.x,
		"meters_per_tile": METERS_PER_TILE,
		"actor_shoulder_width_m": ACTOR_SHOULDER_WIDTH_METERS,
		"minimum_corridor_tiles": MIN_CORRIDOR_CELLS,
		"primary_corridor_tiles": PRIMARY_CORRIDOR_CELLS,
		"rooms": get_architectural_rooms(),
	}

func _room(id: String, rect: Rect2i, floor: Tile) -> Dictionary:
	return {"id": id, "rect": rect, "floor": floor}

func get_architectural_rooms() -> Array[Dictionary]:
	# OTXO-inspired room-run plans deliberately trade realistic micro-rooms for a
	# handful of large, readable combat chambers. Each venue keeps a distinct
	# silhouette and material identity while offering room for dense enemy mixes,
	# dodging, Focus movement and flying/destructible props.
	match layout_variant:
		"nightclub": return [
			_room("service_gallery", Rect2i(2,2,11,24), Tile.DARK_TILE),
			_room("dance_hall", Rect2i(14,2,22,15), Tile.BLACK_PLANK),
			_room("bar_gallery", Rect2i(37,2,9,15), Tile.MOSAIC),
			_room("entry_floor", Rect2i(14,18,22,8), Tile.TERRAZZO),
			_room("back_bar", Rect2i(37,18,9,8), Tile.GOLD_CARPET),
		]
		"sandwich_shop": return [
			_room("prep_hall", Rect2i(2,2,16,12), Tile.WHITE_TILE),
			_room("cook_hall", Rect2i(19,2,27,12), Tile.RUBBER_GRID),
			_room("dining_hall", Rect2i(2,15,32,11), Tile.TERRAZZO),
			_room("manager_store", Rect2i(35,15,11,11), Tile.WOOD),
		]
		"tactical_lab": return [
			_room("west_range", Rect2i(2,2,16,24), Tile.RUBBER_GRID),
			_room("north_range", Rect2i(19,2,19,12), Tile.BLUE_TILE),
			_room("south_range", Rect2i(19,15,19,11), Tile.WHITE_TILE),
			_room("east_observation", Rect2i(39,2,map_size.x-41,map_size.y-4), Tile.BLACK_PLANK),
		]
		"harbor_exchange": return [
			_room("dispatch_hall", Rect2i(2,2,12,24), Tile.WOOD),
			_room("north_loading", Rect2i(15,2,20,13), Tile.RUBBER_GRID),
			_room("south_loading", Rect2i(15,16,20,10), Tile.CONCRETE),
			_room("dock_hall", Rect2i(36,2,10,24), Tile.DARK_TILE),
		]
		"motel_witness": return [
			_room("north_west_suite", Rect2i(2,2,22,8), Tile.RED_CARPET),
			_room("north_east_suite", Rect2i(25,2,21,8), Tile.GOLD_CARPET),
			_room("open_breezeway", Rect2i(2,11,44,6), Tile.CREAM),
			_room("south_west_suite", Rect2i(2,18,22,8), Tile.GOLD_CARPET),
			_room("south_east_suite", Rect2i(25,18,21,8), Tile.RED_CARPET),
		]
		"penthouse": return [
			_room("gallery_lounge", Rect2i(2,2,22,13), Tile.MOSAIC),
			_room("glass_salon", Rect2i(25,2,21,13), Tile.BLACK_PLANK),
			_room("office_hall", Rect2i(2,16,22,10), Tile.GOLD_CARPET),
			_room("private_suite", Rect2i(25,16,21,10), Tile.CREAM),
		]
		"cold_storage": return [
			_room("receiving_bay", Rect2i(2,2,14,24), Tile.CONCRETE),
			_room("north_freezer", Rect2i(17,2,16,15), Tile.BLUE_TILE),
			_room("south_freezer", Rect2i(17,18,16,8), Tile.WHITE_TILE),
			_room("packing_hall", Rect2i(34,2,12,24), Tile.RUBBER_GRID),
		]
		"casino_floor": return [
			_room("west_lounge", Rect2i(2,2,9,24), Tile.BLACK_PLANK),
			_room("north_gaming", Rect2i(12,2,24,13), Tile.GOLD_CARPET),
			_room("south_gaming", Rect2i(12,16,24,10), Tile.RED_CARPET),
			_room("vip_cage", Rect2i(37,2,9,24), Tile.MOSAIC),
		]
		"police_archive": return [
			_room("intake_hall", Rect2i(2,2,13,24), Tile.CONCRETE),
			_room("north_archive", Rect2i(16,2,18,12), Tile.BLUE_TILE),
			_room("south_archive", Rect2i(16,15,18,11), Tile.WOOD),
			_room("evidence_hall", Rect2i(35,2,11,24), Tile.DARK_TILE),
		]
		"slaughterhouse": return [
			_room("receiving_floor", Rect2i(2,2,44,8), Tile.CONCRETE),
			_room("west_kill_floor", Rect2i(2,11,24,8), Tile.RED_BRICK),
			_room("east_processing", Rect2i(27,11,19,8), Tile.WHITE_TILE),
			_room("packing_floor", Rect2i(2,20,44,6), Tile.RUBBER_GRID),
		]
		"broadcast_tower": return [
			_room("reception_gallery", Rect2i(2,2,10,24), Tile.CHECKER),
			_room("north_studio", Rect2i(13,2,22,14), Tile.TEAL_CARPET),
			_room("south_studio", Rect2i(13,17,22,9), Tile.GOLD_CARPET),
			_room("control_gallery", Rect2i(36,2,10,24), Tile.DARK_TILE),
		]
		"last_call": return [
			_room("west_service", Rect2i(2,2,12,24), Tile.CHECKER),
			_room("final_stage", Rect2i(15,2,20,13), Tile.MAGENTA_STAGE),
			_room("ruined_floor", Rect2i(15,16,20,10), Tile.BLACK_PLANK),
			_room("vip_gauntlet", Rect2i(36,2,10,24), Tile.GOLD_CARPET),
		]
	return []

func _get_legacy_architectural_rooms() -> Array[Dictionary]:
	# One native tile represents roughly half a metre. Room rectangles therefore
	# describe believable 3-8m spaces while corridors remain wide enough for two
	# actors to pass and fight without furniture becoming collision clutter.
	match layout_variant:
		"nightclub": return [
			# A real venue plan: controlled public entry in the south, a large
			# unobstructed performance core, guest services on the west and the
			# bar/service spine on the east. Saturated finishes mark destinations,
			# not arbitrary room-sized colour blocks.
			_room("restrooms", Rect2i(2,2,10,15), Tile.BLUE_TILE),
			_room("coat_check_security", Rect2i(2,18,10,8), Tile.DARK_TILE),
			_room("cocktail_lounge", Rect2i(13,2,5,5), Tile.RED_CARPET),
			_room("dj_stage", Rect2i(19,2,12,5), Tile.MAGENTA_STAGE),
			_room("vip_lounge", Rect2i(32,2,14,5), Tile.GOLD_CARPET),
			_room("main_dance_floor", Rect2i(13,7,23,14), Tile.BLACK_PLANK),
			_room("main_bar", Rect2i(37,7,9,14), Tile.MOSAIC),
			_room("entrance_lobby", Rect2i(13,22,23,4), Tile.TERRAZZO),
			_room("back_bar_storage", Rect2i(37,22,9,4), Tile.DARK_TILE),
		]
		"sandwich_shop": return [
			_room("prep_room", Rect2i(2,2,16,12), Tile.WHITE_TILE),
			_room("cook_line", Rect2i(19,2,13,12), Tile.WHITE_TILE),
			_room("cold_pantry", Rect2i(33,2,13,12), Tile.BLUE_TILE),
			_room("kitchen", Rect2i(2,15,20,11), Tile.WHITE_TILE),
			_room("dining_room", Rect2i(15,15,20,11), Tile.TERRAZZO),
			_room("manager_office", Rect2i(36,15,10,11), Tile.WOOD),
		]
		"tactical_lab":
			var east_width := map_size.x - 44
			var rooms: Array[Dictionary] = [
				_room("west_security", Rect2i(2,2,18,10), Tile.RUBBER_GRID),
				_room("west_briefing", Rect2i(2,13,18,12), Tile.DARK_TILE),
				_room("central_lab_a", Rect2i(21,2,21,6), Tile.BLUE_TILE),
				_room("central_lab_b", Rect2i(21,9,21,9), Tile.BLUE_TILE),
				_room("central_decon", Rect2i(21,19,21,7), Tile.WHITE_TILE),
				_room("east_observation", Rect2i(43,2,east_width,14), Tile.BLACK_PLANK),
				_room("east_server", Rect2i(43,17,east_width,map_size.y-19), Tile.TEAL_CARPET),
			]
			if map_size.y > DEFAULT_MAP_SIZE.y:
				rooms.append(_room("south_training", Rect2i(2,26,18,map_size.y-28), Tile.RED_BRICK))
				rooms.append(_room("south_forensics", Rect2i(21,27,21,map_size.y-29), Tile.CREAM))
			return rooms
		"harbor_exchange": return [
			_room("dispatch_office", Rect2i(2,2,12,12), Tile.DARK_TILE),
			_room("records_room", Rect2i(2,15,12,11), Tile.WOOD),
			_room("loading_bay_north", Rect2i(15,2,19,12), Tile.RUBBER_GRID),
			_room("loading_bay_south", Rect2i(15,15,19,11), Tile.CONCRETE),
			_room("dock_cage", Rect2i(35,2,11,16), Tile.DARK_TILE),
			_room("dock_office", Rect2i(35,19,11,7), Tile.WOOD),
		]
		"motel_witness":
			var result: Array[Dictionary] = []
			for index in range(4):
				var unit_width := 8 if index == 3 else 10
				result.append(_room("north_room_%d" % (index + 1), Rect2i(2 + index*12,2,unit_width,8), Tile.RED_CARPET))
				result.append(_room("south_room_%d" % (index + 1), Rect2i(2 + index*12,18,unit_width,8), Tile.GOLD_CARPET))
			return result
		"penthouse": return [
			_room("gallery", Rect2i(2,2,8,14), Tile.MOSAIC),
			_room("living_room", Rect2i(11,2,13,14), Tile.BLACK_PLANK),
			_room("office", Rect2i(2,17,22,9), Tile.GOLD_CARPET),
			_room("kitchen", Rect2i(25,2,12,11), Tile.CREAM),
			_room("bedroom", Rect2i(38,2,8,11), Tile.CREAM),
			_room("private_lounge", Rect2i(25,14,21,7), Tile.TEAL_CARPET),
			_room("bath_suite", Rect2i(25,22,21,4), Tile.WHITE_TILE),
		]
		"cold_storage": return [
			_room("receiving", Rect2i(2,2,13,11), Tile.CONCRETE),
			_room("wash_bay", Rect2i(2,14,13,12), Tile.WHITE_TILE),
			_room("freezer_a", Rect2i(16,2,16,8), Tile.BLUE_TILE),
			_room("freezer_b", Rect2i(16,11,16,9), Tile.BLUE_TILE),
			_room("plant_room", Rect2i(16,21,16,5), Tile.CONCRETE),
			_room("packing", Rect2i(33,2,13,15), Tile.RUBBER_GRID),
			_room("supervisor", Rect2i(33,18,13,8), Tile.WOOD),
		]
		"casino_floor": return [
			_room("west_lobby", Rect2i(2,2,8,15), Tile.GOLD_CARPET),
			_room("west_bar", Rect2i(2,18,8,8), Tile.BLACK_PLANK),
			_room("gaming_north", Rect2i(11,2,27,7), Tile.GOLD_CARPET),
			_room("gaming_floor", Rect2i(11,10,27,7), Tile.BLACK_PLANK),
			_room("cashier_floor", Rect2i(11,18,18,8), Tile.RED_CARPET),
			_room("surveillance", Rect2i(30,18,8,8), Tile.DARK_TILE),
			_room("vip_cage", Rect2i(39,2,7,24), Tile.MOSAIC),
		]
		"police_archive": return [
			_room("records_north", Rect2i(2,2,14,12), Tile.BLUE_TILE),
			_room("intake", Rect2i(2,15,14,11), Tile.CONCRETE),
			_room("archive_office", Rect2i(17,2,15,7), Tile.WOOD),
			_room("archive_stacks", Rect2i(17,10,15,7), Tile.CONCRETE),
			_room("interview_room", Rect2i(17,18,15,8), Tile.DARK_TILE),
			_room("evidence_north", Rect2i(33,2,13,9), Tile.WHITE_TILE),
			_room("evidence_lockup", Rect2i(33,12,13,8), Tile.CONCRETE),
			_room("armory", Rect2i(33,21,13,5), Tile.DARK_TILE),
		]
		"slaughterhouse": return [
			_room("receiving_west", Rect2i(2,2,10,7), Tile.CONCRETE),
			_room("receiving_center", Rect2i(13,2,23,7), Tile.CONCRETE),
			_room("locker_room", Rect2i(37,2,9,7), Tile.TERRAZZO),
			_room("kill_floor", Rect2i(2,10,22,8), Tile.RED_BRICK),
			_room("processing", Rect2i(25,10,21,8), Tile.WHITE_TILE),
			_room("cold_pack", Rect2i(2,19,12,7), Tile.DARK_TILE),
			_room("packaging", Rect2i(15,19,19,7), Tile.RUBBER_GRID),
			_room("wash_office", Rect2i(35,19,11,7), Tile.WHITE_TILE),
		]
		"broadcast_tower": return [
			_room("reception", Rect2i(2,2,9,18), Tile.CHECKER),
			_room("service_room", Rect2i(2,21,9,5), Tile.CONCRETE),
			_room("newsroom", Rect2i(12,2,24,5), Tile.RUBBER_GRID),
			_room("studio_a", Rect2i(12,8,12,13), Tile.TEAL_CARPET),
			_room("studio_b", Rect2i(25,8,11,7), Tile.TEAL_CARPET),
			_room("edit_suite", Rect2i(25,16,11,5), Tile.DARK_TILE),
			_room("green_room", Rect2i(12,22,24,4), Tile.GOLD_CARPET),
			_room("control_room", Rect2i(37,2,9,24), Tile.DARK_TILE),
		]
		"last_call": return [
			_room("entry_service", Rect2i(2,2,12,18), Tile.CHECKER),
			_room("staff_room", Rect2i(2,21,12,5), Tile.WHITE_TILE),
			_room("main_stage", Rect2i(15,2,21,7), Tile.MAGENTA_STAGE),
			_room("club_floor", Rect2i(15,10,21,5), Tile.BLACK_PLANK),
			_room("backstage", Rect2i(15,16,21,10), Tile.RED_BRICK),
			_room("vip_north", Rect2i(37,2,9,19), Tile.GOLD_CARPET),
			_room("security_office", Rect2i(37,22,9,4), Tile.DARK_TILE),
		]
	return []

func get_architectural_circulation() -> Array[Dictionary]:
	# Broad rooms connect directly through wide three-cell thresholds. Separate
	# decorative corridor strips would fragment these arena silhouettes.
	return []

func _get_legacy_architectural_circulation() -> Array[Dictionary]:
	match layout_variant:
		"motel_witness": return [{"rect": Rect2i(2,11,44,6), "floor": Tile.CREAM}]
		"sandwich_shop": return [{"rect": Rect2i(22,14,5,12), "floor": Tile.WOOD}]
		"tactical_lab": return [{"rect": Rect2i(17,2,3,map_size.y-4), "floor": Tile.CONCRETE}, {"rect": Rect2i(39,2,3,map_size.y-4), "floor": Tile.CONCRETE}]
		"harbor_exchange": return [{"rect": Rect2i(14,2,3,24), "floor": Tile.CONCRETE}, {"rect": Rect2i(32,2,3,24), "floor": Tile.CONCRETE}]
		"penthouse": return [{"rect": Rect2i(21,2,4,24), "floor": Tile.CREAM}]
		"cold_storage": return [{"rect": Rect2i(13,2,4,24), "floor": Tile.CONCRETE}, {"rect": Rect2i(30,2,4,24), "floor": Tile.CONCRETE}]
		"casino_floor": return [{"rect": Rect2i(10,14,28,4), "floor": Tile.RED_CARPET}]
		"police_archive": return [{"rect": Rect2i(14,2,4,24), "floor": Tile.CONCRETE}, {"rect": Rect2i(30,2,4,24), "floor": Tile.CONCRETE}]
		"broadcast_tower": return [{"rect": Rect2i(9,7,29,3), "floor": Tile.CONCRETE}]
		"nightclub": return [{"rect": Rect2i(20,20,9,6), "floor": Tile.TERRAZZO}]
		"slaughterhouse", "last_call": return [{"rect": Rect2i(20,9,8,17), "floor": Tile.BLACK_PLANK}]
	return []

func _paint_floor(rect: Rect2i, tile: Tile) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ONE, map_size - Vector2i(2, 2)))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			_set_tile(floor_layer, Vector2i(x, y), tile)

func _set_world_tile(layer: TileMapLayer, cell: Vector2i, tile: Tile) -> void:
	layer.set_cell(cell, 0, Vector2i(int(tile), 0), 0)

func _paint_world_floor(rect: Rect2i, tile: Tile) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ONE, world_size - Vector2i(2, 2)))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			_set_world_tile(floor_layer, Vector2i(x, y), tile)

func _build_exterior_floor() -> void:
	# The playable world now has a genuine exterior apron around the authored
	# building. A hard-surface service walk wraps the façade while grass/asphalt
	# define readable outdoor approach routes without adding collision clutter.
	_paint_world_floor(Rect2i(Vector2i.ONE, world_size - Vector2i(2, 2)), Tile.GRASS)
	var building_rect := Rect2i(building_origin, map_size)
	_paint_world_floor(building_rect.grow(2), Tile.CONCRETE)
	var approach_x := building_origin.x + _get_entrance_authored_x() - 3
	_paint_world_floor(Rect2i(approach_x, building_rect.end.y, 6, EXTERIOR_MARGIN.y - 1), Tile.CONCRETE)
	_paint_world_floor(Rect2i(1, building_rect.end.y + 3, world_size.x - 2, EXTERIOR_MARGIN.y - 4), Tile.DARK_TILE)
	# Sparse lane markings sell parking/loading space while leaving the route open.
	for x in range(4, world_size.x - 4, 8):
		for y in range(building_rect.end.y + 4, mini(world_size.y - 2, building_rect.end.y + 6)):
			_set_world_tile(decoration_layer, Vector2i(x, y), Tile.HAZARD)

func _build_world_boundary() -> void:
	for x in range(world_size.x):
		_set_world_tile(wall_layer, Vector2i(x, 0), Tile.WALL)
		_set_world_tile(wall_layer, Vector2i(x, world_size.y - 1), Tile.WALL)
	for y in range(1, world_size.y - 1):
		_set_world_tile(wall_layer, Vector2i(0, y), Tile.WALL)
		_set_world_tile(wall_layer, Vector2i(world_size.x - 1, y), Tile.WALL)

func _build_custom_floor() -> void:
	_paint_floor(Rect2i(Vector2i.ONE, map_size - Vector2i(2, 2)), Tile.CONCRETE)
	# Floor finishes follow actual room programs, so a threshold communicates a
	# change of use rather than an arbitrary color stripe.
	for room: Dictionary in get_architectural_rooms():
		_paint_floor(room.rect, room.floor)
	# Primary circulation remains visually continuous through every plan.
	var circulation := get_architectural_circulation()
	for zone: Dictionary in circulation:
		_paint_floor(zone.rect, zone.floor)

func _build_boundary(edge_wall: Tile, top_windows: Array[int] = [], side_windows: Array[int] = []) -> void:
	var entrance_x := _get_entrance_authored_x()
	# A full human-scale leaf spans three native 8px cells. Keeping this opening
	# identical to the physical panel length anchors both jambs to the façade.
	var entrance_cells := [entrance_x - 2, entrance_x - 1, entrance_x]
	for x in range(1, map_size.x - 1):
		_set_tile(wall_layer, Vector2i(x, 1), Tile.WINDOW if x in top_windows else edge_wall)
		if x not in entrance_cells:
			_set_tile(wall_layer, Vector2i(x, map_size.y - 2), edge_wall)
	for y in range(2, map_size.y - 2):
		_set_tile(wall_layer, Vector2i(1, y), edge_wall)
		_set_tile(wall_layer, Vector2i(map_size.x - 2, y), Tile.WINDOW if y in side_windows else edge_wall)

func _get_entrance_authored_x() -> int:
	# Entrances align to believable lobby/corridor space, never directly into an
	# interior partition. These two asymmetric façades need an offset threshold.
	if layout_variant == "motel_witness": return 18
	if layout_variant == "penthouse": return 36
	return map_size.x / 2

func _wall_h(y: int, x0: int, x1: int, openings: Array[int] = [], windows: Array[int] = [], tile: Tile = Tile.BRIGHT_WALL) -> void:
	if tile == Tile.BRIGHT_WALL: tile = _get_partition_wall_tile()
	for x in range(x0, x1 + 1):
		if x in openings: continue
		_set_tile(wall_layer, Vector2i(x, y), Tile.WINDOW if x in windows else tile)

func _wall_v(x: int, y0: int, y1: int, openings: Array[int] = [], windows: Array[int] = [], tile: Tile = Tile.BRIGHT_WALL) -> void:
	if tile == Tile.BRIGHT_WALL: tile = _get_partition_wall_tile()
	for y in range(y0, y1 + 1):
		if y in openings: continue
		_set_tile(wall_layer, Vector2i(x, y), Tile.WINDOW if y in windows else tile)

func _build_custom_walls() -> void:
	var exterior_windows: Array[int] = []
	if layout_variant in ["motel_witness", "penthouse"]:
		exterior_windows.append_array([8,9,38,39])
	else:
		exterior_windows.append_array([20,21,22,23,24,25])
	var side_windows: Array[int] = [8,9,18,19]
	_build_boundary(_get_exterior_wall_tile(), exterior_windows, side_windows)
	match layout_variant:
		"nightclub":
			_wall_v(13, 2, 25, [10,11,12], [5,6])
			_wall_v(36, 2, 25, [10,11,12], [15,16])
			_wall_h(20, 14, 45, [22,23,24,40,41,42])
		"sandwich_shop":
			_wall_h(14, 2, 45, [7,8,9,24,25,26,39,40,41], [30,31])
			_wall_v(18, 2, 13, [6,7,8])
			_wall_v(34, 15, 25, [19,20,21])
		"tactical_lab":
			_wall_v(18, 2, map_size.y - 3, [6,7,8,19,20,21], [12,13])
			_wall_v(38, 2, map_size.y - 3, [6,7,8,19,20,21], [11,12])
			_wall_h(14, 19, 37, [27,28,29], [33,34])
			if map_size.x > DEFAULT_MAP_SIZE.x:
				_wall_h(27, 2, map_size.x - 3, [10,11,12,30,31,32,51,52,53])
		"harbor_exchange":
			_wall_v(14, 2, 25, [7,8,9,19,20,21], [4,5])
			_wall_v(35, 2, 25, [7,8,9,19,20,21], [13,14])
			_wall_h(15, 15, 34, [23,24,25], [30,31])
		"motel_witness":
			_wall_h(10, 2, 45, [8,9,10,30,31,32], [18,19,40,41])
			_wall_h(17, 2, 45, [8,9,10,30,31,32], [18,19,40,41])
			_wall_v(24, 2, 9, [5,6,7])
			_wall_v(24, 18, 25, [21,22,23])
		"penthouse":
			_wall_v(24, 2, 25, [7,8,9,20,21,22], [12,13])
			_wall_h(15, 2, 23, [10,11,12], [18,19])
			_wall_h(15, 25, 45, [34,35,36], [42,43])
		"cold_storage":
			_wall_v(16, 2, 25, [7,8,9,20,21,22], [12,13])
			_wall_v(33, 2, 25, [7,8,9,20,21,22], [14,15])
			_wall_h(17, 17, 32, [24,25,26], [29,30])
		"casino_floor":
			_wall_v(11, 2, 25, [7,8,9,20,21,22], [13,14])
			_wall_v(39, 2, 25, [7,8,9,20,21,22], [12,13])
			_wall_h(15, 12, 38, [24,25,26], [33,34])
		"police_archive":
			_wall_v(15, 2, 25, [7,8,9,20,21,22], [12,13])
			_wall_v(34, 2, 25, [7,8,9,20,21,22], [17,18])
			_wall_h(14, 16, 33, [24,25,26], [29,30])
		"slaughterhouse":
			_wall_h(10, 2, 45, [8,9,10,23,24,25,39,40,41], [15,16,33,34])
			_wall_h(19, 2, 45, [8,9,10,23,24,25,39,40,41], [15,16,33,34])
			_wall_v(26, 11, 18, [14,15,16])
		"broadcast_tower":
			_wall_v(12, 2, 25, [7,8,9,20,21,22], [13,14])
			_wall_v(37, 2, 25, [7,8,9,20,21,22], [12,13])
			_wall_h(16, 13, 36, [24,25,26], [31,32])
		"last_call":
			_wall_v(14, 2, 25, [7,8,9,20,21,22], [12,13])
			_wall_v(38, 2, 25, [7,8,9,20,21,22], [11,12])
			_wall_h(15, 15, 37, [25,26,27], [32,33])

func _build_legacy_custom_walls() -> void:
	if layout_variant == "nightclub":
		# Nightclubs deliberately have few exterior windows. Narrow clerestories
		# serve the lounge/VIP areas without exposing the dance floor.
		_build_boundary(_get_exterior_wall_tile(), [14,15,33,34], [4,5])
	else:
		_build_boundary(_get_exterior_wall_tile(), [20,21,22,23,24,25], [11,12,13,14,15])
	match layout_variant:
		"nightclub":
			# West guest-service spine: toilets above, security/coat check below.
			_wall_v(12, 2, 25, [19,20,21])
			_wall_h(17, 2, 11, [6,7,8])
			# A shallow north band holds lounge, DJ and VIP functions while leaving
			# broad thresholds onto the public floor.
			_wall_h(6, 13, 45, [15,16,17,22,23,24,32,33,34])
			_wall_v(18, 2, 6, [3,4,5])
			_wall_v(31, 2, 6, [3,4,5])
			# The bar has customer access from the floor and a separate back-bar
			# route. Staff never need to cross the central dance area.
			_wall_v(36, 7, 25, [12,13,14,22,23,24])
			_wall_h(21, 37, 45, [40,41,42])
			# Wide foyer-to-floor opening supports entry flow and combat retreat.
			# Leave a two-cell turning pocket beside the coat-check doorway; this is
			# both believable queue space and enough clearance for the actor capsule.
			_wall_h(21, 15, 35, [21,22,23,24,25,26,27])
		"sandwich_shop":
			_wall_h(14, 2, 45, [7,8,9,22,23,24,39,40,41], [15,16,33,34])
			_wall_v(18, 2, 13, [6,7,8], [10,11])
			_wall_v(32, 2, 13, [4,5,6], [9,10])
			_wall_v(14, 15, 25, [19,20,21])
			_wall_v(35, 15, 25, [18,19,20], [23,24])
		"tactical_lab":
			_wall_v(20, 2, map_size.y - 3, [5,6,7,23,24], [14,15,30,31])
			_wall_v(42, 2, map_size.y - 3, [4,5,6,20,21,30,31], [12,13,26,27])
			_wall_h(18, 21, 41, [30, 31], [35, 36])
			_wall_h(12, 2, 19, [9, 10], [14, 15])
			_wall_h(8, 21, 41, [29,30,31], [36,37])
			if map_size.y > DEFAULT_MAP_SIZE.y:
				_wall_h(26, 21, 41, [31, 32], [36, 37])
			_wall_h(16, 43, map_size.x - 3, [52, 53], [58, 59])
			if map_size.x > DEFAULT_MAP_SIZE.x:
				_wall_v(53, 17, map_size.y - 3, [24,25,26], [30,31])
		"harbor_exchange":
			_wall_v(14, 2, 25, [5,6,7,19,20,21], [3,4])
			_wall_v(34, 2, 25, [10,11,12,21,22,23], [6,7,17,18])
			_wall_h(14, 2, 45, [8,9,10,24,25,26,40,41,42], [29,30])
			_wall_h(8, 2, 13, [6,7,8])
			_wall_h(10, 15, 33, [23,24,25])
			_wall_h(18, 35, 45, [39,40,41])
		"motel_witness":
			_wall_h(10, 2, 45, [5,6,7,17,18,19,29,30,31,41,42,43], [13,14,25,26,37,38])
			_wall_h(17, 2, 45, [5,6,7,17,18,19,29,30,31,40,41,42], [10,11,22,23,34,35])
			for x: int in [12, 24, 36]: _wall_v(x, 2, 9, [], [], Tile.WALL)
			for x: int in [12, 24, 36]: _wall_v(x, 18, 25, [], [], Tile.WALL)
			for x0: int in [2,14,26,38]: _wall_h(6, x0, mini(45, x0 + 9), [x0 + 6, x0 + 7])
			for x0: int in [2,14,26,38]: _wall_h(22, x0, mini(45, x0 + 9), [x0 + 2, x0 + 3])
		"penthouse":
			_wall_v(24, 2, 25, [8,9,10,19,20,21], [4,5,13,14])
			_wall_h(13, 25, 45, [34,35,36], [28,29,40,41])
			_wall_h(16, 2, 23, [13,14,15], [17,18])
			_wall_v(10, 2, 15, [6,7,8], [12,13])
			_wall_v(37, 2, 12, [7,8,9])
			_wall_h(21, 25, 45, [29,30,31], [40,41])
		"cold_storage":
			_wall_v(15, 2, 25, [6,7,8,22,23,24], [11,12])
			_wall_v(32, 2, 25, [12,13,14,21,22,23], [5,6,18,19])
			_wall_h(13, 2, 14, [8,9,10], [], Tile.WALL)
			_wall_h(10, 16, 31, [22,23,24], [27,28])
			_wall_h(20, 16, 31, [24,25,26], [], Tile.WALL)
			_wall_h(17, 33, 45, [39,40,41], [], Tile.WALL)
		"casino_floor":
			_wall_v(10, 2, 25, [4,5,6,20,21,22], [12,13,14])
			_wall_v(38, 2, 25, [6,7,8,18,19,20], [10,11,12,13])
			_wall_h(17, 11, 37, [20,21,22], [16,17,32,33])
			_wall_h(9, 11, 37, [22,23,24], [14,15,33,34])
			_wall_v(24, 10, 16, [11,12,13])
			_wall_v(29, 18, 25, [21,22,23])
		"police_archive":
			_wall_v(16, 2, 25, [6,7,8,19,20,21], [11,12,13])
			_wall_v(32, 2, 25, [12,13,14,22,23,24], [5,6,17,18])
			_wall_h(14, 2, 15, [8,9,10], [], Tile.WALL)
			_wall_h(9, 17, 31, [22,23,24], [27,28])
			_wall_h(17, 17, 31, [24,25,26], [], Tile.WALL)
			_wall_h(11, 33, 45, [38,39,40], [42,43])
			_wall_h(20, 33, 45, [39,40,41], [], Tile.WALL)
		"slaughterhouse":
			_wall_h(9, 2, 45, [8,9,10,22,23,24,39,40,41], [14,15,32,33])
			_wall_h(18, 2, 45, [5,6,7,19,20,21,35,36,37], [11,12,28,29])
			_wall_v(24, 10, 17, [13,14,15], [], Tile.WALL)
			_wall_v(12, 2, 8, [5,6,7])
			_wall_v(36, 2, 8, [4,5,6])
			_wall_v(14, 19, 25, [21,22,23])
			_wall_v(34, 19, 25, [21,22,23])
		"broadcast_tower":
			_wall_v(11, 2, 25, [8,9,10,20,21,22], [13,14,15])
			_wall_v(36, 2, 25, [6,7,8,18,19,20], [11,12,13,14])
			_wall_h(7, 12, 35, [22,23,24], [15,16,31,32])
			_wall_h(21, 12, 35, [27,28,29], [18,19])
			_wall_v(24, 8, 20, [11,12,13], [17,18])
			_wall_h(15, 25, 35, [29,30,31])
		"last_call":
			_wall_v(14, 2, 25, [4,5,6,19,20,21], [11,12])
			_wall_v(36, 2, 25, [5,6,7,17,18,19], [10,11,22,23])
			_wall_h(15, 15, 35, [24,25,26], [18,19,31,32])
			_wall_h(9, 15, 35, [21,22,23], [17,18,32,33])
			_wall_v(25, 2, 8, [4,5,6])
			_wall_h(20, 2, 13, [6,7,8])
			_wall_h(21, 37, 45, [40,41,42])

func _get_exterior_wall_tile() -> Tile:
	if layout_variant in ["harbor_exchange", "cold_storage", "police_archive", "slaughterhouse"]: return Tile.SERVICE_WALL
	if layout_variant in ["nightclub", "casino_floor", "broadcast_tower", "last_call"]: return Tile.DARK_WALL
	return Tile.BRIGHT_WALL

func _get_partition_wall_tile() -> Tile:
	if layout_variant in ["nightclub", "harbor_exchange", "casino_floor", "broadcast_tower", "last_call"]: return Tile.DARK_WALL
	if layout_variant in ["sandwich_shop", "tactical_lab", "cold_storage", "police_archive", "slaughterhouse"]: return Tile.SERVICE_WALL
	return Tile.BRIGHT_WALL

func _expand_authored_door_openings() -> void:
	# Layouts were originally authored around 16px leaves. Expand each interior
	# threshold by one wall cell before caps, shadows and navigation are built, so
	# the 24px visual, collision and path opening remain one geometry.
	for entry: Array in _get_authored_door_entries():
		var opening_cell: Vector2i = entry[0] + building_origin
		var horizontal_leaf := absf(float(entry[1])) > 0.1
		var leaf_step := Vector2i.RIGHT if horizontal_leaf else Vector2i.DOWN
		for leaf_index in range(DOOR_CELL_SPAN):
			wall_layer.erase_cell(opening_cell + leaf_step * leaf_index)

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
		if layout_variant != "nightclub" and x % 4 == 0: _set_tile(decoration_layer, Vector2i(x, stripe_y), accent)
	if layout_variant in ["penthouse", "broadcast_tower"]:
		for x in range(40, 44):
			for y in range(21, 24): _set_tile(decoration_layer, Vector2i(x, y), Tile.STAIRS)
	match layout_variant:
		"nightclub":
			# Restrained practical detail: light markers describe circulation while
			# cables, glass and service grime tell the story at native pixel scale.
			_place_decor([Vector2i(21,23), Vector2i(26,23), Vector2i(10,20)], Tile.NEON_ARROW)
			_place_decor([Vector2i(20,5), Vector2i(29,5), Vector2i(34,18)], Tile.CABLE)
			_place_decor([Vector2i(15,9), Vector2i(33,10), Vector2i(42,13)], Tile.GLASS_BITS)
			_place_decor([Vector2i(40,23), Vector2i(44,18)], Tile.GRIME)
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

func _place_decor(cells: Array[Vector2i], tile: Tile) -> void:
	for cell: Vector2i in cells:
		if cell.x <= 1 or cell.y <= 1 or cell.x >= map_size.x - 1 or cell.y >= map_size.y - 1: continue
		if wall_layer.get_cell_source_id(cell + building_origin) < 0: _set_tile(decoration_layer, cell, tile)

func _place_objects(cells: Array[Vector2i], tile: Tile) -> void:
	for cell: Vector2i in cells:
		# If the authored anchor conflicts with a door or fixed pickup, retain the
		# prop by sliding it to the first nearby legal perimeter cell. Silently
		# deleting it made destruction density depend on the random seed.
		var placed := false
		for offset in [Vector2i.ZERO, Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(2,0), Vector2i(-2,0), Vector2i(0,2), Vector2i(0,-2)]:
			var candidate: Vector2i = cell + (offset as Vector2i)
			if candidate.x <= 1 or candidate.y <= 1 or candidate.x >= map_size.x - 1 or candidate.y >= map_size.y - 1: continue
			if _is_authored_door_clearance_cell(candidate) or _is_critical_interaction_clearance_cell(candidate): continue
			var world_cell: Vector2i = candidate + building_origin
			if wall_layer.get_cell_source_id(world_cell) >= 0 or object_layer.get_cell_source_id(world_cell) >= 0: continue
			_set_tile(object_layer, candidate, tile)
			placed = true
			break

func _is_critical_interaction_clearance_cell(cell: Vector2i) -> bool:
	# Ammo and other fixed interactables live in the level resource rather than
	# this generated TileWorld. Mirror those authored cells here so shuffled
	# cover can never occupy their approach square.
	var ammo_pixels := {
		"nightclub": [Vector2(116,92),Vector2(220,116),Vector2(324,116),Vector2(324,188)],
		"sandwich_shop": [Vector2(92,84),Vector2(204,84),Vector2(284,196),Vector2(348,196)],
		"tactical_lab": [Vector2(116,120),Vector2(264,120),Vector2(318,188),Vector2(420,120),Vector2(448,240),Vector2(100,116),Vector2(236,124),Vector2(316,164),Vector2(364,116)],
		"harbor_exchange": [Vector2(52,92),Vector2(188,76),Vector2(292,116),Vector2(348,196)],
		"motel_witness": [Vector2(52,108),Vector2(164,108),Vector2(276,108),Vector2(348,204)],
		"penthouse": [Vector2(60,116),Vector2(172,76),Vector2(284,116),Vector2(348,188)],
		"cold_storage": [Vector2(52,92),Vector2(188,92),Vector2(284,116),Vector2(348,196)],
		"casino_floor": [Vector2(60,108),Vector2(156,188),Vector2(276,188),Vector2(348,108)],
		"police_archive": [Vector2(60,108),Vector2(180,76),Vector2(276,164),Vector2(348,108)],
		"slaughterhouse": [Vector2(60,76),Vector2(180,116),Vector2(284,116),Vector2(348,188)],
		"broadcast_tower": [Vector2(60,116),Vector2(156,180),Vector2(276,76),Vector2(348,188)],
		"last_call": [Vector2(60,108),Vector2(172,188),Vector2(276,108),Vector2(348,188)],
	}
	for pixel: Vector2 in ammo_pixels.get(layout_variant, []):
		var anchor := Vector2i(floori(pixel.x / float(TILE_SIZE.x)), floori(pixel.y / float(TILE_SIZE.y)))
		if maxi(absi(cell.x - anchor.x), absi(cell.y - anchor.y)) <= 1: return true
	return false

func _is_authored_door_clearance_cell(cell: Vector2i) -> bool:
	for entry: Array in _get_authored_door_entries():
		var opening: Vector2i = entry[0]
		var horizontal_leaf := absf(float(entry[1])) > 0.1
		var leaf_step := Vector2i.RIGHT if horizontal_leaf else Vector2i.DOWN
		for leaf_index in range(DOOR_CELL_SPAN):
			var leaf_cell := opening + leaf_step * leaf_index
			if maxi(absi(cell.x - leaf_cell.x), absi(cell.y - leaf_cell.y)) <= 2:
				return true
	return false

func _build_custom_objects() -> void:
	# Cover is authored in the same module as the enemy composition. This avoids
	# accidental cover/spawn contradictions and gives each shuffled chamber a
	# recognizable tactical identity rather than a new cloud of random furniture.
	var venue_props := {
		"nightclub": [Tile.SOFA, Tile.TABLE, Tile.TV],
		"sandwich_shop": [Tile.TABLE, Tile.VENDING, Tile.SINK],
		"tactical_lab": [Tile.TABLE, Tile.TV, Tile.VENDING],
		"harbor_exchange": [Tile.TABLE, Tile.VENDING, Tile.PLANT],
		"motel_witness": [Tile.BED, Tile.TABLE, Tile.TV],
		"penthouse": [Tile.SOFA, Tile.TABLE, Tile.PLANT],
		"cold_storage": [Tile.TABLE, Tile.VENDING, Tile.SINK],
		"casino_floor": [Tile.TABLE, Tile.SOFA, Tile.VENDING],
		"police_archive": [Tile.TABLE, Tile.TV, Tile.VENDING],
		"slaughterhouse": [Tile.TABLE, Tile.SINK, Tile.VENDING],
		"broadcast_tower": [Tile.TABLE, Tile.TV, Tile.SOFA],
		"last_call": [Tile.SOFA, Tile.TABLE, Tile.TV],
	}
	var props: Array = venue_props.get(layout_variant, [Tile.TABLE, Tile.SOFA])
	var seed_value := _get_room_run_seed()
	var rooms := get_architectural_rooms()
	var assignments: Array[Dictionary] = HANDCRAFTED_ROOMS.get_assignments(seed_value, rooms.size())
	for room_index in range(rooms.size()):
		var room: Dictionary = rooms[room_index]
		var rect: Rect2i = room.rect
		var prop_anchors: Array = assignments[room_index].props
		# Two or three small destructible anchors leave a generous central floor
		# for high-speed dodging and weapon improvisation.
		var prop_limit := mini(prop_anchors.size(), 3)
		for slot_index in range(prop_limit):
			var uv: Vector2 = prop_anchors[slot_index]
			var cell := rect.position + Vector2i(1 + roundi(uv.x * maxi(1, rect.size.x - 3)), 1 + roundi(uv.y * maxi(1, rect.size.y - 3)))
			cell = cell.clamp(rect.position + Vector2i.ONE, rect.end - Vector2i(2,2))
			_place_objects([cell], props[posmod(seed_value + room_index + slot_index, props.size())])

func _build_legacy_custom_objects() -> void:
	match layout_variant:
		"nightclub":
			_place_objects([Vector2i(15,4), Vector2i(34,4)], Tile.SOFA)
			_place_objects([Vector2i(16,10), Vector2i(29,10), Vector2i(16,17), Vector2i(29,17)], Tile.TABLE)
			_place_objects([Vector2i(4,6), Vector2i(9,6)], Tile.TOILET)
			_place_objects([Vector2i(6,13)], Tile.SINK)
			_place_objects([Vector2i(42,23)], Tile.VENDING)
			_place_objects([Vector2i(43,9)], Tile.TV)
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
	for tile_index in range(PIXEL_ENVIRONMENT_ATLAS.TILE_COUNT):
		var atlas_coordinate := Vector2i(tile_index, 0)
		atlas.create_tile(atlas_coordinate)
	tile_set.add_source(atlas, 0)
	for tile_index in [Tile.WALL, Tile.WINDOW, Tile.BRIGHT_WALL, Tile.DARK_WALL, Tile.SERVICE_WALL] if with_physics else []:
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
	layer.set_cell(cell + building_origin, 0, Vector2i(int(tile), 0), 0)

func _build_exterior() -> void:
	for y in range(world_size.y):
		for x in range(world_size.x):
			var tile := Tile.DARK_TILE if (x + y) % 2 == 0 else Tile.BLACK_PLANK
			_set_world_tile(exterior_layer, Vector2i(x, y), tile)

func _build_floor() -> void:
	_build_exterior_floor()
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
	_build_world_boundary()
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
		"nightclub": Color("a3a3a3"), "sandwich_shop": Color("b8b8b8"),
		"tactical_lab": Color("999999"), "harbor_exchange": Color("8d8d8d"),
		"motel_witness": Color("adadad"), "penthouse": Color("c1c1c1"),
		"cold_storage": Color("bdbdbd"), "casino_floor": Color("b0b0b0"),
		"police_archive": Color("989898"), "slaughterhouse": Color("939393"),
		"broadcast_tower": Color("a0a0a0"), "last_call": Color("9d9d9d"),
	}
	var tint: Color = tint_by_layout.get(layout_variant, Color("a3a3a3"))
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
		"nightclub": [["speaker", Vector2i(20,4)], ["speaker", Vector2i(29,4)], ["bar", Vector2i(41,14)]],
		"sandwich_shop": [["counter", Vector2i(25, 9)], ["freezer", Vector2i(18, 22)], ["crate", Vector2i(32, 22)]],
		"tactical_lab": [["console", Vector2i(28, 12)], ["crate", Vector2i(12, 22)], ["evidence_cabinet", Vector2i(44, 22)]],
		"harbor_exchange": [["crate", Vector2i(8, 5)], ["crate", Vector2i(40, 8)], ["shelf", Vector2i(41, 23)]],
		"motel_witness": [["counter", Vector2i(20, 13)], ["vending", Vector2i(32, 13)], ["shelf", Vector2i(42, 5)]],
		"penthouse": [["bar", Vector2i(16, 20)], ["speaker", Vector2i(29, 5)], ["evidence_cabinet", Vector2i(41, 20)]],
		"cold_storage": [["freezer", Vector2i(8, 14)], ["freezer", Vector2i(23, 14)], ["shelf", Vector2i(39, 14)]],
		"casino_floor": [["slot_machine", Vector2i(13, 7)], ["slot_machine", Vector2i(34, 7)], ["bar", Vector2i(42, 16)]],
		"police_archive": [["evidence_cabinet", Vector2i(8, 14)], ["evidence_cabinet", Vector2i(25, 10)], ["console", Vector2i(39, 14)]],
		"slaughterhouse": [["conveyor", Vector2i(12, 13)], ["conveyor", Vector2i(34, 13)], ["freezer", Vector2i(38, 21)]],
		"broadcast_tower": [["console", Vector2i(20, 13)], ["speaker", Vector2i(31, 8)], ["evidence_cabinet", Vector2i(41, 14)]],
		"last_call": [["speaker", Vector2i(19, 7)], ["speaker", Vector2i(31, 7)], ["bar", Vector2i(40, 20)]],
	}
	for entry: Array in authored.get(layout_variant, []):
		var authored_cell: Vector2i = entry[1]
		if authored_cell.x <= 1 or authored_cell.y <= 1 or authored_cell.x >= map_size.x - 1 or authored_cell.y >= map_size.y - 1: continue
		if _is_authored_door_clearance_cell(authored_cell) or _is_critical_interaction_clearance_cell(authored_cell): continue
		var cell := _authored_cell_to_world(authored_cell)
		if wall_layer.get_cell_source_id(cell) >= 0 or cell in destructible_cells: continue
		var prop := DESTRUCTIBLE_PROP.new() as DestructibleProp
		prop.position = floor_layer.map_to_local(cell)
		prop.setup(str(entry[0]), Color("a3a3a3"))
		prop.solidity_changed.connect(_on_prop_solidity_changed.bind(cell))
		add_child(prop)
		destructible_cells.append(cell)

func _ensure_minimum_destructible_props(minimum_count := 10) -> void:
	var existing := 0
	for child in get_children():
		if child is DestructibleProp: existing += 1
	if existing >= minimum_count: return
	var fallback_kinds := ["crate", "plant", "speaker", "table"]
	for room: Dictionary in get_architectural_rooms():
		var rect: Rect2i = room.rect
		for authored_cell: Vector2i in [
			rect.position + Vector2i(2, 2),
			Vector2i(rect.end.x - 3, rect.position.y + 2),
			Vector2i(rect.position.x + 2, rect.end.y - 3),
			Vector2i(rect.end.x - 3, rect.end.y - 3),
		]:
			if existing >= minimum_count: return
			if _is_authored_door_clearance_cell(authored_cell) or _is_critical_interaction_clearance_cell(authored_cell): continue
			var cell: Vector2i = _authored_cell_to_world(authored_cell)
			if wall_layer.get_cell_source_id(cell) >= 0 or cell in destructible_cells: continue
			var prop := DESTRUCTIBLE_PROP.new() as DestructibleProp
			prop.position = floor_layer.map_to_local(cell)
			prop.setup(fallback_kinds[posmod(existing, fallback_kinds.size())], Color("888888"))
			prop.solidity_changed.connect(_on_prop_solidity_changed.bind(cell))
			add_child(prop)
			destructible_cells.append(cell)
			existing += 1

func _build_path_grid() -> void:
	path_grid.region = Rect2i(Vector2i.ZERO, world_size)
	path_grid.cell_size = Vector2(TILE_SIZE)
	path_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	path_grid.update()
	for y in range(world_size.y):
		for x in range(world_size.x):
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
	for y in range(world_size.y):
		for x in range(world_size.x):
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
	from_cell = from_cell.clamp(Vector2i.ZERO, world_size - Vector2i.ONE)
	to_cell = to_cell.clamp(Vector2i.ZERO, world_size - Vector2i.ONE)
	if path_grid.is_point_solid(from_cell) or path_grid.is_point_solid(to_cell): return PackedVector2Array()
	var id_path := path_grid.get_id_path(from_cell, to_cell)
	var world_path := PackedVector2Array()
	for index in range(1, id_path.size()):
		world_path.append(floor_layer.to_global(floor_layer.map_to_local(id_path[index])))
	return world_path

func _get_authored_door_entries() -> Array:
	# Every listed threshold corresponds to a three-cell opening in the simplified
	# arena walls above. The small, stable door budget prevents maze-like plans and
	# keeps combat entrances readable at full speed.
	var authored := {
		"nightclub": [[Vector2i(13,10),0.0], [Vector2i(36,10),0.0], [Vector2i(22,20),-PI*0.5], [Vector2i(40,20),-PI*0.5]],
		"sandwich_shop": [[Vector2i(18,6),0.0], [Vector2i(7,14),-PI*0.5], [Vector2i(24,14),-PI*0.5], [Vector2i(39,14),-PI*0.5], [Vector2i(34,19),0.0]],
		"tactical_lab": [[Vector2i(18,6),0.0], [Vector2i(18,19),0.0], [Vector2i(38,6),0.0], [Vector2i(38,19),0.0], [Vector2i(27,14),-PI*0.5]],
		"harbor_exchange": [[Vector2i(14,7),0.0], [Vector2i(14,19),0.0], [Vector2i(35,7),0.0], [Vector2i(35,19),0.0], [Vector2i(23,15),-PI*0.5]],
		"motel_witness": [[Vector2i(8,10),-PI*0.5], [Vector2i(30,10),-PI*0.5], [Vector2i(8,17),-PI*0.5], [Vector2i(30,17),-PI*0.5], [Vector2i(24,5),0.0], [Vector2i(24,21),0.0]],
		"penthouse": [[Vector2i(24,7),0.0], [Vector2i(24,20),0.0], [Vector2i(10,15),-PI*0.5], [Vector2i(34,15),-PI*0.5]],
		"cold_storage": [[Vector2i(16,7),0.0], [Vector2i(16,20),0.0], [Vector2i(33,7),0.0], [Vector2i(33,20),0.0], [Vector2i(24,17),-PI*0.5]],
		"casino_floor": [[Vector2i(11,7),0.0], [Vector2i(11,20),0.0], [Vector2i(39,7),0.0], [Vector2i(39,20),0.0], [Vector2i(24,15),-PI*0.5]],
		"police_archive": [[Vector2i(15,7),0.0], [Vector2i(15,20),0.0], [Vector2i(34,7),0.0], [Vector2i(34,20),0.0], [Vector2i(24,14),-PI*0.5]],
		"slaughterhouse": [[Vector2i(8,10),-PI*0.5], [Vector2i(23,10),-PI*0.5], [Vector2i(39,10),-PI*0.5], [Vector2i(8,19),-PI*0.5], [Vector2i(23,19),-PI*0.5], [Vector2i(39,19),-PI*0.5]],
		"broadcast_tower": [[Vector2i(12,7),0.0], [Vector2i(12,20),0.0], [Vector2i(37,7),0.0], [Vector2i(37,20),0.0], [Vector2i(24,16),-PI*0.5]],
		"last_call": [[Vector2i(14,7),0.0], [Vector2i(14,20),0.0], [Vector2i(38,7),0.0], [Vector2i(38,20),0.0], [Vector2i(25,15),-PI*0.5]],
	}
	return authored.get(layout_variant, []).duplicate(true)

func _get_legacy_authored_door_entries() -> Array:
	var authored := {
		"nightclub": [[Vector2i(6,17),-PI*0.5], [Vector2i(12,19),0.0], [Vector2i(22,6),-PI*0.5], [Vector2i(32,6),-PI*0.5], [Vector2i(36,12),0.0], [Vector2i(40,21),-PI*0.5]],
		"sandwich_shop": [[Vector2i(7,14),-PI*0.5], [Vector2i(39,14),-PI*0.5], [Vector2i(18,6),0.0], [Vector2i(32,4),0.0], [Vector2i(14,19),0.0], [Vector2i(35,18),0.0]],
		"tactical_lab": [[Vector2i(20,5),0.0], [Vector2i(20,23),0.0], [Vector2i(42,4),0.0], [Vector2i(30,18),-PI*0.5], [Vector2i(9,12),-PI*0.5], [Vector2i(29,8),-PI*0.5]],
		"harbor_exchange": [[Vector2i(14,5),0.0], [Vector2i(24,14),-PI*0.5], [Vector2i(34,21),0.0], [Vector2i(6,8),-PI*0.5], [Vector2i(23,10),-PI*0.5], [Vector2i(39,18),-PI*0.5]],
		"motel_witness": [[Vector2i(5,10),-PI*0.5], [Vector2i(17,10),-PI*0.5], [Vector2i(29,10),-PI*0.5], [Vector2i(5,17),-PI*0.5], [Vector2i(17,17),-PI*0.5], [Vector2i(29,17),-PI*0.5]],
		"penthouse": [[Vector2i(24,8),0.0], [Vector2i(34,13),-PI*0.5], [Vector2i(13,16),-PI*0.5], [Vector2i(10,6),0.0], [Vector2i(37,7),0.0], [Vector2i(29,21),-PI*0.5]],
		"cold_storage": [[Vector2i(15,6),0.0], [Vector2i(32,12),0.0], [Vector2i(39,17),-PI*0.5], [Vector2i(22,10),-PI*0.5], [Vector2i(24,20),-PI*0.5], [Vector2i(15,22),0.0]],
		"casino_floor": [[Vector2i(10,4),0.0], [Vector2i(38,18),0.0], [Vector2i(20,17),-PI*0.5], [Vector2i(22,9),-PI*0.5], [Vector2i(24,11),0.0], [Vector2i(29,21),0.0]],
		"police_archive": [[Vector2i(16,19),0.0], [Vector2i(32,12),0.0], [Vector2i(24,17),-PI*0.5], [Vector2i(22,9),-PI*0.5], [Vector2i(38,11),-PI*0.5], [Vector2i(39,20),-PI*0.5]],
		"slaughterhouse": [[Vector2i(22,9),-PI*0.5], [Vector2i(19,18),-PI*0.5], [Vector2i(24,13),0.0], [Vector2i(12,5),0.0], [Vector2i(36,4),0.0], [Vector2i(34,21),0.0]],
		"broadcast_tower": [[Vector2i(11,8),0.0], [Vector2i(36,18),0.0], [Vector2i(22,7),-PI*0.5], [Vector2i(27,21),-PI*0.5], [Vector2i(24,11),0.0], [Vector2i(29,15),-PI*0.5]],
		"last_call": [[Vector2i(14,4),0.0], [Vector2i(36,17),0.0], [Vector2i(24,15),-PI*0.5], [Vector2i(21,9),-PI*0.5], [Vector2i(25,4),0.0], [Vector2i(6,20),-PI*0.5]],
	}
	return authored.get(layout_variant, []).duplicate(true)

func get_door_specs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Every venue has a public/service threshold connecting the outdoor approach
	# to the interior. It is part of the same physical door system as room doors.
	var entries: Array = _get_authored_door_entries()
	var entrance_x := _get_entrance_authored_x()
	entries.append([Vector2i(entrance_x - 2, map_size.y - 2), -PI * 0.5])
	for entry: Array in entries:
		var opening_cell: Vector2i = _door_opening_world_cell(entry[0], float(entry[1]))
		var door_rotation := float(entry[1])
		var leaf_axis := Vector2.DOWN.rotated(door_rotation)
		var first_cell_center := floor_layer.map_to_local(opening_cell)
		# Openings span three 8px cells and the scene pivots at the exact jamb edge.
		var hinge_position := first_cell_center - leaf_axis * (TILE_SIZE.y * 0.5)
		var passage_center := first_cell_center + leaf_axis * float(TILE_SIZE.y)
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
	for leaf_index in range(DOOR_CELL_SPAN):
		if not _is_bare_floor_cell(opening_cell + leaf_step * leaf_index): return false
	var negative_open := false
	var positive_open := false
	for leaf_index in range(DOOR_CELL_SPAN):
		var leaf_offset := leaf_step * leaf_index
		var negative_cell: Vector2i = opening_cell + leaf_offset - normal_step
		var positive_cell: Vector2i = opening_cell + leaf_offset + normal_step
		negative_open = negative_open or _is_bare_floor_cell(negative_cell)
		positive_open = positive_open or _is_bare_floor_cell(positive_cell)
	return negative_open and positive_open

func _is_bare_floor_cell(cell: Vector2i) -> bool:
	if eroded_cells.has(cell) and eroded_cells[cell].erosion.remaining() > 0: return false
	if cell.x < 0 or cell.y < 0 or cell.x >= world_size.x or cell.y >= world_size.y: return false
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
		var cell: Vector2i = _authored_cell_to_world(entry[0])
		if path_grid.is_in_boundsv(cell) and not path_grid.is_point_solid(cell):
			result.append({"position": floor_layer.map_to_local(cell), "rotation": float(entry[1])})
	return result

func get_light_positions() -> Array[Vector2]:
	var authored := {
		"nightclub": [Vector2(196, 36), Vector2(196, 116), Vector2(332, 112), Vector2(196, 188)],
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
	for position: Vector2 in authored.get(layout_variant, []): result.append(map_authored_position(position))
	if layout_variant == "tactical_lab" and map_size.x > DEFAULT_MAP_SIZE.x:
		for position in [Vector2(428, 60), Vector2(468, 156), Vector2(300, 252), Vector2(460, 252)]:
			result.append(map_authored_position(position))
	return result

func map_authored_position(authored_position: Vector2) -> Vector2:
	var space_scale := COMBAT_SPACE_SCALE if geometry_expanded else 1
	return authored_position * space_scale + Vector2(building_origin * TILE_SIZE)

func get_default_player_spawn() -> Vector2:
	# Spawn on the exterior approach, centred on the entrance. The main scene can
	# opt back into an authored indoor spawn for story-driven missions.
	var space_scale := COMBAT_SPACE_SCALE if geometry_expanded else 1
	var entrance_x := building_origin.x + (_get_entrance_authored_x() - 1) * space_scale + 1
	var exterior_y := mini(world_size.y - 3, building_origin.y + map_size.y * space_scale + 4)
	return floor_layer.to_global(floor_layer.map_to_local(Vector2i(entrance_x, exterior_y)))

func get_camera_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(world_size * TILE_SIZE))

func get_building_world_rect() -> Rect2:
	var space_scale := COMBAT_SPACE_SCALE if geometry_expanded else 1
	return Rect2(Vector2(building_origin * TILE_SIZE), Vector2(map_size * TILE_SIZE) * space_scale)

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
	var world_cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	var relative_cell := world_cell - building_origin
	var space_scale := COMBAT_SPACE_SCALE if geometry_expanded else 1
	var cell := Vector2i(floori(float(relative_cell.x) / space_scale), floori(float(relative_cell.y) / space_scale))
	if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
		return "exterior_approach"
	# Keep the hound teaching encounter grouped as one kitchen even though a
	# waist-height prep partition gives that space two visual work zones.
	if layout_variant == "sandwich_shop" and cell.y >= 15 and cell.x < 22:
		return "kitchen"
	for room: Dictionary in get_architectural_rooms():
		if (room.rect as Rect2i).has_point(cell): return str(room.id)
	# Cells intentionally left between room rectangles are corridors, vestibules,
	# door reveals, or shared circulation—not anonymous pieces of adjacent rooms.
	return "%s_circulation" % layout_variant

func _build_acoustic_topology() -> void:
	# Sound uses the real floor plan rather than a radius through arbitrary walls.
	# Door thresholds are temporarily treated as sealed while flood-filling; they
	# are then reintroduced as portals whose cost follows the live door state.
	acoustic_sector_by_cell.clear()
	acoustic_portals.clear()
	acoustic_sector_count = 0
	var threshold_cells: Dictionary = {}
	var door_specs: Array[Dictionary] = get_door_specs()
	for spec: Dictionary in door_specs:
		var opening_cell: Vector2i = spec.opening_cell
		var leaf_step := Vector2i.RIGHT if absf(float(spec.rotation)) > 0.1 else Vector2i.DOWN
		for leaf_index in range(DOOR_CELL_SPAN): threshold_cells[opening_cell + leaf_step * leaf_index] = true
	for y in range(world_size.y):
		for x in range(world_size.x):
			var start := Vector2i(x, y)
			if acoustic_sector_by_cell.has(start) or threshold_cells.has(start) or not _is_acoustic_floor_cell(start): continue
			var sector_id := "acoustic_%s_%02d" % [layout_variant, acoustic_sector_count]
			acoustic_sector_count += 1
			var frontier: Array[Vector2i] = [start]
			acoustic_sector_by_cell[start] = sector_id
			var cursor := 0
			while cursor < frontier.size():
				var cell := frontier[cursor]
				cursor += 1
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor: Vector2i = cell + direction
					if acoustic_sector_by_cell.has(neighbor) or threshold_cells.has(neighbor) or not _is_acoustic_floor_cell(neighbor): continue
					acoustic_sector_by_cell[neighbor] = sector_id
					frontier.append(neighbor)
	for spec: Dictionary in door_specs:
		var opening_cell: Vector2i = spec.opening_cell
		var horizontal_leaf := absf(float(spec.rotation)) > 0.1
		var leaf_step := Vector2i.RIGHT if horizontal_leaf else Vector2i.DOWN
		var normal_step := Vector2i.UP if horizontal_leaf else Vector2i.RIGHT
		var side_a := _sector_along_threshold(opening_cell, leaf_step, -normal_step)
		var side_b := _sector_along_threshold(opening_cell, leaf_step, normal_step)
		_append_acoustic_portal(side_a, side_b, "door", spec.passage_center)
	# Windows transmit sound and sight but remain physical movement barriers.
	for cell: Vector2i in wall_layer.get_used_cells():
		if wall_layer.get_cell_atlas_coords(cell).x != int(Tile.WINDOW): continue
		var above := _sector_near_cell(cell + Vector2i.UP)
		var below := _sector_near_cell(cell + Vector2i.DOWN)
		var left := _sector_near_cell(cell + Vector2i.LEFT)
		var right := _sector_near_cell(cell + Vector2i.RIGHT)
		if not above.is_empty() and not below.is_empty() and above != below:
			_append_acoustic_portal(above, below, "window", floor_layer.map_to_local(cell))
		elif not left.is_empty() and not right.is_empty() and left != right:
			_append_acoustic_portal(left, right, "window", floor_layer.map_to_local(cell))

func _is_acoustic_floor_cell(cell: Vector2i) -> bool:
	if eroded_cells.has(cell) and eroded_cells[cell].erosion.remaining() > 0: return false
	if cell.x < 0 or cell.y < 0 or cell.x >= world_size.x or cell.y >= world_size.y: return false
	return floor_layer.get_cell_source_id(cell) >= 0 and wall_layer.get_cell_source_id(cell) < 0

func _sector_along_threshold(opening_cell: Vector2i, leaf_step: Vector2i, side_step: Vector2i) -> String:
	for leaf_index in range(DOOR_CELL_SPAN):
		var sector := _sector_near_cell(opening_cell + leaf_step * leaf_index + side_step)
		if not sector.is_empty(): return sector
	return ""

func _sector_near_cell(origin: Vector2i) -> String:
	if acoustic_sector_by_cell.has(origin): return str(acoustic_sector_by_cell[origin])
	for radius in range(1, 4):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius)]:
			var candidate: Vector2i = origin + Vector2i(offset)
			if acoustic_sector_by_cell.has(candidate): return str(acoustic_sector_by_cell[candidate])
	return ""

func _append_acoustic_portal(side_a: String, side_b: String, kind: String, portal_position: Vector2) -> void:
	if side_a.is_empty() or side_b.is_empty() or side_a == side_b: return
	acoustic_portals.append({"a": side_a, "b": side_b, "kind": kind, "position": portal_position})

func get_acoustic_sector_id(world_position: Vector2) -> String:
	if acoustic_sector_by_cell.is_empty(): return ""
	var cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	return _sector_near_cell(cell)

func get_acoustic_profile() -> Dictionary:
	# Each venue changes how a familiar combat system reads: loud public spaces
	# mask sound, private rooms isolate it, and security sites coordinate harder.
	var profiles := {
		"nightclub": {"hearing_scale": 0.64, "closed_door_cost": 2.35, "open_door_cost": 0.72, "window_cost": 0.95, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "music_masking"},
		"sandwich_shop": {"hearing_scale": 0.82, "closed_door_cost": 2.45, "open_door_cost": 0.62, "window_cost": 1.00, "max_pushers": 1, "max_sweepers": 1, "incident_memory": 5.0, "identity": "service_loop"},
		"tactical_lab": {"hearing_scale": 0.92, "closed_door_cost": 2.05, "open_door_cost": 0.55, "window_cost": 0.78, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 5.5, "identity": "trained_response"},
		"harbor_exchange": {"hearing_scale": 1.02, "closed_door_cost": 2.10, "open_door_cost": 0.48, "window_cost": 0.75, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "open_air_echo"},
		"motel_witness": {"hearing_scale": 0.72, "closed_door_cost": 2.85, "open_door_cost": 0.68, "window_cost": 0.92, "max_pushers": 1, "max_sweepers": 1, "incident_memory": 5.5, "identity": "isolated_rooms"},
		"penthouse": {"hearing_scale": 0.88, "closed_door_cost": 2.30, "open_door_cost": 0.56, "window_cost": 0.52, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 5.0, "identity": "glass_crossfire"},
		"cold_storage": {"hearing_scale": 0.62, "closed_door_cost": 3.05, "open_door_cost": 0.72, "window_cost": 1.20, "max_pushers": 1, "max_sweepers": 1, "incident_memory": 5.0, "identity": "machine_masking"},
		"casino_floor": {"hearing_scale": 0.68, "closed_door_cost": 2.35, "open_door_cost": 0.62, "window_cost": 0.76, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "crowd_masking"},
		"police_archive": {"hearing_scale": 0.84, "closed_door_cost": 2.45, "open_door_cost": 0.58, "window_cost": 0.92, "max_pushers": 1, "max_sweepers": 2, "incident_memory": 6.0, "identity": "cautious_response"},
		"slaughterhouse": {"hearing_scale": 0.60, "closed_door_cost": 2.70, "open_door_cost": 0.68, "window_cost": 1.05, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "industrial_masking"},
		"broadcast_tower": {"hearing_scale": 0.90, "closed_door_cost": 2.65, "open_door_cost": 0.54, "window_cost": 0.82, "max_pushers": 1, "max_sweepers": 2, "incident_memory": 6.0, "identity": "studio_isolation"},
		"last_call": {"hearing_scale": 0.92, "closed_door_cost": 2.20, "open_door_cost": 0.52, "window_cost": 0.70, "max_pushers": 2, "max_sweepers": 2, "incident_memory": 6.0, "identity": "finale_coordination"},
	}
	return (profiles.get(layout_variant, profiles["nightclub"]) as Dictionary).duplicate(true)

func evaluate_acoustic_response(listener_position: Vector2, source_position: Vector2, radius: float, source_kind: String) -> Dictionary:
	var direct_distance := listener_position.distance_to(source_position)
	var profile := get_acoustic_profile()
	var effective_radius := radius * float(profile.get("hearing_scale", 1.0))
	if direct_distance > effective_radius: return {"eligible": false, "priority": INF, "occluded": false, "hops": 99}
	var source_sector := get_acoustic_sector_id(source_position)
	var listener_sector := get_acoustic_sector_id(listener_position)
	if source_sector.is_empty() or listener_sector.is_empty():
		return {"eligible": direct_distance <= effective_radius, "priority": direct_distance, "occluded": false, "hops": 0}
	var route := _find_acoustic_route(source_sector, listener_sector, profile)
	if route.is_empty(): return {"eligible": false, "priority": INF, "occluded": true, "hops": 99}
	var maximum_hops := _maximum_acoustic_hops(source_kind)
	var hops := int(route.get("hops", 0))
	var transmission_cost := float(route.get("cost", 0.0))
	var acoustic_distance := direct_distance + transmission_cost * 48.0
	var eligible := hops <= maximum_hops and acoustic_distance <= effective_radius
	return {
		"eligible": eligible,
		"priority": acoustic_distance,
		"occluded": hops > 0,
		"hops": hops,
		"transmission_cost": transmission_cost,
		"source_sector": source_sector,
		"listener_sector": listener_sector,
	}

func _maximum_acoustic_hops(source_kind: String) -> int:
	if source_kind in ["security_alarm", "security_camera"]: return 99
	if source_kind.contains("shotgun"): return 3
	if source_kind.contains("lmg") or source_kind.contains("smg"): return 2
	if source_kind.contains("pistol") or source_kind.contains("gunshot"): return 1
	if source_kind in ["door", "execution", "landmark_break", "corpse_disposal"]: return 1
	if source_kind.contains("radio") or source_kind == "corpse": return 2
	if source_kind in ["environment_lure", "thrown_weapon"]: return 2
	return 0

func _find_acoustic_route(source_sector: String, listener_sector: String, profile: Dictionary) -> Dictionary:
	if source_sector == listener_sector: return {"cost": 0.0, "hops": 0}
	var frontier: Array[Dictionary] = [{"sector": source_sector, "cost": 0.0, "hops": 0}]
	var best_cost := {source_sector: 0.0}
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cost) < float(b.cost))
		var current: Dictionary = frontier.pop_front()
		var current_sector := str(current.sector)
		var current_cost := float(current.cost)
		if current_sector == listener_sector: return {"cost": current_cost, "hops": int(current.hops)}
		if current_cost > float(best_cost.get(current_sector, INF)) + 0.001: continue
		for portal: Dictionary in acoustic_portals:
			var next_sector := ""
			if str(portal.a) == current_sector: next_sector = str(portal.b)
			elif str(portal.b) == current_sector: next_sector = str(portal.a)
			if next_sector.is_empty(): continue
			var next_cost := current_cost + _acoustic_portal_cost(portal, profile)
			if next_cost >= float(best_cost.get(next_sector, INF)): continue
			best_cost[next_sector] = next_cost
			frontier.append({"sector": next_sector, "cost": next_cost, "hops": int(current.hops) + 1})
	return {}

func _acoustic_portal_cost(portal: Dictionary, profile: Dictionary) -> float:
	if str(portal.kind) == "window": return float(profile.get("window_cost", 0.9))
	var portal_position: Vector2 = portal.position
	for candidate in get_tree().get_nodes_in_group("tactical_door"):
		if not candidate is Node2D or not is_instance_valid(candidate): continue
		var door := candidate as Node2D
		var center: Vector2 = door.get_acoustic_center() if door.has_method("get_acoustic_center") else door.global_position
		if center.distance_to(portal_position) > 18.0: continue
		if door.has_method("is_acoustically_open") and door.is_acoustically_open(): return float(profile.get("open_door_cost", 0.6))
		return float(profile.get("closed_door_cost", 2.4))
	return float(profile.get("closed_door_cost", 2.4))

func get_blood_surface_profile(world_position: Vector2) -> Dictionary:
	var cell := floor_layer.local_to_map(floor_layer.to_local(world_position))
	var tile_id := floor_layer.get_cell_atlas_coords(cell).x
	if tile_id in [Tile.RED_CARPET, Tile.TEAL_CARPET, Tile.GOLD_CARPET]: return {"kind": "carpet", "spread": 0.72, "darken": 0.30, "absorption": 1.5, "cleanup": 3}
	if tile_id in [Tile.WOOD, Tile.BLACK_PLANK]: return {"kind": "wood", "spread": 1.30, "darken": 0.16, "absorption": 0.75, "grain": true, "cleanup": 3}
	if tile_id in [Tile.CHECKER, Tile.BATH_TILE, Tile.CREAM, Tile.BLUE_TILE, Tile.WHITE_TILE, Tile.MOSAIC, Tile.TERRAZZO]: return {"kind": "tile", "spread": 0.92, "darken": 0.0, "absorption": 0.45, "gloss": 0.42, "cleanup": 2}
	if tile_id == Tile.RUBBER_GRID: return {"kind": "rubber", "spread": 0.78, "darken": 0.18, "absorption": 0.62, "cleanup": 2}
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
		# A solid wall beside a window must chip itself, not shatter the neighbor.
		if wall_layer.get_cell_source_id(cell) >= 0: return false
		var found := false
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + Vector2i(offset)
			if wall_layer.get_cell_atlas_coords(neighbor).x == Tile.WINDOW:
				cell = neighbor
				found = true
				break
		if not found: return false
	# Windows are duplicated into WallCaps to create the pseudo-3D top edge.
	# Removing only the collision tile leaves that duplicate looking like an
	# intact pane even though shards have spawned and the opening is passable.
	# Clear every presentation layer together so visual and physical state can
	# never disagree.
	_erase_glass_cell(cell)
	path_grid.set_point_solid(cell, false)
	var shards = GLASS_SHARDS_SCENE.instantiate()
	var effect_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if RuntimeBudget.try_add("debris", shards, effect_parent):
		shards.global_position = hit_position
		shards.setup(flight_direction)
	Events.glass_shattered.emit(hit_position)
	return true

func _erase_glass_cell(cell: Vector2i) -> void:
	wall_layer.erase_cell(cell)
	wall_cap_layer.erase_cell(cell)
	# Windows are currently excluded from this layer, but clearing it here is
	# deliberately defensive if the wall-shadow presentation changes later.
	wall_shadow_layer.erase_cell(cell)
	# The continuous presentation must expose the same broken pane as collision.
	_build_wall_detail_canvas()
