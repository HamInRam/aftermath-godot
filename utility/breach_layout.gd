class_name BreachLayout
extends RefCounted

static func install(world: Node) -> void:
	var choices: Array[Dictionary] = []
	var doors: Array = world.get_door_specs()
	for cell: Vector2i in world.wall_layer.get_used_cells():
		for normal in [Vector2i.RIGHT,Vector2i.DOWN]:
			var tangent: Vector2i = Vector2i(normal.y,normal.x)
			var occupied: Array[Vector2i] = []
			var valid := true
			for depth in range(2):
				for width in range(3):
					var p: Vector2i = cell + normal * depth + tangent * width
					if world.wall_layer.get_cell_source_id(p) < 0 or world.wall_layer.get_cell_atlas_coords(p).x == world.Tile.WINDOW: valid = false
					occupied.append(p)
			if not valid: continue
			var a: Vector2i = cell - normal * 2 + tangent
			var b: Vector2i = cell + normal * 3 + tangent
			if not SwarmLayout.clear_cell(world,a) or not SwarmLayout.clear_cell(world,b): continue
			var pa := Vector2(a*8)+Vector2(4,4)
			var pb := Vector2(b*8)+Vector2(4,4)
			if str(world.get_tactical_room_id(pa)) == "exterior_approach" or str(world.get_tactical_room_id(pb)) == "exterior_approach": continue
			var center := (pa+pb)*.5
			if not SwarmLayout.clear_doors(world,center,doors): continue
			var detour: PackedVector2Array = world.path_grid.get_point_path(a,b)
			if detour.size() < 9: continue
			choices.append({"cell":cell,"cells":occupied,"size":Vector2i(2,3) if normal == Vector2i.RIGHT else Vector2i(3,2),"a":pa,"b":pb,"center":center})
	var rng := RandomNumberGenerator.new()
	rng.seed = world._get_room_run_seed() + 8841
	while not choices.is_empty() and world.breach_panels.size() < 2:
		var candidate: Dictionary = choices.pop_at(rng.randi_range(0,choices.size()-1))
		var separated := true
		for panel in world.breach_panels:
			if panel.global_position.distance_to(candidate.center) < 96: separated = false
		if not separated: continue
		var panel := BreachPanel.new()
		panel.position = Vector2(candidate.cell*8)
		world.add_child(panel)
		panel.setup(world,candidate.cells,candidate.size*8)
		panel.approach_a = candidate.a
		panel.approach_b = candidate.b
		world.breach_panels.append(panel)
		for p: Vector2i in candidate.cells:
			world.breach_cells[p] = panel
			world.wall_layer.erase_cell(p)
			world.wall_cap_layer.erase_cell(p)
			world.wall_shadow_layer.erase_cell(p)
			if world.floor_layer.get_cell_source_id(p) < 0: world._set_tile(world.floor_layer,p,world.Tile.CONCRETE)
	if not world.breach_panels.is_empty():
		world._build_material_detail_canvas()
		world._build_wall_detail_canvas()
		world._queue_erosion_topology()
