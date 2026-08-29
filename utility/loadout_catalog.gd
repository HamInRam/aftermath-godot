class_name LoadoutCatalog
extends RefCounted

const ORDER := ["balanced", "assault", "cleaner", "stealth"]
const KITS := {
	"balanced": {"name": "BALANCED KIT", "description": "PISTOL + SMG // STANDARD CLEANING", "guns": [0, 1], "reserve_magazines": 2, "cleaner_bonus": 0, "noise": 1.0, "move": 1.0},
	"assault": {"name": "ASSAULT KIT", "description": "SMG + LMG + SHOTGUN // FEWER CLEANERS", "guns": [1, 2, 3], "reserve_magazines": 1, "cleaner_bonus": -2, "noise": 1.10, "move": 0.94},
	"cleaner": {"name": "CLEANER KIT", "description": "PISTOL // EXTRA CHEMICALS + MOBILITY", "guns": [0], "reserve_magazines": 2, "cleaner_bonus": 4, "noise": 0.95, "move": 1.05},
	"stealth": {"name": "GHOST KIT", "description": "PISTOL // REDUCED REPORT // LIMITED ARSENAL", "guns": [0], "reserve_magazines": 2, "cleaner_bonus": 1, "noise": 0.58, "move": 1.02},
}

static func get_kit(kit_id: String) -> Dictionary:
	var resolved := kit_id if KITS.has(kit_id) else "balanced"
	var result: Dictionary = (KITS[resolved] as Dictionary).duplicate(true)
	result["id"] = resolved
	return result
