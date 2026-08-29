class_name PlaytestTelemetry
extends Node

const SAVE_PATH := "user://playtest_telemetry.json"
var mission_id := "unknown"
var run_started_ms := 0
var weapon_usage: Dictionary = {}
var deaths: Array[Dictionary] = []

func begin_run(new_mission_id: String) -> void:
	mission_id = new_mission_id
	run_started_ms = Time.get_ticks_msec()
	weapon_usage.clear()
	deaths.clear()
	if not Events.weapon_fired.is_connected(_on_weapon_fired): Events.weapon_fired.connect(_on_weapon_fired)

func _on_weapon_fired(_origin: Vector2, _direction: Vector2, enemy_owned: bool, weapon_id: String) -> void:
	if enemy_owned: return
	weapon_usage[weapon_id] = int(weapon_usage.get(weapon_id, 0)) + 1

func record_death(world_position: Vector2, room_id := "unknown") -> void:
	deaths.append({"x": roundi(world_position.x), "y": roundi(world_position.y), "room": room_id})

func complete_run(cleanup_ratio: float, combat_seconds: float, cleanup_seconds: float, evidence_left: int, alarms: int) -> void:
	if DisplayServer.get_name() == "headless": return
	var history: Array = _load_history()
	history.append({
		"mission": mission_id,
		"completed_at": Time.get_datetime_string_from_system(),
		"duration_seconds": snappedf(float(Time.get_ticks_msec() - run_started_ms) / 1000.0, 0.1),
		"combat_seconds": snappedf(combat_seconds, 0.1),
		"cleanup_seconds": snappedf(cleanup_seconds, 0.1),
		"cleanup_percent": roundi(cleanup_ratio * 100.0),
		"evidence_left": evidence_left,
		"alarms": alarms,
		"weapon_usage": weapon_usage.duplicate(true),
		"deaths": deaths.duplicate(true),
	})
	while history.size() > 100: history.pop_front()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(history, "\t"))

func _load_history() -> Array:
	if not FileAccess.file_exists(SAVE_PATH): return []
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []
