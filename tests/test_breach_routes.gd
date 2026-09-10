extends Node2D
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _ready() -> void: call_deferred("run")
func run() -> void:
	for file in DirAccess.get_files_at("res://scenes/levels"):
		if not file.ends_with(".tscn"): continue
		var scene = load("res://scenes/levels/"+file).instantiate()
		var world = scene.get_node("TileMap")
		scene.remove_child(world); scene.free()
		world.room_run_seed_override = 19
		add_child(world)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(world.breach_panels.size() >= 1 and world.breach_panels.size() <= 2,file+" has bounded side routes")
		for panel: BreachPanel in world.breach_panels:
			var notifications: Array[int] = [0]
			var callback := func(_point: Vector2) -> void: notifications[0] += 1
			world.navigation_graph_changed.connect(callback)
			var a := Vector2i(panel.approach_a / 8)
			var b := Vector2i(panel.approach_b / 8)
			var original: PackedVector2Array = world.path_grid.get_point_path(a,b)
			check(not original.is_empty(),"normal detour available while sealed")
			var probe := CharacterBody2D.new()
			probe.collision_layer = 0
			probe.collision_mask = 4
			var collision := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 5.0
			collision.shape = circle
			probe.add_child(collision); add_child(probe)
			probe.global_position = panel.approach_a
			check(probe.move_and_collide(panel.approach_b-panel.approach_a) != null,"sealed route physically blocks player-sized body")
			panel.receive_projectile_impact_context(Vector2.ZERO,panel.to_global(Vector2(1,1)),"pistol",20)
			await get_tree().process_frame
			check(not panel.opened,"partial damage must not unlock topology")
			check(notifications[0] == 0,"no graph notification for partial chips")
			var before_throw := panel.erosion.remaining()
			var thrown = preload("res://scenes/props/thrown_weapon.tscn").instantiate()
			add_child(thrown)
			thrown.global_position = panel.to_global(Vector2(4,4))
			thrown.velocity = Vector2.RIGHT * 180
			thrown._resolve_impact(panel)
			var after_throw := panel.erosion.remaining()
			thrown._resolve_impact(panel)
			check(after_throw < before_throw and panel.erosion.remaining() == after_throw,"Q throw chips once without duplicate damage")
			for cell in panel.cells: check(world.path_grid.is_point_solid(cell),"partial panel stays navigation solid")
			for y in range(panel.erosion.bounds.size.y):
				for x in range(panel.erosion.bounds.size.x):
					panel.receive_projectile_impact_context(Vector2.ZERO,panel.to_global(Vector2(x,y)),"pistol",30)
			await get_tree().process_frame
			await get_tree().physics_frame
			await get_tree().physics_frame
			check(panel.opened,"fully removed panel opens")
			check(notifications[0] == 1,"one navigation notification per opening")
			world.navigation_graph_changed.disconnect(callback)
			var shortcut: PackedVector2Array = world.path_grid.get_point_path(a,b)
			check(not shortcut.is_empty() and shortcut.size() < original.size(),"breach genuinely shortens navigation route")
			probe.global_position = panel.approach_a
			check(probe.move_and_collide(panel.approach_b-panel.approach_a) == null,"player-sized body crosses actual open hole")
			probe.queue_free()
		print("BREACH_VENUE ",file," routes=",world.breach_panels.size())
		world.queue_free()
		await get_tree().process_frame
	print("BREACH_ROUTES_OK" if failures == 0 else "BREACH_ROUTES_FAILED")
	get_tree().quit(failures)
