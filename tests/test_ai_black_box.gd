extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(70, 0)
	var wall := StaticBody2D.new()
	wall.collision_layer = 32
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 48)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	add_child(wall)
	wall.global_position = Vector2(35, 0)
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = Vector2.ZERO
	enemy.rotation = 0.0
	enemy.tile_world = null
	for frame in range(24): await get_tree().physics_frame
	_expect(enemy.state not in [enemy.State.CHASE, enemy.State.ATTACK], "an occluded player must not trigger omniscient pursuit")
	Events.publish_combat_noise(player.global_position, 160.0, "black_box")
	_expect(enemy.state == enemy.State.INVESTIGATE, "a heard player should trigger investigation without revealing live position")
	wall.queue_free()
	await get_tree().physics_frame
	for frame in range(32): await get_tree().physics_frame
	_expect(enemy.state in [enemy.State.CHASE, enemy.State.ATTACK], "visual contact after investigation should transition to pursuit")
	if failures == 0: print("AI black-box regression: PASS")
	for actor in [enemy, player]:
		for audio_node in actor.find_children("*", "AudioStreamPlayer", true, false):
			(audio_node as AudioStreamPlayer).stop()
	enemy.queue_free()
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
