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
	add_child(blood)
	blood.blood_ammo_mode = true
	blood.set_build("balanced")
	player.gun.blood_fire_payment = blood.pay_for_shot
	player.gun.set_gun_data(AttackCatalog.get_gun_data("mossberg_590a1"), true)
	player.gun.ammo = 0
	blood.reserve = 10.0
	var before_reserve: int = player.gun.reserve_ammo
	_expect(player.gun.try_fire(Vector2.RIGHT), "blood fires without a magazine")
	_expect(blood.reserve == 5.0, "shotgun pellets share one five-point payment")
	_expect(not player.gun.try_fire(Vector2.RIGHT) and blood.reserve == 5.0, "cooldown must not charge")
	player.gun.cooldown = 0.0
	blood.reserve = 0.0
	_expect(not player.gun.try_fire(Vector2.RIGHT), "empty blood prevents firing")
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
