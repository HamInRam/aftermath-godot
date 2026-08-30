extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")
const PIXEL_LIGHTS := preload("res://utility/pixel_light_texture_factory.gd")

var flash_size := 26.0
var duration := 0.045
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.texture = PIXEL_LIGHTS.create_texture()
	light.texture_scale = 1.0
	queue_redraw()
	await get_tree().create_timer(duration, true, false, true).timeout
	queue_free()

func setup(direction: Vector2, size: float, flash_duration: float) -> void:
	rotation = snappedf(direction.angle(), PI / 8.0)
	flash_size = size
	duration = flash_duration

func _draw() -> void:
	PIXELS.line(self, Vector2.ZERO, Vector2(11, -4), Color("ff8a2b"))
	PIXELS.line(self, Vector2.ZERO, Vector2(12, 4), Color("ff8a2b"))
	PIXELS.line(self, Vector2.ZERO, Vector2(13, 0), Color("fff6bf"))
	for point in [Vector2(4,-1),Vector2(5,1),Vector2(7,-2),Vector2(7,2),Vector2(9,-1),Vector2(9,1)]: PIXELS.pixel(self, point, Color("fff0a0"))
