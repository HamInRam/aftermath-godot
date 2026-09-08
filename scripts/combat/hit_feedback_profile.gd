class_name HitFeedbackProfile
extends RefCounted

# One source of truth for body flash, reticle and impact-audio classification.
# Presentation code consumes this profile without understanding ballistics.
static func from_ballistic_result(result: Dictionary, hit_zone := "torso") -> Dictionary:
	var health_damage := maxf(1.0, float(result.get("health_damage", 1.0)))
	var armour_absorbed := maxf(0.0, float(result.get("armour_absorbed", 0.0)))
	var damage_ratio := clampf(float(result.get("damage_ratio", 0.15)), 0.0, 2.0)
	var armour_dominant := armour_absorbed >= health_damage * 0.42
	var kind := "armour" if armour_dominant else ("head" if hit_zone == "head" else "flesh")
	return {
		"kind": kind,
		"hit_zone": hit_zone,
		"lethal": bool(result.get("lethal", false)),
		"intensity": clampf(0.78 + damage_ratio * 0.30, 0.78, 1.0),
		"white_time": 0.026 if kind == "armour" else 0.032,
		"color_time": 0.060 if kind == "armour" else (0.080 if kind == "head" else 0.070),
		"impact_color": Color.WHITE,
		"recovery_color": Color("aaaaaa") if kind == "armour" else NeonPalette.BLOOD_CRIMSON,
	}

static func generic_flesh(hit_zone := "torso", intensity := 0.82) -> Dictionary:
	return from_ballistic_result({"health_damage": 1, "damage_ratio": intensity, "lethal": false}, hit_zone)
