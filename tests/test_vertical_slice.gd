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
