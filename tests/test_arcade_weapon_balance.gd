extends Node

func _ready() -> void:
	var failures := 0
	for id in WeaponPlatformCatalog.get_weapon_ids():
		var gun := WeaponPlatformCatalog.create_gun_data(id)
		if gun.damage <= 0 or gun.fire_interval <= 0 or gun.movement_spread_degrees > 0.65 or gun.turn_spread_degrees > 0.4:
			push_error("Invalid arcade handling: " + id)
			failures += 1
	var heavy := WeaponPlatformCatalog.create_gun_data("mossberg_590a1")
	var fast := WeaponPlatformCatalog.create_gun_data("beretta_1301_mod2")
	var enemy_gun := ArcadeWeaponBalance.for_enemy(heavy)
	if enemy_gun == heavy or enemy_gun.damage != 18 or heavy.damage != 30:
		push_error("Enemy threat tuning must not mutate player/loot data")
		failures += 1
	if heavy.damage * heavy.pellet_count <= fast.damage * fast.pellet_count or heavy.fire_interval <= fast.fire_interval:
		push_error("Heavy pump must trade cycle speed for burst power")
		failures += 1
	if heavy.damage_falloff_start != 85.0 or heavy.damage != 30:
		push_error("Old tactical Mossberg overrides leaked through")
		failures += 1
	print("ARCADE_WEAPON_BALANCE ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)
