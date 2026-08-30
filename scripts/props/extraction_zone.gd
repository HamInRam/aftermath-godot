class_name ExtractionZone
extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

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
	for y in range(-12, 13):
		for x in range(-12, 13):
			if x * x + y * y <= 144 and ((x * 3 + y * 5 + floori(pulse * 5.0)) & 7) == 0: PIXELS.pixel(self, Vector2(x, y), Color(0.08, 0.85, 0.72, 0.16))
	PIXELS.circle(self, Vector2.ZERO, 13, Color(0.35, 1.0, 0.82, glow), true)
	PIXELS.line(self, Vector2(-5, 0), Vector2(5, 0), Color(0.55, 1.0, 0.88, 0.8))
	PIXELS.line(self, Vector2(2, -3), Vector2(5, 0), Color(0.55, 1.0, 0.88, 0.8))
	PIXELS.line(self, Vector2(2, 3), Vector2(5, 0), Color(0.55, 1.0, 0.88, 0.8))
