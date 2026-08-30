class_name MissionTracker
extends RefCounted

signal objectives_changed

var profile: MissionProfile
var enemy_total := 0
var security_total := 0
var enemies_eliminated := 0
var security_shutdowns := 0
var alarm_triggers := 0
var player_shots := 0
var property_damage := 0
var weapon_shots: Dictionary = {}

func configure(mission_profile: MissionProfile, total_enemies: int, total_security: int) -> void:
	profile = mission_profile
	enemy_total = maxi(0, total_enemies)
	security_total = maxi(0, total_security)
	enemies_eliminated = 0
	security_shutdowns = 0
	alarm_triggers = 0
	player_shots = 0
	property_damage = 0
	weapon_shots.clear()
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

func record_player_shot(weapon_id := "unknown") -> void:
	player_shots += 1
	weapon_shots[weapon_id] = int(weapon_shots.get(weapon_id, 0)) + 1
	objectives_changed.emit()

func get_dominant_weapon() -> String:
	var result := "none"
	var highest := 0
	for weapon_id in weapon_shots:
		var count := int(weapon_shots[weapon_id])
		if count > highest:
			highest = count
			result = str(weapon_id)
	return result

func get_projected_weapon_cleanup_cost() -> int:
	var total := 0.0
	for weapon_id in weapon_shots:
		var violence := AttackCatalog.get_violence_profile(str(weapon_id))
		total += int(weapon_shots[weapon_id]) * (1.0 + float(violence.get("gore", 0)) * 0.45 + float(violence.get("pool_bias", 1.0)))
	return roundi(total)

func record_property_damage() -> void:
	property_damage += 1
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
	if profile != null and profile.maximum_alarms_for_bonus >= 0: line += " // STEALTH %d/%d" % [alarm_triggers, profile.maximum_alarms_for_bonus]
	if profile != null and profile.maximum_player_shots_for_bonus >= 0: line += " // SHOTS %d/%d" % [player_shots, profile.maximum_player_shots_for_bonus]
	return line

func get_score_modifier() -> int:
	if profile == null: return 0
	var completion_score := profile.completion_bonus if are_combat_objectives_complete() else 0
	var quiet_success := (profile.maximum_alarms_for_bonus < 0 or alarm_triggers <= profile.maximum_alarms_for_bonus) and (profile.maximum_player_shots_for_bonus < 0 or player_shots <= profile.maximum_player_shots_for_bonus)
	var quiet_bonus := profile.optional_quiet_bonus if quiet_success and (profile.maximum_alarms_for_bonus >= 0 or profile.maximum_player_shots_for_bonus >= 0) else 0
	return completion_score + quiet_bonus - alarm_triggers * profile.alarm_penalty - property_damage * profile.property_damage_penalty
