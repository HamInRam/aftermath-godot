extends Node2D
var failures := 0
class Source:
	extends Node
	var calls := 0
	func absorb_siphon_sector(_o: Vector2, _d: Vector2, _r: float, _a: float, _p: float, budget: int) -> Dictionary:
		calls += 1
		return {"amount": budget, "positions": PackedVector2Array()}

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var pool := ProjectilePool.new()
	add_child(pool)
	pool.warm(4)
	var bullet = pool.acquire()
	var identity: int = bullet.get_instance_id()
	bullet.setup(Vector2.RIGHT, true)
	bullet.blood_enhanced = true
	bullet.combat_time_scale = 0.2
	bullet.shot_id = 88
	bullet.lifetime = 0.01
	bullet.travel_distance = 99
	bullet.retire()
	await get_tree().process_frame
	check(pool.available.size() == 4 and RuntimeBudget.get_count("bullet") == 0, "release returns idle node and budget")
	bullet = pool.acquire()
	check(bullet.get_instance_id() == identity, "same projectile node reused")
	check(not bullet.blood_enhanced and bullet.combat_time_scale == 1 and bullet.shot_id == -1 and bullet.lifetime == 1.2 and bullet.travel_distance == 0, "recycle resets projectile state")
	check(bullet.get_collision_exceptions().is_empty(), "recycle clears collision exceptions")
	pool.release(bullet)
	pool.queue_free()
	var blood := BloodResourceController.new()
	add_child(blood)
	blood.blood_ammo_mode = true
	blood.set_stance_active(true)
	blood.set_stance_active(false, true)
	check(is_equal_approx(blood.siphon_release_remaining, 0.1), "release grants bounded 100ms grace")
	blood.set_stance_active(false, true)
	check(is_equal_approx(blood.siphon_release_remaining, 0.1), "repeated release does not extend grace")
	blood.set_stance_active(false)
	check(blood.siphon_release_remaining == 0, "forced stop cancels grace")
	var actor := Node2D.new()
	var source := Source.new()
	add_child(actor)
	add_child(source)
	blood.reserve = 0
	blood.set_stance_active(true)
	blood.set_stance_active(false, true)
	blood.update_system(0.1, actor, source)
	var gained := blood.reserve
	check(gained > 0 and gained <= blood.absorption_rate_per_second * 0.1, "grace credits only bounded real absorption")
	blood.update_system(1.0, actor, source)
	check(blood.reserve == gained and source.calls == 2, "release cannot continue siphoning after grace")
	actor.queue_free()
	source.queue_free()
	var bus_count := AudioServer.bus_count
	var audio := CombatAudioDirector.new()
	audio.autoplay = false
	add_child(audio)
	audio.set_blood_level(0)
	audio._process(0.25)
	check(audio.blood_filters[0].cutoff_hz == 1200.0, "empty reserve filters music")
	audio.set_blood_level(1)
	audio._process(0.25)
	check(audio.blood_filters[0].cutoff_hz == 20000.0, "refill restores clear music")
	audio.queue_free()
	blood.queue_free()
	await get_tree().process_frame
	check(AudioServer.bus_count == bus_count, "scene exit removes owned buses")
	check(RuntimeBudget.get_count("bullet") == 0, "pool leaves no budget entries")
	print("BLOOD_JUICE_OK" if failures == 0 else "BLOOD_JUICE_FAILED")
	get_tree().quit(failures)
