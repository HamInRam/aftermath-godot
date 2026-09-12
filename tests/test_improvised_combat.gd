extends Node2D

var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var player = preload("res://scenes/player.tscn").instantiate()
	add_child(player)
	player.position = Vector2(60, 60)
	player.set_physics_process(false)
	player.set_process(false)
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.position = Vector2(76, 60)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	var rig = enemy.lifecycle_rig
	var before: Dictionary = rig.get_live_art_pixels()
	enemy.apply_ballistic_hit({"health_damage": 12, "damage_ratio": 0.2, "hit_zone": "torso", "lethal": false}, Vector2(50,60))
	var after: Dictionary = rig.get_live_art_pixels()
	check(not rig.local_injuries.is_empty() and before != after, "live damage changes art")
	var first: float = rig.local_injuries.torso
	enemy.apply_ballistic_hit({"health_damage": 12, "damage_ratio": 0.2, "hit_zone": "torso", "lethal": false}, Vector2(50,60))
	check(rig.local_injuries.torso > first, "same region accumulates injury")
	var corpse_rig := PixelRagdoll2D.new()
	add_child(corpse_rig)
	corpse_rig.setup(Vector2.RIGHT, 10.0, PackedStringArray(), 0, "human", {}, rig.get_pose_snapshot())
	check(corpse_rig.local_injuries == rig.local_injuries, "corpse inherits a detached injury snapshot")
	var original_ammo: int = player.gun.ammo
	var item := ImprovisedWeapon.new()
	item.configure("club")
	add_child(item)
	item.position = Vector2(65,60)
	check(player.attempt_improvised_pickup(), "nearby item can be picked up")
	check(player.improvised_weapon == item and not player.gun.visible, "held item hides but retains gun")
	await get_tree().physics_frame
	var hp: int = enemy.hp
	item.strike()
	check(enemy.hp < hp and item.durability == 2, "melee hit consumes one use")
	var hit_hp: int = enemy.hp
	item.strike()
	check(enemy.hp == hit_hp, "cooldown prevents duplicate melee damage")
	check(player.throw_equipped_gun(Vector2.RIGHT), "Q routes to held object")
	check(player.improvised_weapon == null and player.gun.ammo == original_ammo and player.gun.visible, "throw restores gun without changing ammunition")
	item.set_physics_process(false)
	# Sweep a throw into a thin wall, resolving only one burst.
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.position = Vector2(105,60)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2,50)
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	enemy.position = Vector2(180,60)
	await get_tree().physics_frame
	for i in 8:
		if item.broken: break
		item._physics_process(0.05)
	check(item.broken and item.global_position.x < 105, "thrown object cannot cross thin wall")
	var prop := DestructibleProp.new()
	prop.setup("crate")
	add_child(prop)
	prop.position = Vector2(40,110)
	prop._launch_movable(Vector2.RIGHT, 1.0, "projectile")
	check(prop.velocity.length() > 0.0 and prop.velocity.length() <= 125.0, "scenery retains bounded visual motion")
	prop.launch_remaining = 0.0
	prop._physics_process(0.02)
	check(prop.velocity == Vector2.ZERO, "range cap settles prop")
	prop.position = Vector2(125,110)
	enemy.position = Vector2(143,110)
	enemy.hp = 100
	var state_before_contact: int = enemy.state
	var injuries_before_contact: Dictionary = enemy.lifecycle_rig.local_injuries.duplicate()
	await get_tree().physics_frame
	prop._launch_movable(Vector2.RIGHT, 1.5, "projectile")
	prop.set_physics_process(false)
	for i in 12: prop._physics_process(0.025)
	check(prop.global_position.x < enemy.global_position.x - 4.0, "scenery still physically stops at the enemy")
	check(enemy.hp == 100 and enemy.state == state_before_contact, "furniture contact causes neither damage nor stagger")
	check(enemy.lifecycle_rig.local_injuries == injuries_before_contact, "furniture contact causes no local injury")
	var after_contact: int = enemy.hp
	for i in 12: prop._physics_process(0.025)
	check(enemy.hp == after_contact, "resting contact cannot repeatedly damage enemy")
	player.queue_free()
	enemy.queue_free()
	corpse_rig.queue_free()
	prop.queue_free()
	wall.queue_free()
	await get_tree().process_frame
	print("IMPROVISED_COMBAT: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(1 if failures else 0)
