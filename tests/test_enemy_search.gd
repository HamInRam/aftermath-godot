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
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = Vector2.ZERO
	enemy.tile_world = null
	enemy._begin_search(Vector2(80, 0), Vector2.RIGHT)
	_expect(enemy.state == enemy.State.SEARCH, "enemy should enter SEARCH")
	_expect(not enemy.search_timer_started, "search timer must stay stopped during travel")
	_expect(is_zero_approx(enemy.search_time_remaining), "travel must not consume the search budget")
	enemy._physics_process(0.25)
	_expect(not enemy.search_timer_started, "search timer must remain stopped before reaching the scene")
	enemy.global_position = enemy.search_points[0]
	enemy._physics_process(0.1)
	_expect(enemy.search_timer_started, "search timer should start at the first scene point")
	_expect(is_equal_approx(enemy.search_time_remaining, enemy.search_duration_limit), "the full search budget should be available on arrival")
	enemy.search_points = PackedVector2Array([enemy.global_position + Vector2(40, 0), enemy.global_position + Vector2(60, 0)])
	enemy.search_index = 0
	enemy._reset_movement_progress()
	enemy._update_movement_progress(enemy.stuck_timeout, true)
	_expect(enemy.search_index == 0, "the first stuck timeout should request a replan")
	enemy._update_movement_progress(enemy.stuck_timeout, true)
	_expect(enemy.search_index == 1, "the second stuck timeout should skip an unreachable search point")
	if failures == 0:
		print("enemy search regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
