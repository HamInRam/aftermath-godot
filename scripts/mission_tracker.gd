class_name MissionTracker
extends RefCounted

signal objectives_changed

var profile: MissionProfile
var enemy_total := 0
var security_total := 0
var enemies_eliminated := 0
var security_shutdowns := 0
var alarm_triggers := 0

func configure(mission_profile: MissionProfile, total_enemies: int, total_security: int) -> void:
	profile = mission_profile
	enemy_total = maxi(0, total_enemies)
	security_total = maxi(0, total_security)
	enemies_eliminated = 0
	security_shutdowns = 0
	alarm_triggers = 0
	objectives_changed.emit()

func record_enemy_eliminated() -> void:
	enemies_eliminated = mini(enemy_total, enemies_eliminated + 1)
	objectives_changed.emit()

func record_security_shutdown() -> void:
	security_shutdowns = mini(security_total, security_shutdowns + 1)
	objectives_changed.emit()

func record_alarm_trigger() -> void:
	alarm_triggers += 1
	objectives_changed.emit()

func get_required_eliminations() -> int:
	if profile == null or profile.required_eliminations < 0: return enemy_total
	return mini(enemy_total, profile.required_eliminations)

func get_required_security_shutdowns() -> int:
	if profile == null: return 0
	return mini(security_total, maxi(0, profile.required_security_shutdowns))

func are_combat_objectives_complete() -> bool:
	return enemies_eliminated >= get_required_eliminations() and security_shutdowns >= get_required_security_shutdowns()

func get_status_line() -> String:
	var line := "HOSTILES %02d/%02d" % [enemies_eliminated, get_required_eliminations()]
	var security_required := get_required_security_shutdowns()
	if security_required > 0: line += " // CAMERAS %d/%d" % [security_shutdowns, security_required]
	return line

func get_score_modifier() -> int:
	if profile == null: return 0
	var completion_score := profile.completion_bonus if are_combat_objectives_complete() else 0
	return completion_score - alarm_triggers * profile.alarm_penalty
