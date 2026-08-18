extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	player.set_cleanup_mode(true)
	var corpse = CORPSE_SCENE.instantiate()
	add_child(corpse)
	corpse.global_position = Vector2(10, 0)
	_expect(player.select_cleanup_tool("mop") and player.get_cleanup_efficiency("blood_pool") == 2, "mop should clean blood efficiently")
	_expect(player.select_cleanup_tool("evidence_bag") and player.get_cleanup_efficiency("shell") == 3, "evidence bag should collect small evidence efficiently")
	_expect(player.select_cleanup_tool("body_bag") and player.get_cleanup_efficiency("corpse") == 4, "body bag should process corpses efficiently")
	_expect(not player.select_cleanup_tool("invalid"), "unknown cleanup tools should be rejected")
	_expect(player.attempt_corpse_drag(), "nearby corpse should be draggable during cleanup")
	_expect(corpse.is_being_dragged() and player.dragged_corpse == corpse, "drag state should be shared by player and corpse")
	_expect(player.attempt_corpse_drag(), "second interaction should drop the body")
	_expect(not corpse.is_being_dragged() and not is_instance_valid(player.dragged_corpse), "dropping should clear both drag references")
	if failures == 0: print("cleanup tools regression: PASS")
	for audio_node in player.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	player.queue_free()
	corpse.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
