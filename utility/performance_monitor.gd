class_name PerformanceMonitorService
extends Node

const MAX_FRAME_SAMPLES := 600

var frame_times_ms := PackedFloat32Array()
var frame_cursor := 0
var frame_sample_count := 0
var peak_node_count := 0
var peak_tracked_objects := 0
var peak_draw_calls := 0
var peak_render_objects := 0
var peak_video_memory_bytes := 0

func _ready() -> void:
	frame_times_ms.resize(MAX_FRAME_SAMPLES)
	frame_times_ms.fill(0.0)

func _process(delta: float) -> void:
	# Fixed ring storage avoids shifting a 600-entry PackedFloat32Array every frame.
	frame_times_ms[frame_cursor] = delta * 1000.0
	frame_cursor = (frame_cursor + 1) % MAX_FRAME_SAMPLES
	frame_sample_count = mini(MAX_FRAME_SAMPLES, frame_sample_count + 1)
	peak_node_count = maxi(peak_node_count, roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_tracked_objects = maxi(peak_tracked_objects, RuntimeBudget.get_total_count())
	peak_draw_calls = maxi(peak_draw_calls, roundi(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_render_objects = maxi(peak_render_objects, roundi(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	peak_video_memory_bytes = maxi(peak_video_memory_bytes, roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))

func reset_capture() -> void:
	if frame_times_ms.size() != MAX_FRAME_SAMPLES: frame_times_ms.resize(MAX_FRAME_SAMPLES)
	frame_times_ms.fill(0.0)
	frame_cursor = 0
	frame_sample_count = 0
	peak_node_count = 0
	peak_tracked_objects = 0
	peak_draw_calls = 0
	peak_render_objects = 0
	peak_video_memory_bytes = 0
	RuntimeBudget.reset_metrics()

func get_average_frame_ms() -> float:
	if frame_sample_count <= 0: return 0.0
	var total := 0.0
	for index in range(frame_sample_count): total += frame_times_ms[index]
	return total / float(frame_sample_count)

func get_percentile_frame_ms(percentile := 0.95) -> float:
	if frame_sample_count <= 0: return 0.0
	var sorted: Array[float] = []
	sorted.resize(frame_sample_count)
	for index in range(frame_sample_count): sorted[index] = frame_times_ms[index]
	sorted.sort()
	var index := clampi(ceili(clampf(percentile, 0.0, 1.0) * sorted.size()) - 1, 0, sorted.size() - 1)
	return float(sorted[index])

func get_report() -> Dictionary:
	return {
		"average_frame_ms": get_average_frame_ms(),
		"p95_frame_ms": get_percentile_frame_ms(0.95),
		"peak_node_count": peak_node_count,
		"peak_tracked_objects": peak_tracked_objects,
		"peak_draw_calls": peak_draw_calls,
		"peak_render_objects": peak_render_objects,
		"peak_video_memory_bytes": peak_video_memory_bytes,
		"budget_drops": RuntimeBudget.get_total_dropped(),
		"categories": RuntimeBudget.get_snapshot(),
	}

func get_debug_line() -> String:
	return "PERF %.1f/%.1fMS // DRAW %d // NODE %d // FX %d" % [get_average_frame_ms(), get_percentile_frame_ms(), peak_draw_calls, peak_node_count, RuntimeBudget.get_total_count()]
