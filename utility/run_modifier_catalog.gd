class_name RunModifierCatalog
extends RefCounted

const ORDER := ["standard", "blackout", "armed_response", "scarce_ammo", "forensic_nightmare"]
const MODIFIERS := {
	"standard": {"name": "STANDARD CONDITIONS", "description": "AUTHORED ENCOUNTER"},
	"blackout": {"name": "BLACKOUT", "description": "LOW VISIBILITY // STRONGER LOCAL LIGHTS"},
	"armed_response": {"name": "ARMED RESPONSE", "description": "MORE ASSAULT AND HEAVY OPERATORS"},
	"scarce_ammo": {"name": "SCARCE AMMO", "description": "AMMUNITION PICKUPS ARE HALVED"},
	"forensic_nightmare": {"name": "FORENSIC NIGHTMARE", "description": "MORE BLOOD // FASTER POLICE RESPONSE"},
}

static func get_modifier(modifier_id: String) -> Dictionary:
	var resolved := modifier_id if MODIFIERS.has(modifier_id) else "standard"
	var result: Dictionary = (MODIFIERS[resolved] as Dictionary).duplicate(true)
	result["id"] = resolved
	return result

static func select(mission_id: String, run_mode: String, attempt: int) -> Dictionary:
	if run_mode not in ["new_game_plus", "daily_challenge", "gauntlet"]: return get_modifier("standard")
	var seed_text := mission_id + ":" + (Time.get_date_string_from_system() if run_mode == "daily_challenge" else str(attempt))
	var index := posmod(seed_text.hash(), ORDER.size() - 1) + 1
	return get_modifier(ORDER[index])
