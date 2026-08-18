extends Node

const LEVEL_SCENE := preload("res://scenes/levels/after_hours.tscn")
const TEST_SAVE_PATH := "user://aftermath_result_flow_test.json"

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_path: String = Progression.save_path
	var original_data: Dictionary = Progression.data.duplicate(true)
	var original_current: String = Progression.current_mission_id
	var original_result: Dictionary = Progression.last_result.duplicate(true)
	Progression.save_path = TEST_SAVE_PATH
	Progression.reset_progress(true)
	var level = LEVEL_SCENE.instantiate()
	add_child(level)
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	level.phase = "cleanup"
	level._finish_run(false)
	_expect(Progression.is_mission_completed("after_hours"), "real level completion should reach the progression store")
	_expect(Progression.last_result.mission_id == "after_hours", "result should be attributed to the level mission profile")
	_expect(int(Progression.last_result.score) == level.final_score and Progression.last_result.grade == level.final_grade, "action report should preserve the level's authoritative score and grade")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH), "level completion should persist the action record to disk")
	for audio_node in level.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Progression.reset_progress(true)
	Progression.save_path = original_path
	Progression.data = original_data
	Progression.current_mission_id = original_current
	Progression.last_result = original_result
	if failures == 0: print("mission result flow regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
