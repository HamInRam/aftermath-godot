class_name WeaponPlatformCatalog
extends RefCounted

# Stable platform IDs are deliberately independent from display names.  This lets
# a release build substitute a legally reviewed name without invalidating saves.
const CLASS_ORDER := ["handgun", "pdw", "smg", "shotgun", "carbine", "dmr", "sniper", "lmg"]
const CLASS_NAMES := {
	"handgun": "HANDGUN", "pdw": "PDW / MICRO SMG", "smg": "SUBMACHINE GUN",
	"shotgun": "SHOTGUN", "carbine": "ASSAULT / CARBINE", "dmr": "SEMI-AUTO / DMR",
	"sniper": "SNIPER RIFLE", "lmg": "LIGHT / GENERAL MG",
}
const ALIASES := {
	"pistol": "glock_17_gen5_mos", "smg": "hk_mp5a5", "shotgun": "mossberg_590a1", "lmg": "fn_m249_para",
}
# Authored scene references collapse to the remaining class representative.
const MERGED_PLATFORMS := {
	"sig_p320_m17": "glock_17_gen5_mos",
	"beretta_92x_rdo": "glock_17_gen5_mos",
	"hk_usp45_tactical": "glock_17_gen5_mos",
	"sig_mpx_k": "hk_mp5k_pdw",
	"bt_mp9n": "hk_mp5k_pdw",
	"cz_scorpion_3_micro": "hk_mp5k_pdw",
	"hk_mp5sd6": "hk_mp5a5",
	"bt_apc9_pro": "hk_mp5a5",
	"iwi_uzi_pro": "hk_mp5a5",
	"remington_870_police": "mossberg_590a1",
	"beretta_1301_mod2": "mossberg_590a1",
	"benelli_m3": "mossberg_590a1",
	"hk416a5": "colt_m4a1",
	"sig_mcx_spear_lt": "colt_m4a1",
	"fn_scar_l": "colt_m4a1",
	"ak_74m": "colt_m4a1",
	"hk_m110a1": "fn_scar_17s",
	"m1a_socom16": "fn_scar_17s",
	"galil_ace_gen2": "fn_scar_17s",
	"ai_awm": "remington_700_police",
	"sako_trg_m10": "remington_700_police",
	"barrett_mrad": "remington_700_police",
	"iwi_negev_ng5": "fn_m249_para",
	"rpk_74m": "fn_m249_para",
	"hk_mg4": "fn_m249_para",
	"cz_p10c_or": "glock_17_gen5_mos",
	"walther_pdp_compact": "glock_17_gen5_mos",
	"bt_apc9k_pro": "hk_mp5k_pdw",
	"beretta_pmx": "hk_mp5k_pdw",
	"colt_ro635": "hk_mp5a5",
	"pp19_vityaz": "hk_mp5a5",
	"saiga_12k": "mossberg_590a1",
	"vepr_12": "mossberg_590a1",
	"sig_sg553": "colt_m4a1",
	"knights_sr25_e2": "fn_scar_17s",
	"hk_g3a3": "fn_scar_17s",
	"ai_axmc": "remington_700_police",
	"steyr_ssg08": "remington_700_police",
	"pkm": "fn_m249_para",
	"sig_mg338": "fn_m249_para",
}
const STARTER_WEAPONS := [
	"glock_17_gen5_mos", "hk_mp5k_pdw", "hk_mp5a5", "mossberg_590a1",
	"colt_m4a1", "fn_scar_17s", "remington_700_police", "fn_m249_para",
]

const CLASS_DEFAULTS := {
	"handgun": {"automatic": false, "capacity": 17, "fire_interval": 0.145, "spread": 0.72, "growth": 0.10, "bonus": 0.55, "recovery": 6.2, "move_spread": 1.45, "turn_spread": 1.0, "aim": 16.5, "reload": 1.55, "move": 1.02, "reload_move": 0.84, "blood": 1.0, "blood_range": 145.0, "wall_reach": 48.0, "pattern": "line", "cone": 0.24, "recoil": 0.78, "shake": 0.65, "flash": 27.0, "speed": 650.0, "knockback": 24.0, "noise": 155.0, "hit_stop": 0.034, "penetration": 0.75, "property": 0.65, "cleanup": 1.0, "length_px": 9, "weight": 750.0, "length_mm": 200.0, "visual": "handgun", "action": "semi_auto", "feed": "detachable_magazine", "modes": ["semi"]},
	"pdw": {"automatic": true, "capacity": 30, "fire_interval": 0.072, "spread": 2.2, "growth": 0.40, "bonus": 3.0, "recovery": 3.8, "move_spread": 2.7, "turn_spread": 2.0, "aim": 12.8, "reload": 1.75, "move": 1.04, "reload_move": 0.80, "blood": 0.78, "blood_range": 126.0, "wall_reach": 40.0, "pattern": "fan", "cone": 0.42, "recoil": 0.42, "shake": 0.32, "flash": 23.0, "speed": 650.0, "knockback": 17.0, "noise": 180.0, "hit_stop": 0.029, "penetration": 0.72, "property": 0.7, "cleanup": 1.15, "length_px": 11, "weight": 2400.0, "length_mm": 430.0, "visual": "pdw", "action": "closed_bolt", "feed": "detachable_magazine", "modes": ["semi", "auto"]},
	"smg": {"automatic": true, "capacity": 30, "fire_interval": 0.075, "spread": 1.8, "growth": 0.34, "bonus": 2.6, "recovery": 4.2, "move_spread": 2.5, "turn_spread": 1.8, "aim": 11.8, "reload": 1.9, "move": 1.0, "reload_move": 0.77, "blood": 0.82, "blood_range": 130.0, "wall_reach": 42.0, "pattern": "fan", "cone": 0.46, "recoil": 0.42, "shake": 0.34, "flash": 24.0, "speed": 660.0, "knockback": 18.0, "noise": 190.0, "hit_stop": 0.03, "penetration": 0.72, "property": 0.75, "cleanup": 1.2, "length_px": 12, "weight": 2900.0, "length_mm": 680.0, "visual": "smg", "action": "closed_bolt", "feed": "detachable_magazine", "modes": ["semi", "auto"]},
	"shotgun": {"automatic": false, "capacity": 7, "fire_interval": 0.72, "spread": 1.2, "pellets": 7, "pellet_spread": 8.5, "growth": 0.0, "bonus": 0.0, "recovery": 4.0, "move_spread": 3.7, "turn_spread": 2.8, "aim": 8.5, "reload": 2.35, "move": 0.9, "reload_move": 0.65, "blood": 2.15, "blood_range": 108.0, "wall_reach": 72.0, "pattern": "radial", "cone": 1.02, "recoil": 1.75, "shake": 1.45, "flash": 41.0, "speed": 610.0, "knockback": 52.0, "noise": 275.0, "hit_stop": 0.058, "penetration": 0.72, "property": 1.7, "cleanup": 2.25, "length_px": 15, "weight": 3300.0, "length_mm": 1000.0, "visual": "shotgun", "action": "pump_action", "feed": "tube", "modes": ["single"]},
	"carbine": {"automatic": true, "capacity": 30, "fire_interval": 0.083, "spread": 1.05, "growth": 0.28, "bonus": 2.2, "recovery": 4.6, "move_spread": 2.6, "turn_spread": 2.0, "aim": 10.0, "reload": 2.05, "move": 0.92, "reload_move": 0.72, "blood": 1.15, "blood_range": 160.0, "wall_reach": 55.0, "pattern": "line", "cone": 0.34, "recoil": 0.72, "shake": 0.58, "flash": 31.0, "speed": 760.0, "knockback": 27.0, "noise": 230.0, "hit_stop": 0.039, "penetration": 1.15, "property": 1.1, "cleanup": 1.35, "length_px": 14, "weight": 3200.0, "length_mm": 760.0, "visual": "carbine", "action": "gas_operated", "feed": "detachable_magazine", "modes": ["semi", "auto"]},
	"dmr": {"automatic": false, "capacity": 20, "fire_interval": 0.19, "spread": 0.42, "growth": 0.16, "bonus": 1.0, "recovery": 4.8, "move_spread": 3.0, "turn_spread": 2.5, "aim": 7.8, "reload": 2.35, "move": 0.84, "reload_move": 0.62, "blood": 1.5, "blood_range": 176.0, "wall_reach": 63.0, "pattern": "line", "cone": 0.28, "recoil": 1.25, "shake": 0.95, "flash": 36.0, "speed": 830.0, "knockback": 36.0, "noise": 250.0, "hit_stop": 0.046, "penetration": 1.65, "property": 1.55, "cleanup": 1.65, "length_px": 16, "weight": 4100.0, "length_mm": 930.0, "visual": "dmr", "action": "semi_auto", "feed": "detachable_magazine", "modes": ["semi"]},
	"sniper": {"automatic": false, "capacity": 5, "fire_interval": 0.95, "spread": 0.15, "growth": 0.0, "bonus": 0.0, "recovery": 6.0, "move_spread": 5.2, "turn_spread": 4.0, "aim": 5.8, "reload": 2.8, "move": 0.76, "reload_move": 0.5, "blood": 1.9, "blood_range": 195.0, "wall_reach": 74.0, "pattern": "line", "cone": 0.22, "recoil": 1.65, "shake": 1.25, "flash": 40.0, "speed": 930.0, "knockback": 43.0, "noise": 280.0, "hit_stop": 0.056, "penetration": 2.15, "property": 1.9, "cleanup": 1.95, "length_px": 18, "weight": 5600.0, "length_mm": 1150.0, "visual": "sniper", "action": "bolt_action", "feed": "detachable_magazine", "modes": ["single"]},
	"lmg": {"automatic": true, "capacity": 100, "fire_interval": 0.086, "spread": 2.9, "growth": 0.50, "bonus": 4.8, "recovery": 2.4, "move_spread": 4.6, "turn_spread": 3.5, "aim": 6.4, "reload": 3.5, "move": 0.72, "reload_move": 0.48, "blood": 1.35, "blood_range": 178.0, "wall_reach": 62.0, "pattern": "fan", "cone": 0.62, "recoil": 0.8, "shake": 0.6, "flash": 35.0, "speed": 790.0, "knockback": 34.0, "noise": 255.0, "hit_stop": 0.043, "penetration": 1.35, "property": 1.4, "cleanup": 1.8, "length_px": 17, "weight": 7200.0, "length_mm": 930.0, "visual": "lmg", "action": "open_bolt", "feed": "belt", "modes": ["auto"]},
}

const BALLISTIC_CLASS_PROFILES := {
	"handgun": {"damage": 43.0, "falloff_start": 65.0, "falloff_end": 170.0, "min_damage": 0.62},
	"pdw": {"damage": 34.0, "falloff_start": 55.0, "falloff_end": 145.0, "min_damage": 0.52},
	"smg": {"damage": 40.0, "falloff_start": 70.0, "falloff_end": 175.0, "min_damage": 0.58},
	"shotgun": {"damage": 16.0, "falloff_start": 24.0, "falloff_end": 105.0, "min_damage": 0.38},
	"carbine": {"damage": 66.0, "falloff_start": 110.0, "falloff_end": 255.0, "min_damage": 0.78},
	"dmr": {"damage": 78.0, "falloff_start": 135.0, "falloff_end": 300.0, "min_damage": 0.82},
	"sniper": {"damage": 98.0, "falloff_start": 180.0, "falloff_end": 420.0, "min_damage": 0.90},
	"lmg": {"damage": 62.0, "falloff_start": 120.0, "falloff_end": 280.0, "min_damage": 0.75},
}
const CALIBER_DAMAGE_SCALE := {
	".45 ACP": 1.16, "5.7x28mm": 0.86, "4.6x30mm": 0.82,
	"5.45x39mm": 0.95, "7.62x39mm": 1.10, "7.62x51mm": 1.17,
	"7.62x54R": 1.20, ".338 LAPUA MAGNUM": 1.30, ".338 NORMA MAGNUM": 1.42,
	".50 BMG": 1.52, "9x39mm": 0.90,
}

# Short keys keep the production roster auditable without near-identical
# resources.  All numerical entries are tuned game conversions of the real
# platform's role, calibre, action, size and feeding system.
const PLATFORMS := {
	# Handguns
	"glock_17_gen5_mos": {"name": "GLOCK 17 GEN5 MOS", "maker": "GLOCK", "class": "handgun", "cal": "9x19mm", "cap": 17, "mag": "glock_9", "interfaces": ["pistol_mos", "pistol_rail", "muzzle_9", "glock_backstrap"], "weight": 625.0, "length_mm": 202.0, "trait": "FAST, LIGHT, BROAD ACCESSORY SUPPORT"},
	"fn_fiveseven_mrd": {"name": "FN FIVE-SEVEN MRD", "maker": "FN", "class": "handgun", "cal": "5.7x28mm", "cap": 20, "mag": "fiveseven", "interfaces": ["fn_mrd", "pistol_rail", "muzzle_57"], "recoil": 0.48, "penetration": 1.25, "blood": 0.75, "speed": 760.0, "trait": "LOW RECOIL, HIGH PENETRATION"},
	"colt_m1911a1": {"name": "COLT M1911A1", "maker": "COLT", "class": "handgun", "cal": ".45 ACP", "cap": 7, "mag": "m1911", "interfaces": ["muzzle_45"], "fire_interval": 0.175, "spread": 0.48, "blood": 1.28, "recoil": 1.05, "reload": 1.75, "trait": "CRISP TRIGGER, LOW CAPACITY"},
	# PDWs / micro SMGs
	"hk_mp5k_pdw": {"name": "HK MP5K-PDW", "maker": "HECKLER & KOCH", "class": "pdw", "cal": "9x19mm", "cap": 30, "mag": "mp5", "interfaces": ["mp5_claw", "tri_lug_9", "mp5_handguard", "mp5_stock"], "fire_interval": 0.075, "recoil": 0.34, "length_mm": 603.0, "trait": "ROLLER-DELAYED, COMPACT"},
	"fn_p90": {"name": "FN P90", "maker": "FN", "class": "pdw", "cal": "5.7x28mm", "cap": 50, "mag": "p90", "interfaces": ["p90_optic", "p90_muzzle"], "reload": 2.2, "penetration": 1.3, "blood": 0.72, "length_mm": 500.0, "trait": "TOP-FEED 50-ROUND MAGAZINE"},
	"hk_mp7a2": {"name": "HK MP7A2", "maker": "HECKLER & KOCH", "class": "pdw", "cal": "4.6x30mm", "cap": 40, "mag": "mp7", "interfaces": ["top_rail", "muzzle_46", "under_rail", "mp7_stock"], "fire_interval": 0.063, "recoil": 0.32, "penetration": 1.35, "blood": 0.66, "trait": "ARMOUR PENETRATION, LOW TRAUMA"},
	# Standard SMGs
	"hk_mp5a5": {"name": "HK MP5A5", "maker": "HECKLER & KOCH", "class": "smg", "cal": "9x19mm", "cap": 30, "mag": "mp5", "interfaces": ["mp5_claw", "tri_lug_9", "mp5_handguard", "mp5_stock"], "fire_interval": 0.075, "recoil": 0.30, "spread": 1.25, "trait": "REFERENCE-GRADE CONTROL"},
	"hk_ump45": {"name": "HK UMP45", "maker": "HECKLER & KOCH", "class": "smg", "cal": ".45 ACP", "cap": 25, "mag": "ump45", "interfaces": ["top_rail", "muzzle_45", "under_rail", "ump_stock"], "fire_interval": 0.10, "blood": 1.12, "recoil": 0.56, "penetration": 0.62, "trait": "SLOW, HEAVY .45 IMPULSE"},
	"kriss_vector_45": {"name": "KRISS VECTOR SMG .45", "maker": "KRISS", "class": "smg", "cal": ".45 ACP", "cap": 30, "mag": "glock_45", "interfaces": ["top_rail", "muzzle_45", "under_rail", "vector_stock"], "fire_interval": 0.05, "recoil": 0.26, "turn_spread": 2.6, "blood": 1.05, "trait": "VERY FAST, LOW MUZZLE CLIMB"},
	# Shotguns
	"mossberg_590a1": {"name": "MOSSBERG 590A1", "maker": "MOSSBERG", "class": "shotgun", "cal": "12 GA", "cap": 7, "mag": "tube_12", "interfaces": ["shotgun_top", "shotgun_forend", "shotgun_stock", "cylinder_bore"], "action": "pump_action", "feed": "tube", "pellets": 9, "pellet_spread": 6.25, "ballistic_damage": 18.0, "ballistic_falloff_start": 36.0, "ballistic_falloff_end": 130.0, "ballistic_min_damage": 0.46, "trait": "DENSE 00 BUCK, RUGGED PUMP-ACTION"},
	"benelli_m4": {"name": "BENELLI M4", "maker": "BENELLI", "class": "shotgun", "cal": "12 GA", "cap": 7, "mag": "tube_12", "interfaces": ["top_rail", "shotgun_forend", "m4_stock", "benelli_choke"], "action": "semi_auto_gas", "fire_interval": 0.25, "recoil": 1.35, "weight": 3810.0, "trait": "ARGO SEMI-AUTOMATIC"},
	"keltec_ksg": {"name": "KELTEC KSG", "maker": "KELTEC", "class": "shotgun", "cal": "12 GA", "cap": 14, "mag": "dual_tube_12", "interfaces": ["top_rail", "under_rail", "ksg_muzzle"], "action": "pump_action", "reload": 3.25, "length_mm": 663.0, "aim": 10.0, "trait": "DUAL-TUBE LOAD SELECTION"},
	# Assault rifles / carbines
	"colt_m4a1": {"name": "COLT M4A1", "maker": "COLT", "class": "carbine", "cal": "5.56x45mm", "cap": 30, "mag": "stanag_556", "interfaces": ["top_rail", "muzzle_556", "under_rail", "ar_stock"], "trait": "BALANCED MODULAR STANDARD"},
	"akm": {"name": "AKM", "maker": "KALASHNIKOV", "class": "carbine", "cal": "7.62x39mm", "cap": 30, "mag": "ak762", "interfaces": ["soviet_side_rail", "muzzle_762x39", "ak_handguard", "ak_stock"], "fire_interval": 0.10, "recoil": 1.0, "blood": 1.35, "penetration": 1.3, "trait": "HEAVY IMPULSE, HARD-HITTING"},
	# Semi-auto / DMR
	"fn_scar_17s": {"name": "FN SCAR 17S", "maker": "FN", "class": "dmr", "cal": "7.62x51mm", "cap": 20, "mag": "scar_762", "interfaces": ["top_rail", "muzzle_762", "under_rail", "scar_stock"], "trait": "MOBILE 7.62 BATTLE RIFLE"},
	"ruger_mini14_tactical": {"name": "RUGER MINI-14 TACTICAL", "maker": "RUGER", "class": "dmr", "cal": "5.56x45mm", "cap": 20, "mag": "mini14", "interfaces": ["mini14_rail", "muzzle_556", "mini14_stock"], "recoil": 0.72, "move": 0.91, "penetration": 1.15, "trait": "LIGHT, QUICK RECOVERY"},
	"dragunov_svd": {"name": "DRAGUNOV SVD", "maker": "KALASHNIKOV", "class": "dmr", "cal": "7.62x54R", "cap": 10, "mag": "svd", "interfaces": ["soviet_side_rail", "svd_muzzle", "svd_stock"], "spread": 0.34, "recoil": 1.42, "penetration": 1.85, "reload": 2.55, "trait": "LIGHT SEMI-AUTO MARKSMAN"},
	# Sniper rifles
	"remington_700_police": {"name": "REMINGTON 700 POLICE", "maker": "REMINGTON", "class": "sniper", "cal": "7.62x51mm", "cap": 5, "mag": "r700_internal", "interfaces": ["scope_rail", "muzzle_762", "precision_stock", "bipod_mount"], "feed": "internal_magazine", "trait": "ENTRY PRECISION BOLT-ACTION"},
	"barrett_m82a1": {"name": "BARRETT M82A1", "maker": "BARRETT", "class": "sniper", "cal": ".50 BMG", "cap": 10, "mag": "m82", "interfaces": ["scope_rail", "m82_muzzle", "bipod_mount"], "damage": 3, "action": "semi_auto_recoil", "fire_interval": 0.42, "recoil": 2.7, "blood": 2.8, "penetration": 3.0, "property": 3.0, "cleanup": 2.8, "noise": 340.0, "knockback": 58.0, "weight": 13500.0, "length_mm": 1450.0, "length_px": 22, "trait": "ANTI-MATERIEL SEMI-AUTO"},
	"vss_vintorez": {"name": "VSS VINTOREZ", "maker": "TSNIITOCHMASH", "class": "sniper", "cal": "9x39mm", "cap": 10, "mag": "vss", "interfaces": ["soviet_side_rail", "integral_suppressor", "vss_stock"], "action": "semi_auto_gas", "fire_interval": 0.19, "noise": 78.0, "speed": 520.0, "penetration": 1.45, "blood": 1.45, "aim": 8.2, "move": 0.9, "length_mm": 894.0, "trait": "INTEGRALLY SUPPRESSED SHORT-RANGE"},
	# LMG / GPMG
	"fn_m249_para": {"name": "FN M249 PARA", "maker": "FN", "class": "lmg", "cal": "5.56x45mm", "cap": 100, "mag": "belt_556", "interfaces": ["top_rail", "muzzle_556", "under_rail", "m249_stock", "bipod_mount"], "trait": "COMPACT BELT-FED SUPPORT"},
	"ultimax_100_mk8": {"name": "ULTIMAX 100 MK8", "maker": "ST KINETICS", "class": "lmg", "cal": "5.56x45mm", "cap": 100, "mag": "ultimax_drum", "interfaces": ["top_rail", "muzzle_556", "under_rail", "ultimax_stock", "bipod_mount"], "feed": "drum_magazine", "recoil": 0.45, "growth": 0.30, "capacity": 100, "trait": "CONSTANT-RECOIL CONTROL"},
	"fn_m240b": {"name": "FN M240B", "maker": "FN", "class": "lmg", "cal": "7.62x51mm", "cap": 100, "mag": "belt_762", "interfaces": ["top_rail", "m240_muzzle", "m240_stock", "bipod_mount"], "fire_interval": 0.095, "recoil": 1.25, "blood": 1.75, "penetration": 1.9, "property": 2.0, "cleanup": 2.25, "move": 0.62, "aim": 4.8, "weight": 12500.0, "length_mm": 1260.0, "length_px": 21, "trait": "HEAVY 7.62 GENERAL-PURPOSE MG"},
}

# Expansion platforms increase each family from six to eight while preserving
# stable IDs for every original save. Each addition occupies a different role
# inside its family instead of being a cosmetic duplicate.
const EXTRA_PLATFORMS := {
	# Handguns: compact striker and full-size modular duty pistol.
	# PDWs: controllable modern 9 mm carbine and ultra-compact machine pistol.
	# SMGs: classic straight-blowback and modernized Russian service pattern.
	# Shotguns: detachable-magazine semi-autos with contrasting weight and cycle.
	# Carbines: bullpup CQB and compact Swiss precision.
	"iwi_tavor_x95": {"name": "IWI TAVOR X95", "maker": "IWI", "class": "carbine", "cal": "5.56x45mm", "cap": 30, "mag": "stanag_556", "interfaces": ["top_rail", "muzzle_556", "under_rail", "bullpup_stock"], "weight": 3300.0, "length_mm": 580.0, "aim": 11.4, "move": 0.96, "reload": 2.26, "trait": "BULLPUP LENGTH, REARWARD RELOAD"},
	# DMR / battle rifles: precise AR-10 pattern and heavy full-power service rifle.
	# Snipers: modular magnum chassis and lighter rapid bolt-action.
	# Machine guns: classic general-purpose 7.62 and extreme-range .338 support.
}

static func canonical_id(weapon_id: String) -> String:
	return str(MERGED_PLATFORMS.get(weapon_id, ALIASES.get(weapon_id, weapon_id)))

static func has_weapon(weapon_id: String) -> bool:
	var resolved := canonical_id(weapon_id)
	return PLATFORMS.has(resolved) or EXTRA_PLATFORMS.has(resolved)

static func get_platform(weapon_id: String) -> Dictionary:
	var resolved := canonical_id(weapon_id)
	if EXTRA_PLATFORMS.has(resolved): return (EXTRA_PLATFORMS[resolved] as Dictionary).duplicate(true)
	return (PLATFORMS.get(resolved, PLATFORMS.glock_17_gen5_mos) as Dictionary).duplicate(true)

static func get_weapon_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for weapon_id in PLATFORMS: ids.append(str(weapon_id))
	for weapon_id in EXTRA_PLATFORMS: ids.append(str(weapon_id))
	return ids

static func get_class_weapon_ids(weapon_class: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for weapon_id in PLATFORMS:
		if str((PLATFORMS[weapon_id] as Dictionary).get("class", "")) == weapon_class: ids.append(str(weapon_id))
	for weapon_id in EXTRA_PLATFORMS:
		if str((EXTRA_PLATFORMS[weapon_id] as Dictionary).get("class", "")) == weapon_class: ids.append(str(weapon_id))
	return ids

static func get_all_gun_data() -> Dictionary:
	var result := {}
	for weapon_id in get_weapon_ids(): result[weapon_id] = create_gun_data(str(weapon_id))
	for alias_id in ALIASES: result[alias_id] = result[ALIASES[alias_id]]
	return result

static func create_gun_data(weapon_id: String, attachment_ids := PackedStringArray()) -> GunData:
	var resolved := canonical_id(weapon_id)
	var platform := get_platform(resolved)
	var weapon_class := str(platform.get("class", "handgun"))
	var values: Dictionary = (CLASS_DEFAULTS.get(weapon_class, CLASS_DEFAULTS.handgun) as Dictionary).duplicate(true)
	for key in platform: values[key] = platform[key]
	values["look_ahead"] = float(values.get("look_ahead", 1.0))
	var ballistic: Dictionary = BALLISTIC_CLASS_PROFILES.get(weapon_class, BALLISTIC_CLASS_PROFILES.handgun)
	var caliber_scale := float(CALIBER_DAMAGE_SCALE.get(str(values.get("cal", "9x19mm")), 1.0))
	# Old one-hit resources used values 1-3. Damage is now derived from role and
	# calibre so every one of the 64 platforms participates in the same model.
	values["damage"] = roundi(float(values.get("ballistic_damage", ballistic.damage)) * caliber_scale)
	values["falloff_start"] = float(values.get("ballistic_falloff_start", ballistic.falloff_start))
	values["falloff_end"] = float(values.get("ballistic_falloff_end", ballistic.falloff_end))
	values["min_damage"] = float(values.get("ballistic_min_damage", ballistic.min_damage))
	values = preload("res://utility/arcade_weapon_balance.gd").apply(values, resolved, weapon_class)
	if not attachment_ids.is_empty():
		values = WeaponStatResolver.resolve(values, attachment_ids)
	var data := GunData.new()
	data.weapon_id = resolved
	data.display_name = str(values.get("name", resolved.to_upper()))
	data.manufacturer = str(values.get("maker", ""))
	data.weapon_class = weapon_class
	data.caliber = str(values.get("cal", "9x19mm"))
	var blood_costs := {"handgun": 1.2, "pdw": 0.6, "smg": 0.6, "shotgun": 9.5, "carbine": 1.5, "dmr": 15.0, "sniper": 15.0, "lmg": 1.3}
	var stain_radii := {"handgun": 32.0, "pdw": 32.0, "smg": 32.0, "shotgun": 56.0, "carbine": 48.0, "dmr": 96.0, "sniper": 96.0, "lmg": 64.0}
	# Explicit platform overrides are absolute, never silently caliber-scaled.
	data.caliber_blood_cost = clampf(float(values.get("blood_cost", blood_costs.get(weapon_class, 1.2))), 0.1, 30.0)
	data.blood_stain_radius = clampf(float(values.get("stain_radius", stain_radii.get(weapon_class, 32.0))), 4.0, 320.0)
	data.action_type = str(values.get("action", "semi_auto"))
	data.feed_type = str(values.get("feed", "detachable_magazine"))
	data.magazine_family = str(values.get("mag", "generic"))
	data.fire_modes = PackedStringArray(values.get("modes", ["semi"]))
	data.interface_tags = PackedStringArray(values.get("interfaces", []))
	data.signature_trait = str(values.get("trait", ""))
	data.installed_attachments = PackedStringArray(values.get("accepted_attachments", attachment_ids))
	data.empty_weight_grams = float(values.get("weight", 700.0)) + float(values.get("attachment_weight", 0.0))
	data.overall_length_mm = float(values.get("length_mm", 200.0)) + float(values.get("attachment_length", 0.0))
	data.visual_length_pixels = int(values.get("length_px", 9))
	data.visual_profile = str(values.get("visual", weapon_class))
	data.automatic = bool(values.get("automatic", false))
	data.ammo_capacity = int(values.get("capacity", values.get("cap", 12)))
	data.damage = int(values.get("damage", 1))
	data.damage_falloff_start = float(values.get("falloff_start", 65.0))
	data.damage_falloff_end = float(values.get("falloff_end", 170.0))
	data.minimum_damage_ratio = float(values.get("min_damage", 0.62))
	data.fire_interval = float(values.get("fire_interval", 0.1))
	data.fire_interval_variance = float(values.get("variance", 0.01))
	data.spread_degrees = float(values.get("spread", 1.0))
	data.pellet_count = int(values.get("pellets", 1))
	data.pellet_spread_degrees = float(values.get("pellet_spread", 0.0))
	data.spread_growth_per_shot = float(values.get("growth", 0.0))
	data.maximum_spread_bonus = float(values.get("bonus", 0.0))
	data.spread_recovery = float(values.get("recovery", 4.0))
	data.movement_spread_degrees = float(values.get("move_spread", 2.0))
	data.turn_spread_degrees = float(values.get("turn_spread", 1.5))
	data.aim_follow_speed = float(values.get("aim", 12.0))
	data.reload_duration = float(values.get("reload", 1.8))
	data.movement_speed_multiplier = float(values.get("move", 1.0))
	data.reload_movement_multiplier = float(values.get("reload_move", 0.8))
	data.blood_power = float(values.get("blood", 1.0))
	data.blood_range = float(values.get("blood_range", 150.0))
	data.blood_wall_reach = float(values.get("wall_reach", 48.0))
	data.blood_pattern = str(values.get("pattern", "line"))
	data.blood_cone = float(values.get("cone", 0.24))
	data.recoil_strength = float(values.get("recoil", 0.7))
	data.camera_shake = float(values.get("shake", 0.7))
	data.muzzle_flash_size = float(values.get("flash", 26.0))
	data.muzzle_flash_duration = 0.05
	data.bullet_speed = float(values.get("speed", 650.0))
	data.knockback = float(values.get("knockback", 24.0))
	data.hearing_radius = float(values.get("noise", 190.0))
	data.hit_stop = float(values.get("hit_stop", 0.035))
	data.penetration_power = float(values.get("penetration", 0.8))
	data.property_damage = float(values.get("property", 0.8))
	data.cleanup_burden = float(values.get("cleanup", 1.0))
	data.aim_convergence_multiplier = float(values.get("aim_mult", 1.0))
	var base_length_mm := maxf(1.0, float(platform.get("length_mm", (CLASS_DEFAULTS.get(weapon_class, CLASS_DEFAULTS.handgun) as Dictionary).get("length_mm", 200.0))))
	data.weapon_length_multiplier = clampf(data.overall_length_mm / base_length_mm, 0.72, 1.35)
	data.camera_look_ahead_multiplier = clampf(float(values.get("look_ahead", 1.0)), 0.75, 1.55)
	data.death_style = "firearm_gib" if data.cleanup_burden >= 2.0 else ("firearm_torn" if data.cleanup_burden >= 1.4 else "firearm")
	data.shot_volume_db = -12.0 + clampf((data.hearing_radius - 120.0) / 35.0, 0.0, 7.0)
	data.mechanical_pitch = clampf(1.3 - data.empty_weight_grams / 11000.0, 0.65, 1.25)
	data.punch_pitch = clampf(1.0 - data.recoil_strength * 0.16, 0.45, 0.95)
	data.pitch_min = 0.96
	data.pitch_max = 1.04
	data.shot_stream = load("res://assets/audio/sfx/pistol_shot.wav")
	data.reload_stream = load("res://assets/audio/sfx/pistol_reload.wav")
	data.dry_fire_stream = load("res://assets/audio/sfx/dry_fire.wav")
	return data
