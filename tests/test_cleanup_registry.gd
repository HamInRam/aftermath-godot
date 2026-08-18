extends Node

class DummyCleanupTarget:
	extends Node2D
	var steps := 2
	func _ready() -> void: CleanupRegistry.register_target(self)
	func clean_step() -> void:
		steps -= 1
		if steps <= 0: queue_free()
	func get_cleanup_type() -> String: return "dummy"
	func get_cleanup_cost() -> int: return 2

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	CleanupRegistry.reset()
	var first := DummyCleanupTarget.new()
	var second := DummyCleanupTarget.new()
	add_child(first)
	add_child(second)
	first.global_position = Vector2.ZERO
	second.global_position = Vector2(20, 0)
	_expect(CleanupRegistry.get_remaining_count() == 2, "all cleanup types should share one registry")
	_expect(CleanupRegistry.get_initial_count() == 2 and CleanupRegistry.get_initial_value() == 2, "registry should snapshot initial evidence count and value")
	_expect(CleanupRegistry.get_nearest_target(Vector2(2, 0), 10.0) == first, "registry should select the nearest target")
	first.clean_step()
	first.clean_step()
	await get_tree().process_frame
	_expect(CleanupRegistry.get_remaining_count() == 1, "freed cleanup targets should unregister automatically")
	_expect(CleanupRegistry.get_remaining_value() == 1 and CleanupRegistry.get_resolved_value() == 1, "registry should separate remaining and resolved evidence value")
	_expect(is_equal_approx(CleanupRegistry.get_cleanup_ratio(), 0.5), "cleanup ratio should be value-weighted")
	_expect(int(CleanupRegistry.get_type_counts().get("dummy", 0)) == 1, "registry should expose remaining target types")
	if failures == 0: print("cleanup registry regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
