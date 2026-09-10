extends Node
func _ready() -> void:
	var level = preload("res://scenes/levels/after_hours.tscn").instantiate()
	level.record_progress = false
	add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	var enemies: Array[Node] = level.enemies_container.get_children()
	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy.room_combat_active = false
		enemy.path_refresh = 9.0
	var point := Vector2(200,200)
	for index in range(3):
		var enemy = enemies[index]
		enemy.global_position = point + Vector2(index*20,0)
		enemy.state = enemy.State.INVESTIGATE
		enemy.investigation_target = Vector2(300,300)
	enemies[0].room_combat_active = true
	enemies[1].room_combat_active = true
	enemies[1].global_position = Vector2(1000,1000)
	level._on_navigation_graph_changed(point)
	assert(enemies[0].path_refresh <= .13)
	assert(enemies[0].investigation_target == Vector2(300,300))
	assert(enemies[1].path_refresh == 9.0)
	assert(enemies[2].path_refresh == 9.0 and not enemies[2].room_combat_active)
	# The global bus is world-scoped; an unrelated level cannot alter our AI.
	enemies[0].path_refresh = 9.0
	var empty_cells: Array[Vector2i] = []
	Events.tactical_shortcut_opened.emit(self, empty_cells, point)
	assert(enemies[0].path_refresh == 9.0)
	var world = level.get_node("TileMap")
	var cells: Array[Vector2i] = [Vector2i(20,20)]
	Events.tactical_shortcut_opened.emit(world, cells, point)
	assert(enemies[0].path_refresh <= .13)
	var enemy = enemies[0]
	enemy.state = enemy.State.CHASE
	enemy.enemy_type = "melee"
	enemy.path_points = PackedVector2Array([world.floor_layer.to_global(world.floor_layer.map_to_local(Vector2i(21,20)))])
	enemy._evaluate_shortcut_path()
	assert(enemy.shortcut_flank_time == 0.0)
	enemy.path_points = PackedVector2Array([world.floor_layer.to_global(world.floor_layer.map_to_local(cells[0]))])
	enemy._evaluate_shortcut_path()
	assert(enemy.shortcut_flank_time == 1.0)
	assert(enemy.shortcut_cells.is_empty())
	enemy.shortcut_flank_time = .5
	enemy._evaluate_shortcut_path()
	assert(enemy.shortcut_flank_time == .5) # No repeated boost from the same opening.
	assert(enemy.investigation_target == Vector2(300,300))
	for audio in level.find_children("*","AudioStreamPlayer",true,false):
		audio.stop(); audio.stream = null
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BREACH_AWARENESS_OK")
	get_tree().quit()
