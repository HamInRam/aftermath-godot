extends Node

const CORPSE_SCENE := preload("res://scenes/corpse.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_ragdoll := Settings.ragdoll_enabled
	Settings.update_values({"ragdoll_enabled": true}, false)

	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.collision_mask = 0
	wall.position = Vector2(12, 0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 80)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	add_child(wall)

	var corpse = CORPSE_SCENE.instantiate()
	corpse.position = Vector2.ZERO
	add_child(corpse)
	corpse.setup(0.0, Vector2.RIGHT, 999.0, 2.0, "firearm_gib", "torso", "shotgun", 8.0, "human", "enemy")
	corpse.bleed_time = 0.0
	_expect(corpse.velocity.length() <= 52.01, "a point-blank shotgun must obey the authored corpse root cap")

	for frame in 90: await get_tree().physics_frame
	# Wall begins at x=11 and the corpse has a 4.5px half-width. The swept body
	# must remain on the near side even under an intentionally absurd input force.
	_expect(corpse.global_position.x <= 6.75, "a capped corpse must not tunnel or become embedded through a thin wall")
	_expect(corpse.velocity.length() < 1.0, "wall contact must dissipate corpse root velocity instead of preserving a corner-slide")

	Settings.update_values({"ragdoll_enabled": original_ragdoll}, false)
	corpse.queue_free()
	wall.queue_free()
	if failures == 0: print("corpse wall safety regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
