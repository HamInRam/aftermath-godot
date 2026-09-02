extends Node

const LEVEL_SCENE := preload("res://scenes/levels/after_hours.tscn")
const STAIN_SCENE := preload("res://scenes/blood_stain.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var level = LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().physics_frame
	_expect(level.level_title == "AFTER HOURS // VERTICAL SLICE", "vertical slice should expose its release title")
	_expect(level.started_enemy_count == 10 and level.remaining_enemies == 10, "vertical slice should start with ten active enemies")
	_expect(is_instance_valid(level.player), "vertical slice should spawn a playable character")
	_expect(level.get_node("Doors").get_child_count() >= 5, "vertical slice should exercise multi-door tactics")
	_expect(level._get_security_devices().size() == 2, "vertical slice should include two active security cameras")
	_expect(level.mission_tracker.get_required_security_shutdowns() == 2, "vertical slice should require both security nodes offline")
	var archetype_counts := {}
	for enemy in level.get_node("Enemies").get_children():
		archetype_counts[enemy.archetype_id] = int(archetype_counts.get(enemy.archetype_id, 0)) + 1
	_expect(int(archetype_counts.get("dog", 0)) == 2, "vertical slice should include two Hounds")
	_expect(int(archetype_counts.get("heavy", 0)) == 2, "vertical slice should include two Heavies")
	_expect(int(archetype_counts.get("assault", 0)) == 2, "vertical slice should include two Assault responders")
	for index in range(level.started_enemy_count): level.mission_tracker.record_enemy_eliminated()
	_expect(not level.mission_tracker.are_combat_objectives_complete(), "security objective should gate cleanup after all hostiles fall")
	for camera in level._get_security_devices(): camera.disable()
	_expect(level.mission_tracker.are_combat_objectives_complete(), "camera shutdowns should unlock cleanup once combat objective is done")
	level._enter_cleanup_phase()
	_expect(level.corpse_disposals.size() == 2 and level.corpse_disposals.all(func(disposal): return disposal.active), "vertical slice should activate two authored alternative body-disposal routes")
	_expect(level.get_tree().get_nodes_in_group("scene_secret").size() == 3, "cleanup should author two clues and one valuable opportunity")
	_expect(level.get_tree().get_nodes_in_group("resettable_furniture").size() == 3, "cleanup should author three quick-reset furniture opportunities")
	_expect(not level.player.get_node("BloodFootprintEmitter").generation_enabled, "career cleanup must not generate fresh bloody footprints")
	_expect(level.player.select_cleanup_tool("pressure_washer") and level.player.get_cleanup_efficiency("blood") >= 4, "slot-two pressure washing should provide broad biological cleanup")
	level._on_clean_requested(level.player.global_position + Vector2(20, 0), Vector2.RIGHT, 1.0)
	var liquid_system := level.get_tree().get_first_node_in_group("pixel_liquid_system")
	_expect(is_instance_valid(liquid_system) and liquid_system.get_debug_jet_count() > 0, "live cleanup must route washer input through airborne pixel water")
	if is_instance_valid(liquid_system): liquid_system.jet_particles.clear()
	var tool_guard_stain = STAIN_SCENE.instantiate()
	level.add_child(tool_guard_stain)
	tool_guard_stain.global_position = level.player.global_position + Vector2(8, 0)
	tool_guard_stain.setup(Vector2.RIGHT, 1.0, false)
	var guarded_progress := float(tool_guard_stain.get_cleanup_progress())
	level.player.select_cleanup_tool("body_bag")
	level._on_clean_requested(tool_guard_stain.global_position, Vector2.RIGHT, 1.0)
	_expect(is_equal_approx(float(tool_guard_stain.get_cleanup_progress()), guarded_progress), "body-bag slot must never clean biological stains")
	if failures == 0: print("vertical slice regression: PASS")
	for audio_node in level.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
