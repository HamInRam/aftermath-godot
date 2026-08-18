extends Node

var failures := 0

func _ready() -> void:
	var profile := MissionProfile.new()
	profile.required_eliminations = -1
	profile.required_security_shutdowns = 2
	profile.completion_bonus = 500
	profile.alarm_penalty = 125
	var tracker := MissionTracker.new()
	tracker.configure(profile, 3, 2)
	_expect(not tracker.are_combat_objectives_complete(), "fresh mission should not be complete")
	_expect(tracker.get_status_line() == "HOSTILES 00/03 // CAMERAS 0/2", "status should expose every mandatory objective")
	for index in range(3): tracker.record_enemy_eliminated()
	_expect(not tracker.are_combat_objectives_complete(), "eliminations alone should not bypass security objective")
	tracker.record_security_shutdown()
	tracker.record_alarm_trigger()
	tracker.record_security_shutdown()
	_expect(tracker.are_combat_objectives_complete(), "all configured objectives should complete the combat phase")
	_expect(tracker.get_score_modifier() == 375, "completion bonus should be reduced by alarm penalty")
	tracker.record_enemy_eliminated()
	tracker.record_security_shutdown()
	_expect(tracker.enemies_eliminated == 3 and tracker.security_shutdowns == 2, "objective counters should remain bounded by level totals")
	if failures == 0: print("mission objectives regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
