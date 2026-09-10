extends Node2D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = Vector2(80,80)
	var ctx := DamageContext.create(enemy.position, Vector2.RIGHT, 5, "mossberg_590a1", 0, false, "torso", Vector2(80,120), enemy)
	ctx.weapon_source = AttackCatalog.get_gun_data("mossberg_590a1")
	enemy.apply_living_ballistic_push(ctx)
	assert(is_equal_approx(enemy.stagger_time, .24))
	assert(enemy.velocity.x > 0 and is_zero_approx(enemy.velocity.y))
	assert(enemy.gun.cooldown >= .24)
	var start: Vector2 = enemy.position
	for i in range(20): enemy._move_ballistic_push(1.0/60.0)
	assert(enemy.position.x > start.x + 2 and enemy.position.x <= start.x + 4.01)
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2,40)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = Vector2(87,80)
	add_child(wall)
	enemy.position = start
	await get_tree().physics_frame
	await get_tree().physics_frame
	enemy.apply_living_ballistic_push(ctx)
	for i in range(20): enemy._move_ballistic_push(1.0/60.0)
	assert(enemy.position.x < 83)
	assert(enemy.velocity == Vector2.ZERO)
	ctx.weapon_source = AttackCatalog.get_gun_data("glock_17_gen5_mos")
	enemy.stagger_time = 0
	enemy.apply_living_ballistic_push(ctx)
	assert(is_equal_approx(enemy.stagger_time, .09))
	assert(enemy.ballistic_push_remaining == 1.5)
	enemy.is_dead = true
	enemy.velocity = Vector2.ZERO
	enemy.apply_living_ballistic_push(ctx)
	assert(enemy.velocity == Vector2.ZERO)
	print("LIVING_KNOCKBACK_OK")
	get_tree().quit()
