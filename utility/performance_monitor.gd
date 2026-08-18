class_name PerformanceMonitorService
extends Node

const MAX_FRAME_SAMPLES := 600

var frame_times_ms := PackedFloat32Array()
var peak_node_count := 0
var peak_tracked_objects := 0

func _process(delta: float) -> void:
	frame_times_ms.append(delta * 1000.0)
	if frame_times_ms.size() > MAX_FRAME_SAMPLES: frame_times_ms.remove_at(0)
	peak_node_count = maxi(peak_node_count, roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_tracked_objects = maxi(peak_tracked_objects, RuntimeBudget.get_total_count())

func reset_capture() -> void:
	frame_times_ms.clear()
	peak_node_count = 0
	peak_tracked_objects = 0
	RuntimeBudget.reset_metrics()

func get_average_frame_ms() -> float:
	if frame_times_ms.is_empty(): return 0.0
	var total := 0.0
	for value in frame_times_ms: total += value
	return total / frame_times_ms.size()

func get_percentile_frame_ms(percentile := 0.95) -> float:
	if frame_times_ms.is_empty(): return 0.0
	var sorted := Array(frame_times_ms)
	sorted.sort()
	var index := clampi(ceili(clampf(percentile, 0.0, 1.0) * sorted.size()) - 1, 0, sorted.size() - 1)
	return float(sorted[index])

func get_report() -> Dictionary:
	return {
		"average_frame_ms": get_average_frame_ms(),
		"p95_frame_ms": get_percentile_frame_ms(0.95),
		"peak_node_count": peak_node_count,
		"peak_tracked_objects": peak_tracked_objects,
		"budget_drops": RuntimeBudget.get_total_dropped(),
		"categories": RuntimeBudget.get_snapshot(),
	}

func get_debug_line() -> String:
	return "PERF // AVG %.1fms  P95 %.1fms  NODES %d  TRACKED %d" % [get_average_frame_ms(), get_percentile_frame_ms(), peak_node_count, RuntimeBudget.get_total_count()]
