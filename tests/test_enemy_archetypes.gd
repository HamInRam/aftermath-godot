extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const DOOR_SCENE := preload("res://scenes/props/swing_door.tscn")

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
	_expect(enemy.aim_tracking_strength < 0.5 and enemy.enemy_spread_multiplier > 1.0, "assault shots should use limited tracking and enemy-only spread")
	enemy.configure_combat("heavy")
	_expect(enemy.default_weapon_id == "lmg" and enemy.knockdown_resistance >= 1.0, "heavy should carry LMG and resist knockdown")
	_expect(enemy.aim_tracking_strength < 0.1 and enemy.distance_spread_multiplier > 1.0, "heavy fire should be slow-tracking suppression rather than precision aim")
	enemy.take_door_hit(Vector2.RIGHT, "knockdown")
	_expect(enemy.state == enemy.State.STAGGERED, "heavy door impact should stagger instead of knock down")
	enemy.configure_combat("dog")
	_expect(enemy.actor_type == "dog" and enemy.enemy_type == "melee", "hound should use fast melee behavior")
	_expect(not enemy.gun.visible and enemy.vision_fov_degrees > 100.0, "hound should have no gun and a wide perception cone")
	_expect(EnemyCatalog.has_profile("gunner") and not EnemyCatalog.has_profile("unknown"), "catalog should report supported archetypes")
	player.velocity = Vector2(100, 0)
	_expect(EnemyCombatController.committed_target(player, 0.1).is_equal_approx(player.global_position + Vector2(10, 0)), "enemy aim should commit to a short predicted point")
	_expect(EnemyCombatController.distance_accuracy_multiplier(150.0, 152.0, 1.6) > 1.5, "long enemy shots should receive strong range spread")
	var slam_door_root := DOOR_SCENE.instantiate()
	add_child(slam_door_root)
	var slam_door := slam_door_root.get_node("Door") as SwingDoor
	slam_door.push_door_open(player, Vector2(120, 0))
	_expect(slam_door.is_dangerous, "a high-speed door slam should open a short knockdown window")
	slam_door._physics_process(slam_door.dangerous_window + 0.02)
	_expect(not slam_door.is_dangerous, "door knockdown danger must expire before the full opening animation")
	var gentle_door_root := DOOR_SCENE.instantiate()
	add_child(gentle_door_root)
	var gentle_door := gentle_door_root.get_node("Door") as SwingDoor
	gentle_door.push_door_open(player, Vector2(20, 0))
	_expect(not gentle_door.is_dangerous, "a gentle door push must remain harmless")
	if failures == 0: print("enemy archetype regression: PASS")
	for actor in [enemy, player]:
		for audio_node in actor.find_children("*", "AudioStreamPlayer", true, false):
			var audio := audio_node as AudioStreamPlayer
			audio.stop()
			audio.stream = null
		actor.queue_free()
	slam_door_root.queue_free()
	gentle_door_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
