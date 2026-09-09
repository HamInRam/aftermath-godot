class_name RoomRunController
extends Node

signal room_entered(room_id: String, room_index: int, enemy_count: int)
signal room_cleared(room_id: String, room_index: int)
signal run_cleared(room_count: int)

var world: Node
var enemy_container: Node
var active_room_id := ""
var cleared_rooms: Dictionary = {}
var room_members: Dictionary = {}
var engaged_rooms: Dictionary = {}
var room_ordinals: Dictionary = {}
var room_index := 0
var waiting_for_reward := false
var initialized := false
var run_finished := false
var updating_rooms := false
var swarm_queue: Array[Dictionary] = []
# Retained for isolated legacy tests, disabled in the room-paced game.
var swarm_recruitment_enabled := false
var swarm_cooldown := 0.0
var swarm_tick := 0.0

func _physics_process(delta: float) -> void:
	swarm_cooldown = maxf(0.0, swarm_cooldown - delta)
	swarm_tick -= delta
	if not initialized or run_finished or swarm_queue.is_empty() or swarm_tick > 0.0: return
	swarm_tick = 0.18
	var entry: Dictionary = swarm_queue.pop_front()
	var enemy = entry.enemy
	if not is_instance_valid(enemy) or bool(enemy.get("is_dead")): return
	if bool(enemy.get_meta("rogue_room_active", false)): return
	_set_enemy_active(enemy, true)
	if enemy.has_method("react_to_room_attack"): enemy.react_to_room_attack(entry.position)

func _on_swarm_noise(position: Vector2, _radius: float, kind: String) -> void:
	if not swarm_recruitment_enabled: return
	if not initialized or run_finished or swarm_cooldown > 0.0: return
	if not kind.begins_with("gunshot_") and kind != "door": return
	if not is_instance_valid(world) or not is_instance_valid(enemy_container): return
	var source_id := str(world.get_tactical_room_id(position))
	# Do not summon the floor onto its exterior deployment threshold.
	if source_id == "exterior_approach": return
	swarm_cooldown = 3.0
	var rooms: Array[Dictionary] = []
	var active_melee := 0
	for enemy in enemy_container.get_children():
		if not bool(enemy.get("is_dead")) and str(enemy.get("enemy_type")) == "melee" and bool(enemy.get_meta("rogue_room_active", false)): active_melee += 1
	for id in room_members:
		if str(id) == source_id or cleared_rooms.has(id): continue
		var nearest := INF
		for enemy in room_members[id]:
			if is_instance_valid(enemy) and not bool(enemy.get("is_dead")): nearest = minf(nearest, position.distance_squared_to(enemy.global_position))
		if nearest < 320.0 * 320.0: rooms.append({"id": id, "distance": nearest})
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	var budget := maxi(0, 18 - active_melee - swarm_queue.size())
	for index in range(mini(2, rooms.size())):
		for enemy in room_members[rooms[index].id]:
			if budget <= 0: return
			if not is_instance_valid(enemy) or bool(enemy.get("is_dead")) or str(enemy.get("enemy_type")) != "melee" or bool(enemy.get_meta("rogue_room_active", false)): continue
			var pending := false
			for entry in swarm_queue:
				if entry.enemy == enemy: pending = true; break
			if pending: continue
			swarm_queue.append({"enemy": enemy, "position": position})
			budget -= 1

func configure(level_world: Node, enemies: Node) -> void:
	swarm_queue.clear()
	swarm_cooldown = 0.0
	swarm_tick = 0.0
	if not Events.combat_noise.is_connected(_on_swarm_noise): Events.combat_noise.connect(_on_swarm_noise)
	world = level_world
	enemy_container = enemies
	initialized = false
	active_room_id = ""
	cleared_rooms.clear()
	room_members.clear()
	engaged_rooms.clear()
	room_ordinals.clear()
	room_index = 0
	waiting_for_reward = false
	run_finished = false
	if not is_instance_valid(world) or not world.has_method("get_tactical_room_id") or not is_instance_valid(enemy_container): return
	for enemy in enemy_container.get_children():
		var room_id := str(world.get_tactical_room_id(enemy.global_position))
		enemy.set_meta("rogue_room_id", room_id)
		if enemy is CollisionObject2D:
			enemy.set_meta("rogue_collision_layer", enemy.collision_layer)
			enemy.set_meta("rogue_collision_mask", enemy.collision_mask)
		if not room_members.has(room_id): room_members[room_id] = []
		(room_members[room_id] as Array).append(enemy)
		if enemy.has_signal("combat_contact"):
			var callback := Callable(self, "_on_enemy_combat_contact").bind(enemy)
			if not enemy.is_connected("combat_contact", callback): enemy.connect("combat_contact", callback)
		_set_enemy_active(enemy, false)
	initialized = true

func update_room(player: Node2D) -> void:
	if not initialized or run_finished or updating_rooms or not is_instance_valid(player): return
	updating_rooms = true
	var candidate := str(world.get_tactical_room_id(player.global_position))
	if not cleared_rooms.has(candidate) and _alive_count(candidate) > 0: _activate_room(candidate)
	# Collect every newly cleared room before emitting signals. Multiple rooms can
	# finish on the same shotgun/explosion frame, including an unentered room.
	var just_cleared: Array[String] = []
	for id in room_members:
		var room_id := str(id)
		if cleared_rooms.has(room_id) or _alive_count(room_id) > 0: continue
		cleared_rooms[room_id] = true
		engaged_rooms.erase(room_id)
		_register_room(room_id)
		just_cleared.append(room_id)
		if active_room_id == room_id: active_room_id = ""
	for room_id in just_cleared:
		room_cleared.emit(room_id, int(room_ordinals[room_id]))
	updating_rooms = false
	_finish_if_cleared()

func complete_reward() -> void:
	# Compatibility hook for the existing clear banner. No room transition may
	# interrupt another room's ongoing fight or wait for a retired upgrade modal.
	waiting_for_reward = false
	if not updating_rooms: _finish_if_cleared()

func _finish_if_cleared() -> void:
	if not initialized or run_finished or _total_alive_count() > 0: return
	run_finished = true
	run_cleared.emit(_completed_room_count())

func _register_room(room_id: String) -> void:
	if room_ordinals.has(room_id): return
	room_index += 1
	room_ordinals[room_id] = room_index

func _activate_room(room_id: String) -> void:
	if cleared_rooms.has(room_id) or not room_members.has(room_id): return
	active_room_id = room_id
	if engaged_rooms.has(room_id): return
	engaged_rooms[room_id] = true
	_register_room(room_id)
	var count := 0
	for enemy in room_members.get(room_id, []):
		if not is_instance_valid(enemy) or bool(enemy.get("is_dead")): continue
		_set_enemy_active(enemy, true)
		count += 1
	room_entered.emit(room_id, int(room_ordinals[room_id]), count)

func _on_enemy_combat_contact(source_position: Vector2, enemy: Node) -> void:
	if not initialized or run_finished or not is_instance_valid(enemy): return
	var room_id := str(enemy.get_meta("rogue_room_id", ""))
	if not room_members.has(room_id) or cleared_rooms.has(room_id): return
	var already_engaged := engaged_rooms.has(room_id)
	_activate_room(room_id)
	# Direct harm exposes this local encounter. Other unentered rooms retain
	# ambient patrols; neighbours react to evidence at the hit source rather than
	# gaining omniscient, continuously updated player coordinates.
	for member in room_members[room_id]:
		if not is_instance_valid(member) or bool(member.get("is_dead")): continue
		if member.has_method("react_to_room_attack") and (not already_engaged or member == enemy):
			member.react_to_room_attack(source_position)

func _set_enemy_active(enemy: Node, active: bool) -> void:
	# Every hostile is authored and spawned with the floor. Dormant rooms suspend
	# combat perception only. They continue their authored patrol while a room is
	# dormant, which keeps scouted rooms alive without allowing off-screen guards
	# to acquire or shoot the player through an encounter boundary.
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.set_meta("rogue_room_active", active)
	if enemy.has_method("set_room_combat_active"):
		enemy.set_room_combat_active(active)
	if enemy is CanvasItem: enemy.visible = true
	if enemy is CollisionObject2D:
		enemy.collision_layer = int(enemy.get_meta("rogue_collision_layer", 2))
		enemy.collision_mask = int(enemy.get_meta("rogue_collision_mask", 15))

func _alive_count(room_id: String) -> int:
	var count := 0
	for enemy in room_members.get(room_id, []):
		if is_instance_valid(enemy) and not bool(enemy.get("is_dead")): count += 1
	return count

func _total_alive_count() -> int:
	var count := 0
	if not is_instance_valid(enemy_container): return 0
	for enemy in enemy_container.get_children():
		if is_instance_valid(enemy) and not bool(enemy.get("is_dead")): count += 1
	return count

func _completed_room_count() -> int:
	var count := 0
	for room_id in room_members:
		if _alive_count(str(room_id)) <= 0: count += 1
	return count

func get_active_enemy_count() -> int:
	var count := 0
	if not is_instance_valid(enemy_container): return count
	for enemy in enemy_container.get_children():
		if not bool(enemy.get("is_dead")) and bool(enemy.get_meta("rogue_room_active", false)): count += 1
	return count
