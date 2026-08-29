extends Node

const GAMEPLAY_RULES := preload("res://utility/gameplay_design_rules.gd")

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
	var quiet_profile := MissionProfile.new()
	quiet_profile.completion_bonus = 100
	quiet_profile.optional_quiet_bonus = 75
	quiet_profile.maximum_alarms_for_bonus = 0
	quiet_profile.maximum_player_shots_for_bonus = 2
	quiet_profile.property_damage_penalty = 20
	var quiet_tracker := MissionTracker.new()
	quiet_tracker.configure(quiet_profile, 0, 0)
	quiet_tracker.record_player_shot()
	_expect(quiet_tracker.get_score_modifier() == 175, "meeting authored stealth and shot constraints should award the optional bonus")
	quiet_tracker.record_player_shot()
	quiet_tracker.record_player_shot()
	quiet_tracker.record_property_damage()
	_expect(quiet_tracker.get_score_modifier() == 80, "exceeding an optional constraint should remove its bonus and property damage should reduce score")
	_expect(ContractCatalog.evaluate("silent_blade", 1.0, 0, 0, false), "silent-blade contracts should reward zero-shot clears")
	_expect(not ContractCatalog.evaluate("asset_preservation", 1.0, 0, 0, false, 1), "asset-preservation contracts should fail on property damage")
	_expect(ContractCatalog.evaluate("total_recovery", 0.95, 0, 4, false, 0, 0, 0), "total-recovery contracts should require all bodies and ballistic evidence removed")
	profile.location_archetype = "TEST FLOOR"
	profile.expected_resistance = "HEAVY"
	profile.access_routes = 3
	var forecast := ContractCatalog.get_operational_forecast(profile, "cleaner", "ghost")
	_expect("3 ROUTES" in forecast and "CLEANER KIT" in forecast and "GHOST PROTOCOL" in forecast, "briefing forecast should connect mission, kit, and contract decisions")
	_expect("RESTORATION" in ContractCatalog.get_action_review({"property_damage": 4}), "action review should identify the dominant avoidable cost")
	_expect("BAG BODIES" in ContractCatalog.get_action_review({"bodies": 1}), "action review should teach the cleanup order")
	quiet_tracker.configure(quiet_profile, 0, 0)
	quiet_tracker.record_player_shot("shotgun")
	quiet_tracker.record_player_shot("shotgun")
	quiet_tracker.record_player_shot("pistol")
	_expect(quiet_tracker.get_dominant_weapon() == "shotgun", "mission reports should identify the weapon that drove the encounter")
	_expect(quiet_tracker.get_projected_weapon_cleanup_cost() > 0, "weapon choice should project a visible cleanup burden")
	_expect(float(AttackCatalog.get_aftermath_profile("shotgun").cleanup_load) > float(AttackCatalog.get_aftermath_profile("pistol").cleanup_load), "heavy firearm convenience must create a larger authored aftermath burden")
	_expect(not bool(GAMEPLAY_RULES.get_cleanup_tier(0.89).can_extract) and bool(GAMEPLAY_RULES.get_cleanup_tier(0.90).can_extract), "cleanup certification must use one centralized readable 90-percent threshold")
	_expect(str(GAMEPLAY_RULES.get_kit_aftermath([1, 2, 3]).label) == "HIGH", "assault loadouts should forecast their high cleanup consequence before deployment")
	profile.allowed_contracts = PackedStringArray(["standard", "ghost"])
	_expect(ContractCatalog.get_available_contracts(profile).size() == 2, "missions should whitelist compatible contracts instead of offering contradictory terms")
	var opening_case := MissionCatalog.get_mission("nightclub")
	var second_case := MissionCatalog.get_mission("sandwich_shop")
	var third_case := MissionCatalog.get_mission("after_hours")
	_expect(opening_case.signature_rule != second_case.signature_rule and second_case.signature_rule != third_case.signature_rule, "the first three cases must teach different authored combat-cleanup rules")
	if failures == 0: print("mission objectives regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
