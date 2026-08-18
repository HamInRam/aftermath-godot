class_name RuntimeBudgetManager
extends Node

signal budget_exhausted(category: String, limit: int)

const DEFAULT_LIMITS := {
	"bullet": 128,
	"shell": 128,
	"transient_fx": 96,
	"blood_stain": 128,
	"blood_pool": 48,
	"gore": 128,
	"footprint": 96,
	"corpse": 48,
	"weapon_pickup": 64,
	"ammo_pickup": 32,
	"thrown_weapon": 24,
	"debris": 48,
}

var limits: Dictionary = DEFAULT_LIMITS.duplicate()
var _active: Dictionary = {}
var _peaks: Dictionary = {}
var _dropped: Dictionary = {}

func try_add(category: String, node: Node, parent: Node) -> bool:
	if not is_instance_valid(node) or not is_instance_valid(parent):
		if is_instance_valid(node): node.free()
		return false
	var limit := int(limits.get(category, 0))
	if limit <= 0 or get_count(category) >= limit:
		_dropped[category] = int(_dropped.get(category, 0)) + 1
		budget_exhausted.emit(category, limit)
		node.free()
		return false
	if not _active.has(category): _active[category] = {}
	var instance_id := node.get_instance_id()
	(_active[category] as Dictionary)[instance_id] = true
	_peaks[category] = maxi(int(_peaks.get(category, 0)), get_count(category))
	node.tree_exiting.connect(_release.bind(category, instance_id), CONNECT_ONE_SHOT)
	parent.add_child(node)
	return true

func get_count(category: String) -> int:
	return (_active.get(category, {}) as Dictionary).size()

func get_peak(category: String) -> int:
	return int(_peaks.get(category, 0))

func get_dropped(category: String) -> int:
	return int(_dropped.get(category, 0))

func get_total_count() -> int:
	var total := 0
	for category in _active: total += (_active[category] as Dictionary).size()
	return total

func get_total_dropped() -> int:
	var total := 0
	for category in _dropped: total += int(_dropped[category])
	return total

func get_snapshot() -> Dictionary:
	var snapshot := {}
	for category in limits:
		snapshot[category] = {
			"active": get_count(category),
			"peak": get_peak(category),
			"limit": int(limits[category]),
			"dropped": get_dropped(category),
		}
	return snapshot

func reset_metrics() -> void:
	_peaks.clear()
	_dropped.clear()

func override_limits_for_test(new_limits: Dictionary) -> void:
	limits = DEFAULT_LIMITS.duplicate()
	for category in new_limits: limits[category] = maxi(0, int(new_limits[category]))
	reset_metrics()

func restore_default_limits() -> void:
	limits = DEFAULT_LIMITS.duplicate()
	reset_metrics()

func _release(category: String, instance_id: int) -> void:
	if not _active.has(category): return
	(_active[category] as Dictionary).erase(instance_id)
