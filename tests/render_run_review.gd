extends Node
## Renderer-only visual QA. Captures this game's viewport, not the desktop.
var review_dir := "/tmp/aftermath-render-review"

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Render review requires the real renderer")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(review_dir)
	var title = load("res://scenes/ui/title_menu.tscn").instantiate()
	add_child(title)
	await _capture("title")
	title.queue_free()
	await get_tree().process_frame
	var help = load("res://scenes/ui/run_help.tscn").instantiate()
	add_child(help)
	await _capture("help")
	help.queue_free()
	await get_tree().process_frame
	var level = load("res://scenes/main.tscn").instantiate()
	level.record_progress = false
	add_child(level)
	level._on_entry_loadout_confirmed(LoadoutCatalog.get_kit("balanced"))
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	level.player.set_controls_enabled(false)
	var room: Dictionary = level.get_node("TileMap").get_combat_space_profile().rooms[0]
	level.player.global_position = room.bounds.get_center()
	level.trauma_camera.set_physics_process(false)
	level.trauma_camera.global_position = level.player.global_position
	level.trauma_camera.rotation = 0.0
	level.trauma_camera.reset_smoothing()
	await _capture("combat")
	# Stage the optional safe offer and retry UI without running a live fight.
	level.set_process(false)
	var engaged: Dictionary = level.room_run.engaged_rooms.duplicate()
	level.room_run.engaged_rooms.clear()
	var offer = level.get_node("SafeBuildOffer")
	offer.offer(3)
	await get_tree().create_timer(1.1).timeout
	await _capture("safe_build_offer")
	offer.pending = false
	level.room_run.engaged_rooms = engaged
	level._show_run_end_prompt("RUN ENDED // TRY ANOTHER APPROACH", false)
	await _capture("retry_choices")
	level.run_end_layer.queue_free()
	level.run_end_layer = null
	level.set_process(true)
	# Exercise the same impact/death pipeline used by bullets, keeping other
	# hostiles alive. This is a controlled visual fixture, not a claimed playthrough.
	var killed := 0
	for enemy in level.get_node("Enemies").get_children():
		if enemy.global_position.distance_to(level.player.global_position) > 100.0: continue
		var direction: Vector2 = level.player.global_position.direction_to(enemy.global_position)
		var context := DamageContext.create(enemy.global_position, direction, enemy.hp, "shotgun", 28.0, true, "limb", level.player.global_position, enemy)
		level._on_damage_impact(context)
		enemy.take_damage(enemy.hp, level.player.global_position)
		killed += 1
		if killed >= 2: break
	await get_tree().create_timer(2.1).timeout
	await _capture("battle_aftermath")
	# Readability fixture: striped non-siphonable terrain and red overpaint.
	var terrain_origin: Vector2 = level.player.global_position + Vector2(28, 0)
	level.blood_system.ground_canvas.stamp_pollution(terrain_origin, 23.0)
	level.blood_system.ground_canvas.stamp_weapon_footprint(terrain_origin - Vector2(18, 0), Vector2.RIGHT, "shotgun")
	await _capture("blood_terrain")
	level.player.using_controller_aim = true
	level.player.last_controller_aim = Vector2.RIGHT
	level.player.aim_target_world = level.player.global_position + Vector2(160, 0)
	level.blood_resource.reserve = 0.0
	level.blood_resource.set_stance_active(true)
	await _capture("siphon_sector")
	level.blood_resource.set_stance_active(false)
	level._on_rogue_run_cleared(4)
	await _capture("floor_clear")
	level.queue_free()
	await get_tree().process_frame
	print("RENDER_REVIEW_OK " + review_dir)
	get_tree().quit()

func _capture(id: String) -> void:
	for frame in range(25): await get_tree().process_frame
	var cursor_preview: CanvasLayer
	if id == "siphon_sector":
		# Isolated preview: production hides the real cursor while fixture player
		# controls are disabled. Do not mistake this for an input playthrough.
		cursor_preview = CanvasLayer.new()
		cursor_preview.layer = 120
		add_child(cursor_preview)
		var cursor := CombatReticle.new()
		cursor_preview.add_child(cursor)
		cursor.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(24, 24)
		cursor.set_siphon_strength(1.0)
	await RenderingServer.frame_post_draw
	var output := get_viewport().get_texture().get_image()
	var error := output.save_png(review_dir.path_join(id + ".png"))
	if is_instance_valid(cursor_preview): cursor_preview.queue_free()
	if error != OK: push_error("Could not save render " + id)
