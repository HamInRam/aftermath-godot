extends Node2D
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void: call_deferred("run")
func run() -> void:
	check(EnemyCatalog.get_profile("bleeder").max_health == 12, "fragile bleeder profile")
	for file in DirAccess.get_files_at("res://scenes/levels"):
		if not file.ends_with(".tscn"): continue
		var scene = load("res://scenes/levels/" + file).instantiate()
		var world = scene.get_node("TileMap")
		scene.remove_child(world)
		scene.free()
		add_child(world)
		var base: Dictionary = world.get_handcrafted_encounter_layout()
		var layout := SwarmLayout.build(world,base)
		check(layout.spawns.size() == SwarmLayout.target_count(base) and layout.spawns.size() >= 18 and layout.spawns.size() <= 24, file + " bounded room-paced population")
		check(layout == SwarmLayout.build(world,base), file + " deterministic retry")
		for seed_value in [1, 9917, 314159]:
			var variant := base.duplicate(true)
			variant.seed = seed_value
			check(SwarmLayout.build(world,variant).spawns.size() == SwarmLayout.target_count(variant), file + " alternate population seeds")
		var actors := Node2D.new()
		add_child(actors)
		var start := Vector2i(world.get_nearest_walkable_position(world.get_default_player_spawn(),8) / 8.0)
		var reachable: Array[Vector2i] = []
		for index in layout.spawns.size():
			var actor := Node2D.new()
			actors.add_child(actor)
			actor.global_position = world.get_nearest_walkable_position(world.map_authored_position(layout.spawns[index]),8)
			var cell := Vector2i(actor.global_position / 8.0)
			if not world.path_grid.get_id_path(start,cell).is_empty(): reachable.append(cell)
			if index >= base.spawns.size():
				check(SwarmLayout.clear_cell(world,cell), file + " clear new spawn")
				check(actor.global_position.distance_to(world.get_default_player_spawn()) >= 80, "spawn safety")
				for other in actors.get_children():
					if other != actor: check(actor.global_position.distance_to(other.global_position) >= 16, "resolved spawns remain separated")
		var added := SwarmLayout.add_clutter(world,actors,int(base.seed))
		check(added <= 12 and added <= world.get_architectural_rooms().size() * 2, file + " restrained perimeter dressing")
		var counts: Dictionary = {}
		for prop in world.get_children():
			if not prop.get_meta("swarm_clutter", false): continue
			var room_id: String = world.get_tactical_room_id(prop.global_position)
			counts[room_id] = int(counts.get(room_id, 0)) + 1
			check(counts[room_id] <= 2, "no tactical room receives more than two extra props")
		for cell in reachable: check(not world.path_grid.get_id_path(start,cell).is_empty(), file + " preserves path to actor")
		print("SWARM_VENUE ", file, " enemies=",layout.spawns.size(), " clutter=",added," reachable=",reachable.size())
		actors.queue_free()
		world.queue_free()
		await get_tree().process_frame
	print("SWARM_LAYOUT_OK" if failures == 0 else "SWARM_LAYOUT_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
