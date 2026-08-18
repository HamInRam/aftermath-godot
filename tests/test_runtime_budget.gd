extends Node

var failures := 0

func _ready() -> void:
	RuntimeBudget.override_limits_for_test({"shell": 3})
	var accepted: Array[Node] = []
	for index in range(6):
		var node := Node.new()
		if RuntimeBudget.try_add("shell", node, self): accepted.append(node)
	_expect(accepted.size() == 3, "runtime budget should accept only the configured category limit")
	_expect(RuntimeBudget.get_count("shell") == 3 and RuntimeBudget.get_peak("shell") == 3, "runtime budget should track active and peak counts")
	_expect(RuntimeBudget.get_dropped("shell") == 3, "runtime budget should count denied instances")
	for node in accepted: node.queue_free()
	await get_tree().process_frame
	_expect(RuntimeBudget.get_count("shell") == 0, "tree exit should release every category reservation")
	RuntimeBudget.restore_default_limits()
	PerformanceMonitor.reset_capture()
	for frame in range(4): await get_tree().process_frame
	var report := PerformanceMonitor.get_report()
	_expect(report.has("p95_frame_ms") and report.has("peak_node_count") and report.has("categories"), "performance monitor should expose an auditable report")
	if failures == 0: print("runtime budget regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
