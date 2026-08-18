extends Node

const LEVEL_SCENE := preload("res://scenes/levels/after_hours.tscn")

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
