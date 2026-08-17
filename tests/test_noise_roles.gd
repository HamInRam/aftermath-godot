extends Node

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
		enemy.global_position = Vector2(20.0 + index * 20.0, 0.0)
		enemy.tile_world = null
		enemies.append(enemy)
	Events.publish_combat_noise(Vector2.ZERO, 240.0, "regression")
	_expect(enemies[0].tactical_role == "push", "nearest guard should receive PUSH")
	_expect(enemies[1].tactical_role == "push", "second guard should receive PUSH")
	_expect(enemies[2].tactical_role == "sweep", "third guard should receive SWEEP")
	_expect(enemies[3].tactical_role == "guard" and enemies[4].tactical_role == "guard", "remaining guards should hold position")
	_expect(enemies[3].state == enemies[3].State.IDLE, "GUARD role should not abandon its patrol position")
	enemies[0].configure_combat("gunner")
	enemies[1].configure_combat("melee")
	_expect(is_equal_approx(enemies[0].move_speed, 42.0), "gunner speed tuning should be applied")
	_expect(is_equal_approx(enemies[1].move_speed, 62.0), "melee speed tuning should be applied")
	if failures == 0:
		print("noise roles regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
