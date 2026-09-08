extends Node

const RESOLVER := preload("res://scripts/combat/ballistic_damage_resolver.gd")

var failures := 0

func _ready() -> void:
	var pistol := AttackCatalog.get_gun_data("glock_17_gen5_mos")
	var carbine := AttackCatalog.get_gun_data("colt_m4a1")
	var sniper := AttackCatalog.get_gun_data("remington_700_police")
	var shotgun := AttackCatalog.get_gun_data("mossberg_590a1")
	_expect(pistol.damage < carbine.damage and carbine.damage < sniper.damage, "weapon classes must have a readable per-shot damage ladder")
	_expect(shotgun.damage < pistol.damage and shotgun.pellet_count > 1, "shotgun lethality must come from multiple close-range pellets")
	_expect(shotgun.pellet_count == 9 and shotgun.damage >= 18 and shotgun.pellet_spread_degrees <= 6.25, "the starter Mossberg must use a dense nine-pellet 00 buck pattern instead of weak wide generic buckshot")
	var close_buckshot_damage := 0
	for pellet in 6: close_buckshot_damage += int(_resolve(shotgun, "torso", 42.0, 95, false).health_damage)
	_expect(close_buckshot_damage >= 95, "six centre-mass Mossberg pellet hits must stop even an elite target at room distance")
	var buck_wound := _resolve(shotgun, "torso", 30.0, 75, false)
	var single_wound := RESOLVER.resolve(shotgun.damage, shotgun.penetration_power, "torso", 30.0, shotgun.damage_falloff_start, shotgun.damage_falloff_end, shotgun.minimum_damage_ratio, 75, 75, 0.0, 0.0, 0.0, false, false, "handgun")
	_expect(buck_wound.health_damage == single_wound.health_damage, "shotgun presentation density must never reduce pellet health damage")
	_expect(is_equal_approx(buck_wound.entry_wound_scale, single_wound.entry_wound_scale) and is_equal_approx(buck_wound.exit_wound_scale, single_wound.exit_wound_scale), "pellet density must not also shrink entry/exit spray shape")
	_expect(is_equal_approx(buck_wound.external_blood_scale, single_wound.external_blood_scale * 0.48), "a volley must apply its per-pellet blood density exactly once")
	_expect(is_equal_approx(buck_wound.mist_scale, single_wound.mist_scale), "the temporary blood cloud must not receive a second pellet-density penalty")
	var stopped_buck := RESOLVER.resolve(shotgun.damage, 0.1, "torso", 30.0, 36.0, 130.0, 0.46, 95, 95, 1.45, 0.38, 60.0, false, false, "shotgun")
	_expect(not bool(stopped_buck.projectile_exited) and is_zero_approx(stopped_buck.exit_wound_scale), "stronger buckshot feedback must not invent an exit through stopped armour")

	var torso := _resolve(pistol, "torso", 30.0, 75, false)
	_expect(not bool(torso.lethal), "an alerted normal enemy must survive one ordinary pistol torso hit")
	_expect(int(torso.health_damage) == 52, "arcade duelist pistol must apply its authored 52 torso damage without a hidden multiplier")
	var head := _resolve(pistol, "head", 30.0, 75, false)
	_expect(bool(head.lethal), "a close pistol headshot should remain lethal to a normal enemy")
	var stealth := _resolve(pistol, "limb", 30.0, 75, true)
	_expect(bool(stealth.lethal) and bool(stealth.stealth_critical), "a clean unaware hit should preserve decisive stealth lethality")

	var near_carbine := _resolve(carbine, "torso", 40.0, 95, false)
	var far_carbine := _resolve(carbine, "torso", 400.0, 95, false)
	_expect(int(far_carbine.health_damage) < int(near_carbine.health_damage), "ballistic damage must fall off beyond effective range")

	var low_pen := RESOLVER.resolve(66.0, 0.7, "torso", 30.0, 100.0, 250.0, 0.75, 95, 95, 1.4, 0.34, 52.0, false, false)
	var high_pen := RESOLVER.resolve(66.0, 2.0, "torso", 30.0, 100.0, 250.0, 0.75, 95, 95, 1.4, 0.34, 52.0, false, false)
	_expect(int(high_pen.health_damage) > int(low_pen.health_damage), "over-penetrating ammunition must defeat more armour protection")
	_expect(float(low_pen.armour_damage) > 0.0, "protected hits must degrade armour durability")

	_expect(EnemyCatalog.get_profile("gunner").max_health == 75, "inexperienced enemies should use the 75 HP tier")
	_expect(EnemyCatalog.get_profile("assault").max_health == 85, "experienced enemies should use the 85 HP tier")
	_expect(EnemyCatalog.get_profile("heavy").max_health == 95, "elite enemies should use the 95 HP tier")

	if failures == 0: print("ballistic damage model regression: PASS")
	get_tree().quit(failures)

func _resolve(data: GunData, zone: String, distance: float, hp: int, unaware: bool) -> Dictionary:
	return RESOLVER.resolve(data.damage, data.penetration_power, zone, distance, data.damage_falloff_start, data.damage_falloff_end, data.minimum_damage_ratio, hp, hp, 0.0, 0.0, 0.0, false, unaware, data.weapon_class)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
