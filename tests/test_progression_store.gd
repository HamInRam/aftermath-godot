extends Node

const TEST_SAVE_PATH := "user://aftermath_progress_test.json"

var failures := 0

func _ready() -> void:
	var store := ProgressionStore.new(TEST_SAVE_PATH)
	store.reset_progress(true)
	var campaign := MissionCatalog.get_campaign_missions()
	_expect(campaign.size() == 12, "catalog should expose the complete twelve-case campaign")
	_expect(campaign[0].mission_id == "nightclub" and campaign[11].mission_id == "last_call", "campaign order should run from Nightclub to Last Call")
	_expect(store.is_mission_unlocked(campaign[0]), "first campaign mission should begin unlocked")
	_expect(not store.is_mission_unlocked(campaign[1]), "second campaign mission should begin locked")
	_expect(store.begin_mission("nightclub"), "unlocked mission should be selectable")
	_expect(not store.begin_mission("sandwich_shop"), "locked mission should reject selection")
	_expect(store.record_mission_result("nightclub", 1200, "A", 95.0, 0.9, 1, 3), "first recorded result should report a new completion")
	_expect(store.get_credits() > 0 and int(store.last_result.get("payout", 0)) > 0, "completed cleanup work should award persistent career credits")
	_expect(store.get_specialization_points() == 1, "first-time case completion should award one specialization point")
	_expect(bool(store.buy_specialization("ghost").get("success", false)) and store.get_specialization_level("ghost") == 1, "safehouse should spend points on a selected specialization")
	_expect(store.select_contract("immaculate") and store.get_current_contract_id() == "immaculate", "briefing should persist a valid selected contract")
	_expect(store.select_kit("stealth") and store.get_current_kit_id() == "stealth", "briefing should persist a selected field kit")
	_expect(store.cycle_kit() == "balanced", "field-kit cycling should wrap through the authored kit order")
	_expect(store.get_run_mode() == "standard" and not store.is_replay_mode_unlocked(), "replay modes should remain locked before the finale")
	var offer := store.get_next_upgrade_offer()
	store.data.credits = int(offer.cost)
	_expect(store.buy_next_upgrade() and store.get_upgrade_level(str(offer.id)) == 1, "career credits should purchase the next persistent tool upgrade")
	var insufficient := store.buy_upgrade("pressure_washer")
	_expect(not bool(insufficient.get("success", false)) and str(insufficient.get("reason", "")) == "INSUFFICIENT FUNDS", "chosen upgrades should report insufficient funds instead of failing silently")
	store.data.upgrades.mop = 3
	store.data.upgrades.capacity = 3
	var streamlined_offer := store.get_next_upgrade_offer()
	_expect(str(streamlined_offer.get("id", "")) == "scanner", "career offers must skip the retired single-use cleaner upgrade")
	store.data.credits = 9999
	var chosen := store.buy_upgrade("scanner")
	_expect(bool(chosen.get("success", false)) and store.get_upgrade_level("scanner") == 1, "workshop purchases should support a player-selected upgrade route")
	store.data.upgrades.body_handling = 2
	store.data.upgrades.capacity = 2
	_expect(store.has_upgrade_perk("rapid_seal") and store.has_upgrade_perk("field_collector"), "career levels should unlock mechanical perks instead of only invisible percentages")
	_expect(store.toggle_cleaner_mode() == "professional" and store.toggle_cleaner_mode() == "normal", "cleaner guidance mode should persistently toggle")
	_expect(store.is_mission_unlocked(campaign[1]), "completing Nightclub should unlock Sandwich Shop")
	store.data.completed_missions.append("last_call")
	_expect(store.is_replay_mode_unlocked() and store.cycle_run_mode() == "score_attack" and store.cycle_run_mode() == "new_game_plus", "finishing Last Call should unlock both replay modes")
	_expect(store.cycle_run_mode() == "daily_challenge" and store.cycle_run_mode() == "gauntlet", "campaign completion should unlock seeded daily and continuous gauntlet modes")
	var daily_a := RunModifierCatalog.select("nightclub", "daily_challenge", 1)
	var daily_b := RunModifierCatalog.select("nightclub", "daily_challenge", 99)
	_expect(daily_a.id == daily_b.id and daily_a.id != "standard", "daily challenge conditions should be deterministic for every player on the same date")
	store.record_mission_result("nightclub", 1000, "A", 88.0, 1.0, 0, 0, {"shots": 4})
	var mastery := store.get_mastery("nightclub")
	_expect(bool(mastery.get("ghost", false)) and bool(mastery.get("restraint", false)) and bool(mastery.get("immaculate", false)), "mission mastery should permanently record ghost, restraint and immaculate medals")
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
