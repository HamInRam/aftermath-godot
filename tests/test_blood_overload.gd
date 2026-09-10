extends Node2D

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var resource := BloodResourceController.new()
	resource.blood_ammo_mode = true
	resource.set_build("balanced")
	add_child(resource)
	resource.set_stance_active(true)
	assert(resource.accept_siphon(200000,11,1.0) == 0)
	assert(resource.reserve == 100 and not resource.overload_active)
	assert(resource.accept_siphon(1,12,1.0) < .001)
	resource.reserve = 100
	resource.accept_siphon(200000,12,1.0)
	assert(resource.reserve == 150 and resource.overload_active)
	assert(resource.accept_siphon(200000,12,1.0) == 0)
	resource.update_overload(1.0)
	assert(resource.reserve == 142)
	var gun := GunData.new()
	gun.caliber_blood_cost = 9.5
	assert(resource.pay_for_shot(gun))
	assert(resource.last_shot_overload and resource.reserve == 132.5)
	resource.reserve = 101
	assert(resource.pay_for_shot(gun))
	assert(resource.reserve == 100 and not resource.overload_active and resource.last_shot_overload)
	assert(resource.last_shot_blood_cost == 1)
	assert(resource.pay_for_shot(gun) and resource.reserve == 90.5 and not resource.last_shot_overload)
	var blood := BloodSystem.new()
	add_child(blood)
	blood.ground_canvas.add_blood_pixel(Vector2(10,0),255)
	var before: int = blood.ground_canvas.get_debug_pixel_count()
	var rejected := blood.absorb_siphon_sector(Vector2.ZERO,Vector2.RIGHT,224,PI/4,48,8000,12)
	assert(rejected.amount == 0 and blood.ground_canvas.get_debug_pixel_count() == before)
	for x in [64,96,128,160]:
		for y in [-32,0,32]:
			for dx in range(8):
				for dy in range(8): blood.ground_canvas.add_blood_pixel(Vector2(x+dx,y+dy),255)
	var result := blood.absorb_siphon_sector(Vector2.ZERO,Vector2.RIGHT,224,PI/4,48,8000)
	assert(result.pressure_chunks >= 12 and result.amount > 0)
	var bullet = preload("res://scenes/bullet.tscn").instantiate()
	bullet.breach_round = true
	bullet.reset_for_reuse()
	assert(not bullet.breach_round)
	bullet.free()
	print("BLOOD_OVERLOAD_OK")
	get_tree().quit()
