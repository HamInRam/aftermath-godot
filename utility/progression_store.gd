class_name ProgressionStore
extends Node

const SCHEMA_VERSION := 6
const DEFAULT_SAVE_PATH := "user://aftermath_progress.json"
const UPGRADE_ORDER := ["mop", "capacity", "scanner", "body_handling", "pressure_washer"]
const UPGRADE_DEFINITIONS := {
	"mop": {"name": "MOP POWER", "description": "Stronger passes; level 3 unlocks a wider professional finish.", "base_cost": 120, "cost_step": 140},
	"capacity": {"name": "FIELD CAPACITY", "description": "Larger reservoir; level 2 expands batch evidence collection.", "base_cost": 110, "cost_step": 120},
	"scanner": {"name": "FORENSIC SCAN", "description": "Longer scan reach; level 2 prioritizes high-risk evidence.", "base_cost": 150, "cost_step": 150},
	"body_handling": {"name": "BODY HANDLING", "description": "Faster hauling; level 2 unlocks rapid two-stage sealing.", "base_cost": 140, "cost_step": 145},
	"pressure_washer": {"name": "PRESSURE WASHER", "description": "Faster pump, wider nozzle; level 3 detergent strips diluted and UV residue.", "base_cost": 180, "cost_step": 170},
}

var save_path := DEFAULT_SAVE_PATH
var data: Dictionary = {}
var current_mission_id := "nightclub"
var last_result: Dictionary = {}

func _init(custom_save_path := DEFAULT_SAVE_PATH) -> void:
	save_path = custom_save_path
	_reset_data()

func _ready() -> void:
	load_progress()

func _reset_data() -> void:
	data = {
		"schema_version": SCHEMA_VERSION,
		"completed_missions": [],
		"best_results": {},
		"credits": 0,
		"upgrades": {"mop": 0, "capacity": 0, "scanner": 0, "body_handling": 0, "pressure_washer": 0},
		"cleaner_mode": "normal",
		"specialization_points": 0,
		"specializations": {"executioner": 0, "ghost": 0, "cleaner": 0},
		"heat": 0,
		"current_contract_id": "standard",
		"current_kit_id": "balanced",
		"run_mode": "standard",
		"campaign_endings": [],
		"mission_attempts": {},
		"mastery": {},
		"current_modifier_id": "standard",
		"gauntlet_streak": 0,
		"career_stats": {"cases": 0, "shots": 0, "alarms": 0, "perfect_cleans": 0, "stolen_valuables": 0},
		"challenge_records": {},
	}
	current_mission_id = "nightclub"
	last_result = {}

func load_progress() -> bool:
	if not FileAccess.file_exists(save_path):
		_reset_data()
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_reset_data()
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_reset_data()
		return false
	var source_version := int(parsed.get("schema_version", 1))
	if source_version < 1 or source_version > SCHEMA_VERSION:
		_reset_data()
		return false
	var completed = parsed.get("completed_missions", [])
	var best_results = parsed.get("best_results", {})
	if not completed is Array or not best_results is Dictionary:
		_reset_data()
		return false
	data = {
		"schema_version": SCHEMA_VERSION,
		"completed_missions": completed.duplicate(),
		"best_results": best_results.duplicate(true),
		"credits": maxi(0, int(parsed.get("credits", 0))),
		"upgrades": (parsed.get("upgrades", {}) as Dictionary).duplicate(true),
		"cleaner_mode": str(parsed.get("cleaner_mode", "normal")),
		"specialization_points": maxi(0, int(parsed.get("specialization_points", 0))),
		"specializations": (parsed.get("specializations", {}) as Dictionary).duplicate(true),
		"heat": clampi(int(parsed.get("heat", 0)), 0, 100),
		"current_contract_id": str(parsed.get("current_contract_id", "standard")),
		"current_kit_id": str(parsed.get("current_kit_id", "balanced")),
		"run_mode": str(parsed.get("run_mode", "standard")),
		"campaign_endings": (parsed.get("campaign_endings", []) as Array).duplicate(),
		"mission_attempts": (parsed.get("mission_attempts", {}) as Dictionary).duplicate(true),
		"mastery": (parsed.get("mastery", {}) as Dictionary).duplicate(true),
		"current_modifier_id": str(parsed.get("current_modifier_id", "standard")),
		"gauntlet_streak": maxi(0, int(parsed.get("gauntlet_streak", 0))),
		"career_stats": (parsed.get("career_stats", {}) as Dictionary).duplicate(true),
		"challenge_records": (parsed.get("challenge_records", {}) as Dictionary).duplicate(true),
	}
	for upgrade_id in UPGRADE_ORDER:
		if not (data.upgrades as Dictionary).has(upgrade_id): data.upgrades[upgrade_id] = 0
	data.upgrades.erase("cleaner")
	for branch in ["executioner", "ghost", "cleaner"]:
		if not (data.specializations as Dictionary).has(branch): data.specializations[branch] = 0
	if str(data.run_mode) not in ["standard", "score_attack", "new_game_plus", "daily_challenge", "gauntlet"]: data.run_mode = "standard"
	if source_version < SCHEMA_VERSION: save_progress()
	return true

func save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func begin_mission(mission_id: String) -> bool:
	var profile := MissionCatalog.get_mission(mission_id)
	if profile == null or not is_mission_unlocked(profile): return false
	current_mission_id = mission_id
	var attempts: Dictionary = data.mission_attempts
	attempts[mission_id] = int(attempts.get(mission_id, 0)) + 1
	if get_run_mode() == "gauntlet" and mission_id == "nightclub": data.gauntlet_streak = 0
	data.current_modifier_id = str(RunModifierCatalog.select(mission_id, get_run_mode(), int(attempts[mission_id])).id)
	save_progress()
	return true

func record_mission_result(mission_id: String, score: int, grade: String, elapsed: float, cleanup_ratio: float, alarms: int, evidence_left: int, forensic_report := {}) -> bool:
	var profile := MissionCatalog.get_mission(mission_id)
	if profile == null: return false
	var completed: Array = data.completed_missions
	var first_completion := mission_id not in completed
	if first_completion: completed.append(mission_id)
	var result := {
		"mission_id": mission_id,
		"score": maxi(0, score),
		"grade": grade,
		"elapsed": maxf(0.0, elapsed),
		"cleanup_ratio": clampf(cleanup_ratio, 0.0, 1.0),
		"alarms": maxi(0, alarms),
		"evidence_left": maxi(0, evidence_left),
		"forensic_report": forensic_report.duplicate(true) if forensic_report is Dictionary else {},
	}
	_update_career_stats(cleanup_ratio, alarms, forensic_report)
	var contract_multiplier := float((forensic_report as Dictionary).get("contract_multiplier", 1.0)) if forensic_report is Dictionary else 1.0
	var contract_success := bool((forensic_report as Dictionary).get("contract_success", true)) if forensic_report is Dictionary else true
	var gauntlet_multiplier := 1.0
	if get_run_mode() == "gauntlet":
		data.gauntlet_streak = get_gauntlet_streak() + 1
		gauntlet_multiplier = 1.0 + minf(0.5, get_gauntlet_streak() * 0.04)
	var payout := maxi(50, roundi((float(score) * 0.12 + cleanup_ratio * 120.0 - float(evidence_left) * 2.0) * (contract_multiplier if contract_success else 0.75) * gauntlet_multiplier))
	data.credits = int(data.get("credits", 0)) + payout
	if first_completion: data.specialization_points = get_specialization_points() + 1
	var heat_delta := alarms * 7 + evidence_left - (8 if cleanup_ratio >= 0.999 else 0)
	data.heat = clampi(get_heat() + heat_delta, 0, 100)
	if mission_id == "last_call":
		var ending_id := _resolve_campaign_ending(cleanup_ratio, forensic_report)
		result["ending_id"] = ending_id
		if ending_id not in (data.campaign_endings as Array): data.campaign_endings.append(ending_id)
	result["payout"] = payout
	result["credits"] = int(data.credits)
	result["mastery"] = _record_mastery(mission_id, cleanup_ratio, alarms, forensic_report)
	result["gauntlet_streak"] = get_gauntlet_streak()
	if get_run_mode() == "daily_challenge":
		var daily_key := "%s:%s" % [Time.get_date_string_from_system(), mission_id]
		var previous_daily := int((data.challenge_records as Dictionary).get(daily_key, 0))
		data.challenge_records[daily_key] = maxi(previous_daily, score)
		result["daily_record"] = int(data.challenge_records[daily_key])
	var best_results: Dictionary = data.best_results
	var previous: Dictionary = best_results.get(mission_id, {})
	var new_best := previous.is_empty() or int(result.score) > int(previous.get("score", -1))
	result["first_completion"] = first_completion
	result["new_best"] = new_best
	last_result = result.duplicate(true)
	if new_best:
		best_results[mission_id] = result.duplicate(true)
	save_progress()
	return first_completion

func is_mission_completed(mission_id: String) -> bool:
	return mission_id in (data.completed_missions as Array)

func is_mission_unlocked(profile: MissionProfile) -> bool:
	if profile == null: return false
	return not profile.is_campaign_mission or profile.unlock_after.is_empty() or is_mission_completed(profile.unlock_after)

func get_best_result(mission_id: String) -> Dictionary:
	return (data.best_results as Dictionary).get(mission_id, {}).duplicate(true)

func get_next_unlocked_mission() -> MissionProfile:
	var next := MissionCatalog.get_next_mission(current_mission_id)
	return next if is_mission_unlocked(next) else null

func get_campaign_completion_count() -> int:
	var count := 0
	for profile in MissionCatalog.get_campaign_missions():
		if is_mission_completed(profile.mission_id): count += 1
	return count

func get_credits() -> int:
	return int(data.get("credits", 0))

func get_heat() -> int:
	return int(data.get("heat", 0))

func get_specialization_points() -> int:
	return int(data.get("specialization_points", 0))

func get_specialization_level(branch: String) -> int:
	return int((data.get("specializations", {}) as Dictionary).get(branch, 0))

func buy_specialization(branch: String) -> Dictionary:
	if branch not in ["executioner", "ghost", "cleaner"]: return {"success": false, "reason": "UNKNOWN SPECIALIZATION"}
	var level := get_specialization_level(branch)
	if level >= 3: return {"success": false, "reason": "ALREADY MAXED"}
	if get_specialization_points() <= 0: return {"success": false, "reason": "NO SPECIALIZATION POINTS"}
	data.specialization_points = get_specialization_points() - 1
	data.specializations[branch] = level + 1
	save_progress()
	return {"success": true, "branch": branch, "level": level + 1}

func get_current_contract_id() -> String:
	return str(data.get("current_contract_id", "standard"))

func get_current_kit_id() -> String:
	return str(data.get("current_kit_id", "balanced"))

func select_kit(kit_id: String) -> bool:
	if not LoadoutCatalog.KITS.has(kit_id): return false
	data.current_kit_id = kit_id
	return save_progress()

func cycle_kit() -> String:
	var index := LoadoutCatalog.ORDER.find(get_current_kit_id())
	var next_id: String = LoadoutCatalog.ORDER[(maxi(0, index) + 1) % LoadoutCatalog.ORDER.size()]
	select_kit(next_id)
	return next_id

func is_replay_mode_unlocked() -> bool:
	return is_mission_completed("last_call")

func get_run_mode() -> String:
	return str(data.get("run_mode", "standard"))

func cycle_run_mode() -> String:
	var modes := ["standard", "score_attack", "new_game_plus", "daily_challenge", "gauntlet"] if is_replay_mode_unlocked() else ["standard"]
	var index := modes.find(get_run_mode())
	data.run_mode = modes[(maxi(0, index) + 1) % modes.size()]
	save_progress()
	return get_run_mode()

func get_campaign_endings() -> Array:
	return (data.get("campaign_endings", []) as Array).duplicate()

func get_current_modifier_id() -> String:
	return str(data.get("current_modifier_id", "standard"))

func get_gauntlet_streak() -> int:
	return int(data.get("gauntlet_streak", 0))

func get_mastery(mission_id: String) -> Dictionary:
	return ((data.get("mastery", {}) as Dictionary).get(mission_id, {}) as Dictionary).duplicate(true)

func get_career_stats() -> Dictionary:
	return (data.get("career_stats", {}) as Dictionary).duplicate(true)

func get_daily_record(mission_id: String, date := Time.get_date_string_from_system()) -> int:
	return int((data.get("challenge_records", {}) as Dictionary).get("%s:%s" % [date, mission_id], 0))

func _update_career_stats(cleanup_ratio: float, alarms: int, forensic_report: Dictionary) -> void:
	var stats: Dictionary = data.career_stats
	stats.cases = int(stats.get("cases", 0)) + 1
	stats.shots = int(stats.get("shots", 0)) + int(forensic_report.get("shots", 0))
	stats.alarms = int(stats.get("alarms", 0)) + alarms
	if cleanup_ratio >= 0.999: stats.perfect_cleans = int(stats.get("perfect_cleans", 0)) + 1
	if bool(forensic_report.get("valuables_stolen", false)): stats.stolen_valuables = int(stats.get("stolen_valuables", 0)) + 1

func _record_mastery(mission_id: String, cleanup_ratio: float, alarms: int, forensic_report: Dictionary) -> Dictionary:
	var earned := {
		"ghost": alarms == 0,
		"restraint": int(forensic_report.get("shots", 999)) <= 8,
		"immaculate": cleanup_ratio >= 0.999,
		"total_recovery": int(forensic_report.get("bodies", 999)) == 0 and int(forensic_report.get("ballistic", 999)) == 0,
		"preservation": int(forensic_report.get("property_damage", 999)) == 0,
	}
	var previous: Dictionary = (data.mastery as Dictionary).get(mission_id, {})
	for key in earned: earned[key] = bool(earned[key]) or bool(previous.get(key, false))
	data.mastery[mission_id] = earned.duplicate(true)
	return earned

func _resolve_campaign_ending(cleanup_ratio: float, forensic_report: Dictionary) -> String:
	var stats := get_career_stats()
	if bool(forensic_report.get("cleanup_timed_out", false)) or cleanup_ratio < 0.90 or get_heat() >= 75: return "exposed"
	if int(stats.get("alarms", 0)) == 0 and int(stats.get("stolen_valuables", 0)) == 0: return "ghost"
	if int(stats.get("shots", 0)) >= 140 or int(stats.get("stolen_valuables", 0)) >= 5: return "kingpin"
	if cleanup_ratio >= 0.999 and get_heat() < 30 and not bool(forensic_report.get("valuables_stolen", false)): return "clean_break"
	return "professional"

func select_contract(contract_id: String) -> bool:
	if not ContractCatalog.CONTRACTS.has(contract_id): return false
	data.current_contract_id = contract_id
	return true

func get_upgrade_level(upgrade_id: String) -> int:
	return int((data.get("upgrades", {}) as Dictionary).get(upgrade_id, 0))

func has_upgrade_perk(perk_id: String) -> bool:
	match perk_id:
		"wide_finish": return get_upgrade_level("mop") >= 3
		"field_collector": return get_upgrade_level("capacity") >= 2
		"risk_triage": return get_upgrade_level("scanner") >= 2
		"rapid_seal": return get_upgrade_level("body_handling") >= 2
		"residue_strip": return get_upgrade_level("pressure_washer") >= 3
	return false

func get_upgrade_offer(upgrade_id: String) -> Dictionary:
	if upgrade_id not in UPGRADE_DEFINITIONS: return {}
	var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
	var level := clampi(get_upgrade_level(upgrade_id), 0, 3)
	return {
		"id": upgrade_id,
		"name": str(definition.name),
		"description": str(definition.description),
		"level": level,
		"next_level": mini(3, level + 1),
		"maxed": level >= 3,
		"cost": int(definition.base_cost) + level * int(definition.cost_step),
	}

func get_all_upgrade_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for upgrade_id in UPGRADE_ORDER: offers.append(get_upgrade_offer(upgrade_id))
	return offers

func get_next_upgrade_offer() -> Dictionary:
	for upgrade_id in UPGRADE_ORDER:
		var offer := get_upgrade_offer(upgrade_id)
		if bool(offer.get("maxed", false)): continue
		return {"id": upgrade_id, "level": int(offer.next_level), "cost": int(offer.cost)}
	return {}

func buy_upgrade(upgrade_id: String) -> Dictionary:
	var offer := get_upgrade_offer(upgrade_id)
	if offer.is_empty(): return {"success": false, "reason": "UNKNOWN UPGRADE"}
	if bool(offer.maxed): return {"success": false, "reason": "ALREADY MAXED"}
	if get_credits() < int(offer.cost): return {"success": false, "reason": "INSUFFICIENT FUNDS", "shortfall": int(offer.cost) - get_credits()}
	data.credits = get_credits() - int(offer.cost)
	data.upgrades[upgrade_id] = int(offer.next_level)
	save_progress()
	return {"success": true, "id": upgrade_id, "level": int(offer.next_level), "cost": int(offer.cost), "credits": get_credits()}

func buy_next_upgrade() -> bool:
	var offer := get_next_upgrade_offer()
	return not offer.is_empty() and bool(buy_upgrade(str(offer.id)).get("success", false))

func get_cleaner_mode() -> String:
	return str(data.get("cleaner_mode", "normal"))

func toggle_cleaner_mode() -> String:
	data.cleaner_mode = "professional" if get_cleaner_mode() == "normal" else "normal"
	save_progress()
	return get_cleaner_mode()

func reset_progress(delete_save := false) -> void:
	_reset_data()
	if delete_save and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
