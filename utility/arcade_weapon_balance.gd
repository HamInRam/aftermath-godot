class_name ArcadeWeaponBalance
extends RefCounted
## Gameplay roles, not real-world ballistic specifications. Applied before
## attachments so a saved build retains compatible parts and their effects.
const ROLES := {
	"handgun": {"damage": 52, "reload": 1.05, "move": 1.04, "penetration": 0.8, "trait": "DUELIST // MOBILE PRECISION"},
	"pdw": {"damage": 30, "reload": 1.15, "move": 1.06, "bonus": 1.8, "trait": "RUSH // CLOSE-RANGE BULLET STORM"},
	"smg": {"damage": 38, "reload": 1.35, "move": 1.02, "bonus": 1.3, "trait": "FLOW // CONTROLLED SUSTAINED FIRE"},
	"shotgun": {"damage": 24, "falloff_start": 85.0, "falloff_end": 220.0, "min_damage": 0.65, "reload": 1.65, "move": 0.98, "pellet_spread": 6.0, "trait": "BREACH // CLOSE-RANGE BURST"},
	"carbine": {"damage": 60, "reload": 1.55, "move": 0.98, "penetration": 1.35, "bonus": 1.4, "trait": "ASSAULT // FLEXIBLE ROOM CLEARING"},
	"dmr": {"damage": 95, "reload": 1.65, "move": 0.96, "penetration": 2.0, "trait": "EXECUTION // HEAVY PRECISION SHOTS"},
	"sniper": {"damage": 160, "reload": 1.95, "move": 0.93, "penetration": 3.0, "trait": "SKEWER // LINE PENETRATION"},
	"lmg": {"damage": 48, "reload": 2.5, "move": 0.91, "bonus": 2.0, "penetration": 1.5, "trait": "SIEGE // LONG SUSTAINED VOLLEYS"},
}
const SHOTGUNS := {
	"mossberg_590a1": {"damage": 30, "pellets": 9, "pellet_spread": 5.0, "fire_interval": 0.58, "blood": 2.65, "property": 2.1, "trait": "SLEDGEHAMMER // HEAVY PUMP BURST"},
	"remington_870_police": {"damage": 25, "pellets": 8, "pellet_spread": 4.5, "fire_interval": 0.43, "reload": 1.4, "trait": "QUICK PUMP // FAST FOLLOW-UP"},
	"benelli_m4": {"damage": 20, "pellets": 7, "fire_interval": 0.27, "trait": "PRESSURE // CONTROLLED SEMI-AUTO"},
	"beretta_1301_mod2": {"damage": 17, "pellets": 7, "pellet_spread": 7.0, "fire_interval": 0.19, "trait": "SHREDDER // FAST AMMO DUMP"},
	"benelli_m3": {"damage": 24, "pellets": 7, "pellet_spread": 3.8, "fire_interval": 0.35, "trait": "LANCE // TIGHT SHOT PATTERN"},
	"keltec_ksg": {"damage": 25, "pellets": 9, "pellet_spread": 7.5, "fire_interval": 0.56, "reload": 2.3, "trait": "SWEEPER // WIDE PATTERN, DEEP MAGAZINE"},
}

const DISTINCT_ROLES := {
	"glock_17_gen5_mos": {"spread": 0.35, "trait": "DUELIST // MOBILE PRECISION"},
	"colt_m1911a1": {"damage": 85, "fire_interval": 0.28, "knockback": 38.0, "trait": "HAMMER // HEAVY SINGLE SHOT"},
	"fn_fiveseven_mrd": {"damage": 38, "penetration": 2.5, "fire_interval": 0.12, "trait": "NEEDLE // PIERCING SIDEARM"},
	"hk_mp5k_pdw": {"move": 1.12, "trait": "SPRINTER // MOBILE CLOSE FIRE"},
	"fn_p90": {"fire_interval": 0.055, "damage": 24, "trait": "HOSE // RAPID LOW-COST FIRE"},
	"hk_mp7a2": {"penetration": 2.0, "damage": 32, "trait": "DRILL // ARMOR PRESSURE"},
	"hk_mp5a5": {"spread": 0.6, "trait": "FLOW // STABLE STREAM"},
	"hk_ump45": {"damage": 62, "fire_interval": 0.13, "knockback": 36.0, "trait": "THUMPER // SLOW HEAVY BURSTS"},
	"kriss_vector_45": {"damage": 25, "fire_interval": 0.045, "trait": "TORRENT // EXTREME FIRE RATE"},
	"colt_m4a1": {"trait": "ASSAULT // ALL-ROUND CONTROL"},
	"akm": {"damage": 85, "fire_interval": 0.14, "property": 2.0, "trait": "DEMOLISHER // COVER BREAKER"},
	"iwi_tavor_x95": {"move": 1.08, "damage": 48, "trait": "RAIDER // MOBILE ASSAULT"},
	"fn_scar_17s": {"trait": "EXECUTION // HEAVY PRECISION"},
	"ruger_mini14_tactical": {"damage": 64, "fire_interval": 0.16, "move": 1.05, "trait": "SKIRMISHER // FAST FOLLOW-UP"},
	"dragunov_svd": {"damage": 125, "penetration": 3.0, "fire_interval": 0.42, "trait": "SKEWER // MULTI-TARGET PIERCE"},
	"remington_700_police": {"trait": "MARKSMAN // PRECISE HEAVY SHOT"},
	"barrett_m82a1": {"damage": 220, "penetration": 4.5, "property": 3.0, "fire_interval": 0.95, "trait": "BREAKER // ANTI-MATERIAL CANNON"},
	"vss_vintorez": {"automatic": true, "damage": 70, "fire_interval": 0.20, "penetration": 1.8, "trait": "STITCH // AUTOMATIC PRECISION"},
	"fn_m249_para": {"trait": "SIEGE // SUSTAINED SUPPRESSION"},
	"ultimax_100_mk8": {"move": 1.02, "spread": 0.7, "damage": 40, "trait": "MARCH // MOBILE SUPPORT"},
	"fn_m240b": {"damage": 76, "fire_interval": 0.14, "penetration": 2.5, "property": 2.4, "trait": "JUGGERNAUT // HEAVY LINE BREAKER"},
}

static func apply(values: Dictionary, weapon_id: String, weapon_class: String) -> Dictionary:
	var result := values.duplicate(true)
	result.merge(ROLES.get(weapon_class, {}), true)
	result.merge(SHOTGUNS.get(weapon_id, {}), true)
	result.merge(DISTINCT_ROLES.get(weapon_id, {}), true)
	# Moving and flicking aim are encouraged. Keep inherent pattern and recoil,
	# not the old tactical penalties that turn an aimed shot into a miss.
	result.move_spread = minf(float(result.get("move_spread", 0.0)), 0.65)
	result.turn_spread = minf(float(result.get("turn_spread", 0.0)), 0.4)
	result.aim = maxf(float(result.get("aim", 12.0)), 16.0)
	result.reload_move = maxf(float(result.get("reload_move", 0.8)), 0.85)
	return result

static func for_enemy(source: GunData) -> GunData:
	# Enemy threat is authored separately from the player's arcade power curve.
	# Duplicate: never nerf cached loot or the weapon later picked up by a player.
	var gun := source.duplicate(true) as GunData
	var caps := {"handgun": 43, "pdw": 34, "smg": 40, "shotgun": 18,
		"carbine": 66, "dmr": 78, "sniper": 98, "lmg": 62}
	gun.damage = mini(gun.damage, int(caps.get(gun.weapon_class, 43)))
	var penetration_caps := {"handgun": 0.75, "pdw": 0.72, "smg": 0.72,
		"shotgun": 0.72, "carbine": 1.15, "dmr": 1.65, "sniper": 2.15, "lmg": 1.35}
	gun.penetration_power = minf(gun.penetration_power, float(penetration_caps.get(gun.weapon_class, 0.75)))
	return gun
