extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var level = preload("res://scenes/main.tscn").instantiate()
	level.record_progress = false
	add_child(level)
	level.set_process(false)
	level.player.set_controls_enabled(false)
	var carrier: Node2D
	for enemy in level.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
		if enemy.get_meta("polluter", false): carrier = enemy
	var ok := is_instance_valid(carrier)
	if ok:
		var canvas: PixelBloodCanvas = level.blood_system.ground_canvas
		var before := canvas.get_debug_pixel_count()
		var context := DamageContext.create(carrier.global_position, Vector2.RIGHT, 1, "hk_mp5a5", 10, false, "torso", level.player.global_position, carrier)
		level._on_damage_impact(context)
		ok = canvas.terrain_at(carrier.global_position) == -1 and canvas.get_debug_pixel_count() == before
		context.lethal = true
		level._on_damage_impact(context)
		carrier.take_damage(carrier.hp, level.player.global_position)
		ok = ok and canvas.terrain_at(context.hit_position) == -1 and canvas.get_debug_pixel_count() == before
		ok = ok and level.player.blood_terrain_canvas == canvas
	level.queue_free()
	await get_tree().process_frame
	print("BLOOD_TERRAIN_ROOM_OK" if ok else "BLOOD_TERRAIN_ROOM_FAILED")
	get_tree().quit(0 if ok else 1)
