extends Node2D

const BULLET_SCENE := preload("res://scenes/bullet.tscn")

var failures := 0

func _ready() -> void:
	var player_source := _make_actor(1)
	var player_bullet := BULLET_SCENE.instantiate()
	player_bullet.setup(Vector2.RIGHT, false, 1, "pistol", Vector2.ZERO, 180.0, player_source)
	add_child(player_bullet)
	_expect(player_bullet.collision_mask == 46, "player projectiles should query enemies, world, glass and fresh corpses only")
	_expect(player_bullet.get_collision_exceptions().has(player_source), "a projectile must explicitly exclude its shooter")

	var enemy_source := _make_actor(2)
	var enemy_bullet := BULLET_SCENE.instantiate()
	enemy_bullet.setup(Vector2.RIGHT, true, 1, "smg", Vector2.ZERO, 180.0, enemy_source)
	add_child(enemy_bullet)
	_expect(enemy_bullet.collision_mask == 13, "enemy projectiles should not collide with allies or corpse/debris evidence")
	_expect(enemy_bullet.get_collision_exceptions().has(enemy_source), "enemy projectiles must explicitly exclude their shooter")

	var debris := PhysicalDebris.new()
	add_child(debris)
	debris.global_position = Vector2(18.0, 40.0)
	debris.setup("wood", DestructionMaterial.for_kind("table"), Vector2.RIGHT, 0.01, 0)
	await get_tree().process_frame
	debris.freeze = true
	debris.linear_velocity = Vector2.ZERO
	debris.angular_velocity = 0.0
	var pass_through := BULLET_SCENE.instantiate()
	pass_through.global_position = Vector2(0.0, 40.0)
	pass_through.setup(Vector2.RIGHT, false, 1, "pistol", pass_through.global_position, 180.0)
	add_child(pass_through)
	for frame in range(12): await get_tree().physics_frame
	_expect(is_instance_valid(pass_through), "small environment debris must not swallow a projectile")
	if is_instance_valid(pass_through):
		_expect(pass_through.global_position.x > debris.global_position.x + 4.0, "a projectile should continue beyond struck debris")
	_expect(debris.linear_velocity.length() > 0.0, "struck debris should receive readable physical feedback")

	if failures == 0: print("projectile collision regression: PASS")
	get_tree().quit(failures)

func _make_actor(layer: int) -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	actor.collision_layer = layer
	actor.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	collision.shape = shape
	actor.add_child(collision)
	add_child(actor)
	return actor

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
