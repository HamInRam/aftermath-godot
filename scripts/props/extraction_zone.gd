class_name ExtractionZone
extends Node2D

var active := false
var pulse := 0.0

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	set_process(enabled)
	queue_redraw()

func contains_position(world_position: Vector2, radius := 18.0) -> bool:
	return active and global_position.distance_to(world_position) <= radius

func _draw() -> void:
	if not active: return
	var glow := 0.48 + sin(pulse * 3.2) * 0.12
	draw_circle(Vector2.ZERO, 13.0, Color(0.08, 0.85, 0.72, 0.08))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(0.35, 1.0, 0.82, glow), 1.5)
	draw_line(Vector2(-5, 0), Vector2(5, 0), Color(0.55, 1.0, 0.88, 0.8), 1.0)
	draw_line(Vector2(2, -3), Vector2(5, 0), Color(0.55, 1.0, 0.88, 0.8), 1.0)
	draw_line(Vector2(2, 3), Vector2(5, 0), Color(0.55, 1.0, 0.88, 0.8), 1.0)
