extends Node

const LEVEL := preload("res://scenes/main.tscn")
var transition_count := 0
var observed_cause: StringName
var rejected_transitions := 0

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var snapshot := RunSnapshot.from_dictionary({
		"hp": 57, "blood": 31.0,
		"loadout": {"weapons": [{"weapon_id": "glock_17_gen5_mos", "rounds": 7, "attachments": ["aimpoint_micro_t2"]}], "reserves": {"glock_17_gen5_mos": 19}},
		"combat_perks": {"learned": ["reload_breach"], "breach": true},
		"skill_cooldowns": {"q": 1.4}, "focus": {"charges": 2, "recharge": 0.25},
	})
	var session := RoguelikeRunSession.new()
	session.begin()
	session.remember_snapshot(1, snapshot)
	snapshot.loadout.weapons[0].rounds = 0
	snapshot.combat_perks.learned.clear()
	var restored := session.get_entry_snapshot(1, true)
	assert(restored.loadout.weapons[0].rounds == 7 and restored.combat_perks.breach)
	assert(restored.combat_perks.learned == ["reload_breach"])
	var serialized := session.floor_checkpoint
	serialized.loadout.weapons[0].attachments.clear()
	assert(session.get_entry_snapshot(1, true).loadout.weapons[0].attachments.size() == 1, "compatibility dictionaries cannot mutate the checkpoint")
	restored.loadout.reserves.clear()
	assert(session.get_entry_snapshot(1, true).loadout.reserves.size() == 1)
	assert(session.get_entry_snapshot(2, true) == null)
	var json_data: Dictionary = JSON.parse_string(JSON.stringify(session.floor_checkpoint))
	assert(RunSnapshot.from_dictionary(json_data).to_dictionary() == session.floor_checkpoint)
	var malformed := RunSnapshot.from_dictionary({"hp": {}, "blood": NAN, "loadout": {"weapons": [7, {"weapon_id": "glock_17_gen5_mos", "rounds": [], "attachments": [12]}], "reserves": {"glock_17_gen5_mos": {}}}, "combat_perks": {"learned": [12, "reload_breach"], "swap": INF}})
	assert(malformed.hp == 100 and malformed.blood == 0.0)
	assert(malformed.loadout.weapons.size() == 1 and malformed.loadout.weapons[0].rounds == 0)
	assert(malformed.combat_perks.swap == 0.0)
	# Mixed terminal pellet outcomes still settle a single trigger exactly once.
	var record := ShotRecord.new(3, "mossberg_590a1")
	record.accept(ShotResolvedEvent.create(8, "enemy", true, record.weapon_id))
	record.accept(ShotResolvedEvent.create(8, "budget", false, record.weapon_id))
	assert(not record.is_complete() and record.hit and record.lethal)
	record.accept(ShotResolvedEvent.create(8, "expired", false, record.weapon_id))
	assert(record.is_complete())

	var original_path: String = Progression.save_path
	var original_data: Dictionary = Progression.data.duplicate(true)
	var original_session := Progression.run_session
	var original_mission: String = Progression.current_mission_id
	var original_result: Dictionary = Progression.last_result.duplicate(true)
	Progression.save_path = "user://architecture_contracts_test.json"
	Progression.reset_progress(true)
	Progression.begin_roguelike_run()
	var level := LEVEL.instantiate() as CombatLevel
	add_child(level)
	level._on_entry_loadout_confirmed(LoadoutCatalog.get_kit("balanced"))
	level.set_process(false)
	for enemy in level.enemies_container.get_children(): enemy.set_physics_process(false)
	var actor = level.enemies_container.get_child(0)
	actor.state_changed.connect(_on_state_changed)
	assert(actor.transition_to(actor.State.SEARCH, &"contract_search"))
	assert(transition_count == 1 and observed_cause == &"contract_search")
	assert(actor.transition_to(actor.State.SEARCH, &"duplicate"))
	assert(transition_count == 1, "same-state requests do not replay entry effects or notifications")
	actor.state = actor.State.IDLE
	assert(transition_count == 2 and observed_cause == &"external")
	actor.is_dead = true
	assert(not actor.transition_to(actor.State.ATTACK, &"late_event"))
	assert(actor.state == actor.State.IDLE and transition_count == 2, "late events cannot transition dead actors")
	actor.is_dead = false

	assert(level.floor_flow.get_parent() == level and level.combat_events.get_parent() == level)
	level._on_rogue_run_cleared(4)
	var score := level.final_score
	var exit_node := level.floor_exit
	level._on_rogue_run_cleared(4)
	assert(level.floor_cleared and not level.run_over and level.floor_exit == exit_node and level.final_score == score)
	var data_before := Progression.data.duplicate(true)
	var mission_before: String = Progression.current_mission_id
	level.floor_flow.transition_request = _reject_scene
	await level.floor_flow._enter_floor_exit()
	assert(rejected_transitions == 1)
	assert(Progression.data == data_before and Progression.current_mission_id == mission_before, "failed scene load rolls the floor selection back")
	assert(not level.exit_transition_pending and not level.floor_exit.spent and level.player.controls_enabled)
	var flow_ref: WeakRef = weakref(level.floor_flow)
	var events_ref: WeakRef = weakref(level.combat_events)
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(flow_ref.get_ref() == null and events_ref.get_ref() == null, "controllers must die with their scene")
	Progression.reset_progress(true)
	Progression.save_path = original_path
	Progression.data = original_data
	Progression.run_session = original_session
	Progression.current_mission_id = original_mission
	Progression.last_result = original_result
	print("ARCHITECTURE_CONTRACTS_OK")
	get_tree().quit()

func _on_state_changed(_previous: int, _current: int, cause: StringName) -> void:
	transition_count += 1
	observed_cause = cause

func _reject_scene(_path: String) -> bool:
	rejected_transitions += 1
	await get_tree().process_frame
	return false
