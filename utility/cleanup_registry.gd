extends Node

signal target_count_changed(remaining: int)

const EVIDENCE_VALUES := {
	"corpse": 25,
	"dropped_weapon": 10,
	"gore": 4,
	"blood": 3,
	"blood_footprint": 1,
	"shell": 1,
	"debris": 2,
	"spill": 4,
	"furniture": 8,
}

var _targets: Dictionary = {}
var _registered_values: Dictionary = {}
var _initial_value := 0
var _resolved_value := 0
var _initial_count := 0
var _evidence_history: Dictionary = {}
const SPATIAL_CELL_SIZE := 32.0
var _spatial_cache: Dictionary = {}
var _spatial_cache_bucket := -1

func register_target(target: Node) -> void:
	if not is_instance_valid(target): return
	var instance_id := target.get_instance_id()
	if _targets.has(instance_id): return
	_targets[instance_id] = weakref(target)
	var cleanup_type := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else "unknown"
	if cleanup_type in ["blood", "blood_pool", "blood_footprint", "gore"]:
		target.add_to_group("blood_evidence")
	var evidence_value := int(EVIDENCE_VALUES.get(cleanup_type, 1))
	_registered_values[instance_id] = evidence_value
	_evidence_history[instance_id] = {
		"position": target.global_position if target is Node2D else Vector2.ZERO,
		"value": evidence_value,
		"resolved": false,
		"discarded": false,
	}
	_initial_value += evidence_value
	_initial_count += 1
	_spatial_cache_bucket = -1
	target.tree_exiting.connect(_on_target_exiting.bind(instance_id), CONNECT_ONE_SHOT)
	target_count_changed.emit(get_remaining_count())

func unregister_target(target: Node) -> void:
	if not is_instance_valid(target): return
	_resolve_id(target.get_instance_id())

func get_remaining_count() -> int:
	_prune_invalid()
	return _targets.size()

func get_nearest_target(world_position: Vector2, maximum_distance: float) -> Node2D:
	_prune_invalid()
	_refresh_spatial_cache()
	var nearest: Node2D = null
	var nearest_distance_squared := maximum_distance * maximum_distance
	var center := Vector2i(floori(world_position.x / SPATIAL_CELL_SIZE), floori(world_position.y / SPATIAL_CELL_SIZE))
	var cell_radius := ceili(maximum_distance / SPATIAL_CELL_SIZE)
	for y in range(-cell_radius, cell_radius + 1):
		for x in range(-cell_radius, cell_radius + 1):
			for reference in _spatial_cache.get(center + Vector2i(x, y), []):
				var target := (reference as WeakRef).get_ref() as Node2D
				if not is_instance_valid(target) or not target.has_method("clean_step"): continue
				var distance_squared := target.global_position.distance_squared_to(world_position)
				if distance_squared <= nearest_distance_squared:
					nearest = target
					nearest_distance_squared = distance_squared
	return nearest

func get_nearest_compatible_target(world_position: Vector2, maximum_distance: float, cleanup_types: PackedStringArray) -> Node2D:
	# Prevent unrelated nearby evidence from stealing a tool stroke.
	if cleanup_types.is_empty(): return get_nearest_target(world_position, maximum_distance)
	var candidates := get_targets_in_radius(world_position, maximum_distance, 24, cleanup_types)
	return candidates[0] if not candidates.is_empty() else null

func get_priority_target(world_position: Vector2, maximum_distance: float) -> Node2D:
	var candidates := get_targets_in_radius(world_position, maximum_distance, 64)
	if candidates.is_empty(): return null
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_value := get_evidence_value(a)
		var b_value := get_evidence_value(b)
		if a_value != b_value: return a_value > b_value
		return a.global_position.distance_squared_to(world_position) < b.global_position.distance_squared_to(world_position)
	)
	return candidates[0]

func get_targets_in_radius(world_position: Vector2, maximum_distance: float, maximum_results := 8, cleanup_types: PackedStringArray = PackedStringArray()) -> Array[Node2D]:
	_prune_invalid()
	_refresh_spatial_cache()
	var candidates: Array[Dictionary] = []
	var distance_limit := maximum_distance * maximum_distance
	var center := Vector2i(floori(world_position.x / SPATIAL_CELL_SIZE), floori(world_position.y / SPATIAL_CELL_SIZE))
	var cell_radius := ceili(maximum_distance / SPATIAL_CELL_SIZE)
	var visited := {}
	for y in range(-cell_radius, cell_radius + 1):
		for x in range(-cell_radius, cell_radius + 1):
			for reference in _spatial_cache.get(center + Vector2i(x, y), []):
				var target := (reference as WeakRef).get_ref() as Node2D
				if not is_instance_valid(target) or not target.has_method("clean_step"): continue
				var instance_id := target.get_instance_id()
				if visited.has(instance_id): continue
				visited[instance_id] = true
				var cleanup_type := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else "unknown"
				if not cleanup_types.is_empty() and cleanup_type not in cleanup_types: continue
				var distance_squared := target.global_position.distance_squared_to(world_position)
				if distance_squared <= distance_limit:
					candidates.append({"target": target, "distance_squared": distance_squared})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance_squared) < float(b.distance_squared))
	var results: Array[Node2D] = []
	for candidate in candidates.slice(0, mini(maximum_results, candidates.size())):
		results.append(candidate.target as Node2D)
	return results

func get_area_summary(world_position: Vector2, radius: float) -> Dictionary:
	var targets := get_targets_in_radius(world_position, radius, 128)
	var remaining_value := 0.0
	var total_value := 0.0
	for target in targets:
		var evidence_value := float(get_evidence_value(target))
		var progress := clampf(float(target.get_cleanup_progress()) if target.has_method("get_cleanup_progress") else 0.0, 0.0, 1.0)
		total_value += evidence_value
		remaining_value += evidence_value * (1.0 - progress)
	return {"count": targets.size(), "risk": ceili(remaining_value), "cleanliness": 1.0 if total_value <= 0.0 else clampf(1.0 - remaining_value / total_value, 0.0, 1.0)}

func get_room_summary(world: Node, world_position: Vector2) -> Dictionary:
	if not is_instance_valid(world) or not world.has_method("get_tactical_room_id"): return get_area_summary(world_position, 64.0)
	_prune_invalid()
	var room_id := str(world.get_tactical_room_id(world_position))
	var count := 0
	var remaining_value := 0.0
	var total_value := 0.0
	for instance_id in _evidence_history:
		var record: Dictionary = _evidence_history[instance_id]
		var record_position: Vector2 = record.position
		var target: Node2D = null
		if _targets.has(instance_id):
			target = (_targets[instance_id] as WeakRef).get_ref() as Node2D
			if is_instance_valid(target):
				record_position = target.global_position
				record.position = record_position
		if str(world.get_tactical_room_id(record_position)) != room_id: continue
		var evidence_value := float(record.value)
		total_value += evidence_value
		if bool(record.resolved): continue
		if bool(record.discarded):
			remaining_value += evidence_value
			continue
		if is_instance_valid(target):
			count += 1
			var progress := clampf(float(target.get_cleanup_progress()) if target.has_method("get_cleanup_progress") else 0.0, 0.0, 1.0)
			remaining_value += evidence_value * (1.0 - progress)
		else:
			remaining_value += evidence_value
	return {"room_id": room_id, "count": count, "risk": ceili(remaining_value), "cleanliness": 1.0 if total_value <= 0.0 else clampf(1.0 - remaining_value / total_value, 0.0, 1.0)}

func _refresh_spatial_cache() -> void:
	var bucket := int(Time.get_ticks_msec() / 100)
	if _spatial_cache_bucket == bucket: return
	_spatial_cache_bucket = bucket
	_spatial_cache.clear()
	for reference in _targets.values():
		var target := (reference as WeakRef).get_ref() as Node2D
		if not is_instance_valid(target): continue
		var cell := Vector2i(floori(target.global_position.x / SPATIAL_CELL_SIZE), floori(target.global_position.y / SPATIAL_CELL_SIZE))
		if not _spatial_cache.has(cell): _spatial_cache[cell] = []
		(_spatial_cache[cell] as Array).append(reference)

func get_type_counts() -> Dictionary:
	_prune_invalid()
	var counts := {}
	for reference in _targets.values():
		var target: Node = (reference as WeakRef).get_ref() as Node
		if not is_instance_valid(target): continue
		var type_name := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else "unknown"
		counts[type_name] = int(counts.get(type_name, 0)) + 1
	return counts

func get_initial_value() -> int:
	return _initial_value

func get_remaining_value() -> int:
	_prune_invalid()
	var total := 0.0
	for instance_id in _targets:
		var target := (_targets[instance_id] as WeakRef).get_ref() as Node
		if not is_instance_valid(target): continue
		var progress := clampf(float(target.get_cleanup_progress()) if target.has_method("get_cleanup_progress") else 0.0, 0.0, 1.0)
		total += float(_registered_values.get(instance_id, 1)) * (1.0 - progress)
	return ceili(total)

func get_resolved_value() -> int:
	_prune_invalid()
	return _resolved_value

func get_initial_count() -> int:
	return _initial_count

func get_cleanup_ratio() -> float:
	if _initial_value <= 0: return 1.0
	var cleaned_value := float(_resolved_value)
	for instance_id in _targets:
		var target := (_targets[instance_id] as WeakRef).get_ref() as Node
		if not is_instance_valid(target): continue
		var progress := clampf(float(target.get_cleanup_progress()) if target.has_method("get_cleanup_progress") else 0.0, 0.0, 1.0)
		cleaned_value += float(_registered_values.get(instance_id, 1)) * progress
	return clampf(cleaned_value / float(_initial_value), 0.0, 1.0)

func get_evidence_value(target: Node) -> int:
	if not is_instance_valid(target): return 0
	return int(_registered_values.get(target.get_instance_id(), 0))

func reset() -> void:
	_targets.clear()
	_registered_values.clear()
	_initial_value = 0
	_resolved_value = 0
	_initial_count = 0
	_evidence_history.clear()
	_spatial_cache.clear()
	_spatial_cache_bucket = -1
	target_count_changed.emit(0)

func _on_target_exiting(instance_id: int) -> void:
	_discard_id(instance_id)

func _resolve_id(instance_id: int) -> void:
	if not _targets.erase(instance_id): return
	_resolved_value += int(_registered_values.get(instance_id, 1))
	if _evidence_history.has(instance_id):
		_evidence_history[instance_id].resolved = true
		_evidence_history[instance_id].discarded = false
	_registered_values.erase(instance_id)
	_spatial_cache_bucket = -1
	target_count_changed.emit(get_remaining_count())

func _discard_id(instance_id: int) -> void:
	if not _targets.erase(instance_id): return
	if _evidence_history.has(instance_id): _evidence_history[instance_id].discarded = true
	_registered_values.erase(instance_id)
	_spatial_cache_bucket = -1
	target_count_changed.emit(get_remaining_count())

func _prune_invalid() -> void:
	var stale: Array[int] = []
	for instance_id in _targets:
		var reference := _targets[instance_id] as WeakRef
		if reference == null or not is_instance_valid(reference.get_ref()): stale.append(instance_id)
	for instance_id in stale:
		_discard_id(instance_id)
