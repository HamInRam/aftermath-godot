extends Node

const ROOM_RUN := preload("res://scripts/roguelike/room_run_controller.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

class MockWorld:
	extends Node2D
	func get_tactical_room_id(world_position: Vector2) -> String:
		return "left" if world_position.x < 100.0 else "right"

class MockEnemy:
	extends CharacterBody2D
	signal combat_contact(source_position: Vector2)
	var is_dead := false
	var room_combat_active := true
	func set_room_combat_active(active: bool) -> void:
		room_combat_active = active

class ThreeRoomWorld:
	extends Node2D
	func get_tactical_room_id(world_position: Vector2) -> String:
		return "west" if world_position.x < 100.0 else ("center" if world_position.x < 200.0 else "east")

var failures := 0

func _ready() -> void:
	var world := MockWorld.new()
	var enemies := Node2D.new()
	var left_enemy := MockEnemy.new()
	var right_enemy := MockEnemy.new()
	var player := Node2D.new()
	var controller = ROOM_RUN.new()
	add_child(world)
	add_child(enemies)
	add_child(player)
	add_child(controller)
	enemies.add_child(left_enemy)
	enemies.add_child(right_enemy)
	left_enemy.global_position = Vector2(20, 20)
	right_enemy.global_position = Vector2(140, 20)
	left_enemy.collision_layer = 2
	right_enemy.collision_layer = 2
	controller.configure(world, enemies)
	_expect(left_enemy.visible and right_enemy.visible, "room setup must never hide authored enemies")
	_expect(left_enemy.collision_layer == 2 and right_enemy.collision_layer == 2, "dormant enemies must remain physically present instead of popping into existence")
	_expect(left_enemy.process_mode == Node.PROCESS_MODE_INHERIT and right_enemy.process_mode == Node.PROCESS_MODE_INHERIT, "room isolation must not freeze authored patrol simulation")
	_expect(not left_enemy.room_combat_active and not right_enemy.room_combat_active, "unentered rooms should suppress combat without suppressing patrol")
	player.global_position = Vector2(24, 20)
	controller.update_room(player)
	_expect(left_enemy.room_combat_active, "the entered room should enable complete combat AI")
	_expect(not right_enemy.room_combat_active and right_enemy.process_mode == Node.PROCESS_MODE_INHERIT and right_enemy.visible, "future-room enemies should keep patrolling without acquiring the player")
	left_enemy.is_dead = true
	controller.update_room(player)
	controller.complete_reward()
	player.global_position = Vector2(142, 20)
	controller.update_room(player)
	_expect(right_enemy.room_combat_active and right_enemy.visible, "entering the next room should arm an existing patrol without visual spawning")

	var preclear_enemies := Node2D.new()
	var preclear_enemy := MockEnemy.new()
	var preclear_controller = ROOM_RUN.new()
	add_child(preclear_enemies)
	add_child(preclear_controller)
	preclear_enemies.add_child(preclear_enemy)
	preclear_enemy.global_position = Vector2(140, 20)
	preclear_enemy.is_dead = true
	var run_clear_events: Array[int] = []
	preclear_controller.run_cleared.connect(func(count: int) -> void: run_clear_events.append(count))
	preclear_controller.configure(world, preclear_enemies)
	preclear_controller.update_room(player)
	preclear_controller.update_room(player)
	_expect(run_clear_events.size() == 1 and run_clear_events[0] == 1 and preclear_controller.run_finished, "eliminating every dormant-room enemy from range must finish and credit the room exactly once")
	await _test_real_local_hit_reaction()
	if failures == 0: print("room run visibility regression: PASS")
	get_tree().quit(failures)

func _test_real_local_hit_reaction() -> void:
	var live_world := ThreeRoomWorld.new()
	var enemies := Node2D.new()
	var controller = ROOM_RUN.new()
	var player = PLAYER_SCENE.instantiate()
	add_child(live_world)
	add_child(enemies)
	add_child(controller)
	add_child(player)
	player.global_position = Vector2(20, 40)
	player.set_physics_process(false)
	var positions := [Vector2(75, 40), Vector2(140, 40), Vector2(166, 65), Vector2(275, 40)]
	var guards: Array = []
	for position in positions:
		var enemy = ENEMY_SCENE.instantiate()
		enemy.position = position
		enemies.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.tile_world = null
		enemy.max_hp = 100
		enemy.hp = 100
		enemy.rotation = PI
		guards.append(enemy)
	var clear_ids: Array[String] = []
	var floor_events: Array[int] = []
	controller.room_cleared.connect(func(id: String, _index: int) -> void:
		clear_ids.append(id)
		controller.complete_reward())
	controller.run_cleared.connect(func(count: int) -> void: floor_events.append(count))
	controller.configure(live_world, enemies)
	# Test real motion, not just visibility/process flags on a stub.
	var dormant = guards[3]
	dormant.configure_patrol(PackedVector2Array([dormant.position, dormant.position + Vector2(25, 0)]))
	dormant.patrol_index = 1
	dormant.patrol_mode = dormant.PatrolMode.MOVING
	var before: Vector2 = dormant.position
	for tick in 12:
		await get_tree().physics_frame
		dormant._physics_process(1.0 / 60.0)
	_expect(dormant.position.distance_to(before) > 1.0, "a real dormant guard must walk its authored patrol")
	_expect(not dormant.player_in_sight and not dormant.gun.is_processing(), "ambient patrol must not enable perception or gun simulation")
	controller.update_room(player)
	_expect(guards[0].room_combat_active and not guards[1].room_combat_active and not guards[3].room_combat_active, "entering west must leave distant rooms on patrol")
	guards[1].take_damage(1, player.global_position)
	_expect(guards[1].room_combat_active and guards[2].room_combat_active, "shooting a real dormant guard must wake only its room and companions")
	_expect(guards[0].room_combat_active and not guards[3].room_combat_active, "a second engaged room must neither freeze the original fight nor wake a far room")
	_expect(guards[1].state == guards[1].State.STAGGERED and guards[2].state == guards[2].State.INVESTIGATE, "local attack alert must preserve the victim hitstun and orient its companion")
	guards[1]._physics_process(0.12)
	guards[1]._physics_process(0.02)
	_expect(guards[1].state != guards[1].State.IDLE and guards[1].room_combat_active, "a damaged dormant guard must not revert to ambient patrol on its next physics ticks")
	_expect(guards[1].investigation_target.distance_to(player.global_position) < 0.1, "recovering guard must investigate the actual attack source rather than its own feet")
	guards[0].is_dead = true
	controller.update_room(player)
	_expect(clear_ids == ["west"] and guards[1].room_combat_active and guards[2].room_combat_active, "clearing one engaged room must keep the other room fighting")
	_expect(controller.get_active_enemy_count() == 2, "HUD active-hostile count must include every still-engaged room")
	guards[1].is_dead = true
	guards[2].is_dead = true
	controller.update_room(player)
	controller.update_room(player)
	_expect(clear_ids == ["west", "center"] and floor_events.is_empty(), "remotely cleared rooms must credit once without ending a floor with remaining patrols")
	# Doors and thrown guns cause knockdown without take_damage; they must also
	# break room dormancy without requiring a follow-up bullet.
	guards[3].take_door_hit(Vector2.RIGHT, "knockdown")
	_expect(guards[3].room_combat_active and guards[3].state == guards[3].State.KNOCKED_DOWN, "a thrown weapon or door hit must activate its victim's room while preserving knockdown")
	guards[3].is_dead = true
	controller.update_room(player)
	controller.update_room(player)
	controller.complete_reward()
	_expect(clear_ids == ["west", "center", "east"] and floor_events == [3], "multiple engaged rooms must each count once and emit exactly one floor completion")
	for actor in guards + [player]:
		for audio in actor.find_children("*", "AudioStreamPlayer", true, false):
			(audio as AudioStreamPlayer).stop()
			(audio as AudioStreamPlayer).stream = null
	controller.queue_free()
	enemies.queue_free()
	player.queue_free()
	live_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
