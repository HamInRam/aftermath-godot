extends Node2D

var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var canvas := PixelBloodCanvas.new()
	canvas.configure("ground", -2)
	add_child(canvas)
	var player = preload("res://scenes/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.blood_action_mode = true
	player.blood_terrain_canvas = canvas
	player.global_position = Vector2(-10, -10)
	player.refresh_blood_terrain()
	check(player.blood_terrain_multiplier == 1.0, "clean floor normal speed")
	canvas.add_blood_pixel(player.global_position, 4)
	player.refresh_blood_terrain()
	check(player.blood_terrain_multiplier == 1.3, "blood grants 30 percent speed")
	canvas.stamp_pollution(player.global_position, 5)
	player.refresh_blood_terrain()
	check(player.blood_terrain_multiplier == 0.6, "pollution slows 40 percent")
	check(not player.start_roll(Vector2.RIGHT), "pollution blocks roll start")
	check(int(canvas.absorb_circle(player.global_position, 8, 255, 1000, 10000).amount) == 0, "pollution is not blood currency")
	canvas.add_blood_pixel(player.global_position, 2)
	check(canvas.terrain_at(player.global_position) == 1, "overpaint removes pollution")
	check(player.start_roll(Vector2.RIGHT), "overpainting restores roll")
	canvas.absorb_circle(player.global_position, 1, 255, 10, 100)
	check(canvas.terrain_at(player.global_position) == 0, "absorbing paint never restores erased pollution")
	var spent := canvas.stamp_weapon_footprint(Vector2(100, 100), Vector2.RIGHT, "shotgun", 600)
	check(spent <= 600 and spent > 0, "shotgun paint respects mass budget")
	canvas.stamp_weapon_footprint(Vector2(200, 200), Vector2.RIGHT, "shotgun")
	check(canvas.terrain_at(Vector2(225, 200)) == 1 and canvas.terrain_at(Vector2(175, 200)) == 0, "shotgun paints forward fan only")
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4, 40)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector2(360, 350)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	canvas.stamp_weapon_footprint(Vector2(300, 350), Vector2.RIGHT, "sniper")
	check(canvas.terrain_at(Vector2(340, 350)) == 1, "sniper paints contiguous route")
	check(canvas.terrain_at(Vector2(370, 350)) == 0, "sniper route stops at solid wall")
	check(AttackCatalog.get_blood_profile("hk_mp5a5").pattern == "dots", "SMG gets dotted footprint")
	player.queue_free()
	canvas.queue_free()
	wall.queue_free()
	await get_tree().process_frame
	print("BLOOD_TERRAIN_OK" if failures == 0 else "BLOOD_TERRAIN_FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
