class_name CleaningWetMark
extends Node2D

var lifetime := 2.8
var age := 0.0
var stroke_length := 12.0

func setup(direction: Vector2, strength: float) -> void:
	rotation = direction.angle() if direction.length_squared() > 0.01 else 0.0
	stroke_length = lerpf(8.0, 18.0, clampf(strength, 0.0, 1.25) / 1.25)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var fade := 1.0 - age / lifetime
	draw_line(Vector2(-stroke_length * 0.5, -2.0), Vector2(stroke_length * 0.5, -2.0), Color(0.52, 0.76, 0.82, 0.13 * fade), 3.0)
	draw_line(Vector2(-stroke_length * 0.5, 2.0), Vector2(stroke_length * 0.5, 2.0), Color(0.78, 0.22, 0.28, 0.12 * fade), 2.0)
