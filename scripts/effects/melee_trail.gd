extends Node2D

var radius := 30.0
var arc_angle := PI * 0.5
var trail_color := Color.WHITE
var life := 0.14
var age := 0.0
var effect_type := "fist"

func setup(new_type: String, new_radius: float, new_arc_angle: float, new_life: float, new_color: Color) -> void:
	effect_type = new_type
	radius = new_radius
	arc_angle = new_arc_angle
	life = new_life
	trail_color = new_color
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - age / life
	var start_angle := -arc_angle * 0.5
	var end_angle := arc_angle * 0.5
	if effect_type == "fist":
		var punch_color := Color(trail_color, alpha * 0.20)
		draw_line(Vector2(4, -1), Vector2.RIGHT.rotated(start_angle) * radius, punch_color, 1.0)
		draw_line(Vector2(4, 1), Vector2.RIGHT.rotated(end_angle) * radius, punch_color, 1.0)
	elif effect_type == "knife":
		var knife_color := Color(trail_color, alpha * 0.90)
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 8, knife_color, 1.5)
		draw_line(Vector2(4, 0), Vector2.RIGHT.rotated(end_angle) * radius, Color(trail_color, alpha * 0.55), 1.0)
	else:
		var bat_fill := Color(trail_color, alpha * 0.30)
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 16, bat_fill, 5.0)
		var bat_edge := Color(trail_color, alpha * 0.72)
		draw_line(Vector2(4, 0), Vector2.RIGHT.rotated(start_angle) * radius, bat_edge, 2.0)
		draw_line(Vector2(4, 0), Vector2.RIGHT.rotated(end_angle) * radius, bat_edge, 2.0)
