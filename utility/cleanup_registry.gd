extends Node

signal target_count_changed(remaining: int)

var _targets: Dictionary = {}

func register_target(target: Node) -> void:
	if not is_instance_valid(target): return
	var instance_id := target.get_instance_id()
	if _targets.has(instance_id): return
	_targets[instance_id] = weakref(target)
	target.tree_exiting.connect(_on_target_exiting.bind(instance_id), CONNECT_ONE_SHOT)
	target_count_changed.emit(get_remaining_count())

func unregister_target(target: Node) -> void:
	if not is_instance_valid(target): return
	_remove_id(target.get_instance_id())

func get_remaining_count() -> int:
	_prune_invalid()
	return _targets.size()

func get_nearest_target(world_position: Vector2, maximum_distance: float) -> Node2D:
	_prune_invalid()
	var nearest: Node2D = null
	var nearest_distance_squared := maximum_distance * maximum_distance
	for reference in _targets.values():
		var target := (reference as WeakRef).get_ref() as Node2D
		if not is_instance_valid(target) or not target.has_method("clean_step"): continue
		var distance_squared := target.global_position.distance_squared_to(world_position)
		if distance_squared <= nearest_distance_squared:
			nearest = target
			nearest_distance_squared = distance_squared
	return nearest

func get_type_counts() -> Dictionary:
	_prune_invalid()
	var counts := {}
	for reference in _targets.values():
		var target: Node = (reference as WeakRef).get_ref() as Node
		if not is_instance_valid(target): continue
		var type_name := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else "unknown"
		counts[type_name] = int(counts.get(type_name, 0)) + 1
	return counts

func reset() -> void:
	_targets.clear()
	target_count_changed.emit(0)

func _on_target_exiting(instance_id: int) -> void:
	_remove_id(instance_id)

func _remove_id(instance_id: int) -> void:
	if not _targets.erase(instance_id): return
	target_count_changed.emit(get_remaining_count())

func _prune_invalid() -> void:
	var stale: Array[int] = []
	for instance_id in _targets:
		var reference := _targets[instance_id] as WeakRef
		if reference == null or not is_instance_valid(reference.get_ref()): stale.append(instance_id)
	for instance_id in stale: _targets.erase(instance_id)
