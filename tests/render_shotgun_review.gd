extends Node

## Real-renderer QA using the production Gun -> Bullet -> Enemy -> Main death
## path. No synthetic damage or manually spawned corpses in this capture.
const OUTPUT := "/tmp/aftermath-shotgun-review"
var failures := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Shotgun render review requires the real renderer")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var level = load("res://scenes/main.tscn").instantiate()
	level.record_progress = false
	add_child(level)
	level._on_entry_loadout_confirmed(LoadoutCatalog.get_kit("balanced"))
	level.set_process(false)
	level.set_physics_process(false)
	var world = level.get_node("TileMap")
	var target: Node2D
	for enemy in level.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
		if not is_instance_valid(target) and enemy.actor_type != "dog":
			target = enemy
		else:
			enemy.collision_layer = 0
			enemy.visible = false
	if not is_instance_valid(target):
		push_error("No human enemy available for render QA")
		get_tree().quit(1)
		return
	var player = level.player
	player.set_controls_enabled(false)
	player.set_process(false)
	player.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	var pair := _find_clear_pair(world)
	if pair.is_empty():
		push_error("No clear shooting lane available for render QA")
		get_tree().quit(1)
		return
	player.global_position = pair[0]
	player.rotation = 0.0
	player.upper_body.position = Vector2.ZERO
	player.upper_body.rotation = 0.0
	player.gun.position = Vector2.ZERO
	player.gun.rotation = 0.0
	var data := AttackCatalog.get_gun_data("mossberg_590a1")
	player.gun.set_gun_data(data, true)
	player.gun.set_weapon_ammo(data.weapon_id, data.ammo_capacity)
	target.global_position = pair[1]
	target.rotation = 0.0
	target.configure_combat("gunner")
	target.alert_level = target.AlertLevel.ALERT
	target.state = target.State.CHASE
	level.trauma_camera.set_physics_process(false)
	level.trauma_camera.global_position = (pair[0] + pair[1]) * 0.5
	level.trauma_camera.rotation = 0.0
	level.trauma_camera.reset_smoothing()
	for frame in range(25): await get_tree().process_frame
	await _capture("before")
	var before_kills: int = level.enemies_killed
	seed(5901)
	if not player.gun.try_fire(Vector2.RIGHT):
		push_error("Production shotgun failed to fire in the clear QA lane")
		failures += 1
	for frame in range(5): await get_tree().physics_frame
	await _capture("impact")
	await get_tree().create_timer(0.65).timeout
	await _capture("aftermath")
	if level.enemies_killed != before_kills + 1:
		push_error("The real shotgun shot must kill one alerted normal target")
		failures += 1
	if level.get_tree().get_nodes_in_group("corpse").is_empty():
		push_error("Real shotgun death must create a persistent articulated corpse")
		failures += 1
	level.queue_free()
	await get_tree().process_frame
	print("SHOTGUN_RENDER_REVIEW_", "OK" if failures == 0 else "FAILED", " ", OUTPUT)
	get_tree().quit(failures)

func _find_clear_pair(world: Node2D) -> PackedVector2Array:
	for room in world.get_combat_space_profile().rooms:
		var bounds: Rect2 = room.bounds
		for y in range(ceili(bounds.position.y + 20), floori(bounds.end.y - 20), 8):
			for x in range(ceili(bounds.position.x + 20), floori(bounds.end.x - 65), 8):
				var start := Vector2(x, y)
				var finish := start + Vector2(45, 0)
				if not world.is_navigation_position_walkable(start) or not world.is_navigation_position_walkable(finish): continue
				var clear := true
				for offset in [-6.0, 0.0, 6.0]:
					var query := PhysicsRayQueryParameters2D.create(start + Vector2(0, offset), finish + Vector2(0, offset), 4 | 8)
					if not world.get_world_2d().direct_space_state.intersect_ray(query).is_empty(): clear = false
				if clear: return PackedVector2Array([start, finish])
	return PackedVector2Array()

func _capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(id + ".png")) != OK:
		push_error("Could not save shotgun review " + id)
		failures += 1
