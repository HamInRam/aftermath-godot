extends Node

## Converts raw combat events into tactical assignments. Events remains a pure bus.

const KILL_ZONE_CELL_SIZE := 32.0
const KILL_ZONE_WINDOW_MSEC := 9000
const KILL_ZONE_THRESHOLD := 2
var casualty_memory: Dictionary = {}
var fire_tokens: Dictionary = {}
var next_fire_token_msec := 0
const MAX_SIMULTANEOUS_SHOOTERS := 2
const FIRE_TOKEN_SPACING_MSEC := 120

func _ready() -> void:
	Events.combat_noise.connect(_on_combat_noise)
	Events.tactical_alert.connect(_on_tactical_alert)
	Events.casualty_reported.connect(_on_casualty_reported)

func _on_combat_noise(world_position: Vector2, radius: float, source_kind: String) -> void:
	var candidates: Array[Dictionary] = []
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy_node) or not enemy_node.has_method("evaluate_noise_response"): continue
		var response: Dictionary = enemy_node.evaluate_noise_response(world_position, radius)
		if bool(response.get("eligible", false)):
			candidates.append({"enemy": enemy_node, "response": response})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.response.priority) < float(b.response.priority)
	)
	var rooms := PackedStringArray()
	for candidate in candidates: rooms.append(_candidate_room(candidate.enemy))
	var roles := get_role_plan_for_event(source_kind, world_position, rooms, false)
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		candidate.enemy.receive_combat_noise_result(world_position, radius, source_kind, roles[index], candidate.response)

func _on_tactical_alert(world_position: Vector2, likely_direction: Vector2, source_kind: String, reporter: Node) -> void:
	var candidates: Array[Dictionary] = []
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if enemy_node == reporter or not is_instance_valid(enemy_node) or not enemy_node.has_method("evaluate_tactical_assignment"): continue
		var response: Dictionary = enemy_node.evaluate_tactical_assignment(world_position)
		if bool(response.get("eligible", false)):
			candidates.append({"enemy": enemy_node, "priority": float(response.get("priority", INF))})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.priority) < float(b.priority)
	)
	var rooms := PackedStringArray()
	for candidate in candidates: rooms.append(_candidate_room(candidate.enemy))
	var roles := get_role_plan_for_event(source_kind, world_position, rooms, true)
	for index in range(candidates.size()):
		candidates[index].enemy.receive_tactical_assignment(world_position, likely_direction, source_kind, roles[index])

func _on_casualty_reported(world_position: Vector2, likely_attack_direction: Vector2) -> void:
	register_casualty(world_position, likely_attack_direction)
	if is_kill_zone(world_position):
		Events.publish_tactical_alert(world_position, likely_attack_direction, "ambush", null)

func register_casualty(world_position: Vector2, likely_attack_direction: Vector2, timestamp_msec := -1) -> int:
	var now := Time.get_ticks_msec() if timestamp_msec < 0 else timestamp_msec
	_prune_casualty_memory(now)
	var cell: Variant = _incident_key(world_position)
	var record: Dictionary = casualty_memory.get(cell, {"count": 0, "last": now, "position": world_position, "direction": likely_attack_direction})
	if now - int(record.get("last", now)) > KILL_ZONE_WINDOW_MSEC: record.count = 0
	record.count = int(record.get("count", 0)) + 1
	record.last = now
	record.position = world_position
	if likely_attack_direction.length_squared() > 0.001: record.direction = likely_attack_direction.normalized()
	casualty_memory[cell] = record
	return int(record.count)

func is_kill_zone(world_position: Vector2, timestamp_msec := -1) -> bool:
	var now := Time.get_ticks_msec() if timestamp_msec < 0 else timestamp_msec
	_prune_casualty_memory(now)
	var record: Dictionary = casualty_memory.get(_incident_key(world_position), {})
	return int(record.get("count", 0)) >= KILL_ZONE_THRESHOLD

func get_role_plan_for_event(source_kind: String, world_position: Vector2, rooms: PackedStringArray, tactical: bool) -> PackedStringArray:
	var ambush_risk := source_kind == "ambush" or is_kill_zone(world_position)
	if ambush_risk:
		# A suspected fatal funnel never receives a direct PUSH assignment. One
		# operator searches each viable side while everyone else contains exits.
		return build_room_role_plan(rooms, PackedStringArray(["sweep_left", "sweep_right"] if tactical else ["sweep"]), "guard")
	return build_room_role_plan(rooms, PackedStringArray(["sweep_left", "sweep_right", "guard"]), "observe") if tactical else build_room_role_plan(rooms, PackedStringArray(["push", "push", "sweep"]), "guard")

func reset_kill_zones() -> void:
	casualty_memory.clear()
	fire_tokens.clear()
	next_fire_token_msec = 0

func request_fire_token(enemy: Node, hold_seconds := 0.55) -> bool:
	if not is_instance_valid(enemy): return false
	var now := Time.get_ticks_msec()
	_prune_fire_tokens(now)
	var key := enemy.get_instance_id()
	if fire_tokens.has(key):
		fire_tokens[key].expires = now + roundi(hold_seconds * 1000.0)
		return true
	if now < next_fire_token_msec or fire_tokens.size() >= MAX_SIMULTANEOUS_SHOOTERS: return false
	fire_tokens[key] = {"enemy": weakref(enemy), "expires": now + roundi(hold_seconds * 1000.0)}
	next_fire_token_msec = now + FIRE_TOKEN_SPACING_MSEC
	return true

func release_fire_token(enemy: Node) -> void:
	if is_instance_valid(enemy): fire_tokens.erase(enemy.get_instance_id())

func _prune_fire_tokens(now: int) -> void:
	var expired: Array = []
	for key in fire_tokens:
		var record: Dictionary = fire_tokens[key]
		var owner: Object = (record.enemy as WeakRef).get_ref()
		if not is_instance_valid(owner) or now >= int(record.expires): expired.append(key)
	for key in expired: fire_tokens.erase(key)

func get_safe_ambush_approach(world_position: Vector2, actor_position: Vector2, role: String) -> Vector2:
	var door := _nearest_tactical_door(world_position, 30.0)
	if not is_instance_valid(door) or not door.has_method("get_safe_approach"): return Vector2.INF
	var lateral := -1.0 if role == "sweep_left" else (1.0 if role == "sweep_right" else 0.0)
	return door.get_safe_approach(actor_position, lateral)

func _casualty_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / KILL_ZONE_CELL_SIZE), floori(world_position.y / KILL_ZONE_CELL_SIZE))

func _incident_key(world_position: Vector2) -> Variant:
	var door := _nearest_tactical_door(world_position, 26.0)
	if is_instance_valid(door) and door.has_method("get_tactical_door_id"): return str(door.get_tactical_door_id())
	return _casualty_cell(world_position)

func _nearest_tactical_door(world_position: Vector2, maximum_distance: float) -> Node2D:
	var nearest: Node2D
	var best := maximum_distance * maximum_distance
	for candidate in get_tree().get_nodes_in_group("tactical_door"):
		if not candidate is Node2D or not is_instance_valid(candidate): continue
		var distance := (candidate as Node2D).global_position.distance_squared_to(world_position)
		if distance <= best:
			nearest = candidate
			best = distance
	return nearest

func _prune_casualty_memory(now: int) -> void:
	var expired: Array = []
	for cell in casualty_memory:
		if now - int((casualty_memory[cell] as Dictionary).get("last", 0)) > KILL_ZONE_WINDOW_MSEC: expired.append(cell)
	for cell in expired: casualty_memory.erase(cell)

func build_room_role_plan(room_ids: PackedStringArray, active_roles: PackedStringArray, passive_role: String) -> PackedStringArray:
	var totals := {}
	for room_id in room_ids: totals[room_id] = int(totals.get(room_id, 0)) + 1
	var active_by_room := {}
	var active_index := 0
	var roles := PackedStringArray()
	for room_id in room_ids:
		var room_limit := maxi(1, int(totals.get(room_id, 1)) - 1)
		var can_leave_room := int(active_by_room.get(room_id, 0)) < room_limit
		if active_index < active_roles.size() and can_leave_room:
			roles.append(active_roles[active_index])
			active_index += 1
			active_by_room[room_id] = int(active_by_room.get(room_id, 0)) + 1
		else:
			roles.append(passive_role)
	return roles

func _candidate_room(enemy: Node) -> String:
	return str(enemy.get_tactical_room_id()) if enemy.has_method("get_tactical_room_id") else "open_floor"
