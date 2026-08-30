extends Node

const RIG_SCRIPT := preload("res://scripts/visuals/lifecycle_physics_rig_2d.gd")
var failures := 0

func _ready() -> void:
	var idle_rig = RIG_SCRIPT.new()
	add_child(idle_rig)
	for frame in range(60):
		idle_rig.update_lifecycle(1.0 / 60.0, Vector2.ZERO, 100.0)
	var idle_counters: Dictionary = idle_rig.get_performance_counters()
	_expect(int(idle_counters.simulation_steps) <= 31, "idle living rigs must not solve above 30 Hz")
	_expect(int(idle_counters.redraw_requests) <= 13, "idle living rigs must reuse their draw list between animation beats")

	var moving_rig = RIG_SCRIPT.new()
	add_child(moving_rig)
	for frame in range(60):
		moving_rig.update_lifecycle(1.0 / 60.0, Vector2(90, 0), 100.0)
	var moving_counters: Dictionary = moving_rig.get_performance_counters()
	_expect(int(moving_counters.simulation_steps) <= 31, "moving living rigs must use a pixel-authentic 30 Hz solve cadence")
	_expect(int(moving_counters.redraw_requests) <= 31, "moving living rigs must cap draw-list rebuilds at 30 Hz")

	var reactive_rig = RIG_SCRIPT.new()
	add_child(reactive_rig)
	reactive_rig.apply_hit(Vector2.RIGHT, 18.0, "torso")
	for frame in range(8):
		reactive_rig.update_lifecycle(1.0 / 60.0, Vector2.ZERO, 100.0)
	var reactive_counters: Dictionary = reactive_rig.get_performance_counters()
	_expect(int(reactive_counters.simulation_steps) >= 7, "fresh impacts must retain responsive 60 Hz secondary physics")

	idle_rig.queue_free()
	moving_rig.queue_free()
	reactive_rig.queue_free()
	if failures == 0: print("runtime cadence regression: PASS")
	else: push_error("runtime cadence regression: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
