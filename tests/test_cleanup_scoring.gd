extends Node

const LEVEL_SCENE := preload("res://scenes/levels/after_hours.tscn")
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var level = LEVEL_SCENE.instantiate()
	level.record_progress = false
	add_child(level)
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	_expect(not level.has_method("_enter_cleanup_phase"), "retired cleanup must have no runtime entry point")
	_expect(not level.has_method("_on_clean_requested"), "mop/washer input must not survive in the room shooter")
	_expect(get_tree().get_nodes_in_group("restoration_anchor").is_empty(), "combat must not spawn furniture-return ghosts")
	level.mission_tracker.record_alarm_trigger()
	level._on_rogue_run_cleared(4)
	_expect(level.floor_cleared and not level.run_over and level.final_grade == "A", "one alarm should lower a fast floor from S to A")
	_expect(level.phase == "combat" and level.final_score > 0, "combat completion must score without cleaning")
	_expect(is_instance_valid(level.floor_exit) and level.player.controls_enabled, "intermediate floors must retain a walkable exit and player controls")
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if failures == 0: print("retired cleanup boundary regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
