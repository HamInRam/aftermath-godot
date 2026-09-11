class_name WorldAcoustics
extends RefCounted
## Stateless integration controller; the scene retains lifetime and signal ownership.

static func _build_acoustic_topology(actor: Node2D) -> void:
	# Sound uses the real floor plan rather than a radius through arbitrary walls.
	# Door thresholds are temporarily treated as sealed while flood-filling; they
	# are then reintroduced as portals whose cost follows the live door state.
	actor.acoustic_sector_by_cell.clear()
	actor.acoustic_portals.clear()
	actor.acoustic_sector_count = 0
	var threshold_cells: Dictionary = {}
	var door_specs: Array[Dictionary] = actor.get_door_specs()
	for spec: Dictionary in door_specs:
		var opening_cell: Vector2i = spec.opening_cell
		var leaf_step = Vector2i.RIGHT if absf(float(spec.rotation)) > 0.1 else Vector2i.DOWN
		for leaf_index in range(actor.DOOR_CELL_SPAN): threshold_cells[opening_cell + leaf_step * leaf_index] = true
	for y in range(actor.world_size.y):
		for x in range(actor.world_size.x):
			var start = Vector2i(x, y)
			if actor.acoustic_sector_by_cell.has(start) or threshold_cells.has(start) or not actor._is_acoustic_floor_cell(start): continue
			var sector_id = "acoustic_%s_%02d" % [actor.layout_variant, actor.acoustic_sector_count]
			actor.acoustic_sector_count += 1
			var frontier: Array[Vector2i] = [start]
			actor.acoustic_sector_by_cell[start] = sector_id
			var cursor = 0
			while cursor < frontier.size():
				var cell = frontier[cursor]
				cursor += 1
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor: Vector2i = cell + direction
					if actor.acoustic_sector_by_cell.has(neighbor) or threshold_cells.has(neighbor) or not actor._is_acoustic_floor_cell(neighbor): continue
					actor.acoustic_sector_by_cell[neighbor] = sector_id
					frontier.append(neighbor)
	for spec: Dictionary in door_specs:
		var opening_cell: Vector2i = spec.opening_cell
		var horizontal_leaf = absf(float(spec.rotation)) > 0.1
		var leaf_step = Vector2i.RIGHT if horizontal_leaf else Vector2i.DOWN
		var normal_step = Vector2i.UP if horizontal_leaf else Vector2i.RIGHT
		var side_a = actor._sector_along_threshold(opening_cell, leaf_step, -normal_step)
		var side_b = actor._sector_along_threshold(opening_cell, leaf_step, normal_step)
		actor._append_acoustic_portal(side_a, side_b, "door", spec.passage_center)
	# Windows transmit sound and sight but remain physical movement barriers.
	for cell: Vector2i in actor.wall_layer.get_used_cells():
		if actor.wall_layer.get_cell_atlas_coords(cell).x != int(actor.Tile.WINDOW): continue
		var above = actor._sector_near_cell(cell + Vector2i.UP)
		var below = actor._sector_near_cell(cell + Vector2i.DOWN)
		var left = actor._sector_near_cell(cell + Vector2i.LEFT)
		var right = actor._sector_near_cell(cell + Vector2i.RIGHT)
		if not above.is_empty() and not below.is_empty() and above != below:
			actor._append_acoustic_portal(above, below, "window", actor.floor_layer.map_to_local(cell))
		elif not left.is_empty() and not right.is_empty() and left != right:
			actor._append_acoustic_portal(left, right, "window", actor.floor_layer.map_to_local(cell))


static func _is_acoustic_floor_cell(actor: Node2D, cell: Vector2i) -> bool:
	if actor.breach_cells.has(cell) and not actor.breach_cells[cell].opened: return false
	if actor.eroded_cells.has(cell) and actor.eroded_cells[cell].erosion.remaining() > 0: return false
	if cell.x < 0 or cell.y < 0 or cell.x >= actor.world_size.x or cell.y >= actor.world_size.y: return false
	return actor.floor_layer.get_cell_source_id(cell) >= 0 and actor.wall_layer.get_cell_source_id(cell) < 0


static func _sector_along_threshold(actor: Node2D, opening_cell: Vector2i, leaf_step: Vector2i, side_step: Vector2i) -> String:
	for leaf_index in range(actor.DOOR_CELL_SPAN):
		var sector = actor._sector_near_cell(opening_cell + leaf_step * leaf_index + side_step)
		if not sector.is_empty(): return sector
	return ""


static func _sector_near_cell(actor: Node2D, origin: Vector2i) -> String:
	if actor.acoustic_sector_by_cell.has(origin): return str(actor.acoustic_sector_by_cell[origin])
	for radius in range(1, 4):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius)]:
			var candidate: Vector2i = origin + Vector2i(offset)
			if actor.acoustic_sector_by_cell.has(candidate): return str(actor.acoustic_sector_by_cell[candidate])
	return ""


static func _append_acoustic_portal(actor: Node2D, side_a: String, side_b: String, kind: String, portal_position: Vector2) -> void:
	if side_a.is_empty() or side_b.is_empty() or side_a == side_b: return
	actor.acoustic_portals.append({"a": side_a, "b": side_b, "kind": kind, "position": portal_position})


static func get_acoustic_sector_id(actor: Node2D, world_position: Vector2) -> String:
	if actor.acoustic_sector_by_cell.is_empty(): return ""
	var cell = actor.floor_layer.local_to_map(actor.floor_layer.to_local(world_position))
	return actor._sector_near_cell(cell)


static func get_acoustic_profile(actor: Node2D) -> Dictionary:
	# Each venue changes how a familiar combat system reads: loud public spaces
	# mask sound, private rooms isolate it, and security sites coordinate harder.
	var profiles = {
		"nightclub": {"hearing_scale": 0.64, "closed_door_cost": 2.35, "open_door_cost": 0.72, "window_cost": 0.95, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "music_masking"},
		"sandwich_shop": {"hearing_scale": 0.82, "closed_door_cost": 2.45, "open_door_cost": 0.62, "window_cost": 1.00, "max_pushers": 1, "max_sweepers": 1, "incident_memory": 5.0, "identity": "service_loop"},
		"tactical_lab": {"hearing_scale": 0.92, "closed_door_cost": 2.05, "open_door_cost": 0.55, "window_cost": 0.78, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 5.5, "identity": "trained_response"},
		"harbor_exchange": {"hearing_scale": 1.02, "closed_door_cost": 2.10, "open_door_cost": 0.48, "window_cost": 0.75, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "open_air_echo"},
		"motel_witness": {"hearing_scale": 0.72, "closed_door_cost": 2.85, "open_door_cost": 0.68, "window_cost": 0.92, "max_pushers": 1, "max_sweepers": 1, "incident_memory": 5.5, "identity": "isolated_rooms"},
		"penthouse": {"hearing_scale": 0.88, "closed_door_cost": 2.30, "open_door_cost": 0.56, "window_cost": 0.52, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 5.0, "identity": "glass_crossfire"},
		"cold_storage": {"hearing_scale": 0.62, "closed_door_cost": 3.05, "open_door_cost": 0.72, "window_cost": 1.20, "max_pushers": 1, "max_sweepers": 1, "incident_memory": 5.0, "identity": "machine_masking"},
		"casino_floor": {"hearing_scale": 0.68, "closed_door_cost": 2.35, "open_door_cost": 0.62, "window_cost": 0.76, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "crowd_masking"},
		"police_archive": {"hearing_scale": 0.84, "closed_door_cost": 2.45, "open_door_cost": 0.58, "window_cost": 0.92, "max_pushers": 1, "max_sweepers": 2, "incident_memory": 6.0, "identity": "cautious_response"},
		"slaughterhouse": {"hearing_scale": 0.60, "closed_door_cost": 2.70, "open_door_cost": 0.68, "window_cost": 1.05, "max_pushers": 2, "max_sweepers": 1, "incident_memory": 4.5, "identity": "industrial_masking"},
		"broadcast_tower": {"hearing_scale": 0.90, "closed_door_cost": 2.65, "open_door_cost": 0.54, "window_cost": 0.82, "max_pushers": 1, "max_sweepers": 2, "incident_memory": 6.0, "identity": "studio_isolation"},
		"last_call": {"hearing_scale": 0.92, "closed_door_cost": 2.20, "open_door_cost": 0.52, "window_cost": 0.70, "max_pushers": 2, "max_sweepers": 2, "incident_memory": 6.0, "identity": "finale_coordination"},
	}
	return (profiles.get(actor.layout_variant, profiles["nightclub"]) as Dictionary).duplicate(true)


static func evaluate_acoustic_response(actor: Node2D, listener_position: Vector2, source_position: Vector2, radius: float, source_kind: String) -> Dictionary:
	var direct_distance = listener_position.distance_to(source_position)
	var profile = actor.get_acoustic_profile()
	var effective_radius = radius * float(profile.get("hearing_scale", 1.0))
	if direct_distance > effective_radius: return {"eligible": false, "priority": INF, "occluded": false, "hops": 99}
	var source_sector = actor.get_acoustic_sector_id(source_position)
	var listener_sector = actor.get_acoustic_sector_id(listener_position)
	if source_sector.is_empty() or listener_sector.is_empty():
		return {"eligible": direct_distance <= effective_radius, "priority": direct_distance, "occluded": false, "hops": 0}
	var route = actor._find_acoustic_route(source_sector, listener_sector, profile)
	if route.is_empty(): return {"eligible": false, "priority": INF, "occluded": true, "hops": 99}
	var maximum_hops = actor._maximum_acoustic_hops(source_kind)
	var hops = int(route.get("hops", 0))
	var transmission_cost = float(route.get("cost", 0.0))
	var acoustic_distance = direct_distance + transmission_cost * 48.0
	var eligible = hops <= maximum_hops and acoustic_distance <= effective_radius
	return {
		"eligible": eligible,
		"priority": acoustic_distance,
		"occluded": hops > 0,
		"hops": hops,
		"transmission_cost": transmission_cost,
		"source_sector": source_sector,
		"listener_sector": listener_sector,
	}


static func _maximum_acoustic_hops(actor: Node2D, source_kind: String) -> int:
	if source_kind in ["security_alarm", "security_camera"]: return 99
	if source_kind.contains("shotgun"): return 3
	if source_kind.contains("lmg") or source_kind.contains("smg"): return 2
	if source_kind.contains("pistol") or source_kind.contains("gunshot"): return 1
	if source_kind in ["door", "execution", "landmark_break", "corpse_disposal"]: return 1
	if source_kind.contains("radio") or source_kind == "corpse": return 2
	if source_kind in ["environment_lure", "thrown_weapon"]: return 2
	return 0


static func _find_acoustic_route(actor: Node2D, source_sector: String, listener_sector: String, profile: Dictionary) -> Dictionary:
	if source_sector == listener_sector: return {"cost": 0.0, "hops": 0}
	var frontier: Array[Dictionary] = [{"sector": source_sector, "cost": 0.0, "hops": 0}]
	var best_cost = {source_sector: 0.0}
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cost) < float(b.cost))
		var current: Dictionary = frontier.pop_front()
		var current_sector = str(current.sector)
		var current_cost = float(current.cost)
		if current_sector == listener_sector: return {"cost": current_cost, "hops": int(current.hops)}
		if current_cost > float(best_cost.get(current_sector, INF)) + 0.001: continue
		for portal: Dictionary in actor.acoustic_portals:
			var next_sector = ""
			if str(portal.a) == current_sector: next_sector = str(portal.b)
			elif str(portal.b) == current_sector: next_sector = str(portal.a)
			if next_sector.is_empty(): continue
			var next_cost = current_cost + actor._acoustic_portal_cost(portal, profile)
			if next_cost >= float(best_cost.get(next_sector, INF)): continue
			best_cost[next_sector] = next_cost
			frontier.append({"sector": next_sector, "cost": next_cost, "hops": int(current.hops) + 1})
	return {}


static func _acoustic_portal_cost(actor: Node2D, portal: Dictionary, profile: Dictionary) -> float:
	if str(portal.kind) == "window": return float(profile.get("window_cost", 0.9))
	var portal_position: Vector2 = portal.position
	for candidate in actor.get_tree().get_nodes_in_group("tactical_door"):
		if not candidate is Node2D or not is_instance_valid(candidate): continue
		var door = candidate as Node2D
		var center: Vector2 = door.get_acoustic_center() if door.has_method("get_acoustic_center") else door.global_position
		if center.distance_to(portal_position) > 18.0: continue
		if door.has_method("is_acoustically_open") and door.is_acoustically_open(): return float(profile.get("open_door_cost", 0.6))
		return float(profile.get("closed_door_cost", 2.4))
	return float(profile.get("closed_door_cost", 2.4))

