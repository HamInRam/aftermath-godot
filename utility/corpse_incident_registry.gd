extends Node

const MERGE_RADIUS := 48.0

var _owners: Dictionary = {}
var _completed: Dictionary = {}

func try_claim(corpse: Node2D, investigator: Node) -> bool:
	if not is_instance_valid(corpse) or not is_instance_valid(investigator): return false
	var cluster := _get_cluster(corpse)
	if _cluster_completed(cluster): return false
	var owner := _cluster_owner(cluster)
	if is_instance_valid(owner): return owner == investigator
	for member in cluster: _owners[member.get_instance_id()] = weakref(investigator)
	return true

func complete(corpse: Node2D, investigator: Node) -> void:
	if not is_instance_valid(corpse) or _cluster_owner(_get_cluster(corpse)) != investigator: return
	for member in _get_cluster(corpse):
		var instance_id := member.get_instance_id()
		_completed[instance_id] = true
		_owners.erase(instance_id)

func release(corpse: Node2D, investigator: Node) -> void:
	if not is_instance_valid(corpse): return
	for member in _get_cluster(corpse):
		var instance_id := member.get_instance_id()
		var owner := _owner_for_id(instance_id)
		if owner == investigator: _owners.erase(instance_id)

func has_active_investigator(corpse: Node2D) -> bool:
	return is_instance_valid(_cluster_owner(_get_cluster(corpse)))

func is_complete(corpse: Node2D) -> bool:
	return _cluster_completed(_get_cluster(corpse))

func unregister_corpse(corpse: Node2D) -> void:
	if not is_instance_valid(corpse): return
	var instance_id := corpse.get_instance_id()
	_owners.erase(instance_id)
	_completed.erase(instance_id)

func reset() -> void:
	_owners.clear()
	_completed.clear()

func _get_cluster(origin: Node2D) -> Array[Node2D]:
	var corpses: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("corpse"):
		if is_instance_valid(node) and node is Node2D: corpses.append(node)
	var cluster: Array[Node2D] = [origin]
	var visited := {origin.get_instance_id(): true}
	var cursor := 0
	while cursor < cluster.size():
		var current := cluster[cursor]
		cursor += 1
		for candidate in corpses:
			var candidate_id := candidate.get_instance_id()
			if visited.has(candidate_id): continue
			if current.global_position.distance_to(candidate.global_position) <= MERGE_RADIUS:
				visited[candidate_id] = true
				cluster.append(candidate)
	return cluster

func _cluster_completed(cluster: Array[Node2D]) -> bool:
	for member in cluster:
		if bool(_completed.get(member.get_instance_id(), false)):
			for linked in cluster: _completed[linked.get_instance_id()] = true
			return true
	return false

func _cluster_owner(cluster: Array[Node2D]) -> Node:
	for member in cluster:
		var owner := _owner_for_id(member.get_instance_id())
		if is_instance_valid(owner):
			for linked in cluster: _owners[linked.get_instance_id()] = weakref(owner)
			return owner
	return null

func _owner_for_id(instance_id: int) -> Node:
	var reference := _owners.get(instance_id) as WeakRef
	if reference == null: return null
	var owner := reference.get_ref() as Node
	if not is_instance_valid(owner) or bool(owner.get("is_dead")):
		_owners.erase(instance_id)
		return null
	return owner
