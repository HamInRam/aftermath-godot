extends Node2D

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var pool := ProjectilePool.new()
	add_child(pool)
	pool.warm(200)
	pool.set_physics_process(false)
	var shots: Array = []
	for i in 128:
		var shot = pool.acquire()
		shot.setup(Vector2.RIGHT, false, 43, "pistol", Vector2.ZERO, 650.0)
		shot.position = Vector2(0, i * 4)
		shot.lifetime = 100.0
		shot.set_physics_process(false)
		shots.append(shot)
	await get_tree().physics_frame
	var samples: Array[int] = []
	for sample in 15:
		var start := Time.get_ticks_usec()
		for frame in 30:
			for shot in shots: shot._physics_process(1.0 / 60.0)
		samples.append(Time.get_ticks_usec() - start)
	samples.sort()
	print("PROJECTILE_EMPTY_3840_STEPS_MEDIAN_US=", samples[7])
	for shot in shots: pool.release(shot)
	get_tree().quit()
