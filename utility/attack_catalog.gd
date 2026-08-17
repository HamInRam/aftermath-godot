class_name AttackCatalog
extends RefCounted

const GUNS := {
	"pistol": preload("res://resources/weapons/pistol.tres"),
	"smg": preload("res://resources/weapons/smg.tres"),
	"lmg": preload("res://resources/weapons/lmg.tres"),
}

const MELEE := {
	"fist": {"blood_power": 0.7, "range": 36.0, "wall_reach": 24.0, "pattern": "line", "cone": 0.25, "knockback": 8.0, "style": "blunt", "hit_stop": 0.0, "trauma": 0.16},
	"knife": {"blood_power": 1.35, "range": 54.0, "wall_reach": 52.0, "pattern": "line", "cone": 0.38, "knockback": 15.0, "style": "slash", "hit_stop": 0.032, "trauma": 0.34},
	"bat": {"blood_power": 1.75, "range": 48.0, "wall_reach": 42.0, "pattern": "radial", "cone": 0.95, "knockback": 30.0, "style": "blunt", "hit_stop": 0.055, "trauma": 0.58},
	"execution": {"blood_power": 1.85, "range": 92.0, "wall_reach": 64.0, "pattern": "radial", "cone": 1.05, "knockback": 18.0, "style": "blunt", "hit_stop": 0.045, "trauma": 0.42},
}

static func get_gun_data(weapon_id: String) -> GunData:
	return GUNS.get(weapon_id, GUNS.pistol) as GunData

static func get_blood_profile(attack_id: String) -> Dictionary:
	if GUNS.has(attack_id):
		var data := get_gun_data(attack_id)
		return {
			"blood_power": data.blood_power,
			"range": data.blood_range,
			"wall_reach": data.blood_wall_reach,
			"pattern": data.blood_pattern,
			"cone": data.blood_cone,
		}
	return (MELEE.get(attack_id, MELEE.fist) as Dictionary).duplicate()

static func get_impact_profile(attack_id: String) -> Dictionary:
	if GUNS.has(attack_id):
		var data := get_gun_data(attack_id)
		return {"blood_power": data.blood_power, "knockback": data.knockback, "style": "firearm", "hit_stop": data.hit_stop, "trauma": data.camera_shake}
	return (MELEE.get(attack_id, MELEE.fist) as Dictionary).duplicate()
