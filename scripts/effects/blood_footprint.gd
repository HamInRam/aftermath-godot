class_name BloodFootprint
extends Node2D

var blood_amount := 1.0
var left_foot := true
var cleanup_steps_remaining := 2

func _ready() -> void:
	CleanupRegistry.register_target(self)
	queue_redraw()

func setup(strength: float, is_left_foot: bool) -> void:
	blood_amount = clampf(strength, 0.18, 1.0)
	left_foot = is_left_foot
	cleanup_steps_remaining = get_cleanup_cost()
	queue_redraw()

func clean_step() -> void:
	cleanup_steps_remaining = maxi(0, cleanup_steps_remaining - 1)
	if cleanup_steps_remaining == 0:
		queue_free()
		return
	blood_amount *= 0.45
	queue_redraw()

func get_cleanup_type() -> String:
	return "blood_footprint"

func get_cleanup_cost() -> int:
	return 2

func _draw() -> void:
	var blood := Color(0.47, 0.004, 0.025, 0.88 * blood_amount)
	var dark_blood := Color(0.20, 0.002, 0.012, 0.92 * blood_amount)
	var side := -1.0 if left_foot else 1.0
	draw_rect(Rect2(-2.0, side - 0.75, 2.5, 1.5), dark_blood)
	draw_rect(Rect2(0.25, side - 1.0, 1.75, 2.0), blood)
	draw_rect(Rect2(1.75, side - 0.75, 0.75, 1.5), blood)
