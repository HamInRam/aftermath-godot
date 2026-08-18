extends Node

const DROP_SCENE := preload("res://scenes/effects/blood_drop.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures := 0

func _ready() -> void:
	CleanupRegistry.reset()
	var drop := DROP_SCENE.instantiate() as BloodDrop
	drop.setup(0.8, Vector2.RIGHT, {"spread": 1.35, "darken": 0.2, "cleanup": 3})
	add_child(drop)
	_expect(drop.get_cleanup_cost() == 3, "absorbent surfaces should increase cleanup cost")
	_expect(drop.is_in_group("blood_clue"), "settled droplets should be visible forensic clues")
	var shotgun := AttackCatalog.get_gun_data("shotgun")
	_expect(shotgun.pellet_count == 7, "shotgun should emit seven pellets")
	_expect(shotgun.blood_pattern == "radial", "shotgun should use radial blood geometry")
	_expect(shotgun.hearing_radius >= 600.0, "shotgun should alert most of a floor")
	var enemy := ENEMY_SCENE.instantiate()
	add_child(enemy)
	_expect(enemy.classify_hit_zone(enemy.to_global(Vector2(4, 0))) == "head", "forward local impacts should classify as head hits")
	_expect(enemy.classify_hit_zone(enemy.to_global(Vector2(0, 0))) == "torso", "central impacts should classify as torso hits")
	_expect(enemy.classify_hit_zone(enemy.to_global(Vector2(-5, 0))) == "limb", "rear local impacts should classify as limb hits")
	drop.queue_free()
	enemy.queue_free()
	await get_tree().process_frame
	CleanupRegistry.reset()
	if failures == 0:
		print("blood forensics regression: PASS")
		get_tree().quit(0)
	else: get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
