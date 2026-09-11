class_name LoadoutCatalog
extends RefCounted

const ORDER := ["custom", "balanced", "assault", "cleaner", "stealth"]
const KITS := {
	"custom": {"name": "CUSTOM LOADOUT", "description": "PERSONAL PRIMARY + SECONDARY // SAVED BUILDS", "guns": [], "reserve_magazines": 2, "cleaner_bonus": 0, "noise": 1.0, "move": 1.0, "armor": [1.0, 0.18, 34.0, false]},
	"balanced": {"name": "BALANCED KIT", "description": "COLT M4A1 + GLOCK 17 // STANDARD CLEANING", "guns": ["colt_m4a1", "glock_17_gen5_mos"], "reserve_magazines": 2, "cleaner_bonus": 0, "noise": 1.0, "move": 1.0, "armor": [1.0, 0.18, 34.0, false]},
	"assault": {"name": "ASSAULT KIT", "description": "M249 PARA + MOSSBERG 590A1 // FEWER CLEANERS", "guns": ["fn_m249_para", "mossberg_590a1"], "reserve_magazines": 1, "cleaner_bonus": -2, "noise": 1.10, "move": 0.94, "armor": [1.55, 0.32, 58.0, true]},
	"cleaner": {"name": "CLEANER KIT", "description": "GLOCK 17 // EXTRA CHEMICALS + MOBILITY", "guns": ["glock_17_gen5_mos"], "reserve_magazines": 2, "cleaner_bonus": 4, "noise": 0.95, "move": 1.05, "armor": [0.0, 0.0, 0.0, false]},
	"stealth": {"name": "GHOST KIT", "description": "MP5 + GLOCK // LOW REPORT", "guns": ["hk_mp5a5", "glock_17_gen5_mos"], "reserve_magazines": 2, "cleaner_bonus": 1, "noise": 0.72, "move": 1.01, "armor": [0.7, 0.12, 20.0, false]},
}

static func get_kit(kit_id: String) -> Dictionary:
	var resolved := kit_id if KITS.has(kit_id) else "balanced"
	var result: Dictionary = (KITS[resolved] as Dictionary).duplicate(true)
	if resolved == "custom": result.guns = Array(Progression.get_loadout_weapon_ids())
	result["id"] = resolved
	return result
