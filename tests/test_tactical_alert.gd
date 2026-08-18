extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(1000, 1000)
	var enemies: Array[CharacterBody2D] = []
	for index in range(5):
		var enemy = ENEMY_SCENE.instantiate()
		add_child(enemy)
		enemy.global_position = Vector2(12.0 + index * 16.0, 30.0)
		enemy.tile_world = null
		enemies.append(enemy)
	Events.publish_tactical_alert(Vector2.ZERO, Vector2.RIGHT, "corpse", enemies[0])
	_expect(enemies[1].tactical_role == "sweep_left", "nearest responder should search the left sector")
	_expect(enemies[2].tactical_role == "sweep_right", "second responder should search the right sector")
	_expect(enemies[3].tactical_role == "guard", "third responder should guard its current route")
	_expect(enemies[4].tactical_role == "observe", "remaining responders should stay alert without converging")
	_expect(enemies[1].state == enemies[1].State.SEARCH and enemies[2].state == enemies[2].State.SEARCH, "sector responders should enter SEARCH")
	_expect(enemies[1].search_points[0] != enemies[2].search_points[0], "left and right responders need distinct search points")
	_expect(enemies[1].search_points[0] != Vector2.ZERO and enemies[2].search_points[0] != Vector2.ZERO, "responders must not stack on the corpse")
	_expect(enemies[1].alert_level == enemies[1].AlertLevel.ALERT, "corpse response should raise full alert")
	var patrol := PackedVector2Array([Vector2(80, 20), Vector2(120, 20)])
	enemies[1].configure_patrol(patrol)
	enemies[1]._finish_search()
	_expect(enemies[1].state == enemies[1].State.RETURN, "finished searches should explicitly return to patrol")
	_expect(enemies[1].return_target in patrol, "return target should be one of the original patrol points")
	enemies[1].global_position = enemies[1].return_target
	enemies[1]._update_return_to_patrol(0.1)
	_expect(enemies[1].state == enemies[1].State.IDLE, "arriving at the route should resume patrol")
	enemies[4].alert_memory_time = 0.0
	enemies[4]._update_alert_memory(0.1)
	_expect(enemies[4].alert_level == enemies[4].AlertLevel.SUSPICIOUS, "expired full alert should decay to suspicious")
	enemies[4].alert_memory_time = 0.0
	enemies[4]._update_alert_memory(0.1)
	_expect(enemies[4].alert_level == enemies[4].AlertLevel.NORMAL, "suspicion should eventually return to normal")
	if failures == 0: print("tactical alert regression: PASS")
	for actor in enemies + [player]:
		for audio_node in actor.find_children("*", "AudioStreamPlayer", true, false):
			var audio := audio_node as AudioStreamPlayer
			audio.stop()
			audio.stream = null
		actor.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
