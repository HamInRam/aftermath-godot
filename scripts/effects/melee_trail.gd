extends Node2D

var radius := 30.0
var arc_angle := PI * 0.5
var trail_color := Color.WHITE
var life := 0.14
var age := 0.0

func setup(new_radius: float, new_arc_angle: float, new_color: Color) -> void:
	radius = new_radius
	arc_angle = new_arc_angle
	trail_color = new_color
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha := pow(1.0 - age / life, 1.7)
	var start_angle := -arc_angle * 0.5
	var end_angle := arc_angle * 0.5
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 18, Color(trail_color, alpha), 2.2)
	draw_arc(Vector2.ZERO, radius - 3.0, start_angle + 0.04, end_angle - 0.04, 18, Color(trail_color, alpha * 0.35), 1.0)
