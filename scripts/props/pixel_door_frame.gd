extends StaticBody2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	var ink := Color("17131b")
	var trim := Color("4b3446")
	PIXELS.material_panel(self, Rect2(-3, -3, 6, 3), ink, trim, trim.lightened(0.2), trim.darkened(0.2), 25, &"metal")
	PIXELS.material_panel(self, Rect2(-3, 16, 6, 3), ink, trim, trim.lightened(0.2), trim.darkened(0.2), 26, &"metal")
