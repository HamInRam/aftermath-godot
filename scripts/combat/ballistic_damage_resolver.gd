class_name BallisticDamageResolver
extends RefCounted

# Centralized high-lethality ballistics. Keeping the arithmetic here prevents
# bullets, actors and feedback code from drifting into different damage models.
const HIT_ZONE_MULTIPLIERS := {"head": 1.80, "torso": 1.00, "limb": 0.62}
const MAX_ARMOUR_REDUCTION := 0.72
const TISSUE_RESISTANCE := {"head": 0.86, "torso": 0.72, "limb": 0.54}
const ZONE_BLEED_SCALE := {"head": 1.24, "torso": 1.0, "limb": 0.82}

static func resolve(base_damage: float, penetration: float, hit_zone: String, travel_distance: float, falloff_start: float, falloff_end: float, minimum_damage_ratio: float, target_hp: int, target_max_hp: int, armour_protection: float, armour_reduction: float, armour_durability: float, armour_covers_head: bool, unaware_target: bool, weapon_class := "handgun") -> Dictionary:
	var distance_ratio := 0.0
	if falloff_end > falloff_start:
		distance_ratio = smoothstep(0.0, 1.0, clampf((travel_distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0))
	var distance_multiplier := lerpf(1.0, clampf(minimum_damage_ratio, 0.2, 1.0), distance_ratio)
	var zone_multiplier := float(HIT_ZONE_MULTIPLIERS.get(hit_zone, 1.0))
	var raw_damage := maxf(1.0, base_damage * distance_multiplier * zone_multiplier)
	var armour_applies := armour_durability > 0.0 and armour_reduction > 0.0 and (hit_zone == "torso" or (hit_zone == "head" and armour_covers_head))
	var effective_reduction := 0.0
	var armour_absorbed := 0.0
	var armour_damage := 0.0
	if armour_applies:
		if penetration > armour_protection:
			effective_reduction = armour_reduction * 0.5
		else:
			effective_reduction = armour_reduction + maxf(0.0, armour_protection - penetration) * 0.08
		effective_reduction = clampf(effective_reduction, 0.0, MAX_ARMOUR_REDUCTION)
		armour_absorbed = minf(raw_damage * effective_reduction, armour_durability)
		armour_damage = minf(armour_durability, maxf(1.0, armour_absorbed * 0.72 + raw_damage * 0.08))
	var health_damage := maxi(1, roundi(raw_damage - armour_absorbed))
	var stealth_critical := unaware_target and target_hp > 0
	if stealth_critical: health_damage = maxi(health_damage, target_hp)
	# External bleeding is governed by energy transferred to tissue, not by a
	# simple "more penetration = more blood" multiplier. A stopped projectile has
	# no exit spray; a well-matched round produces the strongest temporary cavity;
	# an extreme over-penetrator exits with much of its energy still aboard.
	var wound := _resolve_wound(base_damage, raw_damage, health_damage, penetration, distance_multiplier, hit_zone, target_max_hp, armour_applies, armour_protection, armour_absorbed, weapon_class)
	return {
		"raw_damage": raw_damage,
		"health_damage": health_damage,
		"armour_absorbed": armour_absorbed,
		"armour_damage": armour_damage,
		"distance_multiplier": distance_multiplier,
		"zone_multiplier": zone_multiplier,
		"stealth_critical": stealth_critical,
		"lethal": health_damage >= target_hp,
		"damage_ratio": clampf(float(health_damage) / maxf(1.0, float(target_max_hp)), 0.0, 2.0),
		"penetration_power": float(wound.penetration_power),
		"penetration_ratio": float(wound.penetration_ratio),
		"energy_transfer": float(wound.energy_transfer),
		"projectile_exited": bool(wound.projectile_exited),
		"projectile_retained": bool(wound.projectile_retained),
		"entry_wound_scale": float(wound.entry_wound_scale),
		"exit_wound_scale": float(wound.exit_wound_scale),
		"mist_scale": float(wound.mist_scale),
		"external_blood_scale": float(wound.external_blood_scale),
		"bleed_rate": float(wound.bleed_rate),
		"bleed_duration": float(wound.bleed_duration),
		"bleed_dps": float(wound.bleed_dps),
		"wound_severity": float(wound.wound_severity),
	}

static func _resolve_wound(base_damage: float, raw_damage: float, health_damage: int, penetration: float, distance_multiplier: float, hit_zone: String, target_max_hp: int, armour_applies: bool, armour_protection: float, armour_absorbed: float, weapon_class: String) -> Dictionary:
	var tissue_resistance := float(TISSUE_RESISTANCE.get(hit_zone, TISSUE_RESISTANCE.torso))
	var retained_energy_ratio := lerpf(0.78, 1.0, distance_multiplier)
	var effective_penetration := maxf(0.05, penetration * retained_energy_ratio)
	var armour_cost := armour_protection * 0.50 if armour_applies else 0.0
	var post_armour_penetration := maxf(0.0, effective_penetration - armour_cost)
	var penetration_ratio := post_armour_penetration / maxf(0.1, tissue_resistance)
	var projectile_exited := penetration_ratio >= 0.92
	var armour_stop_ratio := clampf(armour_absorbed / maxf(1.0, raw_damage), 0.0, 1.0)
	# A smooth bell centered around a useful through-and-through result. Very low
	# penetration fails to open an exit; very high penetration transfers less of
	# the projectile's remaining energy into the target.
	var match_distance := absf(penetration_ratio - 1.18)
	var energy_transfer := clampf(1.12 - match_distance * 0.30, 0.38, 1.08)
	if not projectile_exited: energy_transfer = clampf(0.58 + penetration_ratio * 0.42, 0.46, 0.94)
	if penetration_ratio > 2.15: energy_transfer *= lerpf(1.0, 0.66, clampf((penetration_ratio - 2.15) / 2.0, 0.0, 1.0))
	energy_transfer *= 1.0 - armour_stop_ratio * 0.56
	var calibre_proxy := clampf(sqrt(maxf(1.0, base_damage) / 43.0), 0.52, 1.72)
	var trauma_ratio := clampf(float(health_damage) / maxf(1.0, float(target_max_hp)), 0.0, 1.6)
	var zone_bleed := float(ZONE_BLEED_SCALE.get(hit_zone, 1.0))
	var pellet_scale := 0.48 if weapon_class == "shotgun" else 1.0
	var entry_scale := clampf((0.24 + calibre_proxy * 0.34) * (1.0 - armour_stop_ratio * 0.72), 0.10, 0.92)
	var exit_scale := 0.0
	if projectile_exited:
		var matched_exit := clampf(1.18 - absf(penetration_ratio - 1.30) * 0.22, 0.54, 1.18)
		exit_scale = clampf((0.32 + calibre_proxy * 0.62) * matched_exit * (1.0 - armour_stop_ratio * 0.48), 0.18, 2.15)
	# Each pellet already has its own small calibre/trauma result. Account for
	# the nine simultaneous sprays in density once, not again in their shape.
	# Previously 0.48 reduced entry/exit, then external intensity, then the blood
	# renderer multiplied those together: a useful buckshot hit looked like a
	# tiny pistol wound (~23% of its intended exit spray).
	var density_entry := clampf(entry_scale * pellet_scale, 0.10, 0.92)
	var density_exit := clampf(exit_scale * pellet_scale, 0.18, 2.15) if projectile_exited else 0.0
	var external_scale := clampf((density_entry * 0.55 + density_exit * 0.90) * (0.45 + trauma_ratio * 0.85) * zone_bleed, 0.10, 2.65)
	var wound_severity := clampf((trauma_ratio * 0.72 + energy_transfer * calibre_proxy * 0.28) * zone_bleed, 0.08, 1.65)
	var bleed_rate := clampf((0.16 + wound_severity * 0.90 + density_exit * 0.16) * (1.0 - armour_stop_ratio * 0.62), 0.05, 1.72)
	var bleed_duration := clampf(2.2 + wound_severity * 7.2 + (2.0 if hit_zone == "limb" else 0.0), 1.4, 14.0)
	var bleed_dps := clampf(wound_severity * 1.45, 0.12, 2.6)
	return {
		"penetration_power": effective_penetration,
		"penetration_ratio": penetration_ratio,
		"energy_transfer": energy_transfer,
		"projectile_exited": projectile_exited,
		"projectile_retained": not projectile_exited,
		"entry_wound_scale": entry_scale,
		"exit_wound_scale": exit_scale,
		"mist_scale": clampf(external_scale / pellet_scale * (0.52 + energy_transfer * 0.34), 0.08, 2.25),
		"external_blood_scale": external_scale,
		"bleed_rate": bleed_rate,
		"bleed_duration": bleed_duration,
		"bleed_dps": bleed_dps,
		"wound_severity": wound_severity,
	}
