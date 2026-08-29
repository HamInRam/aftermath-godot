extends Node2D

var weapon_type := "fist"

func set_weapon(new_type: String) -> void:
	weapon_type = new_type
	queue_redraw()

func _draw() -> void:
	if weapon_type == "fist":
		draw_rect(Rect2(6, -4, 3, 3), NeonPalette.INK)
		draw_rect(Rect2(7, -3, 2, 2), NeonPalette.PAPER)
		draw_rect(Rect2(6, 1, 3, 3), NeonPalette.INK)
		draw_rect(Rect2(7, 1, 2, 2), NeonPalette.PAPER)
	elif weapon_type == "knife":
		draw_line(Vector2(2, 0), Vector2(5, 0), NeonPalette.INK, 3.0)
		draw_line(Vector2(5, 0), Vector2(11, 0), NeonPalette.PAPER, 2.0)
		draw_rect(Rect2(10, -1, 2, 2), NeonPalette.CYAN)
	else:
		draw_line(Vector2(2, 0), Vector2(13, 0), NeonPalette.INK, 4.0)
		draw_line(Vector2(4, 0), Vector2(12, 0), Color("a95a35"), 2.0)
		draw_rect(Rect2(1, -2, 4, 4), NeonPalette.DEEP_SHADOW)
		draw_rect(Rect2(11, -1, 2, 2), NeonPalette.MAGENTA)
