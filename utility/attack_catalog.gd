@static_unload
class_name AttackCatalog
extends RefCounted

static var GUNS: Dictionary = WeaponPlatformCatalog.get_all_gun_data()

const MELEE := {
	"fist": {"blood_power": 0.7, "range": 36.0, "wall_reach": 24.0, "pattern": "line", "cone": 0.25, "knockback": 8.0, "style": "blunt", "hit_stop": 0.0, "trauma": 0.16},
	"knife": {"blood_power": 1.35, "range": 54.0, "wall_reach": 52.0, "pattern": "line", "cone": 0.38, "knockback": 15.0, "style": "slash", "hit_stop": 0.032, "trauma": 0.34},
	"bat": {"blood_power": 1.75, "range": 48.0, "wall_reach": 42.0, "pattern": "radial", "cone": 0.95, "knockback": 30.0, "style": "blunt", "hit_stop": 0.055, "trauma": 0.58},
	"execution": {"blood_power": 1.85, "range": 92.0, "wall_reach": 64.0, "pattern": "radial", "cone": 1.05, "knockback": 18.0, "style": "execution", "hit_stop": 0.045, "trauma": 0.42},
	"execution_knife": {"blood_power": 1.65, "range": 68.0, "wall_reach": 56.0, "pattern": "fan", "cone": 0.55, "knockback": 10.0, "style": "execution_blade", "hit_stop": 0.04, "trauma": 0.38},
	"execution_bat": {"blood_power": 2.15, "range": 78.0, "wall_reach": 62.0, "pattern": "radial", "cone": 1.15, "knockback": 24.0, "style": "execution_blunt", "hit_stop": 0.06, "trauma": 0.58},
}

const VIOLENCE := {
	"pistol": {"entry": 1.15, "exit": 2.35, "mist": 1.15, "drops": 13, "gore": 4, "limbs": 1, "pool_bias": 1.32, "wound": "puncture", "flash": Color("ffffff")},
	"smg": {"entry": 1.05, "exit": 2.15, "mist": 1.35, "drops": 18, "gore": 6, "limbs": 1, "pool_bias": 1.42, "wound": "cluster", "flash": Color("ffffff")},
	"lmg": {"entry": 1.7, "exit": 4.25, "mist": 1.9, "drops": 25, "gore": 12, "limbs": 2, "pool_bias": 1.9, "wound": "torn", "flash": Color("ffffff")},
	"shotgun": {"entry": 2.35, "exit": 6.2, "mist": 2.55, "drops": 34, "gore": 18, "limbs": 3, "pool_bias": 2.35, "wound": "blast", "flash": Color("ffffff")},
	"fist": {"entry": 0.6, "exit": 0.5, "mist": 0.35, "drops": 3, "gore": 1, "limbs": 0, "pool_bias": 0.85, "wound": "bruise", "flash": Color("ffffff")},
	"knife": {"entry": 1.1, "exit": 1.2, "mist": 0.7, "drops": 12, "gore": 3, "limbs": 0, "pool_bias": 1.35, "wound": "slash", "flash": Color("bfffff")},
	"bat": {"entry": 1.8, "exit": 1.0, "mist": 1.25, "drops": 10, "gore": 7, "limbs": 0, "pool_bias": 1.45, "wound": "crush", "flash": Color("ffb8e8")},
	"execution": {"entry": 2.2, "exit": 2.5, "mist": 1.6, "drops": 18, "gore": 10, "limbs": 1, "pool_bias": 1.75, "wound": "execution", "flash": Color("ffffff")},
	"execution_knife": {"entry": 1.5, "exit": 1.8, "mist": 1.1, "drops": 16, "gore": 6, "limbs": 1, "pool_bias": 1.55, "wound": "dismember", "flash": Color("c8ffff")},
	"execution_bat": {"entry": 2.4, "exit": 2.0, "mist": 1.8, "drops": 18, "gore": 12, "limbs": 0, "pool_bias": 1.8, "wound": "crush", "flash": Color("ffd0ef")},
}

static func get_gun_data(weapon_id: String, attachment_ids := PackedStringArray()) -> GunData:
	var resolved := WeaponPlatformCatalog.canonical_id(weapon_id)
	if not attachment_ids.is_empty(): return WeaponPlatformCatalog.create_gun_data(resolved, attachment_ids)
	return GUNS.get(resolved, GUNS["glock_17_gen5_mos"]) as GunData

static func get_blood_profile(attack_id: String) -> Dictionary:
	if GUNS.has(attack_id):
		var data := get_gun_data(attack_id)
		return {
			"blood_power": data.blood_power,
			"range": data.blood_range,
			"wall_reach": data.blood_wall_reach,
			"pattern": "dots" if data.weapon_class in ["smg", "pdw"] else data.blood_pattern,
			"cone": 0.85 if data.weapon_class in ["smg", "pdw"] else data.blood_cone,
		}
	return (MELEE.get(attack_id, MELEE.fist) as Dictionary).duplicate()

static func get_impact_profile(attack_id: String) -> Dictionary:
	if GUNS.has(attack_id):
		var data := get_gun_data(attack_id)
		return {"blood_power": data.blood_power, "knockback": data.knockback, "style": data.death_style, "hit_stop": data.hit_stop, "trauma": data.camera_shake}
	return (MELEE.get(attack_id, MELEE.fist) as Dictionary).duplicate()

static func get_violence_profile(attack_id: String) -> Dictionary:
	var resolved := attack_id
	if WeaponPlatformCatalog.has_weapon(attack_id):
		var data := get_gun_data(attack_id)
		var template_id := "pistol"
		match data.weapon_class:
			"pdw", "smg", "carbine": template_id = "smg"
			"shotgun": template_id = "shotgun"
			"dmr", "sniper", "lmg": template_id = "lmg"
		var profile := (VIOLENCE[template_id] as Dictionary).duplicate(true)
		var burden_ratio := clampf(data.cleanup_burden, 0.65, 3.0)
		profile.drops = maxi(9, roundi(float(profile.drops) * burden_ratio * 0.94))
		profile.gore = maxi(3, roundi(float(profile.gore) * burden_ratio * 0.86))
		profile.limbs = 3 if burden_ratio >= 2.4 else (2 if burden_ratio >= 1.55 else 1)
		profile.pool_bias = burden_ratio
		profile.wound = "blast" if data.weapon_class == "shotgun" else ("torn" if burden_ratio >= 1.55 else "puncture")
		return profile
	if not VIOLENCE.has(resolved):
		if attack_id.begins_with("execution"): resolved = "execution"
		elif GUNS.has(attack_id): resolved = attack_id
		else: resolved = "pistol"
	return (VIOLENCE.get(resolved, VIOLENCE.pistol) as Dictionary).duplicate(true)

static func get_aftermath_profile(attack_id: String) -> Dictionary:
	var violence := get_violence_profile(attack_id)
	var noise_radius := 0.0
	if GUNS.has(attack_id): noise_radius = get_gun_data(attack_id).hearing_radius
	elif attack_id in ["bat", "execution", "execution_bat"]: noise_radius = 72.0
	else: noise_radius = 18.0
	var ballistic := 1.0 if GUNS.has(attack_id) else 0.0
	var cleanup_load := ballistic + float(violence.get("drops", 0)) * 0.12 + float(violence.get("gore", 0)) * 0.32 + float(violence.get("pool_bias", 1.0))
	return {
		"cleanup_load": cleanup_load,
		"noise_radius": noise_radius,
		"noise_label": "LOW" if noise_radius < 80.0 else ("HIGH" if noise_radius >= 240.0 else "MED"),
		"evidence_label": "BALLISTIC + BIO" if ballistic > 0.0 else "BIOLOGICAL",
	}
