extends Node2D

var weapon_type := "fist"

func set_weapon(new_type: String) -> void:
	weapon_type = new_type
	queue_redraw()

func _draw() -> void:
	if weapon_type == "fist":
		draw_circle(Vector2(7, -2), 1.7, Color("ffffff"))
		draw_circle(Vector2(7, 2), 1.7, Color("ffffff"))
	elif weapon_type == "knife":
		draw_line(Vector2(3, 0), Vector2(10, 0), Color("00ffff"), 2.0)
		draw_line(Vector2(3, 0), Vector2(1, 2), Color("412e46"), 2.0)
	else:
		draw_line(Vector2(3, 0), Vector2(12, 0), Color("ff007f"), 3.0)
		draw_rect(Rect2(1, -2, 3, 4), Color("44283f"))
