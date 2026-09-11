class_name FloorReport
extends RefCounted
## Typed combat result; Dictionary conversion belongs at the persistence boundary.
var rooms_cleared: int = 0
var best_combo: int = 0
var blood_build: String = "balanced"
var combat_perks: Array[String] = []
var kills: int = 0
var shots: int = 0
var alarms: int = 0
var property_damage: int = 0
var combat_route: int = 0
var combat_seconds: float = 0.0
var dominant_weapon: String = ""

func to_dictionary() -> Dictionary:
	return {"mode": "roguelike", "rooms_cleared": rooms_cleared, "best_combo": best_combo,
		"blood_build": blood_build, "combat_perks": combat_perks.duplicate(), "kills": kills,
		"shots": shots, "alarms": alarms, "property_damage": property_damage,
		"combat_route": combat_route, "combat_seconds": combat_seconds,
		"dominant_weapon": dominant_weapon, "traces": ["%d ROOMS CLEARED" % rooms_cleared]}
