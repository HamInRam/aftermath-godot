extends Node2D

var failures := 0
class BloodSource:
	extends Node
	var center := Vector2.INF
	func absorb_siphon_sector(origin: Vector2, _d: Vector2, _r: float, _a: float, _near: float, budget: int) -> Dictionary:
		center = origin
		return {"amount": budget, "positions": PackedVector2Array([origin])}
	func absorb_pixel_blood(origin: Vector2, _r: float, _p: int, _s: int, budget: int) -> Dictionary:
		center = origin
		return {"amount": budget, "positions": PackedVector2Array([origin])}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = preload("res://scenes/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.blood_action_mode = true
	var blood := BloodResourceController.new()
	_expect(blood.reserve == 100.0 and blood.capacity == 100.0, "new reserve starts full")
	add_child(blood)
	blood.blood_ammo_mode = true
	blood.set_build("balanced")
	player.gun.blood_fire_payment = blood.pay_for_shot
	player.gun.set_gun_data(AttackCatalog.get_gun_data("mossberg_590a1"), true)
	player.gun.ammo = 0
	var shot_cost: float = player.gun.gun_data.caliber_blood_cost
	blood.reserve = shot_cost * 2.0
	var before_reserve: int = player.gun.reserve_ammo
	_expect(player.gun.try_fire(Vector2.RIGHT), "blood fires without a magazine")
	_expect(is_equal_approx(blood.reserve, shot_cost), "shotgun pellets share one GunData payment")
	_expect(not player.gun.try_fire(Vector2.RIGHT) and is_equal_approx(blood.reserve, shot_cost), "cooldown must not charge")
	_expect(not blood.request_skill("q") and not blood.request_skill("e") and not blood.request_skill("r"), "legacy skills disabled in blood-ammo mode")
	for id in WeaponPlatformCatalog.get_weapon_ids():
		var data := AttackCatalog.get_gun_data(id)
		_expect(data.caliber_blood_cost > 0 and data.blood_stain_radius > 0, "every weapon has valid blood parameters")
		player.gun.set_gun_data(data, true)
		player.gun.ammo = 0
		player.gun.reserve_ammo = 0
		player.gun.cooldown = 0
		blood.reserve = data.caliber_blood_cost
		_expect(player.gun.try_fire(Vector2.RIGHT) and is_zero_approx(blood.reserve), "zero-ammo weapon pays once from shared reserve: " + id)
		_expect(player.gun.ammo == 0 and player.gun.reserve_ammo == 0, "blood firing leaves compatibility ammo untouched: " + id)
	# Switching modes while a legacy reload is active must unlock immediately.
	player.gun.blood_fire_payment = Callable()
	player.gun.reserve_ammo = 10
	player.gun.reload()
	_expect(player.gun.is_reloading, "legacy reload remains functional")
	player.gun.blood_fire_payment = blood.pay_for_shot
	_expect(not player.gun.is_reloading and player.gun.reload_timer.is_stopped(), "blood mode cancels legacy animation lock and timer")
	player.gun._on_reload_timer_timeout()
	_expect(player.gun.ammo == 0 and player.gun.reserve_ammo == 10, "stale timeout cannot load conventional ammo")
	player.gun.reserve_ammo = before_reserve
	player.gun.cooldown = 0.0
	blood.reserve = 0.0
	_expect(not player.gun.try_fire(Vector2.RIGHT), "empty blood prevents firing")
	_expect(is_equal_approx(player.gun.cooldown, 0.2), "blood dry fire uses a 200ms cooldown")
	_expect(AttackCatalog.get_gun_data("glock_17_gen5_mos").caliber_blood_cost == 1.2, "handgun blood baseline")
	_expect(AttackCatalog.get_gun_data("hk_mp5a5").caliber_blood_cost == 0.6, "SMG blood baseline")
	_expect(AttackCatalog.get_gun_data("mossberg_590a1").caliber_blood_cost == 9.5, "shotgun blood baseline")
	for id in WeaponPlatformCatalog.get_weapon_ids():
		var shotgun_data := AttackCatalog.get_gun_data(id)
		if shotgun_data.weapon_class == "shotgun":
			_expect(shotgun_data.blood_stain_radius == 56.0, "shotgun uses restrained 56px blood footprint: " + id)
	_expect(AttackCatalog.get_gun_data("ai_axmc").caliber_blood_cost == 15.0, "sniper blood baseline")
	var custom := player.gun.gun_data.duplicate() as GunData
	custom.caliber_blood_cost = 3.3
	blood.reserve = 4.0
	_expect(blood.pay_for_shot(custom) and is_equal_approx(blood.reserve, 0.7), "runtime GunData override is authoritative")
	player.gun.reload()
	_expect(not player.gun.is_reloading and player.gun.reserve_ammo == before_reserve and player.gun.ammo == 0, "blood mode never transfers conventional ammunition")
	_expect(player.start_roll(Vector2.UP), "Space roll may start without blood")
	_expect(player.roll_direction == Vector2.UP and not player.start_roll(Vector2.RIGHT), "roll direction commits and cooldown prevents repeated invulnerability")
	var hp: int = player.hp
	var armor: float = player.armor_durability
	player.take_damage(20)
	player.apply_ballistic_hit({"health_damage": 20, "armour_damage": 10})
	_expect(player.hp == hp and player.armor_durability == armor, "roll protects both health and armor")
	player.roll_time = 0.05
	player.take_damage(1)
	_expect(player.hp == hp - 1, "recovery frames are vulnerable")
	var source := BloodSource.new()
	add_child(source)
	blood.set_stance_active(true)
	player.using_controller_aim = true
	player.last_controller_aim = Vector2.RIGHT
	player.aim_target_world = player.global_position + Vector2(100, 0)
	blood.update_system(0.04, player, source)
	_expect(source.center == player.global_position, "siphon cone originates at player, not mouse")
	_expect(blood.get_movement_multiplier() == 1.0, "siphon never slows WASD")
	for audio in player.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	player.queue_free()
	blood.queue_free()
	source.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if failures == 0: print("BLOOD_ACTION_FLOW_OK")
	get_tree().quit(failures)

func _expect(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)
