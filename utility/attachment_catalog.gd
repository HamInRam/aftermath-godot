class_name AttachmentCatalog
extends RefCounted

const SLOT_ORDER := ["muzzle", "optic", "underbarrel", "magazine", "stock"]
const SLOT_NAMES := {"muzzle": "MUZZLE", "optic": "OPTIC", "underbarrel": "UNDERBARREL", "magazine": "MAG / AMMO", "stock": "STOCK / GRIP"}

# Compatibility describes game-facing real interfaces.  The system never treats
# a Picatinny optic, pistol MOS plate, MP5 claw mount or Soviet side rail as the
# same attachment point.
const ATTACHMENTS := {
	# Muzzle devices
	"silencerco_omega_9k": {"name": "SILENCERCO OMEGA 9K", "slot": "muzzle", "requires_any": ["muzzle_9"], "weight": 220.0, "length": 123.0, "mul": {"noise": 0.62, "flash": 0.52, "aim": 0.94, "move": 0.98, "speed": 0.97}, "tags": ["suppressed"], "summary": "QUIETER 9MM REPORT // LONGER FRONT END"},
	"bt_rbs_sqd_9": {"name": "B&T RBS SQD 9", "slot": "muzzle", "requires_any": ["tri_lug_9"], "weight": 360.0, "length": 130.0, "mul": {"noise": 0.58, "flash": 0.48, "aim": 0.92, "move": 0.97}, "tags": ["suppressed"], "summary": "MP5 TRI-LUG SUPPRESSION"},
	"surefire_socom556_rc2": {"name": "SUREFIRE SOCOM556-RC2", "slot": "muzzle", "requires_any": ["muzzle_556"], "weight": 480.0, "length": 160.0, "mul": {"noise": 0.66, "flash": 0.42, "recoil": 0.94, "aim": 0.90, "move": 0.96}, "tags": ["suppressed"], "summary": "5.56 SIGNATURE REDUCTION"},
	"surefire_socom762_rc2": {"name": "SUREFIRE SOCOM762-RC2", "slot": "muzzle", "requires_any": ["muzzle_762"], "weight": 560.0, "length": 216.0, "mul": {"noise": 0.68, "flash": 0.44, "recoil": 0.92, "aim": 0.87, "move": 0.95}, "tags": ["suppressed"], "summary": "7.62 SUPPRESSION // HEAVY"},
	"obsidian_45": {"name": "RUGGED OBSIDIAN 45", "slot": "muzzle", "requires_any": ["muzzle_45"], "weight": 365.0, "length": 206.0, "mul": {"noise": 0.60, "flash": 0.46, "aim": 0.88, "move": 0.96}, "tags": ["suppressed"], "summary": ".45 SUPPRESSION // SLOWER HANDLING"},
	"warcomp_556": {"name": "SUREFIRE WARCOMP 556", "slot": "muzzle", "requires_any": ["muzzle_556"], "weight": 110.0, "length": 67.0, "mul": {"recoil": 0.87, "flash": 0.78, "noise": 1.10}, "summary": "CONTROLLED MUZZLE RISE // LOUDER"},
	"precision_brake_762": {"name": "7.62 PRECISION BRAKE", "slot": "muzzle", "requires_any": ["muzzle_762", "muzzle_338"], "weight": 180.0, "length": 75.0, "mul": {"recoil": 0.76, "noise": 1.18, "flash": 1.12}, "summary": "MAJOR RECOIL CONTROL // EXTREME BLAST"},
	"shotgun_breacher": {"name": "STANDOFF BREACHER", "slot": "muzzle", "requires_any": ["cylinder_bore", "rem_choke", "benelli_choke", "beretta_choke", "ksg_muzzle"], "weight": 150.0, "length": 55.0, "mul": {"property": 1.20, "aim": 0.95, "noise": 1.05}, "summary": "DOOR / PROP DAMAGE // EXTRA LENGTH"},
	"modified_choke": {"name": "MODIFIED CHOKE", "slot": "muzzle", "requires_any": ["rem_choke", "benelli_choke", "beretta_choke", "saiga_choke", "vepr_choke"], "weight": 35.0, "length": 18.0, "mul": {"pellet_spread": 0.76, "aim": 0.98}, "summary": "TIGHTER PELLET PATTERN"},
	# Optics
	"trijicon_rmr_type2": {"name": "TRIJICON RMR TYPE 2", "slot": "optic", "requires_any": ["pistol_mos", "fn_mrd"], "weight": 34.0, "length": 0.0, "mul": {"spread": 0.90, "aim": 1.08, "turn_spread": 0.88, "look_ahead": 1.05}, "summary": "FASTER HANDGUN ALIGNMENT"},
	"leupold_deltapoint_pro": {"name": "LEUPOLD DELTAPOINT PRO", "slot": "optic", "requires_any": ["dpp_optic"], "weight": 54.0, "length": 0.0, "mul": {"spread": 0.88, "aim": 1.07, "turn_spread": 0.86, "look_ahead": 1.05}, "summary": "M17 OPTIC-PLATE RED DOT"},
	"aimpoint_micro_t2": {"name": "AIMPOINT MICRO T-2", "slot": "optic", "requires_any": ["top_rail", "mp5_claw", "p90_optic", "mini14_rail"], "weight": 130.0, "length": 0.0, "mul": {"spread": 0.88, "aim": 1.10, "move_spread": 0.90, "look_ahead": 1.08}, "summary": "FAST CLOSE-RANGE DOT"},
	"eotech_exps3": {"name": "EOTECH EXPS3", "slot": "optic", "requires_any": ["top_rail", "mp5_claw"], "weight": 317.0, "length": 0.0, "mul": {"spread": 0.86, "aim": 1.06, "move_spread": 0.84, "move": 0.99, "look_ahead": 1.08}, "summary": "FAST TRANSITIONS // HEAVIER"},
	"trijicon_acog_ta31": {"name": "TRIJICON ACOG TA31", "slot": "optic", "requires_any": ["top_rail", "scope_rail"], "weight": 430.0, "length": 0.0, "mul": {"spread": 0.72, "aim": 0.86, "move_spread": 1.12, "turn_spread": 1.10, "look_ahead": 1.30}, "summary": "4X PRECISION // SLOW IN ROOMS"},
	"nightforce_atacr_1_8": {"name": "NIGHTFORCE ATACR 1-8X", "slot": "optic", "requires_any": ["top_rail", "scope_rail"], "weight": 595.0, "length": 0.0, "mul": {"spread": 0.65, "aim": 0.78, "move_spread": 1.18, "turn_spread": 1.18, "move": 0.97, "look_ahead": 1.48}, "summary": "LONG LOOK-AHEAD // SLOW ACQUISITION"},
	"pso1": {"name": "PSO-1", "slot": "optic", "requires_any": ["soviet_side_rail"], "weight": 620.0, "length": 0.0, "mul": {"spread": 0.72, "aim": 0.82, "move_spread": 1.15, "look_ahead": 1.32}, "summary": "SOVIET 4X SIDE-RAIL OPTIC"},
	# Underbarrel / illumination
	"surefire_x300u": {"name": "SUREFIRE X300U", "slot": "underbarrel", "requires_any": ["pistol_rail", "pistol_rail_proprietary"], "weight": 113.0, "length": 0.0, "mul": {"aim": 0.98}, "tags": ["white_light"], "summary": "DARK-ROOM IDENTIFICATION // VISIBLE"},
	"peq15": {"name": "AN/PEQ-15", "slot": "underbarrel", "requires_any": ["under_rail", "top_rail", "ak_handguard"], "weight": 213.0, "length": 0.0, "mul": {"move_spread": 0.82, "turn_spread": 0.86}, "tags": ["visible_laser"], "summary": "BETTER POINT-FIRE // LASER REVEALS AIM"},
	"vertical_grip": {"name": "VERTICAL FOREGRIP", "slot": "underbarrel", "requires_any": ["under_rail", "ak_handguard"], "weight": 115.0, "length": 0.0, "mul": {"recoil": 0.84, "aim": 0.94, "move": 0.99}, "summary": "SUSTAINED CONTROL // SLOWER PRESENTATION"},
	"angled_grip": {"name": "ANGLED FOREGRIP", "slot": "underbarrel", "requires_any": ["under_rail", "ak_handguard"], "weight": 85.0, "length": 0.0, "mul": {"recoil": 0.92, "aim": 1.07, "turn_spread": 0.90}, "summary": "QUICK PRESENTATION"},
	"harris_bipod": {"name": "HARRIS S-BRM BIPOD", "slot": "underbarrel", "requires_any": ["bipod_mount", "under_rail"], "weight": 370.0, "length": 0.0, "mul": {"spread": 0.78, "recoil": 0.72, "aim": 0.76, "move": 0.94}, "tags": ["bipod"], "summary": "STATIONARY PRECISION // HEAVY"},
	# Magazine / ammunition packages
	"glock_24_mag": {"name": "GLOCK 24-ROUND MAGAZINE", "slot": "magazine", "mag_family": ["glock_9"], "weight": 90.0, "length": 0.0, "add": {"capacity": 7}, "mul": {"reload": 1.05, "aim": 0.98}, "summary": "24 ROUNDS // LONGER GRIP"},
	"p320_21_mag": {"name": "P320 21-ROUND MAGAZINE", "slot": "magazine", "mag_family": ["p320_9"], "weight": 80.0, "length": 0.0, "add": {"capacity": 4}, "mul": {"reload": 1.03}, "summary": "21 ROUNDS"},
	"stanag_40_mag": {"name": "40-ROUND STANAG MAGAZINE", "slot": "magazine", "mag_family": ["stanag_556"], "weight": 170.0, "length": 0.0, "add": {"capacity": 10}, "mul": {"reload": 1.08, "aim": 0.96, "move": 0.99}, "summary": "40 ROUNDS // SLOWER RELOAD"},
	"magpul_d60": {"name": "MAGPUL D-60", "slot": "magazine", "mag_family": ["stanag_556"], "weight": 570.0, "length": 0.0, "add": {"capacity": 30}, "mul": {"reload": 1.28, "aim": 0.88, "move": 0.95}, "summary": "60 ROUNDS // HEAVY DRUM"},
	"scar_25_mag": {"name": "SCAR 25-ROUND MAGAZINE", "slot": "magazine", "mag_family": ["scar_762"], "weight": 180.0, "length": 0.0, "add": {"capacity": 5}, "mul": {"reload": 1.10, "move": 0.98}, "summary": "25 ROUNDS // EXTRA BULK"},
	"subsonic_ammunition": {"name": "SUBSONIC AMMUNITION", "slot": "magazine", "classes": ["handgun", "pdw", "smg", "carbine", "dmr"], "weight": 0.0, "length": 0.0, "mul": {"noise": 0.82, "speed": 0.79, "penetration": 0.82, "blood": 0.94}, "tags": ["subsonic"], "summary": "LOWER SIGNATURE // LOWER VELOCITY"},
	"armor_piercing_ammunition": {"name": "ARMOUR-PIERCING AMMUNITION", "slot": "magazine", "classes": ["handgun", "pdw", "smg", "carbine", "dmr", "sniper", "lmg"], "weight": 0.0, "length": 0.0, "mul": {"penetration": 1.28, "property": 1.22, "blood": 0.88, "cleanup": 1.08}, "summary": "MORE PENETRATION AND PROPERTY DAMAGE"},
	"hollow_point_ammunition": {"name": "HOLLOW-POINT AMMUNITION", "slot": "magazine", "classes": ["handgun", "pdw", "smg"], "weight": 0.0, "length": 0.0, "mul": {"penetration": 0.62, "blood": 1.28, "cleanup": 1.24, "knockback": 1.08}, "summary": "MORE TISSUE DAMAGE // LESS PENETRATION"},
	"shotgun_slug": {"name": "12 GA SLUG", "slot": "magazine", "classes": ["shotgun"], "weight": 0.0, "length": 0.0, "set": {"pellets": 1, "pellet_spread": 0.0}, "mul": {"spread": 0.55, "penetration": 1.85, "property": 1.35, "blood": 0.86}, "summary": "SINGLE PROJECTILE // HIGH PENETRATION"},
	# Stocks and grip modules
	"lightweight_stock": {"name": "LIGHTWEIGHT STOCK", "slot": "stock", "requires_any": ["ar_stock", "rear_rail", "scar_stock", "ak_stock", "mp5_stock", "ump_stock", "ace_stock"], "weight": -140.0, "length": -35.0, "mul": {"aim": 1.10, "move": 1.03, "recoil": 1.16, "spread": 1.06}, "summary": "FAST HANDLING // MORE RECOIL"},
	"precision_stock": {"name": "PRECISION STOCK", "slot": "stock", "requires_any": ["ar_stock", "scar_stock", "precision_stock", "m14_stock", "svd_stock"], "weight": 360.0, "length": 28.0, "mul": {"spread": 0.84, "recoil": 0.82, "aim": 0.88, "move": 0.96}, "summary": "STABLE FIRE // SLOW HANDLING"},
	"folding_stock": {"name": "FOLDING STOCK", "slot": "stock", "requires_any": ["rear_rail", "mp5_stock", "ump_stock", "ak_stock", "scar_stock", "uzi_stock", "mp7_stock", "mp9_stock"], "weight": -80.0, "length": -120.0, "mul": {"aim": 1.12, "move": 1.03, "recoil": 1.22, "spread": 1.08}, "summary": "SHORT IN DOORWAYS // LESS CONTROL"},
	"weighted_grip_module": {"name": "WEIGHTED GRIP MODULE", "slot": "stock", "requires_any": ["p320_grip", "glock_backstrap"], "weight": 120.0, "length": 0.0, "mul": {"recoil": 0.86, "aim": 0.96, "move": 0.99}, "summary": "SOFTER HANDGUN RECOIL"},
}

static func get_attachment(attachment_id: String) -> Dictionary:
	return (ATTACHMENTS.get(attachment_id, {}) as Dictionary).duplicate(true)

static func get_attachment_ids_for_slot(slot: String, platform: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for attachment_id in ATTACHMENTS:
		var attachment := ATTACHMENTS[attachment_id] as Dictionary
		if str(attachment.get("slot", "")) == slot and is_compatible(attachment, platform): result.append(str(attachment_id))
	return result

static func is_compatible(attachment: Dictionary, platform: Dictionary) -> bool:
	var platform_interfaces: Array = platform.get("interfaces", []) as Array
	if str(attachment.get("slot", "")) == "muzzle" and "integral_suppressor" in platform_interfaces: return false
	var required: Array = attachment.get("requires_any", []) as Array
	if not required.is_empty():
		var matched := false
		for interface_id in required:
			if interface_id in platform_interfaces: matched = true; break
		if not matched: return false
	var classes: Array = attachment.get("classes", []) as Array
	if not classes.is_empty() and str(platform.get("class", "")) not in classes: return false
	var magazine_families: Array = attachment.get("mag_family", []) as Array
	if not magazine_families.is_empty() and str(platform.get("mag", "")) not in magazine_families: return false
	return true
