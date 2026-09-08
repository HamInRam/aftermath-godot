extends Node
const PERKS := preload("res://scripts/roguelike/run_combat_perks.gd")
var failures := 0

class GunStub extends Node:
	var weapon_id := "test"
	var gun_data := {"weapon_class": "shotgun"}
	var is_reloading := false
	var ammo := 0
	var max_ammo := 8
	var reserve_ammo := 5
	var ammo_by_weapon := {}
	var reserve_by_weapon := {}

func _ready() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var ids: Array = PERKS.DEFINITIONS.keys()
	for mask in 64:
		var p = PERKS.new()
		for index in 6:
			if mask & (1 << index):
				check(p.acquire(ids[index]), "valid unlock")
				check(not p.acquire(ids[index]), "no duplicate stacking")
		p.on_reload()
		p.on_throw()
		p.on_siphon()
		var shot := {"enhanced": true, "damage_multiplier": 1.65, "penetration_bonus": 0.85, "raw_blood_budget": 4500, "blood_return_cap": 2.5}
		p.enhance(shot, true)
		check(shot.raw_blood_budget == 4500 and shot.blood_return_cap == 2.5, "all 64 combinations retain finite blood ledger")
		check(shot.damage_multiplier >= 1.65 and shot.damage_multiplier <= 2.785, "combined burst stays bounded")
		check(not p.breach_ready and p.swap_time == 0.0, "single-use triggers consumed")
		var restored = PERKS.new()
		restored.restore(p.capture())
		check(restored.capture() == p.capture(), "exact checkpoint round trip")
		p.update(10.0)
		check(p.harvest_time == 0.0, "movement window expires")
	var p = PERKS.new()
	p.acquire("field_cycle")
	p.acquire("blood_clock")
	var gun := GunStub.new()
	add_child(gun)
	var cooldowns := {"q": 1.0, "e": 0.1, "r": 0.0}
	p.on_kill(gun, cooldowns, "test")
	check(gun.ammo == 1 and gun.reserve_ammo == 4, "kill transfers real reserve rounds")
	check(is_equal_approx(cooldowns.q, 0.65) and cooldowns.e == 0.0, "kill trims cooldown without going negative")
	p.on_kill(gun, cooldowns, "test")
	check(gun.ammo == 1, "multiple pellets cannot refill repeatedly")
	p.update(1.0)
	gun.reserve_ammo = 0
	p.on_kill(gun, cooldowns, "test")
	check(gun.ammo == 1, "no ammo generated from empty reserves")
	var blood := BloodResourceController.new()
	add_child(blood)
	blood.perks.acquire("reload_breach")
	blood.perks.on_reload()
	blood.set_stance_active(true)
	var initial := blood.reserve
	var first: Dictionary = blood.consume_enhanced_round(10, false).duplicate(true)
	var repeated: Dictionary = blood.consume_enhanced_round(10, true)
	check(first == repeated and is_equal_approx(initial - blood.reserve, blood.enhanced_round_cost), "pellets share one enhanced perk/cost transaction")
	for module in HandcraftedRoomCatalog.get_modules():
		for variant in 8:
			var transformed := HandcraftedRoomCatalog._transform_module(module.duplicate(true), variant)
			for point: Vector2 in transformed.enemies:
				check(Rect2(0.139, 0.139, 0.722, 0.722).has_point(point), "transformed room anchor remains safe")
			for index in transformed.patrols.size():
				check(is_equal_approx(transformed.patrols[index].length(), 1.0), "all transformed patrols keep valid heading")
	gun.queue_free()
	blood.queue_free()
	await get_tree().process_frame
	print("RUN_COMBAT_PERKS ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)
