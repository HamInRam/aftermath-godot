extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures := 0
var hit_count := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	player.rotation = 0.0
	player.equipped_mode = "melee"
	player.set_physics_process(false)
	player.melee_impact.connect(_on_melee_impact)
	var enemies: Array[CharacterBody2D] = []
	for index in range(3):
		var enemy = ENEMY_SCENE.instantiate()
		add_child(enemy)
		enemy.global_position = Vector2(10.0 + index * 2.0, float(index - 1))
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await get_tree().physics_frame
	player.current_melee_type = "knife"
	hit_count = 0
	await player._perform_melee_attack(player.MELEE_DATA.knife)
	_expect(hit_count == 1, "knife should hit only the nearest valid target")
	player.current_melee_type = "bat"
	hit_count = 0
	await player._perform_melee_attack(player.MELEE_DATA.bat)
	_expect(hit_count == 3, "bat should retain a capped three-target crowd hit")
	for enemy in enemies: enemy.global_position = Vector2(100, 100)
	player.current_melee_type = "knife"
	player.melee_cooldown = float(player.MELEE_DATA.knife.cooldown)
	await player._perform_melee_attack(player.MELEE_DATA.knife)
	_expect(player.melee_cooldown > float(player.MELEE_DATA.knife.cooldown), "a missed knife attack should add recovery time")
	if failures == 0:
		print("melee balance regression: PASS")
	get_tree().quit(failures)

func _on_melee_impact(_target: CharacterBody2D, _position: Vector2, _direction: Vector2, _type: String, _lethal: bool) -> void:
	hit_count += 1

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
