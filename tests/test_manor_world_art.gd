extends Node2D

## Focused world fixture: no Main, enemies, HUD or live run is started.
const VENUES := ["nightclub","sandwich_shop","tactical_lab","harbor_exchange","motel_witness","penthouse","cold_storage","casino_floor","police_archive","slaughterhouse","broadcast_tower","last_call"]
const LAYERS := ["ExteriorBackdrop","Floor","Walls","WallCaps","WallShadows","Decoration","ObjectShadows","Objects"]
var failures := 0
var layouts_checked := 0
var modules_seen := {}

func _ready() -> void:
	var atlas := PixelEnvironmentAtlas.create_texture().get_image()
	_expect(atlas.get_size() == Vector2i(320,8), "atlas must retain native tile geometry")
	_expect(_neutral(atlas), "atlas source pixels must already be grayscale")
	_expect(HandcraftedRoomCatalog.validate_catalog().is_empty(), "100 authored formations must remain valid")
	_test_material_fields()
	for venue: String in VENUES:
		var world := TileWorld.new()
		world.layout_id = venue
		world.room_run_seed_override = 1701
		for layer_name: String in LAYERS:
			var layer := TileMapLayer.new()
			layer.name = layer_name
			world.add_child(layer)
		add_child(world)
		_expect(world.get_building_world_rect().size == Vector2(768,448), "%s geometry cannot change with art" % venue)
		_expect(world.scale == Vector2.ONE and TileWorld.DOOR_CELL_SPAN * TileWorld.TILE_SIZE.x == 24, "%s keeps native scale and 24px doors" % venue)
		_expect(is_instance_valid(world.wall_detail_sprite) and world.wall_detail_sprite.visible, "%s must use connected wall artwork" % venue)
		_expect(not world.wall_cap_layer.visible, "%s legacy cap may not cover connected artwork" % venue)
		var floor_image := world.material_detail_sprite.texture.get_image()
		var wall_image := world.wall_detail_sprite.texture.get_image()
		_expect(_neutral(floor_image) and _neutral(wall_image), "%s canvas source must have no chromatic pixels" % venue)
		var spawn := world.get_default_player_spawn()
		for room: Dictionary in world.get_combat_space_profile().rooms:
			var center := world.get_nearest_walkable_position((room.bounds as Rect2).get_center(), 12)
			_expect(not world.get_navigation_path(spawn,center).is_empty(), "%s room %s must connect to arrival" % [venue,room.id])
		for spec: Dictionary in world.get_door_specs():
			var step := Vector2i.DOWN if absf(float(spec.rotation)) < 0.1 else Vector2i.RIGHT
			for index in 3:
				var cell: Vector2i = spec.opening_cell + step * index
				_expect(not world.path_grid.is_point_solid(cell), "%s all door cells remain open" % venue)
				_expect(wall_image.get_pixelv(cell*8+Vector2i(4,4)).a == 0.0, "%s wall drawing cannot visually seal a door" % venue)
		for seed_value in range(48):
			world.room_run_seed_override = seed_value * 109 + 17
			var formation := world.get_handcrafted_encounter_layout()
			for id: String in formation.modules: modules_seen[id.get_slice(":",0)] = true
			for anchor: Vector2 in formation.spawns:
				var point := world.get_nearest_walkable_position(world.map_authored_position(anchor), 3)
				_expect(not world.get_navigation_path(spawn,point).is_empty(), "%s seed %d formation must remain reachable" % [venue,seed_value])
			layouts_checked += 1
		if venue == "nightclub":
			var composite := Image.create(floor_image.get_width(),floor_image.get_height(),false,Image.FORMAT_RGBA8)
			composite.fill(Color("363636"))
			composite.blend_rect(floor_image,Rect2i(Vector2i.ZERO,floor_image.get_size()),Vector2i.ZERO)
			composite.blend_rect(wall_image,Rect2i(Vector2i.ZERO,wall_image.get_size()),Vector2i.ZERO)
			composite.save_png("/tmp/aftermath-manor-world.png")
			for cell: Vector2i in world.wall_layer.get_used_cells():
				if world.wall_layer.get_cell_atlas_coords(cell).x != TileWorld.Tile.WINDOW: continue
				world._erase_glass_cell(cell)
				_expect(world.wall_detail_sprite.texture.get_image().get_pixelv(cell*8+Vector2i(4,4)).a == 0.0, "broken window must disappear from the live wall canvas")
				break
		world.queue_free()
		await get_tree().process_frame
		print("manor world: %s checked" % venue)
	_expect(modules_seen.size() == 100, "seed coverage must include all 100 authored room formations")
	PixelEnvironmentAtlas.clear_cache()
	if failures == 0: print("manor world art regression: PASS (12 venues, %d seed layouts, %d formations)" % [layouts_checked,modules_seen.size()])
	get_tree().quit(failures)

func _test_material_fields() -> void:
	var signatures := {}
	for id in [0,1,2,5,9,11,13,32,35,36,37]:
		var cells := {}
		for y in 8:
			for x in 12: cells[Vector2i(x,y)] = id
		var image := PixelMaterialCanvas.create_texture(Vector2i(12,8),Vector2i(8,8),cells,19).get_image()
		var equal_neighbors := 0
		var comparisons := 0
		var mean := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x,y)
				mean += color.r
				if x < image.get_width()-1:
					equal_neighbors += int(color == image.get_pixel(x+1,y))
					comparisons += 1
		_expect(float(equal_neighbors)/comparisons > 0.80, "material %d must keep broad quiet fields" % id)
		_expect(mean/float(image.get_width()*image.get_height()) > 0.49, "material %d must keep readable floor luminance" % id)
		signatures[hash(image.get_data())] = true
	_expect(signatures.size() == 11, "wood, stone, fabric, brick and metal must have distinct native patterns")
	var walls := {}
	for y in 2:
		for x in 5: walls[Vector2i(x,y)] = 15
	var wall_image := PixelMaterialCanvas.create_wall_texture(Vector2i(5,2),Vector2i(8,8),walls).get_image()
	_expect(wall_image.get_pixel(20,0).r > 0.9, "wall exterior needs pale limestone coping")
	_expect(wall_image.get_pixel(20,7).r < 0.1, "connected walls need a black structural core")
	_expect(wall_image.get_pixel(7,7) == wall_image.get_pixel(8,7), "adjacent wall tiles cannot create an 8px repeated cap seam")

func _neutral(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x,y)
			if c.a > 0.0 and (absf(c.r-c.g) > 0.002 or absf(c.g-c.b) > 0.002): return false
	return true

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
