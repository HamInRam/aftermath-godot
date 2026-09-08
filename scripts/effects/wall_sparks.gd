extends GPUParticles2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pixel_texture := PixelGPUParticles2D.create_one_pixel_texture()
	texture = pixel_texture
	for child in get_children():
		if child is GPUParticles2D:
			child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			child.texture = pixel_texture
			child.restart()
	finished.connect(queue_free)
	restart()

func setup(incoming_direction: Vector2) -> void:
	rotation = snappedf(incoming_direction.angle() + PI, PI / 8.0)
