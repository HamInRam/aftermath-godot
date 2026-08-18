class_name ProgressionStore
extends Node

const SCHEMA_VERSION := 1
const DEFAULT_SAVE_PATH := "user://aftermath_progress.json"

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
	if not parsed is Dictionary or int(parsed.get("schema_version", -1)) != SCHEMA_VERSION:
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
	}
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
	return true

func record_mission_result(mission_id: String, score: int, grade: String, elapsed: float, cleanup_ratio: float, alarms: int, evidence_left: int) -> bool:
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
	}
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

func reset_progress(delete_save := false) -> void:
	_reset_data()
	if delete_save and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
