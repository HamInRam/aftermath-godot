extends Node

const LEVEL_SCENE := preload("res://scenes/levels/after_hours.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RuntimeBudget.restore_default_limits()
	PerformanceMonitor.reset_capture()
	var level = LEVEL_SCENE.instantiate()
	level.record_progress = false
	add_child(level)
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	var started_usec := Time.get_ticks_usec()
	for index in range(230):
		level._on_weapon_fired(Vector2(150, 90), Vector2.RIGHT, false, "lmg")
	for index in range(20):
		level.blood_system.emit_hit(Vector2(120 + index % 5, 90), Vector2.RIGHT, 4, "lmg", 40.0, true)
	for index in range(60):
		level.blood_system.spawn_death_pool(Vector2(100 + index % 12, 110 + index % 5), 2.0)
	var generation_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_expect(RuntimeBudget.get_count("shell") <= int(RuntimeBudget.limits.shell), "stress fire must not exceed shell budget")
	_expect(RuntimeBudget.get_count("transient_fx") <= int(RuntimeBudget.limits.transient_fx), "stress fire must not exceed transient-effect budget")
	_expect(RuntimeBudget.get_count("gore") <= int(RuntimeBudget.limits.gore), "lethal effects must not exceed gore budget")
	_expect(RuntimeBudget.get_count("blood_pool") == 0, "pixel death pools must not allocate legacy pool nodes")
	_expect(RuntimeBudget.get_dropped("shell") > 0 and RuntimeBudget.get_dropped("gore") > 0, "stress scene should prove that remaining node hard caps activate")
	_expect(level.blood_system.ground_canvas.chunks.size() < 64, "dense blood should remain inside a bounded sparse-chunk set (got %d)" % level.blood_system.ground_canvas.chunks.size())
	_expect(int(level.blood_system.ground_canvas.get_debug_pixel_count()) < 20000, "dense blood should remain below the room-scale pixel occupancy budget")
	_expect(generation_ms < 5000.0, "stress generation should complete within a broad CI-safe five-second budget")
	for frame in range(12): await get_tree().process_frame
	var report := PerformanceMonitor.get_report()
	_expect(int(report.peak_node_count) < 1800, "stress scene should remain below the 1800-node release budget")
	_expect(int(report.peak_tracked_objects) <= 640, "tracked gameplay objects should remain within the aggregate release budget")
	for audio_node in level.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	CleanupRegistry.reset()
	_expect(RuntimeBudget.get_total_count() == 0, "stress scene teardown should release every budget reservation")
	RuntimeBudget.restore_default_limits()
	if failures == 0: print("performance stress regression: PASS // generated %.1fms // peak nodes %d" % [generation_ms, int(report.peak_node_count)])
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
