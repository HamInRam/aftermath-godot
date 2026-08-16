extends Node2D

func setup(facing: float) -> void:
	rotation = facing + randf_range(-0.35, 0.35)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-5, -2, 10, 4), Color("1b171e"))
	draw_rect(Rect2(-3, -2, 6, 4), Color("7c235b"))
	draw_circle(Vector2(4, 0), 2.0, Color("a87168"))
	draw_rect(Rect2(-6, -3, 3, 2), Color("302331"))
	draw_rect(Rect2(-6, 1, 3, 2), Color("302331"))
