extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var weapon_type := "fist"

func set_weapon(new_type: String) -> void:
	weapon_type = new_type
	queue_redraw()

func _draw() -> void:
	if weapon_type == "fist":
		PIXEL_PAINTER.material_panel(self, Rect2(6, -4, 3, 3), NeonPalette.INK, NeonPalette.PAPER, Color.WHITE, NeonPalette.PAPER.darkened(0.2), 3)
		PIXEL_PAINTER.material_panel(self, Rect2(6, 1, 3, 3), NeonPalette.INK, NeonPalette.PAPER, Color.WHITE, NeonPalette.PAPER.darkened(0.2), 5)
	elif weapon_type == "knife":
		PIXEL_PAINTER.material_line(self, Vector2(2, 0), Vector2(5, 0), NeonPalette.INK, 3, 7, &"grain")
		PIXEL_PAINTER.line(self, Vector2(5, 0), Vector2(11, 0), NeonPalette.PAPER)
		PIXEL_PAINTER.pixel(self, Vector2(10, -1), NeonPalette.CYAN)
	else:
		PIXEL_PAINTER.material_line(self, Vector2(2, 0), Vector2(13, 0), NeonPalette.INK, 3, 11, &"wood")
		PIXEL_PAINTER.line(self, Vector2(4, 0), Vector2(12, 0), Color("a95a35"))
		PIXEL_PAINTER.material_block(self, Vector2(2, 0), Vector2(4, 4), NeonPalette.DEEP_SHADOW, 13, &"grain")
		PIXEL_PAINTER.pixel(self, Vector2(11, -1), NeonPalette.MAGENTA)
