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
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.configure_combat("assault")
	_expect(enemy.archetype_id == "assault" and enemy.default_weapon_id == "shotgun", "assault profile should carry the close-range Shotgun")
	_expect(enemy.move_speed > EnemyCatalog.get_profile("gunner").move_speed, "assault should push faster than a gunner")
	enemy.configure_combat("heavy")
	_expect(enemy.default_weapon_id == "lmg" and enemy.knockdown_resistance >= 1.0, "heavy should carry LMG and resist knockdown")
	enemy.take_door_hit(Vector2.RIGHT, "knockdown")
	_expect(enemy.state == enemy.State.STAGGERED, "heavy door impact should stagger instead of knock down")
	enemy.configure_combat("dog")
	_expect(enemy.actor_type == "dog" and enemy.enemy_type == "melee", "hound should use fast melee behavior")
	_expect(not enemy.gun.visible and enemy.vision_fov_degrees > 100.0, "hound should have no gun and a wide perception cone")
	_expect(EnemyCatalog.has_profile("gunner") and not EnemyCatalog.has_profile("unknown"), "catalog should report supported archetypes")
	if failures == 0: print("enemy archetype regression: PASS")
	for actor in [enemy, player]:
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
