extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PICKUP_SCENE := preload("res://scenes/props/weapon_pickup.tscn")
const AMMO_SCENE := preload("res://scenes/props/ammo_pickup.tscn")

var failures := 0

func _ready() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(180, 80)
	player.set_physics_process(false)
	var shooter = ENEMY_SCENE.instantiate()
	add_child(shooter)
	shooter.global_position = Vector2(20, 80)
	shooter.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var clear_lane := EnemyCombatController.evaluate_fire_lane(shooter, shooter.gun.global_position, player)
	_expect(bool(clear_lane.clear), "an unobstructed player lane should be fireable: %s" % str(clear_lane))
	var ally = ENEMY_SCENE.instantiate()
	add_child(ally)
	ally.global_position = Vector2(100, 80)
	ally.set_physics_process(false)
	await get_tree().physics_frame
	var blocked_lane := EnemyCombatController.evaluate_fire_lane(shooter, shooter.gun.global_position, player)
	_expect(not bool(blocked_lane.clear) and str(blocked_lane.reason) == "friendly", "an allied body must explicitly reject the fire lane")
	ally.queue_free()
	await get_tree().physics_frame
	var alternate := EnemyCombatController.choose_cover_plan(shooter, player, self, 65.0, 1.0)
	_expect(not alternate.is_empty() and str(alternate.mode) == "flank", "open ground should produce a reachable alternate-route waypoint")
	var corner := StaticBody2D.new()
	corner.collision_layer = 32
	var corner_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6, 6)
	corner_shape.shape = rectangle
	corner.add_child(corner_shape)
	add_child(corner)
	corner.global_position = Vector2(60, 94)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cover := EnemyCombatController.choose_cover_plan(shooter, player, self, 65.0, 1.0)
	_expect(not cover.is_empty() and str(cover.mode) == "cover", "a corner with an adjacent clear lane should produce a cover-and-peek pair")
	corner.queue_free()
	var roles := CombatDirector.build_room_role_plan(PackedStringArray(["A", "A", "B", "B", "C"]), PackedStringArray(["push", "push", "sweep"]), "guard")
	_expect(roles == PackedStringArray(["push", "guard", "push", "guard", "sweep"]), "room-aware assignments should retain one defender in every staffed room")
	shooter.gun.ammo = 0
	var pickup = PICKUP_SCENE.instantiate()
	add_child(pickup)
	pickup.setup("smg", 7)
	_expect(pickup.collect_enemy(shooter), "an empty gunner should accept a dropped firearm")
	_expect(shooter.gun.weapon_id == "smg" and shooter.gun.ammo == 7, "enemy pickup must preserve weapon identity and remaining rounds")
	var melee = ENEMY_SCENE.instantiate()
	add_child(melee)
	melee.configure_combat("melee")
	var rejected = PICKUP_SCENE.instantiate()
	add_child(rejected)
	rejected.setup("pistol", 5)
	_expect(not rejected.collect_enemy(melee), "melee-only archetypes must not abandon their identity for a gun")
	rejected.queue_free()
	player.gun.ammo = 0
	player.gun.set_reserve_ammo("pistol", 5)
	player.gun.is_reloading = true
	player.gun._on_reload_timer_timeout()
	_expect(player.gun.ammo == 5 and player.gun.reserve_ammo == 0, "reloads must transfer finite reserve rounds instead of creating ammunition")
	var ammo = AMMO_SCENE.instantiate()
	add_child(ammo)
	ammo.setup("pistol", 12)
	ammo._on_body_entered(player)
	_expect(player.gun.reserve_ammo == 12, "authored ammo pickups should replenish the matching reserve")
	await get_tree().process_frame
	for node in [player, shooter, melee]:
		if is_instance_valid(node): node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	for scene_path in ["res://scenes/main.tscn", "res://scenes/levels/sandwich_shop.tscn", "res://scenes/levels/tactical_lab.tscn", "res://scenes/levels/after_hours.tscn"]:
		var level = load(scene_path).instantiate()
		add_child(level)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var tile_world = level.get_node("TileMap")
		_expect(level.ammo_pickup_positions.size() == 3, "%s should author exactly three reserve-ammo pickups" % scene_path)
		for position in level.ammo_pickup_positions:
			_expect(tile_world.is_navigation_position_walkable(position), "%s ammo pickup at %s must be reachable; nearest %s" % [scene_path, position, _nearest_walkable(tile_world, position)])
		level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	if failures == 0: print("encounter intelligence regression: PASS")
	get_tree().quit(0 if failures == 0 else 1)

func get_navigation_path(_from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([to])

func is_navigation_position_walkable(_position: Vector2) -> bool:
	return true

func _nearest_walkable(tile_world: Node, origin: Vector2) -> Vector2:
	for radius in range(8, 65, 8):
		for offset in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius), Vector2(radius, radius), Vector2(-radius, radius), Vector2(radius, -radius), Vector2(-radius, -radius)]:
			var candidate: Vector2 = origin + Vector2(offset)
			if tile_world.is_navigation_position_walkable(candidate): return candidate
	return origin

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
