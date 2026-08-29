class_name RagdollImpactResolver
extends RefCounted

# Weapon character is deliberately authored separately from blood quantity.
# A shotgun launches mass; an SMG agitates limbs; a knife opens tissue without
# throwing a body across the room. This keeps physical feedback readable.
const WEAPON_CHARACTER := {
	"pistol": {"linear": 1.0, "limb": 1.05, "spin": 0.75, "close": 1.15, "far": 0.72},
	"smg": {"linear": 0.82, "limb": 1.32, "spin": 1.15, "close": 1.18, "far": 0.68},
	"lmg": {"linear": 1.38, "limb": 1.62, "spin": 1.28, "close": 1.30, "far": 0.78},
	"shotgun": {"linear": 1.72, "limb": 2.05, "spin": 1.55, "close": 1.48, "far": 0.48},
	"fist": {"linear": 0.52, "limb": 0.72, "spin": 0.65, "close": 1.0, "far": 1.0},
	"knife": {"linear": 0.34, "limb": 0.76, "spin": 0.72, "close": 1.0, "far": 1.0},
	"bat": {"linear": 1.28, "limb": 1.42, "spin": 1.75, "close": 1.0, "far": 1.0},
	"execution": {"linear": 0.62, "limb": 1.2, "spin": 1.0, "close": 1.0, "far": 1.0},
	"execution_knife": {"linear": 0.42, "limb": 1.05, "spin": 0.9, "close": 1.0, "far": 1.0},
	"execution_bat": {"linear": 1.05, "limb": 1.55, "spin": 1.65, "close": 1.0, "far": 1.0},
	"hound_bite": {"linear": 0.48, "limb": 0.9, "spin": 0.82, "close": 1.0, "far": 1.0},
	"door": {"linear": 1.18, "limb": 1.24, "spin": 1.8, "close": 1.0, "far": 1.0},
}

static func resolve(attack_id: String, travel_distance: float, hit_zone: String, rig_kind := "human") -> Dictionary:
	var resolved_id := attack_id if WEAPON_CHARACTER.has(attack_id) else ("execution" if attack_id.begins_with("execution") else "pistol")
	var character: Dictionary = WEAPON_CHARACTER[resolved_id]
	var impact := AttackCatalog.get_impact_profile(attack_id)
	var base_force := maxf(7.0, float(impact.get("knockback", 18.0)))
	var distance_factor := 1.0
	if attack_id in AttackCatalog.GUNS:
		var blood_profile := AttackCatalog.get_blood_profile(attack_id)
		var effective_range := maxf(32.0, float(blood_profile.get("range", 140.0)))
		var range_ratio := smoothstep(0.0, 1.0, clampf(travel_distance / effective_range, 0.0, 1.0))
		distance_factor = lerpf(float(character.close), float(character.far), range_ratio)
	var zone_linear := 1.0
	var zone_limb := 1.0
	var zone_spin := 1.0
	match hit_zone:
		"head": zone_linear = 1.08; zone_limb = 1.28; zone_spin = 1.48
		"limb": zone_linear = 0.82; zone_limb = 1.42; zone_spin = 1.22
	var mass_factor := 1.22 if rig_kind == "hound" else 1.0
	# A controlled 18% arcade exaggeration gives kills a readable snap without
	# producing room-crossing physics or interfering with cleanup placement.
	var arcade_exaggeration := 1.18
	return {
		# Root travel is capped below room-crossing speed; the stronger numbers are
		# reserved for internal limb motion. A point-blank shotgun still throws a
		# body roughly 3-4 character lengths, not across an entire encounter space.
		"linear_force": clampf(base_force * float(character.linear) * distance_factor * zone_linear * mass_factor * arcade_exaggeration, 5.0, 96.0),
		"limb_force": clampf(base_force * float(character.limb) * distance_factor * zone_limb * arcade_exaggeration, 7.0, 170.0),
		"spin_force": clampf(float(character.spin) * zone_spin * distance_factor, 0.25, 2.8),
		"distance_factor": distance_factor,
		"weapon_id": attack_id,
		"hit_zone": hit_zone,
	}
