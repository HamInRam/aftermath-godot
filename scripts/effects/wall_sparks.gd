extends GPUParticles2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = PixelGPUParticles2D.create_one_pixel_texture()
	finished.connect(queue_free)
	restart()

func setup(incoming_direction: Vector2) -> void:
	rotation = snappedf(incoming_direction.angle() + PI, PI / 8.0)
