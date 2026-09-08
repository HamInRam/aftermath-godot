class_name WeaponPresentationProfile
extends RefCounted
## Authored arcade presentation, not claimed OTXO source values. Ballistics,
## damage, magazine capacity and attachment tuning remain in GunData.

const CLASSES := {
	"handgun": {"kick": 2.3, "twist": -0.10, "return": 0.13, "cycle": 0.075, "camera": 0.90, "tilt": -0.48, "sound": 1.18},
	"pdw": {"kick": 1.3, "twist": -0.04, "return": 0.085, "cycle": 0.045, "camera": 0.55, "tilt": -0.34, "sound": 1.30},
	"smg": {"kick": 1.7, "twist": -0.055, "return": 0.105, "cycle": 0.055, "camera": 0.68, "tilt": -0.42, "sound": 1.08},
	"shotgun": {"kick": 4.0, "twist": -0.14, "return": 0.24, "cycle": 0.38, "camera": 1.90, "tilt": -0.64, "sound": 0.77},
	"carbine": {"kick": 2.0, "twist": -0.065, "return": 0.12, "cycle": 0.070, "camera": 0.85, "tilt": -0.47, "sound": 0.98},
	"dmr": {"kick": 2.9, "twist": -0.095, "return": 0.17, "cycle": 0.11, "camera": 1.30, "tilt": -0.53, "sound": 0.87},
	"sniper": {"kick": 4.2, "twist": -0.13, "return": 0.27, "cycle": 0.52, "camera": 1.85, "tilt": -0.60, "sound": 0.72},
	"lmg": {"kick": 2.35, "twist": -0.07, "return": 0.15, "cycle": 0.085, "camera": 1.00, "tilt": -0.38, "sound": 0.83},
}

static func for_class(weapon_class: String) -> Dictionary:
	return CLASSES.get(weapon_class, CLASSES.handgun)

static func for_weapon(data: GunData) -> Dictionary:
	var profile: Dictionary = for_class(data.weapon_class).duplicate(true)
	# Stable platform variation, never random pitch/pose drift between pickups.
	var variant := float(posmod(data.weapon_id.hash(), 9) - 4) * 0.012
	profile.sound *= 1.0 + variant
	profile.tilt *= 1.0 + variant
	if data.weapon_class == "shotgun" and data.action_type == "semi_auto":
		profile.cycle = 0.10
		profile["return"] = 0.16
	elif data.action_type == "bolt_action":
		profile.cycle = 0.52
	return profile

static func recoil_pose(profile: Dictionary, age: float, strength := 1.0) -> Dictionary:
	var t := clampf(age / maxf(0.01, float(profile["return"])), 0.0, 1.0)
	var kick := pow(1.0 - t, 3.0)
	var seat := sin(clampf((t - 0.35) / 0.65, 0.0, 1.0) * PI) * 0.18
	return {"offset": Vector2((-kick + seat) * float(profile.kick) * strength, 0), "angle": float(profile.twist) * kick * strength}

static func reload_pose(profile: Dictionary, progress: float, feed: String, action: String, rounds_needed: int) -> Dictionary:
	var t := clampf(progress, 0.0, 1.0)
	var phase := "lower"
	var magazine_offset := Vector2.ZERO
	var chamber := 0.0
	var feed_pulse := 0.0
	var hold := smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.82, 1.0, t))
	if t >= 0.16 and t < 0.70:
		phase = "feed" if feed in ["tube", "belt"] else "exchange"
		var middle := inverse_lerp(0.16, 0.70, t)
		if feed == "tube":
			feed_pulse = sin(middle * float(clampi(rounds_needed, 1, 8)) * TAU) * 0.5 + 0.5
			magazine_offset = Vector2(3, 2 + feed_pulse * 3.0)
		elif feed == "belt":
			magazine_offset = Vector2(-1, 4.0 * sin(middle * PI))
			feed_pulse = middle
		else:
			magazine_offset = Vector2(-middle * 1.5, sin(middle * PI) * 6.0)
	elif t >= 0.70 and t < 0.86:
		phase = "chamber"
		chamber = sin(inverse_lerp(0.70, 0.86, t) * PI)
	elif t >= 0.86:
		phase = "ready"
	var action_tilt := 0.10 if action == "bolt_action" else 0.0
	return {"phase": phase, "offset": Vector2(-1.0, 2.0) * hold, "angle": (float(profile.tilt) - action_tilt) * hold, "magazine_offset": magazine_offset, "chamber": chamber, "feed_pulse": feed_pulse}
