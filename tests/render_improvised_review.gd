extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var level = preload("res://scenes/main.tscn").instantiate()
	level.record_progress = false
	add_child(level)
	level._on_entry_loadout_confirmed(LoadoutCatalog.get_kit("balanced"))
	level.set_process(false)
	level.set_physics_process(false)
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	var player = level.player
	player.set_physics_process(false)
	player.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var items := get_tree().get_nodes_in_group("improvised_pickup")
	if items.is_empty():
		push_error("Actual floor did not generate temporary weapons")
		get_tree().quit(1)
		return
	print("Actual floor temporary weapons: ", items.size())
	var item = items[0]
	player.global_position = item.global_position
	player.actual_aim_angle = 0.0
	player.upper_body.rotation = 0.0
	item.collect(player)
	level.trauma_camera.set_physics_process(false)
	level.trauma_camera.global_position = player.global_position
	level.trauma_camera.reset_smoothing()
	for frame in 4: await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/aftermath-improvised-review.png")
	item.release(true)
	for frame in 45: await get_tree().physics_frame
	print("IMPROVISED_RENDER_REVIEW: PASS")
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit()
