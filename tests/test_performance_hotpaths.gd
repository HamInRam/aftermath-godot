extends Node2D

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var blood := BloodSystem.new()
	add_child(blood)
	for x in range(48,192):
		for y in range(-64,65): blood.ground_canvas.add_blood_pixel(Vector2(x,y),255)
	var times: Array[int] = []
	for i in range(40):
		await get_tree().process_frame
		var start := Time.get_ticks_usec()
		blood.absorb_siphon_sector(Vector2.ZERO,Vector2.RIGHT,224,PI/4,48,8000,12)
		times.append(Time.get_ticks_usec()-start)
	var rays := blood.siphon_ray_queries
	blood.absorb_siphon_sector(Vector2.ZERO,Vector2.RIGHT,224,PI/4,48,8000)
	assert(blood.siphon_ray_queries == rays)
	blood.absorb_siphon_sector(Vector2(1,0),Vector2.RIGHT,224,PI/4,48,8000)
	assert(blood.siphon_ray_queries == rays+96)
	var resource := BloodResourceController.new()
	resource.blood_ammo_mode = true
	resource.reserve = 0
	resource.set_build("balanced")
	add_child(resource)
	var player := Node2D.new()
	add_child(player)
	resource.set_stance_active(true)
	resource.update_system(10.0,player,blood)
	assert(resource.last_absorption_steps <= 2 and resource.reserve <= 4.801)
	var level = preload("res://scenes/levels/after_hours.tscn").instantiate()
	var world = level.get_node("TileMap")
	level.remove_child(world)
	level.free()
	world.layout_id = "nightclub"
	add_child(world)
	await get_tree().create_timer(.15).timeout
	var before: int = world.erosion_acoustic_refreshes
	var container: Node = world.light_occluder_container
	var tested := false
	for cell: Vector2i in world.static_occluders_by_cell.keys():
		if cell.x <= 1 or cell.y <= 1: continue
		world._chip_wall_deferred(Vector2(cell*8)+Vector2(4,4),Vector2.RIGHT,1)
		tested = true
		break
	assert(tested)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(world.light_occluder_container == container)
	assert(world.erosion_acoustic_refreshes == before)
	for i in range(50): world._queue_erosion_topology(Vector2i(2,2))
	await get_tree().create_timer(.15).timeout
	assert(world.erosion_acoustic_refreshes == before+1)
	times.sort()
	print("HOTPATH_CPU_US median=",times[20]," p95=",times[38]," max=",times[39])
	print("PERFORMANCE_HOTPATHS_OK")
	get_tree().quit()
