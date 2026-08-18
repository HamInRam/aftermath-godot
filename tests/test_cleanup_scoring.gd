extends Node

const LEVEL_SCENE := preload("res://scenes/levels/after_hours.tscn")

class DummyCorpseEvidence:
	extends Node2D
	func _ready() -> void: CleanupRegistry.register_target(self)
	func clean_step() -> void: pass
	func get_cleanup_type() -> String: return "corpse"

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var level = LEVEL_SCENE.instantiate()
	add_child(level)
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	var evidence := DummyCorpseEvidence.new()
	level.add_child(evidence)
	evidence.global_position = Vector2(200, 100)
	_expect(CleanupRegistry.get_initial_value() == 25 and CleanupRegistry.get_remaining_value() == 25, "corpse evidence should carry critical severity")
	level.phase = "cleanup"
	level.extraction_zone.set_active(true)
	level.player.global_position = level.extraction_zone.global_position
	level._on_extraction_requested()
	_expect(level.run_over and level.final_grade == "D", "leaving all critical evidence should produce a failing grade")
	_expect(level.status_label.text == "SCENE ABANDONED", "partial extraction should clearly report abandonment")
	_expect(level.final_score > 0, "combat and time components should still produce a numeric score")
	_expect(level.extraction_zone.contains_position(level.player.global_position), "extraction zone should recognize the player")
	if failures == 0: print("cleanup scoring regression: PASS")
	for audio_node in level.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	CleanupRegistry.reset()
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
