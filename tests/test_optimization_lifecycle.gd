extends Node2D

var failures := 0
class DoorTarget:
	extends CharacterBody2D
	var hits := 0
	func take_door_hit(_direction: Vector2, _kind: String) -> void:
		hits += 1

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var pool := ProjectilePool.new()
	add_child(pool)
	pool.warm(4)
	var shot = pool.acquire()
	shot.position = Vector2(-100,-100)
	shot.setup(Vector2.RIGHT,false,43,"pistol",shot.position,60)
	check(not shot.is_physics_processing() and pool.is_physics_processing(), "one dispatcher, no duplicate projectile ticks")
	pool.set_physics_process(false)
	pool._physics_process(0.1)
	check(is_equal_approx(shot.position.x,-94.0), "flight speed is unchanged")
	shot.lifetime = 0.001
	pool._physics_process(0.1)
	await get_tree().process_frame
	check(pool.active.is_empty() and not pool.is_physics_processing(), "empty pool sleeps after deferred retirement")
	var discarded = pool.acquire()
	discarded.queue_free()
	await get_tree().process_frame
	check(pool.active.is_empty() and pool.leased.is_empty(), "external deletion leaves no dangling dispatcher entries")
	pool.free()

	var canvas := PixelBloodCanvas.new()
	add_child(canvas)
	canvas.add_blood_pixel(Vector2(4,4),100)
	canvas._flush_upload_queue()
	check(not canvas.is_processing(), "blood canvas sleeps after uploads")
	var chunk: PixelBloodCanvas.PixelBloodChunk = canvas.chunks.values()[0]
	for i in 50:
		chunk.add_local_pixel(Vector2i(4,4),1)
		chunk.absorb_local_pixel(Vector2i(4,4),1)
	check(chunk.blood_load == 100 and not chunk.dirty and canvas.upload_queue.is_empty(), "100 density changes keep exact mass without rendering unchanged red")
	chunk.absorb_local_pixel(Vector2i(4,4),100)
	check(chunk.dirty and canvas.is_processing(), "last blood pixel wakes renderer")
	canvas._flush_upload_queue()
	check(chunk.image.get_pixel(4,4).a == 0, "final absorption erases the pixel")
	canvas.free()

	var mist := BloodMistBatch.new()
	add_child(mist)
	mist.emit_mist(Vector2(-100,-100),Vector2.RIGHT,2,Color.RED,0.8,0)
	check(not mist.emission_alive.is_empty(), "mist tracks active emissions")
	mist._process(1.0)
	check(mist.particles.is_empty() and mist.emission_alive.is_empty() and mist.emission_remaining.is_empty(), "expired mist frees all ledgers without full rescans")
	mist.free()

	var door_root = preload("res://scenes/props/swing_door.tscn").instantiate()
	add_child(door_root)
	var door: SwingDoor = door_root.get_node("Door")
	check(door is AnimatableBody2D and not door.is_physics_processing(), "door has no rigid hinge simulation and rests idle")
	var target := DoorTarget.new()
	target.collision_layer = 2
	target.collision_mask = 0
	target.add_to_group("enemy")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5
	shape.shape = circle
	target.add_child(shape)
	add_child(target)
	target.position = Vector2(9,14)
	var pusher := Node2D.new()
	add_child(pusher)
	pusher.position = Vector2(-14,12)
	await get_tree().physics_frame
	door.push_door_open(pusher,Vector2.RIGHT * 115)
	for i in 35: await get_tree().physics_frame
	check(door.current_state == SwingDoor.DoorState.OPEN and not door.is_physics_processing(), "door settles and stops updating")
	check(target.hits == 1, "kick still knocks down the enemy exactly once")
	check(not door.get_node("HitArea").monitoring, "open door disables overlap monitoring")
	print("OPTIMIZATION_LIFECYCLE_OK" if failures == 0 else "OPTIMIZATION_LIFECYCLE_FAILED")
	get_tree().quit(failures)
