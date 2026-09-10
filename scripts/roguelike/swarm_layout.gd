class_name SwarmLayout
extends RefCounted

static func target_count(base: Dictionary) -> int:
	# Add a small supporting group, not a floor-wide horde. Authored module
	# populations remain the primary encounter composition.
	return clampi((base.spawns as PackedVector2Array).size() + 4, 18, 24)

static func build(world: Node, base: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	var target := target_count(base)
	var spawns: PackedVector2Array = result.spawns
	var patrols: PackedVector2Array = result.patrols
	var types: PackedStringArray = result.types
	var occupied := PackedVector2Array()
	for point in spawns: occupied.append(world.map_authored_position(point))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.seed) + 71039
	var buckets: Array = []
	var doors: Array = world.get_door_specs()
	var origin: Vector2 = world.map_authored_position(Vector2.ZERO)
	var scale_factor: float = world.map_authored_position(Vector2.RIGHT).x - origin.x
	for room: Dictionary in world.get_architectural_rooms():
		var rect: Rect2i = room.rect
		var points: Array[Vector2] = []
		var start: Vector2i = Vector2i(world.map_authored_position(Vector2(rect.position * 8)) / 8.0)
		var end: Vector2i = Vector2i(world.map_authored_position(Vector2(rect.end * 8)) / 8.0)
		for y in range(start.y + 2, end.y - 2, 2):
			for x in range(start.x + 2, end.x - 2, 2):
				var cell := Vector2i(x,y)
				var point := Vector2(cell * 8) + Vector2(4,4)
				if clear_cell(world, cell) and point.distance_to(world.get_default_player_spawn()) >= 80.0 and clear_doors(world, point, doors): points.append(point)
		for i in range(points.size() - 1, 0, -1):
			var j := rng.randi_range(0,i)
			var temp := points[i]
			points[i] = points[j]
			points[j] = temp
		buckets.append(points)
	var progress := true
	while spawns.size() < target and progress:
		progress = false
		for bucket: Array in buckets:
			while not bucket.is_empty() and spawns.size() < target:
				var point: Vector2 = bucket.pop_back()
				var safe := true
				for other in occupied:
					if point.distance_squared_to(other) < 20.0 * 20.0: safe = false; break
				if not safe: continue
				occupied.append(point)
				spawns.append((point - origin) / scale_factor)
				patrols.append(Vector2.RIGHT.rotated(rng.randf() * TAU) * 40.0)
				types.append("bleeder")
				progress = true
				break
	result.spawns = spawns
	result.patrols = patrols
	result.types = types
	return result

static func clear_cell(world: Node, cell: Vector2i) -> bool:
	for y in range(-1,2):
		for x in range(-1,2):
			var p := cell + Vector2i(x,y)
			if not world.path_grid.is_in_boundsv(p) or world.path_grid.is_point_solid(p): return false
	return true

static func clear_doors(_world: Node, point: Vector2, doors: Array) -> bool:
	if _world.has_method("breach_clearance") and not _world.breach_clearance(point): return false
	for door: Dictionary in doors:
		if point.distance_to(door.passage_center) < 32.0: return false
	return true

static func add_clutter(world: Node, actors: Node, seed_value: int) -> int:
	# Preserve a five-cell-wide navigation spine to every living spawn. The
	# random fill can change tactics, never remove the pre-existing routes.
	var protected: Dictionary = {}
	var start := Vector2i(world.get_nearest_walkable_position(world.get_default_player_spawn(), 8) / 8.0)
	for actor in actors.get_children():
		var end := Vector2i(actor.global_position / 8.0)
		if not world.path_grid.is_in_boundsv(end) or world.path_grid.is_point_solid(end): continue
		for p in world.path_grid.get_id_path(start,end):
			for y in range(-2,3):
				for x in range(-2,3): protected[p + Vector2i(x,y)] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 18977
	var count := 0
	var room_counts: Dictionary = {}
	var rooms: Array = world.get_architectural_rooms()
	var furniture: Array = {
		"nightclub": ["speaker", "table"], "sandwich_shop": ["table", "crate"],
		"motel_witness": ["table", "paper_stack"], "police_archive": ["paper_stack", "crate"],
		"broadcast_tower": ["speaker", "paper_stack"], "casino_floor": ["table", "paper_stack"],
	}.get(str(world.layout_variant), ["crate", "table"])
	var doors: Array = world.get_door_specs()
	var region: Rect2i = world.path_grid.region
	for attempt in range(2400):
		if count >= mini(12, rooms.size() * 2): break
		var cell := Vector2i(rng.randi_range(2,region.end.x-3), rng.randi_range(2,region.end.y-3))
		var point := Vector2(cell * 8) + Vector2(4,4)
		if protected.has(cell) or not clear_cell(world,cell) or not clear_doors(world,point,doors): continue
		var id := str(world.get_tactical_room_id(point))
		if id == "exterior_approach" or id.ends_with("circulation"): continue
		if int(room_counts.get(id, 0)) >= 2: continue
		# Dress the perimeter rather than scattering obstructions across the
		# aiming lanes. Keep the middle of each authored chamber open.
		var near_perimeter := false
		for room: Dictionary in rooms:
			var rect: Rect2i = room.rect
			var bounds := Rect2(world.map_authored_position(Vector2(rect.position * 8)), Vector2.ZERO)
			bounds.end = world.map_authored_position(Vector2(rect.end * 8))
			if not bounds.has_point(point): continue
			var edge_distance := minf(minf(point.x - bounds.position.x, bounds.end.x - point.x), minf(point.y - bounds.position.y, bounds.end.y - point.y))
			near_perimeter = edge_distance <= 32.0
			break
		if not near_perimeter: continue
		var safe := true
		for actor in actors.get_children():
			if point.distance_to(actor.global_position) < 26.0: safe = false; break
		if not safe: continue
		var prop := DestructibleProp.new()
		prop.setup(furniture[count % furniture.size()])
		prop.position = point
		prop.set_meta("swarm_clutter", true)
		world.add_child(prop)
		world.path_grid.set_point_solid(cell,true)
		world.destructible_cells.append(cell)
		prop.solidity_changed.connect(world._on_prop_solidity_changed.bind(cell))
		count += 1
		room_counts[id] = int(room_counts.get(id, 0)) + 1
	return count
