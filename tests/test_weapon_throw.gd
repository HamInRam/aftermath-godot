extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const THROWN_SCENE := preload("res://scenes/props/thrown_weapon.tscn")

var failures := 0
var emitted_weapon_id := ""
var emitted_rounds := -1

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.acquire_gun("smg", 7)
	player.weapon_throw_requested.connect(_on_weapon_throw_requested)
	_expect(player.throw_equipped_gun(Vector2.RIGHT), "equipped gun should be throwable")
	_expect(emitted_weapon_id == "smg" and emitted_rounds == 7, "throw signal should preserve weapon and magazine")
	_expect(1 not in player.owned_gun_indices and player.gun.weapon_id == "pistol", "throwing SMG should fall back to owned pistol")
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	var thrown = THROWN_SCENE.instantiate()
	add_child(thrown)
	thrown.setup(Vector2.RIGHT, "smg", 7)
	thrown._resolve_impact(enemy)
	_expect(enemy.state == enemy.State.KNOCKED_DOWN, "thrown gun should knock down a normal enemy")
	await get_tree().process_frame
	var pickups := get_tree().get_nodes_in_group("weapon_pickup")
	_expect(not pickups.is_empty(), "thrown gun should settle as a recoverable pickup")
	if not pickups.is_empty():
		_expect(pickups[0].weapon_id == "smg" and pickups[0].rounds == 7, "recovered pickup should retain remaining rounds")
	if failures == 0: print("weapon throw regression: PASS")
	for actor in [enemy, player]:
		for audio_node in actor.find_children("*", "AudioStreamPlayer", true, false):
			var audio := audio_node as AudioStreamPlayer
			audio.stop()
			audio.stream = null
		actor.queue_free()
	for pickup in pickups: pickup.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _on_weapon_throw_requested(_origin: Vector2, _direction: Vector2, weapon_id: String, rounds: int) -> void:
	emitted_weapon_id = weapon_id
	emitted_rounds = rounds

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
