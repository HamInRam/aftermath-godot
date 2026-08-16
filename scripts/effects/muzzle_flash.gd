extends Node2D

var flash_size := 26.0
var duration := 0.045
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.82, 0.35, 0.95))
	gradient.set_color(1, Color(1.0, 0.35, 0.08, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	light.texture = texture
	light.texture_scale = flash_size / 32.0
	queue_redraw()
	await get_tree().create_timer(duration, true, false, true).timeout
	queue_free()

func setup(direction: Vector2, size: float, flash_duration: float) -> void:
	rotation = direction.angle()
	flash_size = size
	duration = flash_duration

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(11, -4), Vector2(8, 0), Vector2(12, 4)]), Color("ff8a2b"))
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(8, -2), Vector2(13, 0), Vector2(8, 2)]), Color("fff6bf"))
