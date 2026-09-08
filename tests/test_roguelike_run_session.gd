extends Node

const PLAYER := preload("res://scenes/player.tscn")
const BLOOD := preload("res://scripts/roguelike/blood_resource_controller.gd")
const HELP := preload("res://scenes/ui/run_help.tscn")
const REPORT := preload("res://scenes/ui/debrief_screen.tscn")
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var store := ProgressionStore.new("/tmp/aftermath_run_session_regression.json")
	store.reset_progress(true)
	var player = PLAYER.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.configure_field_kit(LoadoutCatalog.get_kit("balanced"))
	var blood = BLOOD.new()
	add_child(blood)
	var profile := store.begin_roguelike_run()
	player.hp = 57
	player.armor_durability = 9.0
	player.gun.ammo = 3
	player.gun.reserve_ammo = 7
	blood.set_build("harvester")
	blood.perks.acquire("last_word")
	blood.perks.acquire("reload_breach")
	blood.perks.on_reload()
	blood.reserve = 31.0
	blood.skill_cooldowns.q = 1.4
	var session := store.run_session
	_expect(not session.finish_floor(2, {}, 999, {}), "out-of-order completion must not fabricate a cleared floor")
	var initial := session.capture(player, blood, {"charges": 1, "recharge": 0.25})
	session.remember_floor_start(1, initial)
	player.hp = 12
	player.gun.ammo = 0
	blood.reserve = 2.0
	blood.set_build("heavy")
	_expect(session.restore(session.get_entry_state(1, true), player, blood), "retry must restore its floor entry checkpoint")
	_expect(player.hp == 57 and player.gun.ammo == 3 and player.gun.reserve_ammo == 7, "retry must restore exact health and rounds, not issue a fresh kit")
	_expect(is_equal_approx(blood.reserve, 31.0) and is_equal_approx(blood.skill_cooldowns.q, 1.4), "retry must preserve blood/cooldown checkpoint")
	_expect(blood.build_id == "harvester" and blood.capacity == 70.0 and blood.absorption_rate_per_second == 32.0, "retry must restore build modifiers as well as its name")
	_expect("last_word" in blood.perks.learned and blood.perks.breach_ready, "retry restores behavior unlocks and their trigger state")
	_expect(session.get_entry_state(2, true).is_empty(), "a checkpoint must never leak into another floor")
	var report := {"mode": "roguelike", "rooms_cleared": 4, "kills": 16, "combat_seconds": 50.0, "alarms": 0}
	var seen := {}
	for floor_number in range(1, RoguelikeRunSession.FLOOR_LIMIT + 1):
		_expect(profile != null and not seen.has(profile.mission_id), "the six-floor deck must contain no duplicate venue")
		seen[profile.mission_id] = true
		store.record_roguelike_floor(profile.mission_id, 1000, "A", 50.0, report.duplicate(true), initial)
		var credits_before := store.get_credits()
		store.record_roguelike_floor(profile.mission_id, 1000, "A", 50.0, report.duplicate(true), initial)
		_expect(store.get_credits() == credits_before, "duplicate floor-clear signals must not mint credits")
		if floor_number < RoguelikeRunSession.FLOOR_LIMIT:
			profile = store.begin_next_roguelike_floor()
			_expect(store.begin_next_roguelike_floor() == null and store.get_roguelike_floor() == floor_number + 1, "double continuation cannot advance the deck twice")
			var transfer := session.get_entry_state(floor_number + 1, false)
			_expect(session.restore(transfer, player, blood), "next floor must receive its carried resources")
			_expect(blood.build_id == "harvester" and blood.capacity == 70.0, "blood style must survive floor transfer")
			_expect(player.gun.ammo == 3 and player.hp == 57 and is_equal_approx(blood.reserve, 31.0), "next floor must not replenish magazines, health or blood")
			session.remember_floor_start(floor_number + 1, transfer)
	_expect(session.is_complete() and int(session.totals.rooms) == 24 and int(session.totals.score) == 6000, "victory must aggregate all six floors exactly once")
	_expect(store.begin_next_roguelike_floor() == null, "the finale must not continue into an accidental endless seventh floor")
	_expect(int(store.data.roguelike_records.victories) == 1, "victory record must increment once")
	var prior_data := Progression.data.duplicate(true)
	var prior_result := Progression.last_result.duplicate(true)
	var prior_session := Progression.run_session
	Progression.last_result = store.last_result.duplicate(true)
	Progression.run_session = session
	var screen = REPORT.instantiate()
	add_child(screen)
	await get_tree().process_frame
	_expect(screen.get_node("Panel/VBox/Actions/NextButton").text == "NEW RUN", "final report must offer a new descent")
	_expect(not screen.get_node("Panel/VBox/Actions/RetryButton").visible, "credited victories must not offer a reward-farming retry")
	var panel: Control = screen.get_node("Panel")
	var actions: Control = screen.get_node("Panel/VBox/Actions")
	_expect(actions.get_global_rect().end.y <= panel.get_global_rect().end.y + 0.1, "run report actions must fit within the panel")
	var serial_before := int(Progression.data.get("roguelike_run_serial", 0))
	screen._lock_actions()
	screen._continue_campaign()
	_expect(int(Progression.data.get("roguelike_run_serial", 0)) == serial_before, "repeated final-report input cannot replace the run during transition")
	_expect(screen.get_node("Panel/VBox/Actions/NextButton").disabled, "accepted report actions must disable keyboard activation")
	screen.queue_free()
	var help = HELP.instantiate()
	add_child(help)
	await get_tree().process_frame
	var footer: Control = help.get_node("Panel/Layout/Back")
	_expect(footer.get_global_rect().end.y <= 180.0, "help footer must stay onscreen while instructions scroll")
	_expect(help.get_node("Panel/Layout/Scroll") is ScrollContainer, "long help content must scroll instead of pushing buttons outside the window")
	help.queue_free()
	Progression.data = prior_data
	Progression.last_result = prior_result
	Progression.run_session = prior_session
	store.begin_roguelike_run()
	_expect(store.run_session.floor_checkpoint.is_empty() and store.run_session.transfer_state.is_empty(), "new runs must discard previous inventory/checkpoints")
	store.reset_progress(true)
	store.free()
	player.queue_free()
	blood.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if failures == 0: print("roguelike run session regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
