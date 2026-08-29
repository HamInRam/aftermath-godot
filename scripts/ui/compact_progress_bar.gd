class_name CompactProgressBar
extends Control

var max_value := 100.0:
	set(next):
		max_value = maxf(0.001, next)
		queue_redraw()
var value := 0.0:
	set(next):
		value = clampf(next, 0.0, max_value)
		queue_redraw()
var show_percentage := false

func _draw() -> void:
	# A code-drawn bar has no font/theme minimum, so one authored world pixel
	# remains exactly one pixel before integer viewport scaling.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.035, 0.05, 0.48), true)
	var ratio := clampf(value / max_value, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(floorf(size.x * ratio), size.y)), Color.WHITE, true)
