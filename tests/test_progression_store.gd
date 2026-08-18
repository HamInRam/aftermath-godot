extends Node

const TEST_SAVE_PATH := "user://aftermath_progress_test.json"

var failures := 0

func _ready() -> void:
	var store := ProgressionStore.new(TEST_SAVE_PATH)
	store.reset_progress(true)
	var campaign := MissionCatalog.get_campaign_missions()
	_expect(campaign.size() == 3, "catalog should expose three ordered campaign missions")
	_expect(campaign[0].mission_id == "nightclub" and campaign[2].mission_id == "after_hours", "campaign order should run from Nightclub to After Hours")
	_expect(store.is_mission_unlocked(campaign[0]), "first campaign mission should begin unlocked")
	_expect(not store.is_mission_unlocked(campaign[1]), "second campaign mission should begin locked")
	_expect(store.begin_mission("nightclub"), "unlocked mission should be selectable")
	_expect(not store.begin_mission("sandwich_shop"), "locked mission should reject selection")
	_expect(store.record_mission_result("nightclub", 1200, "A", 95.0, 0.9, 1, 3), "first recorded result should report a new completion")
	_expect(store.is_mission_unlocked(campaign[1]), "completing Nightclub should unlock Sandwich Shop")
	store.record_mission_result("nightclub", 800, "B", 120.0, 0.7, 2, 10)
	_expect(int(store.get_best_result("nightclub").score) == 1200, "lower replay score must not replace personal best")
	var reloaded := ProgressionStore.new(TEST_SAVE_PATH)
	_expect(reloaded.load_progress(), "saved campaign progress should reload from disk")
	_expect(reloaded.is_mission_completed("nightclub"), "completed mission should survive reload")
	_expect(int(reloaded.get_best_result("nightclub").score) == 1200, "best result should survive reload")
	_expect(reloaded.get_best_result("nightclub").grade == "A", "best grade metadata should remain attached to best score")
	reloaded.reset_progress(true)
	store.free()
	reloaded.free()
	if failures == 0: print("progression store regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
